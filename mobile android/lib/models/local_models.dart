// Local storage models for SUP FUN
// Models with Hive annotations for offline storage

import 'package:hive/hive.dart';

part 'local_models.g.dart';

/// GPS-точка маршрута для локального хранения
@HiveType(typeId: 1)
class LocalRoutePoint extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double? speed;

  @HiveField(4)
  final double? altitude;

  @HiveField(5)
  final double? accuracy;

  LocalRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.altitude,
    this.accuracy,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'speed': speed,
        'altitude': altitude,
        'accuracy': accuracy,
      };

  factory LocalRoutePoint.fromJson(Map<String, dynamic> json) =>
      LocalRoutePoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        speed: (json['speed'] as num?)?.toDouble(),
        altitude: (json['altitude'] as num?)?.toDouble(),
        accuracy: (json['accuracy'] as num?)?.toDouble(),
      );
}

/// Сохраненный маршрут пользователя
@HiveType(typeId: 2)
class LocalRoute extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? waterBodyId;

  @HiveField(4)
  String? waterBodyName;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  double distance; // km

  @HiveField(7)
  int durationSeconds;

  @HiveField(8)
  double? maxSpeed;

  @HiveField(9)
  double? avgSpeed;

  @HiveField(10)
  List<LocalRoutePoint> points;

  @HiveField(11)
  String difficulty; // easy, medium, hard

  @HiveField(12)
  bool isPublic;

  @HiveField(13)
  int likes;

  @HiveField(14)
  String? coverImagePath;

  LocalRoute({
    required this.id,
    required this.name,
    this.description,
    this.waterBodyId,
    this.waterBodyName,
    required this.createdAt,
    this.distance = 0,
    this.durationSeconds = 0,
    this.maxSpeed,
    this.avgSpeed,
    List<LocalRoutePoint>? points,
    this.difficulty = 'easy',
    this.isPublic = false,
    this.likes = 0,
    this.coverImagePath,
  }) : points = points ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'waterBodyId': waterBodyId,
        'waterBodyName': waterBodyName,
        'createdAt': createdAt.toIso8601String(),
        'distance': distance,
        'durationSeconds': durationSeconds,
        'maxSpeed': maxSpeed,
        'avgSpeed': avgSpeed,
        'points': points.map((p) => p.toJson()).toList(),
        'difficulty': difficulty,
        'isPublic': isPublic,
        'likes': likes,
        'coverImagePath': coverImagePath,
      };

  Duration get duration => Duration(seconds: durationSeconds);
}

/// Кэшированный водоем для офлайн-доступа
@HiveType(typeId: 3)
class LocalWaterBody extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type;

  @HiveField(3)
  String city;

  @HiveField(4)
  double latitude;

  @HiveField(5)
  double longitude;

  @HiveField(6)
  String? description;

  @HiveField(7)
  double? temperature;

  @HiveField(8)
  String? weatherCondition;

  @HiveField(9)
  double rating;

  @HiveField(10)
  bool isFavorite;

  @HiveField(11)
  DateTime cachedAt;

  @HiveField(12)
  List<String> imagePaths; // локальные пути к фото

  LocalWaterBody({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.latitude,
    required this.longitude,
    this.description,
    this.temperature,
    this.weatherCondition,
    this.rating = 0,
    this.isFavorite = false,
    required this.cachedAt,
    List<String>? imagePaths,
  }) : imagePaths = imagePaths ?? [];
}

/// Сообщение в чате
@HiveType(typeId: 4)
class LocalChatMessage extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String conversationId;

  @HiveField(2)
  String senderId;

  @HiveField(3)
  String senderName;

  @HiveField(4)
  String content;

  @HiveField(5)
  DateTime sentAt;

  @HiveField(6)
  bool isFromMe;

  @HiveField(7)
  bool isRead;

  @HiveField(8)
  MessageStatus status; // sending, sent, delivered, read, failed

  @HiveField(9)
  String? attachmentPath;

  @HiveField(10)
  String? replyToMessageId;

  LocalChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
    this.isFromMe = false,
    this.isRead = false,
    this.status = MessageStatus.sent,
    this.attachmentPath,
    this.replyToMessageId,
  });
}

