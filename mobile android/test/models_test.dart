// Разбор ответов сервера: проверены реальные формы JSON, снятые
// скриптом scripts/api_probe.mjs (голые массивы, GeoJSON, lite-версии).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sup_fun/api/sup_fun_api.dart';
import 'package:sup_fun/core/api_client.dart';
import 'package:sup_fun/models/api_models.dart';

Map<String, dynamic> _json(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('WaterBody', () {
    test('читает и плоские координаты, и GeoJSON Point', () {
      final flat = WaterBody.fromJson({
        'id': 'w1',
        'name': 'Истра',
        'region': 'Московская обл.',
        'latitude': 55.92,
        'longitude': 36.86,
      });
      expect(flat.latitude, 55.92);
      expect(flat.longitude, 36.86);

      final geo = WaterBody.fromJson({
        'id': 'w2',
        'name': 'Сенеж',
        'location': {
          'type': 'Point',
          'coordinates': [36.86, 55.92],
        },
      });
      // GeoJSON порядок — [долгота, широта].
      expect(geo.longitude, 36.86);
      expect(geo.latitude, 55.92);
    });

    test('без координат distanceTo = null', () {
      const body = WaterBody(id: 'w3', name: 'Без гео');
      expect(body.distanceTo(55, 37), isNull);
    });

    test('distanceTo считает расстояние в метрах', () {
      const body =
          WaterBody(id: 'w4', name: 'Круглое', latitude: 55.0, longitude: 37.0);
      final meters = body.distanceTo(55.009, 37.0)!;
      // ~1 км по меридиану.
      expect(meters, closeTo(1001, 20));
    });
  });

  group('Track', () {
    test('полный трек: GeoJSON routeLine и словари статусов', () {
      final track = Track.fromJson(_json('''
      {
        "id": "t1",
        "userId": "u1",
        "name": "Круг по Истре",
        "status": "published",
        "difficulty": "medium",
        "distanceMeters": "5120.5",
        "durationSeconds": 3000,
        "avgSpeedKph": 6.1,
        "maxSpeedKph": 8.4,
        "calories": 210,
        "startedAt": "2026-10-01T08:00:00.000Z",
        "endedAt": "2026-10-01T08:50:00.000Z",
        "user": {"id": "u1", "name": "Аня"},
        "waterBody": {"id": "w1", "name": "Истра"},
        "routeLine": {
          "type": "LineString",
          "coordinates": [[36.86, 55.92], [36.87, 55.93]]
        }
      }'''));

      expect(track.title, 'Круг по Истре');
      expect(track.authorName, 'Аня');
      expect(track.waterBodyName, 'Истра');
      expect(track.isPublished, isTrue);
      expect(track.difficulty, TrackDifficulty.medium);
      expect(track.distanceMeters, 5120.5);
      expect(track.routeLine.first, [36.86, 55.92]);
      expect(track.isFinished, isTrue);
    });

    test('lite-версия из /feed: snake_case и userName вместо author', () {
      final track = trackLite({
        'id': 't2',
        'name': 'Утро на Сенеже',
        'userName': 'Игорь',
        'distance_meters': 4200,
        'duration_seconds': 2400,
        'avgSpeedKph': 6.3,
        'difficulty': 'hard',
        'startedAt': '2026-10-02T06:00:00.000Z',
      });

      expect(track.userId, '');
      expect(track.authorName, 'Игорь');
      expect(track.distanceMeters, 4200);
      expect(track.difficulty, TrackDifficulty.hard);
      expect(track.status, TrackStatus.published);
    });

    test('неизвестный статус → личный маршрут, а не падение', () {
      final track = Track.fromJson({
        'id': 't3',
        'userId': 'u1',
        'status': 'weird',
        'startedAt': '2026-10-03T06:00:00.000Z',
      });
      expect(track.status, TrackStatus.privateRoute);
    });
  });

  group('SupEvent', () {
    test('разбор вложенных organizer/waterBody/track', () {
      final event = SupEvent.fromJson(_json('''
      {
        "id": "e1",
        "title": "Субботний заплыв",
        "eventDate": "2026-10-20T09:00:00.000Z",
        "status": "scheduled",
        "level": "pro",
        "visibility": "public",
        "access": "open",
        "maxParticipants": 12,
        "participantCount": 4,
        "startLat": 55.92,
        "startLng": 36.86,
        "photos": ["/uploads/a.jpg"],
        "organizer": {"id": "u1", "name": "Аня", "email": "a@b.c", "xp": 120},
        "waterBody": {"id": "w1", "name": "Истра"},
        "track": {"id": "t1", "name": "Круг по Истре"}
      }'''));

      expect(event.organizerName, 'Аня');
      expect(event.organizer?.xp, 120);
      expect(event.waterBodyName, 'Истра');
      expect(event.trackName, 'Круг по Истре');
      expect(event.maxParticipants, 12);
      expect(event.participantCount, 4);
      expect(event.status, EventStatus.scheduled);
      expect(event.levelLabel, 'Профи');
      expect(event.photos.single, contains('/uploads/a.jpg'));
    });

    test('пустой ответ не роняет разбор', () {
      final event = SupEvent.fromJson({});
      expect(event.id, '');
      expect(event.title, 'Заплыв');
      expect(event.status, EventStatus.scheduled);
      expect(event.organizer, isNull);
    });
  });

  group('агрегаторы', () {
    test('/feed → объект с routes/events/listings', () {
      final feed = FeedSnapshot.fromJson(_json('''
      {
        "routes": [{
          "id": "t1", "name": "Маршрут", "userName": "Аня",
          "distance_meters": 3000, "startedAt": "2026-10-01T08:00:00.000Z"
        }],
        "events": [{
          "id": "e1", "title": "Заплыв",
          "eventDate": "2026-10-20T09:00:00.000Z", "organizerName": "Аня"
        }],
        "listings": [{
          "id": "l1", "title": "Доска", "category": "boards",
          "price": 25000, "createdAt": "2026-10-01T08:00:00.000Z",
          "seller": {"id": "u1", "name": "Игорь"}
        }]
      }'''));

      expect(feed.routes.single.authorName, 'Аня');
      expect(feed.events.single.organizerName, 'Аня');
      expect(feed.listings.single.sellerName, 'Игорь');
      expect(feed.isEmpty, isFalse);
    });

    test('/search → пять групп', () {
      final found = SearchResults.fromJson(_json('''
      {
        "waterbodies": [{"id": "w1", "name": "Истра"}],
        "users": [{"id": "u1", "name": "Аня", "city": "Москва"}],
        "events": [{"id": "e1", "title": "Заплыв",
          "eventDate": "2026-10-20T09:00:00.000Z"}],
        "tracks": [{"id": "t1", "name": "Маршрут", "userName": "Аня",
          "startedAt": "2026-10-01T08:00:00.000Z"}],
        "listings": []
      }'''));

      expect(found.total, 4);
      expect(found.waterbodies.single.name, 'Истра');
      expect(found.tracks.single.authorName, 'Аня');
    });
  });

  group('SupFunApi', () {
    test('списки разбираются из голого массива', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/waterbodies')) {
            return http.Response(
              jsonEncode([
                {'id': 'w1', 'name': 'Истра', 'latitude': 55.9, 'longitude': 36.8}
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 't1',
                'userId': 'u1',
                'name': 'Маршрут',
                'status': 'published',
                'startedAt': '2026-10-01T08:00:00.000Z'
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final api = SupFunApi(client);

      final bodies = await api.waterbodies.list();
      expect(bodies.single.name, 'Истра');

      final routes = await api.tracks.list(scope: 'published');
      expect(routes.single.isPublished, isTrue);

      client.close();
    });

    test('рейтинг: объект entries/me, me может отсутствовать', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'entries': [
                {'rank': 1, 'id': 'u1', 'name': 'Аня', 'xp': 900, 'level': 9}
              ],
              'me': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final api = SupFunApi(client);

      final board = await api.ratings.leaderboard();
      expect(board.entries.single.rank, 1);
      expect(board.me, isNull);

      client.close();
    });
  });
}
