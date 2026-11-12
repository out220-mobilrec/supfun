// Живая проверка контрактов: гоняет реальный клиент (ApiClient + SupFunApi)
// по запущенному бэкенду. Выключена по умолчанию, чтобы не требовать сервер
// на обычном `flutter test`.
//
//   $env:SUP_SMOKE='1'; flutter test test/live_contract_test.dart
//
// Нужен dev-доступ к БД (server/scripts/dbq.js) — им подтверждается email,
// потому что коды верификации сервер только логирует. Логин выполняется один
// раз на группу: /auth/* под троттлером, лишние вызовы дают 429.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sup_fun/api/sup_fun_api.dart';
import 'package:sup_fun/core/api_client.dart';
import 'package:sup_fun/models/api_models.dart';

final _smoke = Platform.environment['SUP_SMOKE'] == '1';
final _base = Platform.environment['SUP_API'] ?? 'http://localhost:3000/api';
final _dbq = Platform.environment['SUP_DBQ'] ?? '../server/scripts/dbq.js';

const _password = 'password123';

Future<void> _db(String query) async {
  final result = await Process.run('node', [_dbq, query]);
  if (result.exitCode != 0) {
    throw StateError('dbq: ${result.stderr}');
  }
}

void main() {
  group('контракты живого бэкенда', () {
    late ApiClient client;
    late SupFunApi api;
    late String email;
    var accessToken = '';
    var refreshToken = '';

    setUpAll(() async {
      email = 'dart.smoke.${DateTime.now().millisecondsSinceEpoch}@supfun.app';
      client = ApiClient(baseUrl: _base);
      api = SupFunApi(client);

      await api.auth.register(
        name: 'Dart Smoke',
        email: email,
        password: _password,
        city: 'Хабаровск',
      );
      await _db("UPDATE users SET is_email_verified = true "
          "WHERE email='$email'");

      final session = await api.auth.login(email, _password);
      accessToken = session.accessToken;
      refreshToken = session.refreshToken;
    });

    tearDownAll(() => client.close());

    void authorized() => client.accessToken = accessToken;

    test('login выдаёт пару токенов и пользователя', () {
      expect(accessToken, isNotEmpty);
      expect(refreshToken, isNotEmpty);
    });

    test('списки — голый массив, агрегаторы — объект', () async {
      authorized();

      final bodies = await api.waterbodies.list(limit: 3);
      expect(bodies, isA<List<WaterBody>>());

      final feed = await api.feed.feed(limit: 5);
      expect(feed, isA<FeedSnapshot>());

      final news = await api.news.list(limit: 3);
      expect(news, isA<List<NewsItem>>());

      final board = await api.ratings.leaderboard(limit: 3);
      expect(board.entries, isA<List<LeaderboardEntry>>());
    });

    test('профиль, уровень и правила читаются', () async {
      authorized();

      final me = await api.users.me();
      expect(me.email, email);

      final level = await api.gamification.me();
      expect(level.level, greaterThanOrEqualTo(1));

      expect(await api.gamification.achievements(), isNotEmpty);
      expect(await api.gamification.rules(), isNotEmpty);
    });

    test('водоёмы, заплывы и поиск отдают разбираемые модели', () async {
      authorized();

      final bodies = await api.waterbodies.list(limit: 5);
      final withCoords =
          bodies.where((b) => b.latitude != null && b.longitude != null);
      if (withCoords.isNotEmpty) {
        final first = withCoords.first;
        final nearby = await api.waterbodies
            .nearby(first.latitude!, first.longitude!, 50000);
        expect(nearby, isA<List<NearbyWaterBody>>());
        if (nearby.isNotEmpty) {
          expect(nearby.first.distanceMeters, greaterThanOrEqualTo(0));
        }
      }

      final events = await api.events.upcoming(limit: 5);
      expect(events.every((e) => e.status == EventStatus.scheduled), isTrue);

      final found = await api.search.all('а', limit: 3);
      expect(found, isA<SearchResults>());
    });

    test('полный цикл заплыва: старт → точки → финиш с наградой', () async {
      authorized();

      final started = await api.tracks.create(
        name: 'Dart smoke заплыв',
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(started.id, isNotEmpty);

      final points = [
        for (var i = 0; i < 8; i++)
          GpsPoint(
            seq: i,
            lat: 48.48 + i * 0.0008,
            lng: 135.08 + i * 0.0008,
            altitude: 40.0 + i,
            speedKph: 5 + i * 0.1,
            recordedAt:
                DateTime.now().subtract(Duration(seconds: (8 - i) * 10)),
          ),
      ];
      expect(await api.tracks.addPoints(started.id, points), points.length);

      final result = await api.tracks.complete(
        started.id,
        DateTime.now(),
        name: 'Dart smoke заплыв',
        difficulty: TrackDifficulty.easy,
      );
      expect(result.track.distanceMeters, greaterThan(0));
      expect(result.award.points, greaterThanOrEqualTo(0));

      final mine = await api.tracks.mine();
      expect(mine.map((t) => t.id), contains(started.id));
    });

    test('клиент сам обновляет токен при 401', () async {
      // Заголовок HTTP обязан быть ASCII — «битый», но латиницей.
      client.accessToken = 'broken-access-token';
      client.onUnauthorized = () async {
        try {
          final next = await api.auth.refresh(refreshToken);
          accessToken = next.accessToken;
          refreshToken = next.refreshToken;
          return next.accessToken;
        } on ApiException {
          return null;
        }
      };

      final me = await api.users.me();
      expect(me.email, email);
      expect(client.accessToken, isNot('broken-access-token'));
      client.onUnauthorized = null;
    });

    test('refresh ротируется: старый токен больше не принимается', () async {
      final previous = refreshToken;
      final refreshed = await api.auth.refresh(previous);
      expect(refreshed.accessToken, isNotEmpty);
      expect(refreshed.refreshToken, isNot(previous));
      accessToken = refreshed.accessToken;
      refreshToken = refreshed.refreshToken;

      ApiException? reused;
      try {
        await api.auth.refresh(previous);
      } on ApiException catch (e) {
        reused = e;
      }
      // Сервер отвечает 4xx на переиспользованный refresh (токен помечен
      // использованным при ротации).
      expect(reused?.statusCode, inInclusiveRange(400, 499));
    });
  }, skip: _smoke ? false : 'запустить с SUP_SMOKE=1');
}
