import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import 'track_offline_store.dart';

class TrackSyncResult {
  final bool ok;
  final String? error;
  final int pointsSent;
  const TrackSyncResult({required this.ok, this.error, this.pointsSent = 0});
}

class TrackSyncService {
  TrackSyncService._();
  static final TrackSyncService instance = TrackSyncService._();

  final TrackOfflineStore _store = TrackOfflineStore.instance;
  final ApiClient _api = ApiClient.instance;

  final ValueNotifier<bool> syncing = ValueNotifier(false);

  Future<TrackSyncResult> ensureServerTrack(LocalTrackRecord local) async {
    if (local.serverId != null && local.serverId!.isNotEmpty) {
      return TrackSyncResult(ok: true);
    }
    try {
      final j = await _api.post('/tracks', data: <String, dynamic>{
        if (local.name != null && local.name!.trim().isNotEmpty) 'name': local.name,
        if (local.waterBodyId != null) 'waterBodyId': local.waterBodyId,
        if (local.eventId != null) 'eventId': local.eventId,
        'difficulty': local.difficulty,
        'startedAt': local.startedAt.toUtc().toIso8601String(),
      });
      final serverId = j['id'] as String?;
      if (serverId == null || serverId.isEmpty) {
        return const TrackSyncResult(ok: false, error: 'Сервер не вернул id трека');
      }
      await _store.attachServerId(local.localId, serverId);
      return const TrackSyncResult(ok: true);
    } on ApiException catch (e) {
      return TrackSyncResult(ok: false, error: e.message);
    } catch (e) {
      return TrackSyncResult(ok: false, error: 'Ошибка сети');
    }
  }

  /// Upload unsent points in batches. Returns when all sent or on first hard error.
  Future<TrackSyncResult> syncPoints(int localId, {int batchSize = 50}) async {
    final local = await _store.getTrack(localId);
    if (local == null) return const TrackSyncResult(ok: false, error: 'Локальный трек не найден');

    final ensured = await ensureServerTrack(local);
    if (!ensured.ok) return ensured;
    final serverId = (await _store.getTrack(localId))?.serverId;
    if (serverId == null) return const TrackSyncResult(ok: false, error: 'Нет serverId');

    int totalSent = 0;
    while (true) {
      final batch = await _store.getUnsentPoints(localId, limit: batchSize);
      if (batch.isEmpty) break;
      try {
        await _api.post('/tracks/$serverId/points', data: {
          'points': batch
              .map((p) => <String, dynamic>{
                    'seq': p.seq,
                    'lat': p.lat,
                    'lng': p.lng,
                    if (p.altitude != null) 'altitude': p.altitude,
                    if (p.speedKph != null) 'speedKph': p.speedKph,
                    'recordedAt': p.recordedAt.toUtc().toIso8601String(),
                  })
              .toList(),
        });
        await _store.markPointsSent(localId, batch.map((p) => p.seq).toList());
        totalSent += batch.length;
      } on ApiException catch (e) {
        // 401 will be retried by ApiClient interceptor; if it bubbles up, stop.
        // 403 ended track etc - stop syncing points.
        return TrackSyncResult(ok: false, error: e.message, pointsSent: totalSent);
      } catch (_) {
        return TrackSyncResult(ok: false, error: 'Ошибка сети', pointsSent: totalSent);
      }
    }
    return TrackSyncResult(ok: true, pointsSent: totalSent);
  }

  /// Flush points and complete the track on the server.
  Future<({bool ok, String? error, TrackCompleteResult? result})> completeTrack(
    int localId, {
    String? name,
    String? difficulty,
  }) async {
    syncing.value = true;
    try {
      final local = await _store.getTrack(localId);
      if (local == null) return (ok: false, error: 'Локальный трек не найден', result: null);

      await _store.setTrackStatus(localId, 'pending_complete',
          endedAt: DateTime.now(), name: name);

      final syncRes = await syncPoints(localId);
      if (!syncRes.ok && await _store.unsentCount(localId) > 0) {
        await _store.setTrackStatus(localId, 'sync_error');
        return (ok: false, error: syncRes.error ?? 'Не удалось отправить точки', result: null);
      }

      final refreshed = await _store.getTrack(localId);
      final serverId = refreshed?.serverId;
      if (serverId == null) {
        await _store.setTrackStatus(localId, 'sync_error');
        return (ok: false, error: 'Трек не создан на сервере', result: null);
      }

      final j = await _api.post('/tracks/$serverId/complete', data: <String, dynamic>{
        'endedAt': DateTime.now().toUtc().toIso8601String(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (difficulty != null) 'difficulty': difficulty,
      });
      await _store.setTrackStatus(localId, 'completed', name: name);
      return (ok: true, error: null, result: TrackCompleteResult.fromJson(j));
    } on ApiException catch (e) {
      await _store.setTrackStatus(localId, 'sync_error');
      return (ok: false, error: e.message, result: null);
    } catch (e) {
      await _store.setTrackStatus(localId, 'sync_error');
      return (ok: false, error: 'Ошибка сети', result: null);
    } finally {
      syncing.value = false;
    }
  }

  /// Best-effort background sync of unsent points for a recording track.
  Future<void> trySyncRecording(int localId) async {
    if (syncing.value) return;
    try {
      await syncPoints(localId);
    } catch (_) {}
  }
}
