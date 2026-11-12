// Модели данных SUP FUN — ровно то, что отдаёт бэкенд NestJS.
//
// Имена полей совпадают с JSON сервера, разбор терпимый к null:
// сервер отдаёт сущности целиком (см. ТЕХНИЧЕСКОЕ_РЕШЕНИЕ.md §8 п.7),
// поэтому лишние поля просто игнорируются.
import '../core/formatting.dart';
import '../core/json_utils.dart';


// ------------------------------------------------------------------- пользователь

enum UserRole { user, guide, moderator, admin }

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? city;
  final String? region;
  final String? country;
  final String? avatarUrl;
  final String? bio;
  final String? homeWaterBodyId;
  final UserRole role;
  final int xp;
  final bool isEmailVerified;
  final bool isBanned;
  final String profileVisibility;
  final String activityVisibility;
  final String geoVisibility;
  final bool showOnline;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.city,
    this.region,
    this.country,
    this.avatarUrl,
    this.bio,
    this.homeWaterBodyId,
    this.role = UserRole.user,
    this.xp = 0,
    this.isEmailVerified = false,
    this.isBanned = false,
    this.profileVisibility = 'public',
    this.activityVisibility = 'public',
    this.geoVisibility = 'private',
    this.showOnline = true,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asString(json['id']),
        email: asString(json['email']),
        name: asString(json['name'], 'Без имени'),
        phone: asStringOrNull(json['phone']),
        city: asStringOrNull(json['city']),
        region: asStringOrNull(json['region']),
        country: asStringOrNull(json['country']),
        avatarUrl: absoluteUrl(asStringOrNull(json['avatarUrl'])),
        bio: asStringOrNull(json['bio']),
        homeWaterBodyId: asStringOrNull(json['homeWaterBodyId']),
        role: userRoleFrom(json['role']),
        xp: asInt(json['xp']),
        isEmailVerified: asBool(json['isEmailVerified']),
        isBanned: asBool(json['isBanned']),
        profileVisibility: asString(json['profileVisibility'], 'public'),
        activityVisibility: asString(json['activityVisibility'], 'public'),
        geoVisibility: asString(json['geoVisibility'], 'private'),
        showOnline: asBool(json['showOnline'], true),
        createdAt: asDateOrNull(json['createdAt']),
      );

  /// Пользователь в мини-карточке (участник, продавец, автор).
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters2();
    return '${parts[0].characters2()} ${parts[1].characters2()}';
  }

  String get displayCity => city ?? region ?? '';

  bool get isStaff => role == UserRole.admin || role == UserRole.moderator;

  String get roleLabel => switch (role) {
        UserRole.admin => 'Администратор',
        UserRole.moderator => 'Модератор',
        UserRole.guide => 'Гид',
        UserRole.user => 'Участник',
      };

  AppUser copyWith({
    String? name,
    String? city,
    String? region,
    String? country,
    String? bio,
    String? phone,
    String? avatarUrl,
    int? xp,
    bool? isEmailVerified,
  }) =>
      AppUser(
        id: id,
        email: email,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        region: region ?? this.region,
        country: country ?? this.country,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        homeWaterBodyId: homeWaterBodyId,
        role: role,
        xp: xp ?? this.xp,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        isBanned: isBanned,
        profileVisibility: profileVisibility,
        activityVisibility: activityVisibility,
        geoVisibility: geoVisibility,
        showOnline: showOnline,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'city': city,
        'region': region,
        'country': country,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'homeWaterBodyId': homeWaterBodyId,
        'role': role.name,
        'xp': xp,
        'isEmailVerified': isEmailVerified,
        'isBanned': isBanned,
        'profileVisibility': profileVisibility,
        'activityVisibility': activityVisibility,
        'geoVisibility': geoVisibility,
        'showOnline': showOnline,
        'createdAt': createdAt?.toIso8601String(),
      };
}

UserRole userRoleFrom(Object? value) => switch (asString(value)) {
      'admin' => UserRole.admin,
      'moderator' => UserRole.moderator,
      'guide' => UserRole.guide,
      _ => UserRole.user,
    };

