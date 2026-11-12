import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// WaterBody
// ---------------------------------------------------------------------------
class WaterBody {
  final String id;
  final String name;
  final String? description;
  final String? region;
  final double? latitude;
  final double? longitude;
  final bool active;

  WaterBody({
    required this.id,
    required this.name,
    this.description,
    this.region,
    this.latitude,
    this.longitude,
    this.active = true,
  });

  LatLng? get location =>
      latitude != null && longitude != null ? LatLng(latitude!, longitude!) : null;

  factory WaterBody.fromJson(Map<String, dynamic> j) => WaterBody(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        region: j['region'] as String?,
        latitude: _d(j['latitude']),
        longitude: _d(j['longitude']),
        active: (j['active'] ?? true) as bool,
      );

  factory WaterBody.fromNearby(Map<String, dynamic> j) => WaterBody(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        region: j['region'] as String?,
        latitude: null,
        longitude: null,
      );

  double? get distanceMeters => _d(j?['distance_meters']);

  Map<String, dynamic>? j;
}

// ---------------------------------------------------------------------------
// Event
// ---------------------------------------------------------------------------
class Event {
  final String id;
  final String organizerId;
  final SimpleUser? organizer;
  final String title;
  final String? description;
  final List<String> photos;
  final String? waterBodyId;
  final WaterBody? waterBody;
  final DateTime? eventDate;
  final int? expectedDurationMinutes;
  final int? expectedDistanceMeters;
  final String? level;
  final String? visibility;
  final String? access;
  final int? maxParticipants;
  final String status;
  final double? startLat;
  final double? startLng;
  final int participantCount;
  final DateTime? createdAt;

  Event({
    required this.id,
    required this.organizerId,
    this.organizer,
    required this.title,
    this.description,
    this.photos = const [],
    this.waterBodyId,
    this.waterBody,
    this.eventDate,
    this.expectedDurationMinutes,
    this.expectedDistanceMeters,
    this.level,
    this.visibility,
    this.access,
    this.maxParticipants,
    this.status = 'scheduled',
    this.startLat,
    this.startLng,
    this.participantCount = 0,
    this.createdAt,
  });

  LatLng? get startPoint =>
      startLat != null && startLng != null ? LatLng(startLat!, startLng!) : null;

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        organizerId: j['organizerId'] as String,
        organizer: j['organizer'] != null
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['organizer']))
            : null,
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        photos: _strList(j['photos']),
        waterBodyId: j['waterBodyId'] as String?,
        waterBody: j['waterBody'] != null && j['waterBody'] is Map
            ? WaterBody.fromJson(Map<String, dynamic>.from(j['waterBody']))
            : null,
        eventDate: _dt(j['eventDate']),
        expectedDurationMinutes: _int(j['expectedDurationMinutes']),
        expectedDistanceMeters: _int(j['expectedDistanceMeters']),
        level: j['level'] as String?,
        visibility: j['visibility'] as String?,
        access: j['access'] as String?,
        maxParticipants: _int(j['maxParticipants']),
        status: (j['status'] ?? 'scheduled') as String,
        startLat: _d(j['startLat']),
        startLng: _d(j['startLng']),
        participantCount: _int(j['participantCount']) ?? 0,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// Track
