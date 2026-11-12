// Оффлайн-хранение записей трекинга (ТЗ §12.4, §12.5, §29).
//
// SQLite выбран из-за частой записи: точка GPS пишется в локальную очередь
// всегда, а в сервер уходит пачкой. Подтверждённые сервером точки помечаются
// acked=1 — повторная отправка исключает дубли, а незавершённая запись
// переживает убийство процесса.
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/api_models.dart';

/// Локальная сессия записи. [serverTrackId] равен null, пока трек не создан
/// на сервере (старт без сети) — тогда при первой синхронизации он создаётся.
class Recording {
  final String id;
  final String? serverTrackId;
  final String? eventId;
  final String? name;
  final String? difficulty;
  final String? waterBodyId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool finished;
  final bool completed;
  final double distanceMeters;
  final int durationSeconds;
  final double avgSpeedKph;
  final double maxSpeedKph;

  const Recording({
    required this.id,
    this.serverTrackId,
    this.eventId,
    this.name,
    this.difficulty,
    this.waterBodyId,
    required this.startedAt,
    this.endedAt,
    this.finished = false,
    this.completed = false,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.avgSpeedKph = 0,
    this.maxSpeedKph = 0,
  });

  factory Recording.fromRow(Map<String, dynamic> row) => Recording(
        id: row['id'] as String,
        serverTrackId: row['server_track_id'] as String?,
        eventId: row['event_id'] as String?,
        name: row['name'] as String?,
        difficulty: row['difficulty'] as String?,
        waterBodyId: row['water_body_id'] as String?,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        endedAt: row['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
        finished: (row['finished'] as int? ?? 0) == 1,
        completed: (row['completed'] as int? ?? 0) == 1,
        distanceMeters: (row['distance_meters'] as num? ?? 0).toDouble(),
        durationSeconds: (row['duration_seconds'] as int? ?? 0),
        avgSpeedKph: (row['avg_speed_kph'] as num? ?? 0).toDouble(),
        maxSpeedKph: (row['max_speed_kph'] as num? ?? 0).toDouble(),
      );
}

/// Запись вместе с количеством неотправленных точек.
typedef PendingRecording = ({Recording recording, int pendingPoints});


class TrackStore {
  TrackStore._();

  static final TrackStore instance = TrackStore._();

  Database? _db;
  final Random _random = Random();