extension on String {
  String characters2() => isEmpty ? '?' : substring(0, 1).toUpperCase();
}

// ------------------------------------------------------------------ геймификация

class LevelInfo {
  final int level;
  final int xp;
  final int currentLevelXp;
  final int nextLevelXp;
  final double progress;

  const LevelInfo({
    required this.level,
    required this.xp,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.progress,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> json) => LevelInfo(
        level: asInt(json['level'], 1),
        xp: asInt(json['xp']),
        currentLevelXp: asInt(json['currentLevelXp']),
        nextLevelXp: asInt(json['nextLevelXp'], 1),
        progress: asDouble(json['progress']).clamp(0, 1).toDouble(),
      );

  static LevelInfo empty() =>
      const LevelInfo(
          level: 1, xp: 0, currentLevelXp: 0, nextLevelXp: 200, progress: 0);
}

class Achievement {
  final String code;
  final String title;
  final String description;
  final String icon;
  final int xp;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.xp,
    required this.unlocked,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        code: asString(json['code']),
        title: asString(json['title']),
        description: asString(json['description']),
        icon: asString(json['icon'], '🏅'),
        xp: asInt(json['xp']),
        unlocked: asBool(json['unlocked']),
        unlockedAt: asDateOrNull(json['unlockedAt']),
      );
}

class PointLogEntry {
  final String id;
  final String action;
  final int points;
  final String? refType;
  final DateTime createdAt;

  const PointLogEntry({
    required this.id,
    required this.action,
    required this.points,
    this.refType,
    required this.createdAt,
  });

  factory PointLogEntry.fromJson(Map<String, dynamic> json) => PointLogEntry(
        id: asString(json['id']),
        action: asString(json['action']),
        points: asInt(json['points']),
        refType: asStringOrNull(json['refType']),
        createdAt: asDate(json['createdAt']),
      );

  /// Человекочитаемое название начисления (ТЗ §19).
  String get label => switch (action) {
        'track_completed' => 'Завершён заплыв',
        'distance_bonus' => 'Бонус за дистанцию',
        'group_swim' => 'Заплыв в составе события',
        'route_published' => 'Опубликован маршрут',
        'event_created' => 'Создан заплыв',
        'achievement' => 'Открыто достижение',
        _ => action,
      };
}

/// Ответ /tracks/:id/complete и /events/:id/tracks/:trackId/finish.
class AwardResult {
  final int points;
  final int userXp;
  final List<Achievement> unlocked;

  const AwardResult({
    required this.points,
    required this.userXp,
    this.unlocked = const [],
  });

  factory AwardResult.fromJson(Map<String, dynamic> json) => AwardResult(
        points: asInt(json['points']),
        userXp: asInt(json['userXp']),
        unlocked: asMapList(json['unlocked'])
            .map(Achievement.fromJson)
            .toList(growable: false),
      );

  static const empty = AwardResult(points: 0, userXp: 0);
}

class LeaderboardEntry {
  final int rank;
  final String id;
  final String name;
  final String? avatarUrl;
  final String? city;
  final int xp;
  final int level;

  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    this.avatarUrl,
    this.city,
    required this.xp,
    required this.level,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: asInt(json['rank']),
        id: asString(json['id']),
        name: asString(json['name']),
        avatarUrl: absoluteUrl(asStringOrNull(json['avatarUrl'])),
        city: asStringOrNull(json['city']),
        xp: asInt(json['xp']),
        level: asInt(json['level']),
      );
}

// ---------------------------------------------------------------------- водоёмы

class WaterBody {
  final String id;
  final String name;
  final String? description;
  final String? region;
  final bool active;
  final double? latitude;
  final double? longitude;

  const WaterBody({
    required this.id,
    required this.name,
    this.description,
    this.region,
    this.active = true,
    this.latitude,
    this.longitude,
  });

  factory WaterBody.fromJson(Map<String, dynamic> json) {
    final point = geoPoint(json);
    return WaterBody(
      id: asString(json['id']),
      name: asString(json['name'], 'Водоём'),
      description: asStringOrNull(json['description']),
      region: asStringOrNull(json['region']),
      active: asBool(json['active'], true),
      latitude: point?.$1,
      longitude: point?.$2,
    );
  }