// ---------------------------------------------------------------------------
class Track {
  final String id;
  final String userId;
  final SimpleUser? user;
  final String? name;
  final String? status;
  final String? difficulty;
  final String? waterBodyId;
  final WaterBody? waterBody;
  final String? eventId;
  final String? routeId;
  final String? routeName;
  final double distanceMeters;
  final int durationSeconds;
  final double avgSpeedKph;
  final double maxSpeedKph;
  final double elevationGainMeters;
  final double elevationLossMeters;
  final int calories;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  Track({
    required this.id,
    required this.userId,
    this.user,
    this.name,
    this.status,
    this.difficulty,
    this.waterBodyId,
    this.waterBody,
    this.eventId,
    this.routeId,
    this.routeName,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.avgSpeedKph = 0,
    this.maxSpeedKph = 0,
    this.elevationGainMeters = 0,
    this.elevationLossMeters = 0,
    this.calories = 0,
    this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        userId: j['userId'] as String,
        user: j['user'] != null && j['user'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['user']))
            : null,
        name: j['name'] as String?,
        status: j['status'] as String?,
        difficulty: j['difficulty'] as String?,
        waterBodyId: j['waterBodyId'] as String?,
        waterBody: j['waterBody'] != null && j['waterBody'] is Map
            ? WaterBody.fromJson(Map<String, dynamic>.from(j['waterBody']))
            : null,
        eventId: j['eventId'] as String?,
        routeId: j['routeId'] as String?,
        routeName: (j['route'] is Map && (j['route'] as Map)['name'] != null)
            ? (j['route'] as Map)['name'].toString()
            : null,
        distanceMeters: _d(j['distanceMeters']) ?? 0.0,
        durationSeconds: _int(j['durationSeconds']) ?? 0,
        avgSpeedKph: _d(j['avgSpeedKph']) ?? 0.0,
        maxSpeedKph: _d(j['maxSpeedKph']) ?? 0.0,
        elevationGainMeters: _d(j['elevationGainMeters']) ?? 0.0,
        elevationLossMeters: _d(j['elevationLossMeters']) ?? 0.0,
        calories: _int(j['calories']) ?? 0,
        startedAt: _dt(j['startedAt']),
        endedAt: _dt(j['endedAt']),
        createdAt: _dt(j['createdAt']),
      );

  String? get distanceLabel {
    if (distanceMeters <= 0) return null;
    if (distanceMeters >= 1000) return '${(distanceMeters / 1000).toStringAsFixed(1)} км';
    return '${distanceMeters.round()} м';
  }

  String? get durationLabel {
    if (durationSeconds <= 0) return null;
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }
}

// ---------------------------------------------------------------------------
// TrackCompleteResult
// ---------------------------------------------------------------------------
class TrackCompleteResult {
  final Track track;
  final Award award;

  TrackCompleteResult({required this.track, required this.award});

  factory TrackCompleteResult.fromJson(Map<String, dynamic> j) =>
      TrackCompleteResult(
        track: Track.fromJson(Map<String, dynamic>.from(j['track'])),
        award: Award.fromJson(Map<String, dynamic>.from(j['award'])),
      );
}

class Award {
  final int points;
  final int userXp;
  final List<Achievement> unlocked;

  Award({required this.points, required this.userXp, this.unlocked = const []});