  bool get isReady => _db != null;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'sup_fun_sync.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE recordings (
            id TEXT PRIMARY KEY,
            server_track_id TEXT,
            event_id TEXT,
            name TEXT,
            difficulty TEXT,
            water_body_id TEXT,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            finished INTEGER NOT NULL DEFAULT 0,
            completed INTEGER NOT NULL DEFAULT 0,
            distance_meters REAL NOT NULL DEFAULT 0,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            avg_speed_kph REAL NOT NULL DEFAULT 0,
            max_speed_kph REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            recording_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            altitude REAL,
            speed_kph REAL,
            accuracy REAL,
            recorded_at INTEGER NOT NULL,
            acked INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE UNIQUE INDEX points_rec_seq ON points(recording_id, seq)');
        await db.execute(
            'CREATE INDEX points_rec_acked ON points(recording_id, acked)');
      },
    );
  }

  Database get _d {
    final db = _db;
    if (db == null) {
      throw StateError('TrackStore.init() must be awaited before use');
    }
    return db;
  }

  String _newId() =>
      'rec_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(0xFFFFFF)}';

  Future<Recording> startRecording({
    String? name,
    String? difficulty,
    String? waterBodyId,
    String? eventId,
    String? serverTrackId,
  }) async {
    final id = _newId();
    final startedAt = DateTime.now();
    await _d.insert('recordings', {
      'id': id,
      'server_track_id': serverTrackId,
      'event_id': eventId,
      'name': name,
      'difficulty': difficulty,
      'water_body_id': waterBodyId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'finished': 0,
      'completed': 0,
    });
    return Recording(
      id: id,
      serverTrackId: serverTrackId,
      eventId: eventId,
      name: name,
      difficulty: difficulty,
      waterBodyId: waterBodyId,
      startedAt: startedAt,
    );
  }

  Future<void> attachServerTrack(String id, String serverTrackId) =>
      _d.update('recordings', {'server_track_id': serverTrackId},
          where: 'id = ?', whereArgs: [id]);

  Future<void> appendPoint(String recordingId, GpsPoint point,
          {double? accuracy}) =>
      _d.insert(
        'points',
        {
          'recording_id': recordingId,
          'seq': point.seq,
          'lat': point.lat,
          'lng': point.lng,
          'altitude': point.altitude,
          'speed_kph': point.speedKph,
          'accuracy': accuracy,
          'recorded_at': point.recordedAt.millisecondsSinceEpoch,
          'acked': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  /// Точки, которые сервер ещё не подтвердил.
  Future<List<GpsPoint>> pendingPoints(String recordingId,
      {int limit = 100}) async {
    final rows = await _d.query(
      'points',
      where: 'recording_id = ? AND acked = 0',
      whereArgs: [recordingId],
      orderBy: 'seq ASC',
      limit: limit,
    );
    return rows
        .map((row) => GpsPoint(
              seq: row['seq'] as int,
              lat: row['lat'] as double,
              lng: row['lng'] as double,
              altitude: (row['altitude'] as num?)?.toDouble(),
              speedKph: (row['speed_kph'] as num?)?.toDouble(),
              recordedAt: DateTime.fromMillisecondsSinceEpoch(
                  row['recorded_at'] as int),
            ))
        .toList(growable: false);
  }

  Future<void> markAcked(String recordingId, List<int> seqs) async {
    if (seqs.isEmpty) return;
    final batch = _d.batch();
    for (final seq in seqs) {
      batch.update(
        'points',
        {'acked': 1},
        where: 'recording_id = ? AND seq = ?',
        whereArgs: [recordingId, seq],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countPoints(String recordingId, {bool onlyPending = false}) async {
    final rows = await _d.rawQuery(
      'SELECT COUNT(*) AS c FROM points WHERE recording_id = ?'
      '${onlyPending ? ' AND acked = 0' : ''}',
      [recordingId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Все точки записи — для отрисовки линии маршрута.
  Future<List<GpsPoint>> allPoints(String recordingId) async {
    final rows = await _d.query(
      'points',
      where: 'recording_id = ?',
      whereArgs: [recordingId],
      orderBy: 'seq ASC',
    );
    return rows
        .map((row) => GpsPoint(
              seq: row['seq'] as int,
              lat: row['lat'] as double,
              lng: row['lng'] as double,
              altitude: (row['altitude'] as num?)?.toDouble(),
              speedKph: (row['speed_kph'] as num?)?.toDouble(),
              recordedAt: DateTime.fromMillisecondsSinceEpoch(
                  row['recorded_at'] as int),
            ))
        .toList(growable: false);
  }

  Future<int> nextSeq(String recordingId) async {
    final rows = await _d.rawQuery(
      'SELECT MAX(seq) AS m FROM points WHERE recording_id = ?',
      [recordingId],
    );
    final max = rows.first['m'] as int?;
    return (max ?? -1) + 1;
  }

  Future<void> saveStats(
    String recordingId, {
    required double distanceMeters,
    required int durationSeconds,
    required double avgSpeedKph,
    required double maxSpeedKph,
  }) =>
      _d.update(
        'recordings',
        {
          'distance_meters': distanceMeters,
          'duration_seconds': durationSeconds,
          'avg_speed_kph': avgSpeedKph,
          'max_speed_kph': maxSpeedKph,
        },
        where: 'id = ?',
        whereArgs: [recordingId],
      );

  Future<void> markFinished(String recordingId, DateTime endedAt) =>
      _d.update('recordings',
          {'finished': 1, 'ended_at': endedAt.millisecondsSinceEpoch},
          where: 'id = ?', whereArgs: [recordingId]);

  Future<void> markCompleted(String recordingId) =>
      _d.update('recordings', {'completed': 1},
          where: 'id = ?', whereArgs: [recordingId]);

  Future<void> rename(String recordingId, String? name, String? difficulty) =>
      _d.update('recordings', {'name': name, 'difficulty': difficulty},
          where: 'id = ?', whereArgs: [recordingId]);

  /// Незакрытая запись (приложение закрыли посреди заплыва) — ТЗ §12.5.
  Future<PendingRecording?> unfinishedRecording() async {
    final rows = await _d.query(
      'recordings',
      where: 'completed = 0',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final recording = Recording.fromRow(rows.first);
    return (
      recording: recording,
      pendingPoints: await countPoints(recording.id, onlyPending: true),
    );
  }

  /// Все записи, которые не дошли до сервера (для фоновой досинхронизации).
  Future<List<Recording>> unsyncedRecordings() async {
    final rows = await _d.query('recordings',
        where: 'completed = 0', orderBy: 'started_at ASC');
    return rows.map(Recording.fromRow).toList(growable: false);
  }

  Future<void> deleteRecording(String id) async {
    await _d.delete('points', where: 'recording_id = ?', whereArgs: [id]);
    await _d.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