  /// Расстояние от точки пользователя; null, если у водоёма нет координат.
  double? distanceTo(double lat, double lng) {
    final a = latitude, b = longitude;
    if (a == null || b == null) return null;
    return haversineMeters(a, b, lat, lng);
  }
}

class NearbyWaterBody {
  final String id;
  final String name;
  final String? region;
  final double distanceMeters;

  const NearbyWaterBody({
    required this.id,
    required this.name,
    this.region,
    required this.distanceMeters,
  });

  factory NearbyWaterBody.fromJson(Map<String, dynamic> json) =>
      NearbyWaterBody(
        id: asString(json['id']),
        name: asString(json['name'], 'Водоём'),
        region: asStringOrNull(json['region']),
        distanceMeters: asDouble(
            json['distance_meters'] ?? json['distanceMeters']),
      );
}

// ----------------------------------------------------------------------- заплывы

enum EventStatus { draft, scheduled, onWater, completed, cancelled }

enum ParticipantStatus { going, maybe, notGoing }

class SupEvent {
  final String id;
  final String title;
  final String? description;
  final List<String> photos;
  final String? organizerId;
  final AppUser? organizer;
  final String? organizerName;
  final String? waterBodyId;
  final String? waterBodyName;
  final String? trackId;
  final String? trackName;
  final DateTime eventDate;
  final int? expectedDurationMinutes;
  final double? expectedDistanceMeters;
  final String level;
  final String visibility;
  final String access;
  final int? maxParticipants;
  final EventStatus status;
  final double? startLat;
  final double? startLng;
  final int participantCount;

  const SupEvent({
    required this.id,
    required this.title,
    this.description,
    this.photos = const [],
    this.organizerId,
    this.organizer,
    this.organizerName,
    this.waterBodyId,
    this.waterBodyName,
    this.trackId,
    this.trackName,
    required this.eventDate,
    this.expectedDurationMinutes,
    this.expectedDistanceMeters,
    this.level = 'beginner',
    this.visibility = 'public',
    this.access = 'open',
    this.maxParticipants,
    this.status = EventStatus.scheduled,
    this.startLat,
    this.startLng,
    this.participantCount = 0,
  });

  factory SupEvent.fromJson(Map<String, dynamic> json) {
    final organizer = asMap(json['organizer']);
    final waterBody = asMap(json['waterBody']);
    final track = asMap(json['track']);
    return SupEvent(
      id: asString(json['id']),
      title: asString(json['title'], 'Заплыв'),
      description: asStringOrNull(json['description']),
      photos: asStringList(json['photos'])
          .map((url) => absoluteUrl(url) ?? url)
          .toList(growable: false),
      organizerId: asStringOrNull(json['organizerId']),
      organizer: organizer.isEmpty
          ? null
          : AppUser.fromJson(organizer),
      organizerName: asStringOrNull(organizer['name']),
      waterBodyId: asStringOrNull(json['waterBodyId']),
      waterBodyName: asStringOrNull(waterBody['name']),
      trackId: asStringOrNull(json['trackId']),
      trackName: asStringOrNull(track['name']),
      eventDate: asDate(json['eventDate']),
      expectedDurationMinutes:
          asDoubleOrNull(json['expectedDurationMinutes'])?.toInt(),
      expectedDistanceMeters:
          asDoubleOrNull(json['expectedDistanceMeters']),
      level: asString(json['level'], 'beginner'),
      visibility: asString(json['visibility'], 'public'),
      access: asString(json['access'], 'open'),
      maxParticipants: asDoubleOrNull(json['maxParticipants'])?.toInt(),
      status: eventStatusFrom(json['status']),
      startLat: asDoubleOrNull(json['startLat']),
      startLng: asDoubleOrNull(json['startLng']),
      participantCount: asInt(json['participantCount']),
    );
  }

  String get levelLabel => switch (level) {
        'beginner' => 'Начальный',
        'pro' => 'Профи',
        _ => 'Средний',
      };

  String get statusLabel => switch (status) {
        EventStatus.draft => 'Черновик',
        EventStatus.scheduled => 'Запланирован',
        EventStatus.onWater => 'На воде',
        EventStatus.completed => 'Завершён',
        EventStatus.cancelled => 'Отменён',
      };