@HiveType(typeId: 5)
enum MessageStatus {
  @HiveField(0)
  sending,
  @HiveField(1)
  sent,
  @HiveField(2)
  delivered,
  @HiveField(3)
  read,
  @HiveField(4)
  failed,
}

/// Диалог/беседа
@HiveType(typeId: 6)
class LocalConversation extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String? otherUserId;

  @HiveField(2)
  String? otherUserName;

  @HiveField(3)
  String? otherUserAvatar;

  @HiveField(4)
  String? groupName;

  @HiveField(5)
  String? groupAvatar;

  @HiveField(6)
  String? lastMessagePreview;

  @HiveField(7)
  DateTime? lastMessageAt;

  @HiveField(8)
  int unreadCount;

  @HiveField(9)
  bool isGroup;

  @HiveField(10)
  List<String> participantIds;

  @HiveField(11)
  bool isMuted;

  @HiveField(12)
  bool isPinned;

  LocalConversation({
    required this.id,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.groupName,
    this.groupAvatar,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isGroup = false,
    List<String>? participantIds,
    this.isMuted = false,
    this.isPinned = false,
  }) : participantIds = participantIds ?? [];
}

/// Пост в ленте
@HiveType(typeId: 7)
class LocalFeedPost extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String authorId;

  @HiveField(2)
  String authorName;

  @HiveField(3)
  String? authorAvatar;

  @HiveField(4)
  String content;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  List<String> imagePaths; // локальные пути

  @HiveField(7)
  int likes;

  @HiveField(8)
  int comments;

  @HiveField(9)
  bool isLiked;

  @HiveField(10)
  String? relatedTripId;

  @HiveField(11)
  String? location;

  LocalFeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
    List<String>? imagePaths,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
    this.relatedTripId,
    this.location,
  }) : imagePaths = imagePaths ?? [];
}

/// Событие/мероприятие
@HiveType(typeId: 8)
class LocalEvent extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  String waterBodyId;

  @HiveField(4)
  String? waterBodyName;

  @HiveField(5)
  DateTime startsAt;

  @HiveField(6)
  DateTime? endsAt;

  @HiveField(7)
  int maxParticipants;

  @HiveField(8)
  int currentParticipants;

  @HiveField(9)
  String type; // individual, group, training, competition

  @HiveField(10)
  String? imagePath;

  @HiveField(11)
  double? price;

  @HiveField(12)
  String difficulty;

  @HiveField(13)
  bool isParticipating;

  LocalEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.waterBodyId,
    this.waterBodyName,
    required this.startsAt,
    this.endsAt,
    this.maxParticipants = 0,
    this.currentParticipants = 0,
    required this.type,
    this.imagePath,
    this.price,
    this.difficulty = 'easy',
    this.isParticipating = false,
  });
}

/// Пользовательские настройки
@HiveType(typeId: 9)
class LocalUserSettings extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String? displayName;

  @HiveField(2)
  String? email;

  @HiveField(3)
  String? avatarPath;

  @HiveField(4)
  String language;

  @HiveField(5)
  String units; // metric, imperial

  @HiveField(6)
  bool darkMode;

  @HiveField(7)
  bool notificationsEnabled;

  @HiveField(8)
  bool locationTrackingEnabled;

  @HiveField(9)
  bool autoSyncEnabled;

  @HiveField(10)
  DateTime? lastSyncAt;

  @HiveField(11)
  int totalTrips;

  @HiveField(12)
  double totalDistance;

  LocalUserSettings({
    required this.userId,
    this.displayName,
    this.email,
    this.avatarPath,
    this.language = 'ru',
    this.units = 'metric',
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.locationTrackingEnabled = true,
    this.autoSyncEnabled = true,
    this.lastSyncAt,
    this.totalTrips = 0,
    this.totalDistance = 0,
  });
}
