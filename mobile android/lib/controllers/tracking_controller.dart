// Контроллер трекинга: GPS → локальная очередь (SQLite) → пачками на сервер.
//
// Порядок работы (ТЗ §12, §29, ТР §6):
//   1. «Начать заплыв» — запись создаётся локально ВСЕГДА, трек на сервере —
//      если есть сеть (иначе создастся при первой синхронизации);
//   2. каждая точка пишется в SQLite и помечается seq;
//   3. пачки по 60 точек уходят на POST /tracks/:id/points
//      (или /events/:id/tracks/:trackId/points — там сервер дедуплицирует по seq);
//   4. «Стоп» → /tracks/:id/complete, сервер считает статистику и вернёт
//      награду (баллы, XP, достижения);
//   5. незакрытая запись находится при следующем старте (ТЗ §12.5).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../services/geo_service.dart';
import '../services/track_store.dart';
import 'session_controller.dart';

enum RecordingPhase { idle, recording, paused, finishing }

enum SyncState { online, offline, syncing, synced, error }

/// Итог завершения: серверный трек либо локальная сводка, если сети не было.
typedef FinishOutcome = ({
  Track track,
  AwardResult award,
  bool synced,
});

class TrackingController extends ChangeNotifier {
  TrackingController(this.session);

  final SessionController session;
  final GeoService geo = const GeoService();
  final TrackStore store = TrackStore.instance;

  static const int _batchSize = 60;
  static const int _flushEveryPoints = 12;
  static const double _maxAccuracyMeters = 35;
  static const double _maxJumpMeters = 400;

  Recording? _recording;
  Recording? get recording => _recording;

  RecordingPhase _phase = RecordingPhase.idle;
  RecordingPhase get phase => _phase;

  SyncState _sync = SyncState.online;
  SyncState get sync => _sync;

  String? _error;
  String? get error => _error;

  double _distance = 0;
  double get distanceMeters => _distance;

  int _durationSeconds = 0;
  Duration get elapsed => Duration(seconds: _durationSeconds);

  double _currentSpeed = 0;
  double get currentSpeedKph => _currentSpeed;

  double _maxSpeed = 0;
  double get maxSpeedKph => _maxSpeed;

  double get avgSpeedKph =>
      _durationSeconds > 0 ? _distance / 1000 / (_durationSeconds / 3600) : 0;

  int _pointCount = 0;
  int get pointCount => _pointCount;

  int _pendingPoints = 0;
  int get pendingPoints => _pendingPoints;

  bool _hasFix = false;
  bool get hasFix => _hasFix;

  double _accuracy = 0;
  double get accuracyMeters => _accuracy;

  int _pausedSeconds = 0;
  int get pausedSeconds => _pausedSeconds;

  /// Последние точки для мини-карты на экране трекинга.
  List<GpsPoint> _trail = const [];
  List<GpsPoint> get trail => _trail;

  String? _permissionMessage;
  String? get permissionMessage => _permissionMessage;

  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  Future<void> _writeChain = Future.value();
  bool _flushing = false;
  int _nextSeq = 0;
  Position? _last;
  DateTime? _pauseStartedAt;
  int _flushCounter = 0;

  bool get isBusy => _phase == RecordingPhase.finishing;

  /// Записи, которые ещё не доехали до сервера (для бейджа на главной).
  int _pendingRecordings = 0;
  int get pendingCount => _pendingRecordings;

  /// Незакрытая запись с прошлой сессии (ТЗ §12.5).
  PendingRecording? _resumeCandidate;
  PendingRecording? get resumeCandidate => _resumeCandidate;

  /// Считает очередь локальных записей; вызывается при открытии главной.
  Future<void> refreshPendingSummary() async {
    await store.init();
    final all = await store.unsyncedRecordings();
    _pendingRecordings = all.where((r) => r.finished && !r.completed).length;
    _resumeCandidate =
        all.any((r) => !r.finished) ? await store.unfinishedRecording() : null;
    notifyListeners();
  }

  // ------------------------------------------------------------------- запуск