  bool get isUpcoming =>
      status == EventStatus.scheduled && eventDate.isAfter(DateTime.now());
}

EventStatus eventStatusFrom(Object? value) => switch (asString(value)) {
      'draft' => EventStatus.draft,
      'on_water' => EventStatus.onWater,
      'completed' => EventStatus.completed,
      'cancelled' => EventStatus.cancelled,
      _ => EventStatus.scheduled,
    };

ParticipantStatus participantStatusFrom(Object? value) =>
    switch (asString(value)) {
      'maybe' => ParticipantStatus.maybe,
      'not_going' => ParticipantStatus.notGoing,
      _ => ParticipantStatus.going,
    };

extension ParticipantStatusX on ParticipantStatus {
  String get label => switch (this) {
        ParticipantStatus.going => 'Иду',
        ParticipantStatus.maybe => 'Может быть',
        ParticipantStatus.notGoing => 'Не пойду',
      };

  String get apiValue => switch (this) {
        ParticipantStatus.going => 'going',
        ParticipantStatus.maybe => 'maybe',
        ParticipantStatus.notGoing => 'not_going',
      };
}

class EventParticipant {
  final String userId;
  final String name;
  final String? avatarUrl;
  final ParticipantStatus status;
  final DateTime? joinedAt;

  const EventParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.status,
    this.joinedAt,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return EventParticipant(
      userId: asString(json['userId'] ?? user['id']),
      name: asString(user['name'], 'Участник'),
      avatarUrl: absoluteUrl(asStringOrNull(user['avatarUrl'])),
      status: participantStatusFrom(json['status']),
      joinedAt: asDateOrNull(json['joinedAt']),
    );
  }
}

// ------------------------------------------------------------------------ треки

enum TrackStatus { draft, privateRoute, moderation, published, hidden }

enum TrackDifficulty { easy, medium, hard }

class Track {
  final String id;
  final String userId;
  final String? authorName;
  final String? name;
  final TrackStatus status;
  final TrackDifficulty? difficulty;
  final String? waterBodyId;
  final String? waterBodyName;
  final String? eventId;
  final double distanceMeters;
  final int durationSeconds;
  final double avgSpeedKph;
  final double maxSpeedKph;
  final double elevationGainMeters;
  final double elevationLossMeters;
  final int calories;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<List<double>> routeLine;

