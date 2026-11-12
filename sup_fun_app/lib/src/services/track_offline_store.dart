import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalTrackRecord {
  final int localId;
  final String? serverId;
  final String userId;
  final String? name;
  final String? waterBodyId;
  final String? eventId;
  final String? routeId;
  final String difficulty;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // recording | pending_complete | completed | sync_error
  final int lastSeq;
  final double distanceMeters;
  final int durationSeconds;

  const LocalTrackRecord({
    required this.localId,
    required this.serverId,
    required this.userId,
    required this.name,
    required this.waterBodyId,
    required this.eventId,
    this.routeId,
    required this.difficulty,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.lastSeq,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  bool get isUnfinished => status == 'recording' || status == 'pending_complete';

  LocalTrackRecord copyWith({
    String? serverId,
    DateTime? endedAt,
    String? status,
    int? lastSeq,
    double? distanceMeters,
    int? durationSeconds,
    String? name,
  }) =>
      LocalTrackRecord(
        localId: localId,
        serverId: serverId ?? this.serverId,
        userId: userId,
        name: name ?? this.name,
        waterBodyId: waterBodyId,
        eventId: eventId,
        routeId: routeId,
        difficulty: difficulty,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        lastSeq: lastSeq ?? this.lastSeq,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}

class LocalPointRecord {
  final int? localId;
  final int trackLocalId;
  final int seq;
  final double lat;
  final double lng;
  final double? altitude;
  final double? speedKph;
  final DateTime recordedAt;
  final bool sent;

  const LocalPointRecord({
    this.localId,
    required this.trackLocalId,
    required this.seq,
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.speedKph,
    required this.recordedAt,
    this.sent = false,
  });
}

class TrackOfflineStore {
  TrackOfflineStore._();
  static final TrackOfflineStore instance = TrackOfflineStore._();

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'supfun_tracks.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_tracks (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_id TEXT,
            user_id TEXT NOT NULL,
            name TEXT,
            water_body_id TEXT,
            event_id TEXT,
            route_id TEXT,
            difficulty TEXT NOT NULL DEFAULT 'easy',
            started_at TEXT NOT NULL,
            ended_at TEXT,
            status TEXT NOT NULL,
            last_seq INTEGER NOT NULL DEFAULT -1,
            distance_meters REAL NOT NULL DEFAULT 0,
            duration_seconds INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE local_points (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            track_local_id INTEGER NOT NULL,
            seq INTEGER NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            altitude REAL,
            speed_kph REAL,
            recorded_at TEXT NOT NULL,
            sent INTEGER NOT NULL DEFAULT 0,
            UNIQUE(track_local_id, seq)
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_local_points_unsent ON local_points(track_local_id, sent, seq)');
        await db.execute(
            'CREATE INDEX idx_local_tracks_status ON local_tracks(status)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE local_tracks ADD COLUMN route_id TEXT');
          } catch (_) {}
        }
      },
    );
    return _db!;
  }

  LocalTrackRecord _trackFromRow(Map<String, Object?> r) => LocalTrackRecord(
        localId: r['local_id'] as int,
        serverId: r['server_id'] as String?,
        userId: r['user_id'] as String,
        name: r['name'] as String?,
        waterBodyId: r['water_body_id'] as String?,
        eventId: r['event_id'] as String?,
        routeId: r['route_id'] as String?,
        difficulty: (r['difficulty'] as String?) ?? 'easy',
        startedAt: DateTime.parse(r['started_at'] as String),
        endedAt: r['ended_at'] != null ? DateTime.parse(r['ended_at'] as String) : null,
        status: r['status'] as String,
        lastSeq: (r['last_seq'] as int?) ?? -1,
        distanceMeters: (r['distance_meters'] as num?)?.toDouble() ?? 0,
        durationSeconds: (r['duration_seconds'] as int?) ?? 0,
      );

  Future<LocalTrackRecord> createTrack({
    required String userId,
    String? serverId,
    String? name,
    String? waterBodyId,
    String? eventId,
    String? routeId,
    String difficulty = 'easy',
    required DateTime startedAt,
  }) async {
    final db = await _database;
    final id = await db.insert('local_tracks', {
      'server_id': serverId,
      'user_id': userId,
      'name': name,
      'water_body_id': waterBodyId,
      'event_id': eventId,
      'route_id': routeId,
      'difficulty': difficulty,
      'started_at': startedAt.toUtc().toIso8601String(),
      'status': 'recording',
      'last_seq': -1,
      'distance_meters': 0,
      'duration_seconds': 0,
    });
    return (await getTrack(id))!;
  }

  Future<LocalTrackRecord?> getTrack(int localId) async {
    final db = await _database;
    final rows = await db.query('local_tracks',
        where: 'local_id = ?', whereArgs: [localId], limit: 1);
    if (rows.isEmpty) return null;
    return _trackFromRow(rows.first);
  }

  Future<LocalTrackRecord?> getTrackByServerId(String serverId) async {
    final db = await _database;
    final rows = await db.query('local_tracks',
        where: 'server_id = ?', whereArgs: [serverId], limit: 1);
    if (rows.isEmpty) return null;
    return _trackFromRow(rows.first);
  }

  Future<LocalTrackRecord?> findUnfinished(String userId) async {
    final db = await _database;
    final rows = await db.query(
      'local_tracks',
      where: "user_id = ? AND status IN ('recording','pending_complete')",
      whereArgs: [userId],
      orderBy: 'local_id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _trackFromRow(rows.first);
  }

  Future<void> attachServerId(int localId, String serverId) async {
    final db = await _database;
    await db.update('local_tracks', {'server_id': serverId},
        where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<void> updateTrackProgress(
    int localId, {
    required int lastSeq,
    required double distanceMeters,
    required int durationSeconds,
  }) async {
    final db = await _database;
    await db.update(
      'local_tracks',
      {
        'last_seq': lastSeq,
        'distance_meters': distanceMeters,
        'duration_seconds': durationSeconds,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> setTrackStatus(int localId, String status,
      {DateTime? endedAt, String? name}) async {
    final db = await _database;
    final data = <String, Object?>{'status': status};
    if (endedAt != null) data['ended_at'] = endedAt.toUtc().toIso8601String();
    if (name != null) data['name'] = name;
    await db.update('local_tracks', data,
        where: 'local_id = ?', whereArgs: [localId]);
  }

  Future<void> insertPoint(LocalPointRecord point) async {
    final db = await _database;
    await db.insert(
      'local_points',
      {
        'track_local_id': point.trackLocalId,
        'seq': point.seq,
        'lat': point.lat,
        'lng': point.lng,
        'altitude': point.altitude,
        'speed_kph': point.speedKph,
        'recorded_at': point.recordedAt.toUtc().toIso8601String(),
        'sent': point.sent ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<LocalPointRecord>> getUnsentPoints(int trackLocalId,
      {int limit = 50}) async {
    final db = await _database;
    final rows = await db.query(
      'local_points',
      where: 'track_local_id = ? AND sent = 0',
      whereArgs: [trackLocalId],
      orderBy: 'seq ASC',
      limit: limit,
    );
    return rows
        .map((r) => LocalPointRecord(
              localId: r['local_id'] as int,
              trackLocalId: r['track_local_id'] as int,
              seq: r['seq'] as int,
              lat: (r['lat'] as num).toDouble(),
              lng: (r['lng'] as num).toDouble(),
              altitude: (r['altitude'] as num?)?.toDouble(),
              speedKph: (r['speed_kph'] as num?)?.toDouble(),
              recordedAt: DateTime.parse(r['recorded_at'] as String),
              sent: (r['sent'] as int) == 1,
            ))
        .toList();
  }

  Future<int> unsentCount(int trackLocalId) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM local_points WHERE track_local_id = ? AND sent = 0',
        [trackLocalId]);
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markPointsSent(int trackLocalId, List<int> seqs) async {
    if (seqs.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(seqs.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE local_points SET sent = 1 WHERE track_local_id = ? AND seq IN ($placeholders)',
      [trackLocalId, ...seqs],
    );
  }

  Future<List<LocalPointRecord>> getAllPoints(int trackLocalId) async {
    final db = await _database;
    final rows = await db.query('local_points',
        where: 'track_local_id = ?',
        whereArgs: [trackLocalId],
        orderBy: 'seq ASC');
    return rows
        .map((r) => LocalPointRecord(
              localId: r['local_id'] as int,
              trackLocalId: r['track_local_id'] as int,
              seq: r['seq'] as int,
              lat: (r['lat'] as num).toDouble(),
              lng: (r['lng'] as num).toDouble(),
              altitude: (r['altitude'] as num?)?.toDouble(),
              speedKph: (r['speed_kph'] as num?)?.toDouble(),
              recordedAt: DateTime.parse(r['recorded_at'] as String),
              sent: (r['sent'] as int) == 1,
            ))
        .toList();
  }

  Future<void> deleteTrack(int localId) async {
    final db = await _database;
    await db.delete('local_points',
        where: 'track_local_id = ?', whereArgs: [localId]);
    await db.delete('local_tracks', where: 'local_id = ?', whereArgs: [localId]);
  }
}
