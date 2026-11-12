import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/auth.dart';
import 'session.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? data;

  ApiException(this.statusCode, this.message, [this.data]);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  late final Dio dio = _build();

  /// Emitted when refresh fails and the session must be cleared.
  final ValueNotifier<bool> authExpired = ValueNotifier(false);

  bool _refreshing = false;
  final List<Completer<void>> _refreshWaiters = [];

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = Session.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 && !_isAuthRoute(e.requestOptions)) {
          if (!_refreshing) {
            _refreshing = true;
            final ok = await _tryRefresh();
            _refreshing = false;
            for (final c in _refreshWaiters) {
              c.complete();
            }
            _refreshWaiters.clear();
            if (ok) {
              try {
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${Session.accessToken}';
                final retry = await dio.fetch(opts);
                return handler.resolve(retry);
              } on DioException catch (err) {
                final ex = _toException(err);
                return handler.reject(DioException(requestOptions: e.requestOptions, error: ex));
              }
            }
            authExpired.value = true;
          } else {
            final c = Completer<void>();
            _refreshWaiters.add(c);
            await c.future;
            if (Session.accessToken != null) {
              try {
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer ${Session.accessToken}';
                final retry = await dio.fetch(opts);
                return handler.resolve(retry);
              } on DioException catch (err) {
                final ex = _toException(err);
                return handler.reject(DioException(requestOptions: e.requestOptions, error: ex));
              }
            }
            return handler.reject(e);
          }
        }
        handler.next(e);
      },
    ));
    return d;
  }

  bool _isAuthRoute(RequestOptions o) {
    final p = o.path;
    return p.contains('/auth/register') ||
        p.contains('/auth/login') ||
        p.contains('/auth/refresh') ||
        p.contains('/auth/reset-password') ||
        p.contains('/auth/forgot-password') ||
        p.contains('/auth/verify-email');
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = _refreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiBase))
          .post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = res.data as Map<String, dynamic>;
      final auth = AuthResult.fromJson(Map<String, dynamic>.from(data));
      await Session.save(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
        sessionUser: auth.user,
      );
      return true;
    } catch (_) {
      await Session.clear();
      return false;
    }
  }

  String? _refreshToken() {
    // Refresh token is held in memory; fall back to session persistence.
    return _memRefresh ?? _readPrefsRefresh();
  }

  String? _memRefresh;
  static String? _readPrefsRefresh() => null;

  /// Keep an in-memory refresh token reference (set on login/save).
  void attachRefresh(String token) => _memRefresh = token;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    try {
      final res = await dio.get(path, queryParameters: query);
      return res.data is List ? (res.data as List) : <dynamic>[];
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {Object? data, Map<String, dynamic>? query}) async {
    try {
      final res = await dio.post(path, data: data ?? const {}, queryParameters: query);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Object? data, Map<String, dynamic>? query}) async {
    try {
      final res = await dio.patch(path, data: data ?? const {}, queryParameters: query);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path, {Object? data}) async {
    try {
      final res = await dio.delete(path, data: data);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Future<String> uploadImage(String field, String filePath) async {
    final form = FormData.fromMap({
      field: await MultipartFile.fromFile(filePath),
    });
    try {
      final res = await dio.post('/uploads/images', data: form);
      final data = _asMap(res.data);
      final urls = (data['urls'] as List?)?.cast<String>() ?? const <String>[];
      if (urls.isNotEmpty) return urls.first;
      return data['url'] as String? ?? '';
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return Map<String, dynamic>.from(jsonDecode(data));
    return <String, dynamic>{};
  }

  ApiException _toException(DioException e) {
    final res = e.response;
    final status = res?.statusCode;
    String message = 'Ошибка сети';
    Map<String, dynamic>? body;
    if (res?.data != null) {
      final d = res!.data;
      if (d is Map) body = Map<String, dynamic>.from(d);
      if (d is Map && d['message'] != null) {
        final m = d['message'];
        if (m is String) {
          message = m;
        } else if (m is List) {
          message = m.join('\n');
        }
      } else {
        message = _statusMessage(status);
      }
    } else {
      message = _statusMessage(status);
    }
    return ApiException(status, message, body);
  }

  String _statusMessage(int? status) {
    switch (status) {
      case 400:
        return 'Некорректный запрос';
      case 401:
        return 'Требуется авторизация';
      case 403:
        return 'Доступ запрещён';
      case 404:
        return 'Не найдено';
      case 409:
        return 'Конфликт';
      case 429:
        return 'Слишком много запросов, попробуйте позже';
      case null:
        return 'Ошибка сети';
      default:
        return 'Ошибка сервера ($status)';
    }
  }
}