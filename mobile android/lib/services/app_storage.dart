// Локальное хранилище клиента.
//
// Hive — настройки и кеш профиля; flutter_secure_storage — токены
// (refresh-токен даёт полный доступ к аккаунту, поэтому его нельзя
// хранить в обычном SharedPreferences/Hive).
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/api_models.dart';

class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  static const _settingsBox = 'settings';
  static const _keyBaseUrl = 'api_base_url';
  static const _keyUser = 'cached_user';
  static const _keyLastEmail = 'last_email';
  static const _keyOnboarded = 'onboarded';
  static const _keyChecklist = 'prestart_checklist';
  static const _keyMapLayers = 'map_layers';

  static const _secureAccess = 'access_token';
  static const _secureRefresh = 'refresh_token';

  /// Значение по умолчанию: 10.0.2.2 — хостовая машина для Android-эмулятора.
  static const defaultBaseUrl = 'http://10.0.2.2:3000/api';

  late Box _settings;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _settings = await Hive.openBox(_settingsBox);
    _ready = true;
  }

  // --------------------------------------------------------------- api base url

  String get baseUrl {
    if (!_ready) return defaultBaseUrl;
    return _settings.get(_keyBaseUrl) as String? ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) => _settings.put(_keyBaseUrl, url);

  Future<void> resetBaseUrl() => _settings.delete(_keyBaseUrl);

  // ---------------------------------------------------------------------- user

  AppUser? get cachedUser {
    if (!_ready) return null;
    final raw = _settings.get(_keyUser) as String?;
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AppUser user) =>
      _settings.put(_keyUser, jsonEncode(user.toJson()));

  String? get lastEmail => _settings.get(_keyLastEmail) as String?;

  Future<void> setLastEmail(String email) =>
      _settings.put(_keyLastEmail, email);

  bool get isOnboarded => _settings.get(_keyOnboarded) == true;

  Future<void> setOnboarded(bool value) =>
      _settings.put(_keyOnboarded, value);

  List<String> get checklist {
    final raw = _settings.get(_keyChecklist);
    if (raw is List) return raw.map((e) => '$e').toList();
    return const [
      'Жилет надет и застёгнут',
      'Лиш (страховочный трос) закреплён',
      'Телефон в гермочехле',
      'Вода и перекус взяты',
      'О погоде и ветре посмотрел',
    ];
  }

  Future<void> setChecklistDone(List<String> done) =>
      _settings.put(_keyChecklist, done);

  // ------------------------------------------------------------------- карта

  /// Включённые слои карты (ТЗ §8.2) — запоминаются между запусками.
  Map<String, bool> get mapLayers {
    final raw = _ready ? _settings.get(_keyMapLayers) : null;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value == true));
    }
    return const {
      'waterbodies': true,
      'routes': false,
      'events': true,
      'people': false,
    };
  }

  Future<void> setMapLayers(Map<String, bool> value) =>
      _settings.put(_keyMapLayers, Map<String, bool>.of(value));

  // -------------------------------------------------------------------- tokens

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secure.write(key: _secureAccess, value: accessToken);
    await _secure.write(key: _secureRefresh, value: refreshToken);
  }

  Future<String?> readAccessToken() => _secure.read(key: _secureAccess);

  Future<String?> readRefreshToken() => _secure.read(key: _secureRefresh);

  Future<void> clearTokens() async {
    await _secure.delete(key: _secureAccess);
    await _secure.delete(key: _secureRefresh);
    if (_ready) await _settings.delete(_keyUser);
  }
}