  const Track({
    required this.id,
    required this.userId,
    this.authorName,
    this.name,
    this.status = TrackStatus.privateRoute,
    this.difficulty,
    this.waterBodyId,
    this.waterBodyName,
    this.eventId,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.avgSpeedKph = 0,
    this.maxSpeedKph = 0,
    this.elevationGainMeters = 0,
    this.elevationLossMeters = 0,
    this.calories = 0,
    required this.startedAt,
    this.endedAt,
    this.routeLine = const [],
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    final waterBody = asMap(json['waterBody']);
    final line = asMap(json['routeLine']);
    final coordinates = line['coordinates'];
    final points = <List<double>>[];
    if (coordinates is List) {
      for (final c in coordinates) {
        if (c is List && c.length >= 2) {
          points.add([asDouble(c[0]), asDouble(c[1])]);
        }
      }
    }
    return Track(
      id: asString(json['id']),
      userId: asString(json['userId'] ?? user['id']),
      authorName: asStringOrNull(user['name']),
      name: asStringOrNull(json['name']),
      status: trackStatusFrom(json['status']),
      difficulty: asStringOrNull(json['difficulty']) == null
          ? null
          : trackDifficultyFrom(json['difficulty']),
      waterBodyId: asStringOrNull(json['waterBodyId']),
      waterBodyName: asStringOrNull(waterBody['name']),
      eventId: asStringOrNull(json['eventId']),
      distanceMeters: asDouble(json['distanceMeters']),
      durationSeconds: asInt(json['durationSeconds']),
      avgSpeedKph: asDouble(json['avgSpeedKph']),
      maxSpeedKph: asDouble(json['maxSpeedKph']),
      elevationGainMeters: asDouble(json['elevationGainMeters']),
      elevationLossMeters: asDouble(json['elevationLossMeters']),
      calories: asInt(json['calories']),
      startedAt: asDate(json['startedAt']),
      endedAt: asDateOrNull(json['endedAt']),
      routeLine: points,
    );
  }

  String get title => name?.isNotEmpty == true ? name! : 'Заплыв';

  double get distanceKm => distanceMeters / 1000;

  String get difficultyLabel => switch (difficulty) {
        TrackDifficulty.easy => 'Лёгкий',
        TrackDifficulty.medium => 'Средний',
        TrackDifficulty.hard => 'Сложный',
        null => '—',
      };

  String get statusLabel => switch (status) {
        TrackStatus.draft => 'Черновик',
        TrackStatus.privateRoute => 'Личный',
        TrackStatus.moderation => 'На модерации',
        TrackStatus.published => 'Опубликован',
        TrackStatus.hidden => 'Скрыт',
      };

  bool get isPublished => status == TrackStatus.published;
  bool get isFinished => endedAt != null;
}

TrackStatus trackStatusFrom(Object? value) => switch (asString(value)) {
      'draft' => TrackStatus.draft,
      'moderation' => TrackStatus.moderation,
      'published' => TrackStatus.published,
      'hidden' => TrackStatus.hidden,
      _ => TrackStatus.privateRoute,
    };

TrackDifficulty trackDifficultyFrom(Object? value) => switch (asString(value)) {
      'hard' => TrackDifficulty.hard,
      'medium' => TrackDifficulty.medium,
      _ => TrackDifficulty.easy,
    };

extension TrackDifficultyX on TrackDifficulty {
  String get apiValue => name;
  String get label => switch (this) {
        TrackDifficulty.easy => 'Лёгкий',
        TrackDifficulty.medium => 'Средний',
        TrackDifficulty.hard => 'Сложный',
      };
}

/// Точка GPS в очереди отправки (seq — ключ идемпотентности на сервере).
class GpsPoint {
  final int seq;
  final double lat;
  final double lng;
  final double? altitude;
  final double? speedKph;
  final DateTime recordedAt;

  const GpsPoint({
    required this.seq,
    required this.lat,
    required this.lng,
    this.altitude,
    this.speedKph,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'lat': lat,
        'lng': lng,
        if (altitude != null) 'altitude': altitude,
        if (speedKph != null) 'speedKph': speedKph,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}

class TrackPoint {
  final int? seq;
  final double lat;
  final double lng;
  final double? altitude;
  final double? speedKph;
  final DateTime recordedAt;

  const TrackPoint({
    this.seq,
    required this.lat,
    required this.lng,
    this.altitude,
    this.speedKph,
    required this.recordedAt,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        seq: asDoubleOrNull(json['seq'])?.toInt(),
        lat: asDouble(json['lat']),
        lng: asDouble(json['lng']),
        altitude: asDoubleOrNull(json['altitude']),
        speedKph: asDoubleOrNull(json['speedKph']),
        recordedAt: asDate(json['recordedAt']),
      );
}

// ------------------------------------------------------------------ лента/посты

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String type;
  final String? title;
  final String? body;
  final List<String> photos;
  final String? refId;
  final String? refType;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool likedByMe;
  final bool canDelete;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.type,
    this.title,
    this.body,
    this.photos = const [],
    this.refId,
    this.refType,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.likedByMe = false,
    this.canDelete = false,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final author = asMap(json['author']);
    return Post(
      id: asString(json['id']),
      authorId: asString(json['authorId'] ?? author['id']),
      authorName: asString(author['name'], 'Участник'),
      authorAvatar: absoluteUrl(asStringOrNull(author['avatarUrl'])),
      type: asString(json['type'], 'swim'),
      title: asStringOrNull(json['title']),
      body: asStringOrNull(json['body']),
      photos: asStringList(json['photos'])
          .map((url) => absoluteUrl(url) ?? url)
          .toList(growable: false),
      refId: asStringOrNull(json['refId']),
      refType: asStringOrNull(json['refType']),
      likeCount: asInt(json['likeCount']),
      commentCount: asInt(json['commentCount']),
      shareCount: asInt(json['shareCount']),
      likedByMe: asBool(json['likedByMe']),
      canDelete: asBool(json['canDelete']),
      createdAt: asDate(json['createdAt']),
    );
  }

  String get typeLabel => switch (type) {
        'swim' => 'завершил заплыв',
        'route' => 'опубликовал маршрут',
        'achievement' => 'получил достижение',
        'event' => 'создал заплыв',
        'news' => 'новость',
        'waterbody' => 'новый водоём',
        _ => type,
      };
}

/// Агрегатор GET /feed — маршруты, заплывы и объявления рядом.
class FeedSnapshot {
  final List<Track> routes;
  final List<SupEvent> events;
  final List<Listing> listings;

