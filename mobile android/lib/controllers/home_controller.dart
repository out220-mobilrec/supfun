// Данные главной экрана (ТЗ §6): ближайший заплыв, активность, маршруты.
import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../models/api_models.dart';
import 'load_state.dart';

class HomeController extends ChangeNotifier with LoadCoordinator {
  HomeController(this.api);

  final SupFunApi api;

  final Section<FeedSnapshot> feed = Section();
  final Section<List<SupEvent>> upcoming = Section();
  final Section<List<Track>> routes = Section();
  final Section<List<Track>> popularTracks = Section();
  final Section<List<SupEvent>> nearbyEvents = Section();
  final Section<List<NewsItem>> news = Section();

  /// Свои записи — нужны блоку «Ваша статистика» (ТЗ §6.3). Сервер не
  /// отдаёт агрегат для мобильного, поэтому считаем из своих треков.
  final Section<List<Track>> myTracks = Section();

  bool _loading = false;
  bool get isRefreshing => _loading;

  Future<void> refresh({double? lat, double? lng}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    await Future.wait([
      guard<FeedSnapshot>(feed, () => api.feed.feed(limit: 20)),
      guard<List<SupEvent>>(
          upcoming, () => api.events.mine('going')),
      guard<List<Track>>(routes, () => api.tracks.list(scope: 'published', limit: 10)),
      guard<List<Track>>(
          popularTracks, () => api.tracks.list(scope: 'published', limit: 12)),
      guard<List<NewsItem>>(news, () => api.news.list(limit: 3)),
      guard<List<Track>>(myTracks, api.tracks.mine),
      if (lat != null && lng != null)
        guard<List<SupEvent>>(
            nearbyEvents, () => api.events.nearby(lat, lng)),
    ]);
    // Без координат «рядом» превращается в «из ленты» — экран не должен
    // показывать пустоту только из-за отсутствия геолокации.
    if (lat == null || lng == null) {
      final fromFeed = feed.data?.events ?? const <SupEvent>[];
      nearbyEvents
        ..data = fromFeed
        ..error = null
        ..offline = feed.offline
        ..state = fromFeed.isEmpty ? LoadState.empty : LoadState.ready;
    }
    _loading = false;
    notifyListeners();
  }

  /// Обновить всё; координаты добавляют блоки «рядом».
  Future<void> refreshAll({double? lat, double? lng}) =>
      refresh(lat: lat, lng: lng);

  /// Блок «рядом» — когда геопозиция стала известна после первой загрузки.
  Future<void> loadNearby(double lat, double lng) => guard<List<SupEvent>>(
      nearbyEvents, () => api.events.nearby(lat, lng));

  Future<void> loadNews({int limit = 30}) =>
      guard<List<NewsItem>>(news, () => api.news.list(limit: limit));


  /// Самый ближайший заплыв пользователя — hero-карточка.
  SupEvent? get nextOwnEvent {
    final list = upcoming.data;
    if (list == null || list.isEmpty) return null;
    final sorted = [...list]..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return sorted.first;
  }

  /// Самый ближайший публичный заплыв — если своего нет.
  SupEvent? get nextNearbyEvent {
    final list = nearbyEvents.data ?? feed.data?.events;
    if (list == null || list.isEmpty) return null;
    final now = DateTime.now();
    final future = list.where((e) => e.eventDate.isAfter(now)).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return future.isEmpty ? null : future.first;
  }
}
