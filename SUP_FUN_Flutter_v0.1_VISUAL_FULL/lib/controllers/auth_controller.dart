// Authentication controller — server-side login with refresh-token persistence
//
// Flow:
// 1. First launch: no tokens → AuthScreen
// 2. Login: POST /auth/login → accessToken (15 min) + refreshToken (30 days)
// 3. Persist refreshToken in flutter_secure_storage (Android Keychain)
// 4. Next launches: read refreshToken → POST /auth/refresh → new accessToken
// 5. accessToken also persisted (Hive) for offline fallback read of cached user
// 6. refreshToken rotates on every use (server invalidates old, returns new)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../services/local_storage_service.dart';

class AuthController extends ChangeNotifier {
  // Secure storage for refresh token (Android Keychain / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'auth_user_id';

  AppUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isResumingSession = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isResumingSession => _isResumingSession;
  String? get errorMessage => _errorMessage;

  /// Backend API URL. For Android emulator use 10.0.2.2, for real device
  /// set this to your LAN address (e.g. http://192.168.1.5:3000/api).
  static String apiBaseUrl = 'http://localhost:3000/api';
  static String? _runtimeBaseUrl;

  /// Allows runtime override of API URL from settings (persisted by
  /// LocalStorageService).
  static String get activeApiBaseUrl =>
      _runtimeBaseUrl ?? apiBaseUrl;

  static void overrideApiBaseUrl(String url) {
    _runtimeBaseUrl = url;
  }

  String _api(String path) =>
      '${_runtimeBaseUrl ?? apiBaseUrl}$path';

  LocalStorageService get _storage => LocalStorageService.instance;