  Future<bool> start({
    String? name,
    String? waterBodyId,
    String? eventId,
    TrackDifficulty? difficulty,
  }) async {
    if (_phase != RecordingPhase.idle) return false;
    final permission = await geo.ensurePermission();
    if (!permission.isOk) {
      _permissionMessage = permission.message;
      notifyListeners();
      return false;
    }
    _permissionMessage = null;
    await store.init();
    _recording = await store.startRecording(
      name: name,
      difficulty: difficulty?.apiValue,
      waterBodyId: waterBodyId,
      eventId: eventId,
    );
    _resetMetrics();
    _phase = RecordingPhase.recording;
    notifyListeners();
    _listen();
    _startTicker();
    unawaited(_ensureServerTrack());
    return true;
  }

  /// Продолжение найденной незавершённой записи (ТЗ §12.5).
  Future<bool> resumeRecording(Recording saved) async {
    if (_phase != RecordingPhase.idle) return false;
    final permission = await geo.ensurePermission();
    if (!permission.isOk) {
      _permissionMessage = permission.message;
      notifyListeners();
      return false;
    }
    await store.init();
    _recording = saved;
    _distance = saved.distanceMeters;
    _durationSeconds = saved.durationSeconds;
    _maxSpeed = saved.maxSpeedKph;
    _pointCount = await store.countPoints(saved.id);
    _pendingPoints = await store.countPoints(saved.id, onlyPending: true);
    _nextSeq = await store.nextSeq(saved.id);
    _trail = (await store.allPoints(saved.id));
    _phase = RecordingPhase.recording;
    _permissionMessage = null;
    notifyListeners();
    _listen();
    _startTicker();
    unawaited(_ensureServerTrack());
    return true;
  }

  void pause() {
    if (_phase != RecordingPhase.recording) return;
    _phase = RecordingPhase.paused;
    _pauseStartedAt = DateTime.now();
    _ticker?.cancel();
    unawaited(_persistStats());
    notifyListeners();
  }

  void resume() {
    if (_phase != RecordingPhase.paused) return;
    final started = _pauseStartedAt;
    if (started != null) {
      _pausedSeconds += DateTime.now().difference(started).inSeconds;
    }
    _pauseStartedAt = null;
    _phase = RecordingPhase.recording;
    _startTicker();
    notifyListeners();
  }

  Future<void> discardRecording() async {
    final rec = _recording;
    await _stopSources();
    if (rec != null) {
      await store.deleteRecording(rec.id);
    }
    _recording = null;
    _resetMetrics();
    _phase = RecordingPhase.idle;
    notifyListeners();
  }

  /// «Стоп» на экране трекинга. Возвращает null, если завершать нечего.
  Future<FinishOutcome?> finish({
    String? name,
    TrackDifficulty? difficulty,
  }) async {
    final rec = _recording;
    if (rec == null || _phase == RecordingPhase.finishing) return null;
    _phase = RecordingPhase.finishing;
    notifyListeners();

    await _stopSources();
    final endedAt = DateTime.now();
    if (_pauseStartedAt != null) {
      _pausedSeconds += endedAt.difference(_pauseStartedAt!).inSeconds;
      _pauseStartedAt = null;
    }
    if (name != null || difficulty != null) {
      await store.rename(rec.id, name, difficulty?.apiValue ?? rec.difficulty);
    }
    await store.saveStats(
      rec.id,
      distanceMeters: _distance,
      durationSeconds: _durationSeconds,
      avgSpeedKph: avgSpeedKph,
      maxSpeedKph: _maxSpeed,
    );
    await store.markFinished(rec.id, endedAt);

    final trackId = await _ensureServerTrack();
    if (trackId != null) {
      await _flush(all: true);
    }

    try {
      if (trackId == null) throw ApiException.network();
      final api = session.api;
      if (rec.eventId != null) {
        final award = await api.events.finishTrack(
            rec.eventId!, trackId, endedAt,
            name: name, difficulty: difficulty);
        final track = await api.tracks.byId(trackId);
        await store.markCompleted(rec.id);
        _afterFinish();
        return (track: track, award: award, synced: true);
      }
      final result = await api.tracks.complete(trackId, endedAt,
          name: name, difficulty: difficulty);
      await store.markCompleted(rec.id);
      _afterFinish();
      return (
        track: result.track,
        award: result.award,
        synced: true
      );
    } on ApiException catch (e) {
      // Трек остался на устройстве — досинхронизируется позже (ТЗ §12.4).
      _error = e.isNetwork
          ? 'Нет связи — заплыв сохранён на устройстве, синхронизируем позже.'
          : e.message;
      _afterFinish();
      return (
        track: _localTrack(rec, endedAt),
        award: AwardResult.empty,
        synced: false,
      );
    }
  }

