// Профиль, геймификация, снаряжение, рейтинг (ТЗ §16, §18, §17).
import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../core/api_client.dart';
import '../models/api_models.dart';
import 'load_state.dart';

class ProfileController extends ChangeNotifier with LoadCoordinator {
  ProfileController(this.api);

  final SupFunApi api;

  final Section<List<Track>> tracks = Section();
  final Section<List<Achievement>> achievements = Section();
  final Section<List<PointLogEntry>> points = Section();
  final Section<List<GearItem>> gear = Section();
  final Section<List<Listing>> listings = Section();
  final Section<({List<LeaderboardEntry> entries, LeaderboardEntry? me})>
      leaderboard = Section();

  Future<void> loadAll() async {
    await Future.wait([
      guard<List<Track>>(tracks, api.tracks.mine),
      guard<List<Achievement>>(
          achievements, () => api.gamification.achievements()),
      guard<List<PointLogEntry>>(points, () => api.gamification.points()),
      guard<List<GearItem>>(gear, () => api.gear.mine()),
      guard<List<Listing>>(listings, () => api.marketplace.mine()),
    ]);
  }

  Future<void> loadLeaderboard({String scope = 'all'}) => guard(
      leaderboard, () => api.ratings.leaderboard(scope: scope, limit: 50));

  Future<AppUser?> updateProfile(Map<String, Object?> body) async {
    try {
      return await api.users.updateMe(
        name: body['name'] as String?,
        city: body['city'] as String?,
        region: body['region'] as String?,
        bio: body['bio'] as String?,
        phone: body['phone'] as String?,
        profileVisibility: body['profileVisibility'] as String?,
        activityVisibility: body['activityVisibility'] as String?,
        geoVisibility: body['geoVisibility'] as String?,
        showOnline: body['showOnline'] as bool?,
      );
    } on ApiException {
      return null;
    }
  }

  Future<bool> publishTrack(String trackId) async {
    try {
      final track = await api.tracks.publish(trackId);
      tracks.data = [
        for (final t in tracks.data ?? const <Track>[])
          if (t.id == track.id) track else t,
      ];
      tracks.state = (tracks.data ?? const []).isEmpty
          ? LoadState.empty
          : LoadState.ready;
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<bool> deleteTrack(String trackId) async {
    try {
      await api.tracks.remove(trackId);
      tracks.data = (tracks.data ?? const <Track>[])
          .where((t) => t.id != trackId)
          .toList();
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Сводка для верхней части профиля: считается из своих треков,
  /// сервер отдельного эндпоинта агрегата для мобильного не отдаёт.
  double get totalDistanceMeters => (tracks.data ?? const <Track>[])
      .fold<double>(0, (sum, t) => sum + t.distanceMeters);

  int get totalSwims => (tracks.data ?? const <Track>[])
      .where((t) => t.isFinished)
      .length;

  int get unlockedAchievements =>
      (achievements.data ?? const <Achievement>[]).where((a) => a.unlocked).length;
}

class NotificationsController extends ChangeNotifier with LoadCoordinator {
  NotificationsController(this.api);

  final SupFunApi api;

  final Section<List<AppNotification>> items = Section();

  int get unread =>
      (items.data ?? const <AppNotification>[]).where((n) => !n.isRead).length;

  Future<void> refresh() =>
      guard<List<AppNotification>>(items, () => api.notifications.list());

  Future<void> markAllRead() async {
    try {
      await api.notifications.markAllRead();
      items.data = (items.data ?? const <AppNotification>[])
          .map((n) => AppNotification(
                id: n.id,
                type: n.type,
                title: n.title,
                body: n.body,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
      notifyListeners();
    } on ApiException {
      // молча: уведомления не критичны
    }
  }
}
