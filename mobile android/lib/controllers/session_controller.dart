// Сессия пользователя: состояние входа, токены, профиль, уровень.
//
// Реальный флоу бэкенда (server/src/modules/auth):
//   1. POST /auth/register — токенов НЕ выдаёт, только отправляет код;
//   2. POST /auth/verify-email {email, code} — выдаёт пару токенов;
//   3. POST /auth/login — только для подтверждённых аккаунтов;
//   4. POST /auth/refresh — ротация: старый refresh становится невалидным,
//      поэтому клиент обязан сразу сохранить новую пару.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../core/api_client.dart';
import '../models/api_models.dart';
import '../services/app_storage.dart';

enum SessionStatus {
  /// Инициализация хранилища.
  starting,

  /// Пробуем тихо войти по refresh-токену.
  restoring,

  signedIn,
  signedOut,
}

class SessionController extends ChangeNotifier {
  SessionController({AppStorage? storage})
      : storage = storage ?? AppStorage.instance {
    client = ApiClient(baseUrl: this.storage.baseUrl);
    client.onUnauthorized = _refreshAccessToken;
    client.onSessionExpired = _handleSessionExpired;
    api = SupFunApi(client);
  }

  final AppStorage storage;
  late final ApiClient client;
  late final SupFunApi api;

  SessionStatus _status = SessionStatus.starting;
  SessionStatus get status => _status;

  AppUser? _user;
  AppUser? get user => _user;

  LevelInfo _level = LevelInfo.empty();
  LevelInfo get level => _level;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  /// true, если данные не удалось обновить с сервера (работаем из кеша).
  bool _offline = false;
  bool get isOffline => _offline;

  bool get isAuthenticated => _status == SessionStatus.signedIn;
  bool get isResuming => _status == SessionStatus.restoring;

  String get baseUrl => client.baseUrl;

  /// Стартовое восстановление сессии.
  Future<void> bootstrap() async {
    await storage.init();
    client.baseUrl = storage.baseUrl;
    final refreshToken = await storage.readRefreshToken();
    _user = storage.cachedUser;
    if (refreshToken == null || refreshToken.isEmpty) {
      _setStatus(SessionStatus.signedOut);
      return;
    }
    _setStatus(SessionStatus.restoring);
    final session = await _callRefresh(refreshToken);
    if (session == null) {
      if (_offline && _user != null) {
        // Нет связи — оставляем пользователя в приложении из кеша (ТЗ §29).
        _setStatus(SessionStatus.signedIn);
        return;
      }
      await storage.clearTokens();
      _user = null;
      _setStatus(SessionStatus.signedOut);
      return;
    }
    await _applySession(session);
    _setStatus(SessionStatus.signedIn);
    unawaited(refreshProfile());
  }

  Future<void> login(String email, String password) async {
    _run(() async {
      final session = await api.auth.login(email, password);
      await _applySession(session);
      await storage.setLastEmail(email);
      _setStatus(SessionStatus.signedIn);
      unawaited(refreshProfile());
    });
  }

  /// Шаг 1 регистрации: сервер шлёт код на email.
  Future<String> register({
    required String name,
    required String email,
    required String password,
    String? city,
  }) async {
    return _runQuiet(() => api.auth.register(
          name: name,
          email: email,
          password: password,
          city: city,
        ));
  }

  /// Шаг 2: подтверждение email — сразу вход в приложение.
  Future<void> verifyEmail(String email, String code) async {
    _run(() async {
      final session = await api.auth.verifyEmail(email, code);
      await _applySession(session);
      await storage.setLastEmail(email);
      _setStatus(SessionStatus.signedIn);
      unawaited(refreshProfile());
    });
  }

  Future<void> resendVerification() =>
      _runQuiet(() => api.auth.resendVerification());

  Future<void> forgotPassword(String email) =>
      _runQuiet(() => api.auth.forgotPassword(email));

  Future<void> resetPassword(
          {required String email,
          required String code,
          required String password}) =>
      _runQuiet(() => api.auth
          .resetPassword(email: email, code: code, password: password));

  Future<void> logout() async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await api.auth.logout(refreshToken);
      } catch (e) {
        debugPrint('logout notify failed: $e');
      }
    }
    await storage.clearTokens();
    client.accessToken = null;
    _user = null;
    _level = LevelInfo.empty();
    _setStatus(SessionStatus.signedOut);
  }

  Future<void> setBaseUrl(String url) async {
    var value = url.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    await storage.setBaseUrl(value);
    client.baseUrl = value;
    notifyListeners();
  }

  Future<void> resetBaseUrl() async {
    await storage.resetBaseUrl();
    client.baseUrl = storage.baseUrl;
    notifyListeners();
  }

  /// Профиль + уровень; ошибки не показываются — экраны живут своими загрузками.
  Future<void> refreshProfile() async {
    try {
      final results = await Future.wait([
        api.users.me(),
        api.gamification.me(),
      ]);
      _user = results[0] as AppUser;
      _level = results[1] as LevelInfo;
      await storage.saveUser(_user!);
      _offline = false;
      _error = null;
    } on ApiException catch (e) {
      if (e.isNetwork) {
        _offline = true;
      } else if (e.isUnauthorized) {
        return;
      } else {
        _error = e.message;
      }
    }
    notifyListeners();
  }

  void applyUser(AppUser updated) {
    _user = updated;
    storage.saveUser(updated);
    notifyListeners();
  }

  void applyLevel(LevelInfo info) {
    _level = info;
    notifyListeners();
  }

  // ------------------------------------------------------------------- служебное

  void _setStatus(SessionStatus value) {
    _status = value;
    notifyListeners();
  }

  Future<void> _applySession(AuthSession session) async {
    client.accessToken = session.accessToken;
    await storage.saveTokens(session.accessToken, session.refreshToken);
    _user = session.user;
    await storage.saveUser(session.user);
    _offline = false;
    _error = null;
    notifyListeners();
  }

  /// Хук ApiClient.onUnauthorized.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final session = await _callRefresh(refreshToken);
    return session?.accessToken;
  }

  Future<AuthSession?> _callRefresh(String refreshToken) async {
    try {
      // Отдельный клиент без хука, чтобы не зациклить повтор на 401.
      final bare = ApiClient(baseUrl: client.baseUrl);
      final session = await SupFunApi(bare).auth.refresh(refreshToken);
      bare.close();
      await _applySession(session);
      _offline = false;
      return session;
    } on ApiException catch (e) {
      if (e.isNetwork) {
        _offline = true;
        notifyListeners();
        return null;
      }
      return null;
    }
  }

  void _handleSessionExpired() {
    if (_status != SessionStatus.signedIn) return;
    storage.clearTokens();
    client.accessToken = null;
    _user = null;
    _error = 'Сессия истекла, войдите заново';
    _setStatus(SessionStatus.signedOut);
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Что-то пошло не так. Попробуйте ещё раз.';
      debugPrint('session error: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<T> _runQuiet<T>(Future<T> Function() action) => action();
}