  /// Досинхронизация записей, оставшихся с прошлых сессий.
  Future<int> syncPendingRecordings() async {
    final sent = await _syncUnsynced();
    await refreshPendingSummary();
    return sent;
  }

  Future<int> _syncUnsynced() async {
    if (!store.isReady) await store.init();
    final pending = await store.unsyncedRecordings();
    var sent = 0;
    for (final rec in pending) {
      if (!rec.finished) continue; // активная запись — не трогаем
      final trackId = rec.serverTrackId ?? await _createServerTrack(rec);
      if (trackId == null) continue;
      final attached = await store
          .pendingPoints(rec.id, limit: 500);
      if (attached.isNotEmpty) {
        try {
          await session.api.tracks.addPoints(trackId, attached);
          await store.markAcked(
              rec.id, attached.map((p) => p.seq).toList(growable: false));
        } on ApiException catch (e) {
          if (e.isNetwork) return sent;
        }
      }
      final endedAt = rec.endedAt ?? DateTime.now();
      try {
        await session.api.tracks.complete(trackId, endedAt, name: rec.name);
        await store.markCompleted(rec.id);
        sent++;
      } on ApiException catch (e) {
        if (e.isNetwork) return sent;
      }
    }
    return sent;
  }

  Future<PendingRecording?> findUnfinished() async {
    await store.init();
    final pending = await store.unfinishedRecording();
    _resumeCandidate = pending;
    notifyListeners();
    return pending;
  }

  Future<void> deleteUnfinished(String id) => store.deleteRecording(id);

  // ------------------------------------------------------------------- внутреннее