  const FeedSnapshot({
    this.routes = const [],
    this.events = const [],
    this.listings = const [],
  });

  factory FeedSnapshot.fromJson(Map<String, dynamic> json) => FeedSnapshot(
        routes: asMapList(json['routes']).map(trackLite).toList(),
        events: asMapList(json['events']).map(_eventLite).toList(),
        listings: asMapList(json['listings']).map(Listing.fromJson).toList(),
      );

  bool get isEmpty => routes.isEmpty && events.isEmpty && listings.isEmpty;
}

/// Маршрут из агрегаторов (/feed, /search) — там трек пришлён «облегчённо».
Track trackLite(Map<String, dynamic> json) => Track(
      id: asString(json['id']),
      userId: asString(json['userId']),
      authorName: asStringOrNull(json['userName']),
      name: asStringOrNull(json['name']),
      distanceMeters: asDouble(json['distance_meters'] ?? json['distanceMeters']),
      durationSeconds: asInt(json['duration_seconds'] ?? json['durationSeconds']),
      avgSpeedKph: asDouble(json['avgSpeedKph']),
      difficulty: asStringOrNull(json['difficulty']) == null
          ? null
          : trackDifficultyFrom(json['difficulty']),
      startedAt: asDate(json['startedAt']),
      status: TrackStatus.published,
    );

SupEvent _eventLite(Map<String, dynamic> json) => SupEvent(
      id: asString(json['id']),
      title: asString(json['title'], 'Заплыв'),
      organizerId: asStringOrNull(json['organizerId']),
      organizerName: asStringOrNull(json['organizerName']),
      waterBodyName: asStringOrNull(json['waterBodyName']),
      eventDate: asDate(json['eventDate']),
      visibility: asString(json['visibility'], 'public'),
      startLat: asDoubleOrNull(json['startLat']),
      startLng: asDoubleOrNull(json['startLng']),
    );

// ------------------------------------------------------------------- маркетплейс

class Listing {
  final String id;
  final String sellerId;
  final String sellerName;
  final String category;
  final String title;
  final String? description;
  final double? price;
  final String currency;
  final List<String> photos;
  final String? city;
  final String status;
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.category,
    required this.title,
    this.description,
    this.price,
    this.currency = 'RUB',
    this.photos = const [],
    this.city,
    this.status = 'active',
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    final seller = asMap(json['seller']);
    return Listing(
      id: asString(json['id']),
      sellerId: asString(json['sellerId'] ?? seller['id']),
      sellerName: asString(seller['name'], 'Продавец'),
      category: asString(json['category'], 'other'),
      title: asString(json['title'], 'Объявление'),
      description: asStringOrNull(json['description']),
      price: asDoubleOrNull(json['price']),
      currency: asString(json['currency'], 'RUB'),
      photos: asStringList(json['photos'])
          .map((url) => absoluteUrl(url) ?? url)
          .toList(growable: false),
      city: asStringOrNull(json['city']),
      status: asString(json['status'], 'active'),
      createdAt: asDate(json['createdAt']),
    );
  }

  String get priceLabel {
    if (price == null) return 'Договорная';
    final formatted = price! % 1 == 0
        ? price!.toStringAsFixed(0)
        : price!.toStringAsFixed(2);
    return '$formatted ${currency == 'RUB' ? '₽' : currency}';
  }