  Future<String?> _readSecureRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('Secure storage read error: $e');
      return null;
    }
  }

  Future<void> _writeSecureRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      debugPrint('Secure storage write error: $e');
    }
  }

  Future<void> _clearSecureRefreshToken() async {
    try {
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _userIdKey);
    } catch (e) {
      debugPrint('Secure storage delete error: $e');
    }
  }

  /// Called once on app startup. Tries to resume the session silently:
  /// 1. Read refreshToken from secure storage
  /// 2. POST /auth/refresh → new accessToken + new refreshToken (rotation)
  /// 3. Optionally GET /users/me to refresh cached user
  /// 4. Mark authenticated → main.dart pushes Shell automatically
  Future<void> initialize() async {
    // Подтянуть настройку адреса сервера из локального хранилища
    try {
      final savedUrl = _storage.getApiBaseUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _runtimeBaseUrl = savedUrl;
      }
    } catch (_) {}

    _isResumingSession = true;
    notifyListeners();

    try {
      // Try cached profile for instant paint while refreshing
      final cachedUserId = _storage.getCurrentUserId();
      final cachedAccess = _storage.getAuthToken();
      if (cachedUserId != null) {
        _currentUser = _storage.getUser(cachedUserId);
      }
      if (cachedAccess != null) {
        _accessToken = cachedAccess;
      }

      // Refresh accessToken using the stored refreshToken
      final refresh = await _readSecureRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        _isResumingSession = false;
        notifyListeners();
        return;
      }

      final ok = await _tryRefreshToken(refresh);
      if (!ok) {
        await _clearSecureRefreshToken();
        _currentUser = null;
        _accessToken = null;
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
    }

    _isResumingSession = false;
    notifyListeners();
  }

  /// Exchange a refresh token for a new pair.
  /// Returns true on success, false on any failure.
  Future<bool> _tryRefreshToken(String refreshToken) async {
    try {
      final response = await http
          .post(
            Uri.parse(_api('/auth/refresh')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        await _applyAuthResult(jsonDecode(response.body));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Refresh token error: $e');
      return false;
    }
  }

  /// Login with email and password. Server is the single source of truth.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse(_api('/auth/login')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        await _applyAuthResult(jsonDecode(response.body));
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _parseError(response.body);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Login network error: $e');
      _errorMessage =
          'Не удалось связаться с сервером. Проверьте подключение к интернету.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a new account on the server.
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String city,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse(_api('/auth/register')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'name': name,
              'city': city,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _applyAuthResult(jsonDecode(response.body));
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = _parseError(response.body);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Register network error: $e');
      _errorMessage =
          'Не удалось связаться с сервером. Проверьте подключение к интернету.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Apply response from /auth/login, /auth/register, or /auth/refresh.
  /// Persists tokens for next launches.
  Future<void> _applyAuthResult(Map<String, dynamic> data) async {
    _accessToken = data['accessToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    if (data['user'] is Map) {
      _currentUser =
          _mapServerUser(data['user'] as Map<String, dynamic>);
    }

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      await _writeSecureRefreshToken(_refreshToken!);
    }
    if (_currentUser != null) {
      await _storage.saveUser(_currentUser!);
      await _storage.saveCurrentUserId(_currentUser!.id);
      if (_accessToken != null) {
        await _storage.saveAuthToken(_accessToken!);
      }
    }
    _isAuthenticated = _accessToken != null && _currentUser != null;
  }

  /// Map server's `users` row to our AppUser.
  AppUser _mapServerUser(Map<String, dynamic> json) {
    final xp = json['xp'] ?? 0;
    final level = (xp ~/ 100) + 1;
    return AppUser(
      id: json['id'].toString(),
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'],
      city: json['city'],
      bio: json['bio'],
      phone: json['phone'],
      level: level,
      rank: _rankFromRole(json['role']),
      experience: xp,
      experienceToNext: level * 100,
      registeredAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      lastSyncAt: DateTime.now(),
      isVerified: json['isEmailVerified'] == true,
      totalDistance: 0.0,
      totalTrips: 0,
      daysOnWater: 0,
    );
  }

  String _rankFromRole(dynamic role) {
    switch (role?.toString()) {
      case 'admin':
        return 'Администратор';
      case 'moderator':
        return 'Модератор';
      case 'guide':
        return 'Гид';
      default:
        return 'Новичок';
    }
  }

  /// Force refresh of accessToken using stored refreshToken.
  Future<bool> ensureFreshToken() async {
    if (_refreshToken == null) {
      _refreshToken = await _readSecureRefreshToken();
    }
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    return _tryRefreshToken(_refreshToken!);
  }

  /// Update user profile — sync local + remote
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? city,
    String? bio,
    String? avatarUrl,
    String? localAvatarPath,
  }) async {
    if (_currentUser == null || _accessToken == null) return false;
    _isLoading = true;
    notifyListeners();

    _currentUser = _currentUser!.copyWith(
      name: name ?? _currentUser!.name,
      city: city ?? _currentUser!.city,
      bio: bio ?? _currentUser!.bio,
      avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
      localAvatarPath: localAvatarPath ?? _currentUser!.localAvatarPath,
      lastSyncAt: DateTime.now(),
    );
    await _storage.saveUser(_currentUser!);

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (city != null) body['city'] = city;
      if (bio != null) body['bio'] = bio;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (email != null) body['email'] = email;
      final response = await http
          .patch(
            Uri.parse(_api('/users/me')),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
            'Profile update failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Profile sync error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Force-reload profile from server.
  Future<void> refreshProfile() async {
    if (_currentUser == null || _accessToken == null) return;
    try {
      final response = await http
          .get(
            Uri.parse(_api('/users/me')),
            headers: {'Authorization': 'Bearer $_accessToken'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final mapped = _mapServerUser(jsonDecode(response.body));
        _currentUser =
            mapped.copyWith(localAvatarPath: _currentUser!.localAvatarPath);
        await _storage.saveUser(_currentUser!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh profile error: $e');
    }
  }

  /// Logout — drop tokens locally + invalidate refresh on server.
  Future<void> logout() async {
    final refresh = _refreshToken ?? await _readSecureRefreshToken();
    if (refresh != null && _accessToken != null) {
      try {
        await http
            .post(
              Uri.parse(_api('/auth/logout')),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
              body: jsonEncode({'refreshToken': refresh}),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _isAuthenticated = false;
    _errorMessage = null;
    await _clearSecureRefreshToken();
    await _storage.clearAuthToken();
    await _storage.saveCurrentUserId('');
    notifyListeners();
  }

  String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      return data['error']?.toString() ?? 'Ошибка авторизации';
    } catch (_) {
      return 'Ошибка авторизации';
    }
  }
}