  void _listen() {
    _sub?.cancel();
    _sub = geo.watch().listen(
      (position) {
        _writeChain = _writeChain.then((_) => _onPosition(position)).catchError(
              (Object e) => debugPrint('track point failed: $e'),
            );
      },
      onError: (Object e) {
        _hasFix = false;
        notifyListeners();
      },
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_phase == RecordingPhase.recording) {
        _durationSeconds++;
        notifyListeners();
      }
    });
  }

  Future<void> _onPosition(Position position) async {
    final rec = _recording;
    if (rec == null || _phase == RecordingPhase.paused) return;

    _hasFix = true;
    _accuracy = position.accuracy;
    _currentSpeed = math.max(0, position.speed * 3.6);
    if (_currentSpeed > _maxSpeed) _maxSpeed = _currentSpeed;

    final isFirst = _last == null;
    if (!isFirst && position.accuracy > _maxAccuracyMeters) {
      notifyListeners();
      return;
    }

    final recordedAt = position.timestamp;
    final point = GpsPoint(
      seq: _nextSeq,
      lat: position.latitude,
      lng: position.longitude,
      altitude: position.altitude,
      speedKph: double.parse((position.speed * 3.6).toStringAsFixed(2)),
      recordedAt: recordedAt,
    );
    _nextSeq++;

    final previous = _last;
    if (previous != null) {
      final step = haversineMeters(previous.latitude, previous.longitude,
          position.latitude, position.longitude);
      if (step <= _maxJumpMeters) _distance += step;
    }
    _last = position;

    await store.appendPoint(rec.id, point, accuracy: position.accuracy);
    _pointCount++;
    _trail = [..._trail, point];
    _pendingPoints++;
    _flushCounter++;

    if (_flushCounter >= _flushEveryPoints) {
      _flushCounter = 0;
      await _flush();
    } else {
      _sync = _sync == SyncState.offline ? SyncState.offline : SyncState.online;
    }
    notifyListeners();
    if (isFirst) {
      // Первая точка — есть сигнал, экрану важно показать это сразу.
      notifyListeners();
    }
  }

  /// Пачка неподтверждённых точек на сервер. Идемпотентность держится на seq.
  Future<void> _flush({bool all = false}) async {
    final rec = _recording;
    if (rec == null || _flushing) return;
    final trackId = rec.serverTrackId;
    if (trackId == null) {
      _sync = SyncState.offline;
      return;
    }
    _flushing = true;
    try {
      while (true) {
        final batch = await store.pendingPoints(rec.id,
            limit: all ? 500 : _batchSize);
        if (batch.isEmpty) {
          _pendingPoints = 0;
          _sync = SyncState.synced;
          break;
        }
        _sync = SyncState.syncing;
        if (rec.eventId != null) {
          await session.api.events
              .appendTrackPoints(rec.eventId!, trackId, batch);
        } else {
          await session.api.tracks.addPoints(trackId, batch);
        }
        await store.markAcked(
            rec.id, batch.map((p) => p.seq).toList(growable: false));
        _pendingPoints = await store.countPoints(rec.id, onlyPending: true);
        if (batch.length < (all ? 500 : _batchSize)) {
          _sync = SyncState.synced;
          break;
        }
      }
    } on ApiException catch (e) {
      _sync = e.isNetwork ? SyncState.offline : SyncState.error;
      if (!e.isNetwork) _error = e.message;
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  /// Трек на сервере: создаём при старте, если есть сеть.
  Future<String?> _ensureServerTrack() async {
    final rec = _recording;
    if (rec == null) return null;
    if (rec.serverTrackId != null) return rec.serverTrackId;
    final trackId = await _createServerTrack(rec);
    if (trackId != null) {
      _recording = Recording(
        id: rec.id,
        serverTrackId: trackId,
        eventId: rec.eventId,
        name: rec.name,
        difficulty: rec.difficulty,
        waterBodyId: rec.waterBodyId,
        startedAt: rec.startedAt,
        endedAt: rec.endedAt,
        finished: rec.finished,
        completed: rec.completed,
        distanceMeters: rec.distanceMeters,
        durationSeconds: rec.durationSeconds,
        avgSpeedKph: rec.avgSpeedKph,
        maxSpeedKph: rec.maxSpeedKph,
      );
    }
    return trackId;
  }

  Future<String?> _createServerTrack(Recording rec) async {
    try {
      final api = session.api;
      final track = rec.eventId != null
          ? await api.events.startTrack(rec.eventId!, name: rec.name)
          : await api.tracks.create(
              name: rec.name,
              waterBodyId: rec.waterBodyId,
              difficulty: rec.difficulty == null
                  ? null
                  : trackDifficultyFrom(rec.difficulty),
              startedAt: rec.startedAt,
            );
      await store.attachServerTrack(rec.id, track.id);
      return track.id;
    } on ApiException catch (e) {
      _sync = e.isNetwork ? SyncState.offline : SyncState.error;
      if (!e.isNetwork) _error = e.message;
      return null;
    }
  }

  Future<void> _persistStats() => store.saveStats(
        _recording!.id,
        distanceMeters: _distance,
        durationSeconds: _durationSeconds,
        avgSpeedKph: avgSpeedKph,
        maxSpeedKph: _maxSpeed,
      );

  Future<void> _stopSources() async {
    await _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    await _writeChain;
  }

  void _afterFinish() {
    _recording = null;
    _phase = RecordingPhase.idle;
    _resumeCandidate = null;
    unawaited(session.refreshProfile());
    unawaited(refreshPendingSummary());
    notifyListeners();
  }

  void _resetMetrics() {
    _distance = 0;
    _durationSeconds = 0;
    _currentSpeed = 0;
    _maxSpeed = 0;
    _pointCount = 0;
    _pendingPoints = 0;
    _pausedSeconds = 0;
    _hasFix = false;
    _accuracy = 0;
    _trail = const [];
    _last = null;
    _nextSeq = 0;
    _error = null;
    _sync = SyncState.online;
  }

  Track _localTrack(Recording rec, DateTime endedAt) => Track(
        id: rec.serverTrackId ?? rec.id,
        userId: session.user?.id ?? '',
        authorName: session.user?.name,
        name: rec.name ?? 'Заплыв ${dayLabel(rec.startedAt)}',
        status: TrackStatus.privateRoute,
        difficulty: rec.difficulty == null
            ? null
            : trackDifficultyFrom(rec.difficulty),
        waterBodyId: rec.waterBodyId,
        distanceMeters: _distance,
        durationSeconds: _durationSeconds,
        avgSpeedKph: avgSpeedKph,
        maxSpeedKph: _maxSpeed,
        startedAt: rec.startedAt,
        endedAt: endedAt,
        routeLine: [
          for (final p in _trail) [p.lng, p.lat]
        ],
      );

  String get syncLabel => switch (_sync) {
        SyncState.online => 'Онлайн',
        SyncState.offline => 'Нет связи — запись продолжается',
        SyncState.syncing => 'Синхронизация…',
        SyncState.synced => 'Синхронизировано',
        SyncState.error => 'Ошибка синхронизации',
      };

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
