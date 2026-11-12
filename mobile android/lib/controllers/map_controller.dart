// Данные для раздела «Карта»: слои, единый поиск, страница водоёма.
import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../models/api_models.dart';
import '../services/app_storage.dart';
import 'load_state.dart';

/// Состояние слоёв карты (ТЗ §8.2).
class MapLayers {
  const MapLayers({
    this.waterbodies = true,
    this.routes = false,
    this.events = true,
    this.people = false,
  });

  final bool waterbodies;
  final bool routes;
  final bool events;
  final bool people;

  MapLayers copyWith({
    bool? waterbodies,
    bool? routes,
    bool? events,
    bool? people,
  }) =>
      MapLayers(
        waterbodies: waterbodies ?? this.waterbodies,
        routes: routes ?? this.routes,
        events: events ?? this.events,
        people: people ?? this.people,
      );

  static MapLayers fromMap(Map<String, bool> map) => MapLayers(
        waterbodies: map['waterbodies'] ?? true,
        routes: map['routes'] ?? false,
        events: map['events'] ?? true,
        people: map['people'] ?? false,
      );

  Map<String, bool> toMap() => {
        'waterbodies': waterbodies,
        'routes': routes,
        'events': events,
        'people': people,
      };
}

class MapLayersController extends ChangeNotifier with LoadCoordinator {
  MapLayersController(this.api);

  final SupFunApi api;

  MapLayers _layers = const MapLayers();
  TrackDifficulty? _difficultyFilter;
  double? _latitude;
  double? _longitude;

  final Section<List<WaterBody>> waterbodies = Section();
  final Section<List<Track>> routes = Section();
  final Section<List<SupEvent>> events = Section();
  final Section<List<AppUser>> people = Section();
  final Section<SearchResults> results = Section();

  MapLayers get layers => _layers;
  TrackDifficulty? get difficultyFilter => _difficultyFilter;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get lastQuery => _lastQuery;

  /// Позиция пользователя для стартового центра карты.
  void rememberPosition(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  Future<void> loadLayers() async {
    _layers = MapLayers.fromMap(AppStorage.instance.mapLayers);
    notifyListeners();
    await Future.wait([
      guard(waterbodies, () => api.waterbodies.list(limit: 100)),
      guard(routes, () => api.tracks.list(scope: 'published', limit: 60)),
      guard(events, () => api.events.upcoming(limit: 60)),
    ]);
  }

  Future<void> setLayers(MapLayers layers) async {
    _layers = layers;
    notifyListeners();
    await AppStorage.instance.setMapLayers(layers.toMap());
    // Людей сервер отдельным списком не отдаёт (GET /users — только для
    // модерации), поэтому слой «Люди» наполняется результатами поиска.
    if (layers.people && _lastQuery.isNotEmpty && !people.hasData) {
      await search(_lastQuery);
    }
  }

  String _lastQuery = '';

  Future<void> setDifficulty(TrackDifficulty? difficulty) async {
    _difficultyFilter = difficulty;
    notifyListeners();
    await guard(
      routes,
      () => api.tracks.list(
        scope: 'published',
        difficulty: difficulty?.apiValue,
        limit: 60,
      ),
    );
  }

  /// Единый поиск (ТЗ §25).
  Future<void> search(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    if (trimmed.isEmpty) {
      results
        ..data = null
        ..error = null
        ..offline = false
        ..state = LoadState.empty;
      notifyListeners();
      return;
    }
    await guard<SearchResults>(
      results,
      () async {
        final found = await api.search.all(trimmed, limit: 6);
        if (_difficultyFilter == null) return found;
        return SearchResults(
          waterbodies: found.waterbodies,
          users: found.users,
          events: found.events,
          listings: found.listings,
          tracks: found.tracks
              .where((t) => t.difficulty == _difficultyFilter)
              .toList(growable: false),
        );
      },
    );
    people
      ..data = results.data?.users
      ..state = (results.data?.users.isEmpty ?? true)
          ? LoadState.empty
          : LoadState.ready;
  }

  /// Ближайшие водоёмы от точки (для предстартового экрана).
  Future<List<WaterBody>> nearestWaterBodies(
    double latitude,
    double longitude, {
    int limit = 6,
  }) async {
    final all = waterbodies.data ?? await api.waterbodies.list(limit: 200);
    final sorted = [...all]..sort((a, b) {
        final da = a.distanceTo(latitude, longitude) ?? double.infinity;
        final db = b.distanceTo(latitude, longitude) ?? double.infinity;
        return da.compareTo(db);
      });
    return sorted.take(limit).toList();
  }
}

/// Данные одной страницы водоёма.
class WaterbodyController extends ChangeNotifier with LoadCoordinator {
  WaterbodyController(this.api);

  final SupFunApi api;

  final Section<WaterBody> waterbody = Section();
  final Section<List<Track>> routes = Section();
  final Section<List<SupEvent>> events = Section();

  Future<void> load(String waterBodyId) async {
    await Future.wait([
      guard(waterbody, () => api.waterbodies.byId(waterBodyId)),
      guard(routes, () => api.tracks.list(
          scope: 'published', waterBodyId: waterBodyId, limit: 20)),
      guard(
          events, () => api.events.upcoming(waterBodyId: waterBodyId, limit: 20)),
    ]);
  }
}
