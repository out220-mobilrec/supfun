// Единый HTTP-клиент SUP FUN.
//
// Бэкенд (NestJS, глобальный JwtAuthGuard) отдаёт:
//  * списки — «голым» JSON-массивом;
//  * агрегаторы (/feed, /search, /news, /ratings) — объектом;
//  * ошибки — {statusCode, message, error}, где message бывает строкой или массивом.
// Клиент разбирает все три формы, сам подставляет Bearer-токен и при 401
// один раз перевыпускает пару токенов (сервер ротирует refresh — старый
// экземпляр становится невалидным, поэтому повтор запроса обязан идти с новым).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Ошибка обращения к серверу. [isNetwork] — не дошли до сервера (offline).
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final bool isNetwork;

  /// Email не подтверждён — сервер отвечает 403 с code = EMAIL_NOT_VERIFIED.
  final bool emailNotVerified;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetwork = false,
    this.emailNotVerified = false,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  factory ApiException.network([String? detail]) => ApiException(
        'Нет связи с сервером. Проверьте подключение к интернету.',
        isNetwork: true,
      );

  @override
  String toString() => message;
}

/// Стратегия обновления токена: возвращает новый access-токен либо null,
/// если сессию нужно считать потерянной.
typedef TokenRefresher = Future<String?> Function();

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client() {
    this.baseUrl = baseUrl;
  }

  final http.Client _http;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    _baseUrl = v;
  }

  late String _baseUrl;

  String? accessToken;

  /// Вызывается при 401; должен вернуть свежий access-токен или null.
  TokenRefresher? onUnauthorized;

  /// Вызывается, когда обновить сессию не удалось (нужен выход в логин).
  void Function()? onSessionExpired;

  static const Duration _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final qp = <String, String>{};
    query?.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        if (value.isEmpty) return;
        qp[key] = value.join(',');
      } else {
        qp[key] = '$value';
      }
    });
    final uri = Uri.parse('$_baseUrl$normalized');
    return qp.isEmpty ? uri : uri.replace(queryParameters: qp);
  }

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path,
          {Object? body, Map<String, Object?>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> patch(String path,
          {Object? body, Map<String, Object?>? query}) =>
      _send('PATCH', path, body: body, query: query);

  Future<dynamic> put(String path,
          {Object? body, Map<String, Object?>? query}) =>
      _send('PUT', path, body: body, query: query);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool allowRetry = true,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers.addAll(_headers());
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed =
          await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw const ApiException(
        'Сервер не отвечает. Попробуйте ещё раз.',
        isNetwork: true,
      );
    } on HttpException {
      throw ApiException.network();
    } on FormatException {
      throw ApiException.network();
    }

    if (response.statusCode == 401 && allowRetry && onUnauthorized != null) {
      final fresh = await onUnauthorized!();
      if (fresh != null) {
        accessToken = fresh;
        return _send(method, path, body: body, query: query, allowRetry: false);
      }
      onSessionExpired?.call();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _decode(response);
    }
    throw _error(response);
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('json')) return response.body;
    return jsonDecode(response.body);
  }

  ApiException _error(http.Response response) {
    final decoded = _isJson(response) ? _tryDecode(response.body) : null;
    var message = 'Ошибка сервера (${response.statusCode})';
    var notVerified = false;
    if (decoded is Map) {
      final raw = decoded['message'];
      if (raw is String && raw.isNotEmpty) message = raw;
      if (raw is List && raw.isNotEmpty) message = raw.join('; ');
      notVerified = decoded['code'] == 'EMAIL_NOT_VERIFIED';
    } else if (decoded is String && decoded.isNotEmpty) {
      message = decoded;
    }
    return ApiException(
      humanize(message),
      statusCode: response.statusCode,
      emailNotVerified: notVerified,
    );
  }

  bool _isJson(http.Response response) =>
      (response.headers['content-type'] ?? '').contains('json');

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Сообщения валидации DTO приходят по-английски — переводим типовые.
  static String humanize(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid email or password')) {
      return 'Неверный email или пароль';
    }
    if (lower.contains('email не подтвержд')) return message;
    if (lower.contains('account is banned')) {
      return 'Аккаунт заблокирован. Обратитесь в поддержку.';
    }
    if (lower.contains('invalid or expired code')) {
      return 'Код недействителен или истёк';
    }
    if (lower.contains('already been registered') ||
        lower.contains('already registered')) {
      return 'Такой email уже зарегистрирован';
    }
    if (lower.contains('rate limit') || lower.contains('throttl')) {
      return 'Слишком много запросов. Подождите минуту.';
    }
    if (lower.contains('not found')) return 'Ничего не найдено';
    return message;
  }

  void close() => _http.close();
}
