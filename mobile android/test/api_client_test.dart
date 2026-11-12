// Проверка сетевого клиента: формы ответов NestJS, разбор ошибок и
// ротация refresh-токена (см. scripts/api_probe.mjs).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sup_fun/core/api_client.dart';

void main() {
  group('baseUrl', () {
    test('срезает завершающие слеши', () {
      final client = ApiClient(baseUrl: 'http://localhost:3000/api///');
      expect(client.baseUrl, 'http://localhost:3000/api');
      client.close();
    });
  });

  group('запросы', () {
    test('списки приходят «голым» массивом', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {'id': '1'},
              {'id': '2'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      final data = await client.get('/waterbodies');
      expect(data, isA<List>());
      expect((data as List).length, 2);
      client.close();
    });

    test('агрегаторы (/feed, /search) приходят объектом', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'routes': [
                {'id': 'r1'}
              ],
              'events': <Object>[],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final data = await client.get('/feed') as Map<String, dynamic>;
      expect(data['routes'], hasLength(1));
      client.close();
    });

    test('null-параметры отбрасываются, списки склеиваются через запятую',
        () async {
      Uri? requested;
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      await client.get('/tracks', query: {
        'status': 'published',
        'difficulty': null,
        'ids': ['a', 'b'],
        'limit': 10,
      });

      expect(requested!.queryParameters['status'], 'published');
      expect(requested!.queryParameters.containsKey('difficulty'), isFalse);
      expect(requested!.queryParameters['ids'], 'a,b');
      expect(requested!.queryParameters['limit'], '10');
      client.close();
    });

    test('204 без тела читается как null', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient((_) async => http.Response('', 204)),
      );
      expect(await client.delete('/tracks/x'), isNull);
      client.close();
    });
  });

  group('ошибки', () {
    test('массив сообщений валидации склеивается', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'statusCode': 400,
              'message': [
                'email должен быть email',
                'password слишком короткий',
              ],
              'error': 'Bad Request',
            }),
            400,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      Object? caught;
      try {
        await client.post('/auth/register', body: {});
      } on ApiException catch (e) {
        caught = e;
      }
      expect(caught, isA<ApiException>());
      expect((caught as ApiException).statusCode, 400);
      expect(caught.message, contains('; '));
      client.close();
    });

    test('403 EMAIL_NOT_VERIFIED помечается отдельным флагом', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'statusCode': 403,
              'message': 'Email не подтверждён',
              'code': 'EMAIL_NOT_VERIFIED',
            }),
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      Object? caught;
      try {
        await client.post('/chats');
      } on ApiException catch (e) {
        caught = e;
      }
      expect((caught as ApiException).isForbidden, isTrue);
      expect(caught.emailNotVerified, isTrue);
      client.close();
    });

    test('humanize переводит типовые сообщения', () {
      expect(ApiClient.humanize('Invalid email or password'),
          'Неверный email или пароль');
      expect(
          ApiClient.humanize('User with this email has already been registered.'),
          'Такой email уже зарегистрирован');
      expect(ApiClient.humanize('Invalid or expired code'),
          'Код недействителен или истёк');
    });
  });

  group('ротация токенов', () {
    test('при 401 токен обновляется один раз и запрос повторяется с ним',
        () async {
      final authHeaders = <String?>[];
      var refreshCalls = 0;

      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient((request) async {
          final auth = request.headers['Authorization'];
          authHeaders.add(auth);
          if (auth == 'Bearer old') {
            return http.Response(
              jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}),
              401,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([
              {'id': 'me'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      client.accessToken = 'old';
      client.onUnauthorized = () async {
        refreshCalls++;
        return 'new';
      };

      final data = await client.get('/tracks/mine');
      expect((data as List), hasLength(1));
      expect(refreshCalls, 1);
      expect(authHeaders, ['Bearer old', 'Bearer new']);
      expect(client.accessToken, 'new');
      client.close();
    });

    test('если refresh не помог — сессия считается потерянной', () async {
      var expired = false;
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'statusCode': 401, 'message': 'Unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      client.accessToken = 'old';
      client.onUnauthorized = () async => null;
      client.onSessionExpired = () => expired = true;

      Object? caught;
      try {
        await client.get('/users/me');
      } on ApiException catch (e) {
        caught = e;
      }
      expect((caught as ApiException).isUnauthorized, isTrue);
      expect(expired, isTrue);
      client.close();
    });
  });
}