  String get statusLabel => switch (status) {
        'draft' => 'Черновик',
        'moderation' => 'На модерации',
        'active' => 'Активно',
        'sold' => 'Продано',
        'completed' => 'Завершено',
        'removed' => 'Снято',
        'blocked' => 'Заблокировано',
        _ => status,
      };
}

// ------------------------------------------------------------------------ чаты

class ConversationSummary {
  final String id;
  final String type;
  final String? title;
  final String? eventId;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final int unreadCount;
  final List<ChatParticipant> participants;

  const ConversationSummary({
    required this.id,
    required this.type,
    this.title,
    this.eventId,
    this.lastMessageAt,
    this.lastMessageText,
    this.unreadCount = 0,
    this.participants = const [],
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final last = asMap(json['lastMessage']);
    return ConversationSummary(
      id: asString(json['id']),
      type: asString(json['type'], 'direct'),
      title: asStringOrNull(json['title']),
      eventId: asStringOrNull(json['eventId']),
      lastMessageAt: asDateOrNull(json['lastMessageAt']),
      lastMessageText: asStringOrNull(last['content']),
      unreadCount: asInt(json['unreadCount']),
      participants: asMapList(json['participants'])
          .map(ChatParticipant.fromJson)
          .toList(growable: false),
    );
  }

  String get typeLabel => switch (type) {
        'direct' => 'Личный',
        'group' => 'Группа',
        'event' => 'Заплыв',
        'deal' => 'Сделка',
        _ => type,
      };
}

class ChatParticipant {
  final String userId;
  final String name;
  final String? avatarUrl;

  const ChatParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return ChatParticipant(
      userId: asString(json['userId'] ?? user['id']),
      name: asString(user['name'], 'Участник'),
      avatarUrl: absoluteUrl(asStringOrNull(user['avatarUrl'])),
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String type;
  final String? content;
  final double? latitude;
  final double? longitude;
  final String status;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.content,
    this.latitude,
    this.longitude,
    this.status = 'sent',
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = asMap(json['sender']);
    return ChatMessage(
      id: asString(json['id']),
      conversationId: asString(json['conversationId']),
      senderId: asString(json['senderId'] ?? sender['id']),
      senderName: asString(sender['name'], 'Участник'),
      type: asString(json['type'], 'text'),
      content: asStringOrNull(json['content']),
      latitude: asDoubleOrNull(json['latitude']),
      longitude: asDoubleOrNull(json['longitude']),
      status: asString(json['status'], 'sent'),
      createdAt: asDate(json['createdAt']),
    );
  }

  String get displayText =>
      content ?? (type == 'location' ? 'Геолокация' : 'Вложение');
}

// ------------------------------------------------------------------ уведомления

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: asString(json['id']),
        type: asString(json['type'], 'info'),
        title: asString(json['title']),
        body: asStringOrNull(json['body']),
        isRead: asBool(json['isRead']),
        createdAt: asDate(json['createdAt']),
      );
}

// ------------------------------------------------------------------- снаряжение

class GearItem {
  final String id;
  final String category;
  final String? brand;
  final String? model;
  final String? notes;

  const GearItem({
    required this.id,
    required this.category,
    this.brand,
    this.model,
    this.notes,
  });

  factory GearItem.fromJson(Map<String, dynamic> json) => GearItem(
        id: asString(json['id']),
        category: asString(json['category'], 'other'),
        brand: asStringOrNull(json['brand']),
        model: asStringOrNull(json['model']),
        notes: asStringOrNull(json['notes']),
      );

  String get title {
    final parts = [brand, model].whereType<String>().toList();
    return parts.isEmpty ? categoryLabel : parts.join(' ');
  }

  String get categoryLabel => switch (category) {
        'board' => 'Доска',
        'paddle' => 'Весло',
        'wetsuit' => 'Гидрокостюм',
        'vest' => 'Жилет',
        'leash' => 'Лиш',
        'pump' => 'Насос',
        'drybag' => 'Гермочехол',
        _ => 'Другое',
      };
}

/// Аватары и фото бэкенд отдаёт относительными путями /uploads/...
String? absoluteUrl(String? value) {
  if (value == null) return null;
  if (value.startsWith('http')) return value;
  return value;
}