  factory Award.fromJson(Map<String, dynamic> j) => Award(
        points: _int(j['points']) ?? 0,
        userXp: _int(j['userXp']) ?? 0,
        unlocked: (j['unlocked'] as List?)
                ?.map((e) => Achievement.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

// ---------------------------------------------------------------------------
// Post
// ---------------------------------------------------------------------------
class Post {
  final String id;
  final String authorId;
  final SimpleUser? author;
  final String type;
  final String? title;
  final String? body;
  final List<String> photos;
  final String? refId;
  final String? refType;
  final String? visibility;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool likedByMe;
  final bool canDelete;
  final DateTime? createdAt;

  Post({
    required this.id,
    required this.authorId,
    this.author,
    this.type = 'swim',
    this.title,
    this.body,
    this.photos = const [],
    this.refId,
    this.refType,
    this.visibility,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.likedByMe = false,
    this.canDelete = false,
    this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        author: j['author'] != null && j['author'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['author']))
            : null,
        type: (j['type'] ?? 'swim') as String,
        title: j['title'] as String?,
        body: j['body'] as String?,
        photos: _strList(j['photos']),
        refId: j['refId'] as String?,
        refType: j['refType'] as String?,
        visibility: j['visibility'] as String?,
        likeCount: _int(j['likeCount']) ?? 0,
        commentCount: _int(j['commentCount']) ?? 0,
        shareCount: _int(j['shareCount']) ?? 0,
        likedByMe: (j['likedByMe'] ?? false) as bool,
        canDelete: (j['canDelete'] ?? false) as bool,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// Listing (Marketplace)
// ---------------------------------------------------------------------------
class Listing {
  final String id;
  final String sellerId;
  final SimpleUser? seller;
  final String category;
  final String title;
  final String? description;
  final double? price;
  final String? currency;
  final List<String> photos;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String status;
  final DateTime? createdAt;

  Listing({
    required this.id,
    required this.sellerId,
    this.seller,
    required this.category,
    required this.title,
    this.description,
    this.price,
    this.currency,
    this.photos = const [],
    this.latitude,
    this.longitude,
    this.city,
    this.status = 'active',
    this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
        sellerId: j['sellerId'] as String,
        seller: j['seller'] != null && j['seller'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['seller']))
            : null,
        category: (j['category'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: j['description'] as String?,
        price: _d(j['price']),
        currency: j['currency'] as String?,
        photos: _strList(j['photos']),
        latitude: _d(j['latitude']),
        longitude: _d(j['longitude']),
        city: j['city'] as String?,
        status: (j['status'] ?? 'active') as String,
        createdAt: _dt(j['createdAt']),
      );

  String? get priceLabel {
    if (price == null) return null;
    return '${_fmtNum(price!.round())} ${currency ?? '₽'}';
  }
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final SimpleUser? sender;
  final String type;
  final String? content;
  final double? latitude;
  final double? longitude;
  final String? replyToId;
  final Message? replyTo;
  final String status;
  final DateTime? createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.sender,
    this.type = 'text',
    this.content,
    this.latitude,
    this.longitude,
    this.replyToId,
    this.replyTo,
    this.status = 'sent',
    this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        sender: j['sender'] != null && j['sender'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['sender']))
            : null,
        type: (j['type'] ?? 'text') as String,
        content: j['content'] as String?,
        latitude: _d(j['latitude']),
        longitude: _d(j['longitude']),
        replyToId: j['replyToId'] as String?,
        replyTo: j['replyTo'] != null && j['replyTo'] is Map
            ? Message.fromJson(Map<String, dynamic>.from(j['replyTo']))
            : null,
        status: (j['status'] ?? 'sent') as String,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------
class Conversation {
  final String id;
  final String type;
  final String? title;
  final String? eventId;
  final DateTime? lastMessageAt;
  final Message? lastMessage;
  final int unreadCount;
  final List<ConversationParticipant> participants;

  Conversation({
    required this.id,
    this.type = 'direct',
    this.title,
    this.eventId,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.participants = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        type: (j['type'] ?? 'direct') as String,
        title: j['title'] as String?,
        eventId: j['eventId'] as String?,
        lastMessageAt: _dt(j['lastMessageAt']),
        lastMessage: j['lastMessage'] != null && j['lastMessage'] is Map
            ? Message.fromJson(Map<String, dynamic>.from(j['lastMessage']))
            : null,
        unreadCount: _int(j['unreadCount']) ?? 0,
        participants: (j['participants'] as List?)
                ?.map((e) => ConversationParticipant.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );

  SimpleUser? otherParticipant(String selfId) {
    for (final p in participants) {
      if (p.userId != selfId) return p.user;
    }
    return null;
  }
}

class ConversationParticipant {
  final String id;
  final String userId;
  final SimpleUser? user;

  ConversationParticipant({required this.id, required this.userId, this.user});

  factory ConversationParticipant.fromJson(Map<String, dynamic> j) =>
      ConversationParticipant(
        id: j['id'] as String,
        userId: j['userId'] as String,
        user: j['user'] != null && j['user'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['user']))
            : null,
      );
}

// ---------------------------------------------------------------------------
// Notification
// ---------------------------------------------------------------------------
class AppNotification {
  final String id;
  final String type;
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    this.title,
    this.body,
    this.data,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: (j['type'] ?? 'system') as String,
        title: j['title'] as String?,
        body: j['body'] as String?,
        data: j['data'] is Map ? Map<String, dynamic>.from(j['data']) : null,
        isRead: (j['isRead'] ?? false) as bool,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// Achievement
// ---------------------------------------------------------------------------
class Achievement {
  final String code;
  final String title;
  final String description;
  final String? icon;
  final int xp;
  final bool unlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.code,
    required this.title,
    required this.description,
    this.icon,
    this.xp = 0,
    this.unlocked = false,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        code: (j['code'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        icon: j['icon'] as String?,
        xp: _int(j['xp']) ?? 0,
        unlocked: (j['unlocked'] ?? false) as bool,
        unlockedAt: _dt(j['unlockedAt']),
      );
}

// ---------------------------------------------------------------------------
// LevelInfo
// ---------------------------------------------------------------------------
class LevelInfo {
  final int level;
  final int xp;
  final int currentLevelXp;
  final int nextLevelXp;
  final double progress;

  LevelInfo({
    this.level = 1,
    this.xp = 0,
    this.currentLevelXp = 0,
    this.nextLevelXp = 100,
    this.progress = 0.0,
  });

  factory LevelInfo.fromJson(Map<String, dynamic> j) => LevelInfo(
        level: _int(j['level']) ?? 1,
        xp: _int(j['xp']) ?? 0,
        currentLevelXp: _int(j['currentLevelXp']) ?? 0,
        nextLevelXp: _int(j['nextLevelXp']) ?? 100,
        progress: (_d(j['progress']) ?? 0.0).clamp(0.0, 1.0),
      );
}

// ---------------------------------------------------------------------------
// EventParticipant
// ---------------------------------------------------------------------------
class EventParticipant {
  final String id;
  final String eventId;
  final String userId;
  final SimpleUser? user;
  final String status;
  final DateTime? joinedAt;

  EventParticipant({
    required this.id,
    required this.eventId,
    required this.userId,
    this.user,
    this.status = 'going',
    this.joinedAt,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> j) => EventParticipant(
        id: j['id'] as String,
        eventId: j['eventId'] as String,
        userId: j['userId'] as String,
        user: j['user'] != null && j['user'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['user']))
            : null,
        status: (j['status'] ?? 'going') as String,
        joinedAt: _dt(j['joinedAt']),
      );
}

// ---------------------------------------------------------------------------
// SimpleUser (compact, used inside nested relations)
// ---------------------------------------------------------------------------
class SimpleUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? city;
  final int? xp;

  SimpleUser({required this.id, required this.name, this.avatarUrl, this.city, this.xp});

  factory SimpleUser.fromJson(Map<String, dynamic> j) => SimpleUser(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
        city: j['city'] as String?,
        xp: _int(j['xp']),
      );
}

// ---------------------------------------------------------------------------
// FriendRequest
// ---------------------------------------------------------------------------
class FriendRequest {
  final String id;
  final String requesterId;
  final SimpleUser? requester;
  final String addresseeId;
  final SimpleUser? addressee;
  final String status;
  final DateTime? createdAt;

  FriendRequest({
    required this.id,
    required this.requesterId,
    this.requester,
    required this.addresseeId,
    this.addressee,
    this.status = 'pending',
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> j) => FriendRequest(
        id: j['id'] as String,
        requesterId: j['requesterId'] as String,
        requester: j['requester'] != null && j['requester'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['requester']))
            : null,
        addresseeId: j['addresseeId'] as String,
        addressee: j['addressee'] != null && j['addressee'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['addressee']))
            : null,
        status: (j['status'] ?? 'pending') as String,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// Channel
// ---------------------------------------------------------------------------
class Channel {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? photoUrl;
  final String ownerId;
  final SimpleUser? owner;
  final bool isPublic;
  final int subscriberCount;
  final bool isMember;
  final String? myRole;
  final DateTime? createdAt;

  Channel({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.photoUrl,
    required this.ownerId,
    this.owner,
    this.isPublic = true,
    this.subscriberCount = 0,
    this.isMember = false,
    this.myRole,
    this.createdAt,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        slug: j['slug'] as String?,
        description: j['description'] as String?,
        photoUrl: j['photoUrl'] as String?,
        ownerId: j['ownerId'] as String,
        owner: j['owner'] != null && j['owner'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['owner']))
            : null,
        isPublic: (j['isPublic'] ?? true) as bool,
        subscriberCount: _int(j['subscriberCount']) ?? 0,
        isMember: (j['isMember'] ?? false) as bool,
        myRole: j['myRole'] as String?,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// ChannelPost
// ---------------------------------------------------------------------------
class ChannelPost {
  final String id;
  final String channelId;
  final String authorId;
  final SimpleUser? author;
  final String? title;
  final String? body;
  final List<String> photos;
  final bool isPinned;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool canDelete;
  final bool canPin;
  final DateTime? createdAt;

  ChannelPost({
    required this.id,
    required this.channelId,
    required this.authorId,
    this.author,
    this.title,
    this.body,
    this.photos = const [],
    this.isPinned = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.canDelete = false,
    this.canPin = false,
    this.createdAt,
  });

  factory ChannelPost.fromJson(Map<String, dynamic> j) => ChannelPost(
        id: j['id'] as String,
        channelId: j['channelId'] as String,
        authorId: j['authorId'] as String,
        author: j['author'] != null && j['author'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['author']))
            : null,
        title: j['title'] as String?,
        body: j['body'] as String?,
        photos: _strList(j['photos']),
        isPinned: (j['isPinned'] ?? false) as bool,
        likeCount: _int(j['likeCount']) ?? 0,
        commentCount: _int(j['commentCount']) ?? 0,
        likedByMe: (j['likedByMe'] ?? false) as bool,
        canDelete: (j['canDelete'] ?? false) as bool,
        canPin: (j['canPin'] ?? false) as bool,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// News
// ---------------------------------------------------------------------------
class NewsItem {
  final String id;
  final String title;
  final String body;
  final String? coverUrl;
  final String authorId;
  final SimpleUser? author;
  final bool isPublished;
  final DateTime? createdAt;

  NewsItem({
    required this.id,
    required this.title,
    required this.body,
    this.coverUrl,
    required this.authorId,
    this.author,
    this.isPublished = true,
    this.createdAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        coverUrl: j['coverUrl'] as String?,
        authorId: j['authorId'] as String,
        author: j['author'] != null && j['author'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['author']))
            : null,
        isPublished: (j['isPublished'] ?? true) as bool,
        createdAt: _dt(j['createdAt']),
      );
}

// ---------------------------------------------------------------------------
// GearItem
// ---------------------------------------------------------------------------
class GearItem {
  final String id;
  final String userId;
  final String category;
  final String? brand;
  final String? model;
  final int? lengthCm;
  final int? widthCm;
  final int? volumeL;
  final double? weightKg;
  final String? material;
  final String? notes;

  GearItem({
    required this.id,
    required this.userId,
    required this.category,
    this.brand,
    this.model,
    this.lengthCm,
    this.widthCm,
    this.volumeL,
    this.weightKg,
    this.material,
    this.notes,
  });

  factory GearItem.fromJson(Map<String, dynamic> j) => GearItem(
        id: j['id'] as String,
        userId: j['userId'] as String,
        category: (j['category'] ?? 'other') as String,
        brand: j['brand'] as String?,
        model: j['model'] as String?,
        lengthCm: _int(j['lengthCm']),
        widthCm: _int(j['widthCm']),
        volumeL: _int(j['volumeL']),
        weightKg: _d(j['weightKg']),
        material: j['material'] as String?,
        notes: j['notes'] as String?,
      );

  String get displayName {
    final parts = <String>[
      if (brand != null && brand!.isNotEmpty) brand!,
      if (model != null && model!.isNotEmpty) model!,
    ];
    return parts.isEmpty ? _categoryLabel : parts.join(' ');
  }

  String get _categoryLabel {
    const labels = {
      'board': 'Доска',
      'paddle': 'Пaddle',
      'wetsuit': 'Гидрокостюм',
      'vest': 'Жилет',
      'leash': 'Лиш',
      'pump': 'Насос',
      'drybag': 'Влагонепрониц. сумка',
      'other': 'Другое',
    };
    return labels[category] ?? category;
  }
}

// ---------------------------------------------------------------------------
// RatingEntry
// ---------------------------------------------------------------------------
class RatingEntry {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? city;
  final String? region;
  final String? country;
  final int xp;
  final int level;
  final int rank;

  RatingEntry({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.city,
    this.region,
    this.country,
    this.xp = 0,
    this.level = 1,
    this.rank = 0,
  });

  factory RatingEntry.fromJson(Map<String, dynamic> j) => RatingEntry(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
        city: j['city'] as String?,
        region: j['region'] as String?,
        country: j['country'] as String?,
        xp: _int(j['xp']) ?? 0,
        level: _int(j['level']) ?? 1,
        rank: _int(j['rank']) ?? 0,
      );
}

// ---------------------------------------------------------------------------
// RatingResponse
// ---------------------------------------------------------------------------
class RatingResponse {
  final String scope;
  final int? seasonYear;
  final RatingEntry? me;
  final List<RatingEntry> entries;

  RatingResponse({required this.scope, this.seasonYear, this.me, this.entries = const []});

  factory RatingResponse.fromJson(Map<String, dynamic> j) => RatingResponse(
        scope: (j['scope'] ?? 'all') as String,
        seasonYear: _int(j['seasonYear']),
        me: j['me'] != null && j['me'] is Map
            ? RatingEntry.fromJson(Map<String, dynamic>.from(j['me']))
            : null,
        entries: (j['entries'] as List?)
                ?.map((e) => RatingEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

// ---------------------------------------------------------------------------
// PointLog
// ---------------------------------------------------------------------------
class PointLog {
  final String id;
  final String action;
  final int points;
  final String? refType;
  final String? refId;
  final DateTime? createdAt;

  PointLog({required this.id, required this.action, this.points = 0, this.refType, this.refId, this.createdAt});

  factory PointLog.fromJson(Map<String, dynamic> j) => PointLog(
        id: j['id'] as String,
        action: (j['action'] ?? '') as String,
        points: _int(j['points']) ?? 0,
        refType: j['refType'] as String?,
        refId: j['refId'] as String?,
        createdAt: _dt(j['createdAt']),
      );

  String get actionLabel {
    const labels = <String, String>{
      'track_completed': 'Заплыв',
      'route_published': 'Маршрут',
      'event_created': 'Мероприятие',
      'distance_bonus': 'Дистанция',
      'group_swim': 'Группа',
      'achievement': 'Достижение',
    };
    return labels[action] ?? action;
  }
}

// ---------------------------------------------------------------------------
// ProfileView (GET /users/:id/profile)
// ---------------------------------------------------------------------------
class ProfileStats {
  final int friends;
  final int eventsOrganized;
  final int eventsAttended;
  final int tracksPublished;
  final int listingsActive;
  final double ratingAverage;
  final int reviewsCount;

  ProfileStats({
    this.friends = 0,
    this.eventsOrganized = 0,
    this.eventsAttended = 0,
    this.tracksPublished = 0,
    this.listingsActive = 0,
    this.ratingAverage = 0,
    this.reviewsCount = 0,
  });

  factory ProfileStats.fromJson(Map<String, dynamic>? j) => j == null
      ? ProfileStats()
      : ProfileStats(
          friends: _int(j['friends']) ?? 0,
          eventsOrganized: _int(j['eventsOrganized']) ?? 0,
          eventsAttended: _int(j['eventsAttended']) ?? 0,
          tracksPublished: _int(j['tracksPublished']) ?? 0,
          listingsActive: _int(j['listingsActive']) ?? 0,
          ratingAverage: _d(j['ratingAverage']) ?? 0,
          reviewsCount: _int(j['reviewsCount']) ?? 0,
        );
}

class ProfileUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? city;
  final String? region;
  final String? country;
  final String? bio;
  final String? role;
  final int? xp;
  final String? homeWaterBodyId;
  final WaterBody? homeWaterBody;

  ProfileUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.city,
    this.region,
    this.country,
    this.bio,
    this.role,
    this.xp,
    this.homeWaterBodyId,
    this.homeWaterBody,
  });

  factory ProfileUser.fromJson(Map<String, dynamic> j) => ProfileUser(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
        city: j['city'] as String?,
        region: j['region'] as String?,
        country: j['country'] as String?,
        bio: j['bio'] as String?,
        role: j['role'] as String?,
        xp: _int(j['xp']),
        homeWaterBodyId: j['homeWaterBodyId'] as String?,
        homeWaterBody: j['homeWaterBody'] != null && j['homeWaterBody'] is Map
            ? WaterBody.fromJson(Map<String, dynamic>.from(j['homeWaterBody']))
            : null,
      );
}

class ProfileView {
  final ProfileUser user;
  final ProfileStats? stats;
  final bool canView;
  final bool blocked;
  final bool isFriend;
  final bool isSelf;

  ProfileView({
    required this.user,
    this.stats,
    this.canView = false,
    this.blocked = false,
    this.isFriend = false,
    this.isSelf = false,
  });

  factory ProfileView.fromJson(Map<String, dynamic> j) => ProfileView(
        user: ProfileUser.fromJson(Map<String, dynamic>.from(j['user'])),
        stats: ProfileStats.fromJson(j['stats'] is Map ? Map<String, dynamic>.from(j['stats']) : null),
        canView: (j['canView'] ?? false) as bool,
        blocked: (j['blocked'] ?? false) as bool,
        isFriend: (j['isFriend'] ?? false) as bool,
        isSelf: (j['isSelf'] ?? false) as bool,
      );
}

// ---------------------------------------------------------------------------
// FeedRoute / FeedEvent / FeedListing (snake_case from server)
// ---------------------------------------------------------------------------
class FeedRoute {
  final String id;
  final String? name;
  final double distanceMeters;
  final int durationSeconds;
  final double avgSpeedKph;
  final DateTime? startedAt;
  final String? difficulty;
  final String? userName;
  final String? userId;

  FeedRoute({
    required this.id,
    this.name,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.avgSpeedKph = 0,
    this.startedAt,
    this.difficulty,
    this.userName,
    this.userId,
  });

  factory FeedRoute.fromJson(Map<String, dynamic> j) => FeedRoute(
        id: j['id'] as String,
        name: j['name'] as String?,
        distanceMeters: _d(j['distance_meters']) ?? 0.0,
        durationSeconds: _int(j['duration_seconds']) ?? 0,
        avgSpeedKph: _d(j['avgSpeedKph']) ?? 0.0,
        startedAt: _dt(j['startedAt']),
        difficulty: j['difficulty'] as String?,
        userName: j['userName'] as String?,
        userId: j['userId'] as String?,
      );
}

class FeedEvent {
  final String id;
  final String? title;
  final String? description;
  final DateTime? eventDate;
  final double? startLat;
  final double? startLng;
  final String? visibility;
  final String? organizerName;
  final String? organizerId;
  final String? waterBodyName;

  FeedEvent({
    required this.id,
    this.title,
    this.description,
    this.eventDate,
    this.startLat,
    this.startLng,
    this.visibility,
    this.organizerName,
    this.organizerId,
    this.waterBodyName,
  });

  factory FeedEvent.fromJson(Map<String, dynamic> j) => FeedEvent(
        id: j['id'] as String,
        title: j['title'] as String?,
        description: j['description'] as String?,
        eventDate: _dt(j['eventDate']),
        startLat: _d(j['startLat']),
        startLng: _d(j['startLng']),
        visibility: j['visibility'] as String?,
        organizerName: j['organizerName'] as String?,
        organizerId: j['organizerId'] as String?,
        waterBodyName: j['waterBodyName'] as String?,
      );
}

class FeedListing {
  final String id;
  final String? title;
  final String? category;
  final double? price;
  final String? currency;
  final List<String> photos;
  final String? city;
  final DateTime? createdAt;

  FeedListing({
    required this.id,
    this.title,
    this.category,
    this.price,
    this.currency,
    this.photos = const [],
    this.city,
    this.createdAt,
  });

  factory FeedListing.fromJson(Map<String, dynamic> j) => FeedListing(
        id: j['id'] as String,
        title: j['title'] as String?,
        category: j['category'] as String?,
        price: _d(j['price']),
        currency: j['currency'] as String?,
        photos: _strList(j['photos']),
        city: j['city'] as String?,
        createdAt: _dt(j['createdAt']),
      );
}

class FeedResponse {
  final List<FeedRoute> routes;
  final List<FeedEvent> events;
  final List<FeedListing> listings;

  FeedResponse({this.routes = const [], this.events = const [], this.listings = const []});

  factory FeedResponse.fromJson(Map<String, dynamic> j) => FeedResponse(
        routes: (j['routes'] as List?)?.map((e) => FeedRoute.fromJson(e)).toList() ?? const [],
        events: (j['events'] as List?)?.map((e) => FeedEvent.fromJson(e)).toList() ?? const [],
        listings:
            (j['listings'] as List?)?.map((e) => FeedListing.fromJson(e)).toList() ?? const [],
      );
}

// ---------------------------------------------------------------------------
// Search response
// ---------------------------------------------------------------------------
class SearchResponse {
  final List<WaterBody> waterbodies;
  final List<SimpleUser> users;
  final List<FeedEvent> events;
  final List<FeedRoute> tracks;
  final List<FeedListing> listings;

  SearchResponse({
    this.waterbodies = const [],
    this.users = const [],
    this.events = const [],
    this.tracks = const [],
    this.listings = const [],
  });

  factory SearchResponse.fromJson(Map<String, dynamic> j) => SearchResponse(
        waterbodies:
            (j['waterbodies'] as List?)?.map((e) => WaterBody.fromJson(e)).toList() ?? const [],
        users: (j['users'] as List?)?.map((e) => SimpleUser.fromJson(e)).toList() ?? const [],
        events: (j['events'] as List?)?.map((e) => FeedEvent.fromJson(e)).toList() ?? const [],
        tracks: (j['tracks'] as List?)?.map((e) => FeedRoute.fromJson(e)).toList() ?? const [],
        listings:
            (j['listings'] as List?)?.map((e) => FeedListing.fromJson(e)).toList() ?? const [],
      );

  bool get isEmpty =>
      waterbodies.isEmpty &&
      users.isEmpty &&
      events.isEmpty &&
      tracks.isEmpty &&
      listings.isEmpty;
}

// ---------------------------------------------------------------------------
// Pageinated list (used by posts, channels, news, gear)
// ---------------------------------------------------------------------------
class Page<T> {
  final List<T> items;
  final bool hasMore;

  Page({this.items = const [], this.hasMore = false});

  factory Page.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) fromItem) =>
      Page(
        items: (j['items'] as List?)?.map((e) => fromItem(e)).toList() ?? const [],
        hasMore: (j['hasMore'] ?? false) as bool,
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

DateTime? _dt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  return DateTime.tryParse(v.toString())?.toUtc();
}

List<String> _strList(dynamic v) {
  if (v is List) return v.whereType<String>().toList();
  return const [];
}

String _fmtNum(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u00a0');
    buf.write(s[i]);
  }
  return buf.toString();
}