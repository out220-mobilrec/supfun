// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalRoutePointAdapter extends TypeAdapter<LocalRoutePoint> {
  @override
  final int typeId = 1;

  @override
  LocalRoutePoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalRoutePoint(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      timestamp: fields[2] as DateTime,
      speed: fields[3] as double?,
      altitude: fields[4] as double?,
      accuracy: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalRoutePoint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.speed)
      ..writeByte(4)
      ..write(obj.altitude)
      ..writeByte(5)
      ..write(obj.accuracy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalRoutePointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalRouteAdapter extends TypeAdapter<LocalRoute> {
  @override
  final int typeId = 2;

  @override
  LocalRoute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalRoute(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      waterBodyId: fields[3] as String?,
      waterBodyName: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      distance: fields[6] as double,
      durationSeconds: fields[7] as int,
      maxSpeed: fields[8] as double?,
      avgSpeed: fields[9] as double?,
      points: (fields[10] as List?)?.cast<LocalRoutePoint>(),
      difficulty: fields[11] as String,
      isPublic: fields[12] as bool,
      likes: fields[13] as int,
      coverImagePath: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalRoute obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.waterBodyId)
      ..writeByte(4)
      ..write(obj.waterBodyName)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.distance)
      ..writeByte(7)
      ..write(obj.durationSeconds)
      ..writeByte(8)
      ..write(obj.maxSpeed)
      ..writeByte(9)
      ..write(obj.avgSpeed)
      ..writeByte(10)
      ..write(obj.points)
      ..writeByte(11)
      ..write(obj.difficulty)
      ..writeByte(12)
      ..write(obj.isPublic)
      ..writeByte(13)
      ..write(obj.likes)
      ..writeByte(14)
      ..write(obj.coverImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalRouteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalWaterBodyAdapter extends TypeAdapter<LocalWaterBody> {
  @override
  final int typeId = 3;

  @override
  LocalWaterBody read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalWaterBody(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      city: fields[3] as String,
      latitude: fields[4] as double,
      longitude: fields[5] as double,
      description: fields[6] as String?,
      temperature: fields[7] as double?,
      weatherCondition: fields[8] as String?,
      rating: fields[9] as double,
      isFavorite: fields[10] as bool,
      cachedAt: fields[11] as DateTime,
      imagePaths: (fields[12] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, LocalWaterBody obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.temperature)
      ..writeByte(8)
      ..write(obj.weatherCondition)
      ..writeByte(9)
      ..write(obj.rating)
      ..writeByte(10)
      ..write(obj.isFavorite)
      ..writeByte(11)
      ..write(obj.cachedAt)
      ..writeByte(12)
      ..write(obj.imagePaths);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalWaterBodyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalChatMessageAdapter extends TypeAdapter<LocalChatMessage> {
  @override
  final int typeId = 4;

  @override
  LocalChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalChatMessage(
      id: fields[0] as String,
      conversationId: fields[1] as String,
      senderId: fields[2] as String,
      senderName: fields[3] as String,
      content: fields[4] as String,
      sentAt: fields[5] as DateTime,
      isFromMe: fields[6] as bool,
      isRead: fields[7] as bool,
      status: fields[8] as MessageStatus,
      attachmentPath: fields[9] as String?,
      replyToMessageId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalChatMessage obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.senderName)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.sentAt)
      ..writeByte(6)
      ..write(obj.isFromMe)
      ..writeByte(7)
      ..write(obj.isRead)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.attachmentPath)
      ..writeByte(10)
      ..write(obj.replyToMessageId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalConversationAdapter extends TypeAdapter<LocalConversation> {
  @override
  final int typeId = 6;

  @override
  LocalConversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalConversation(
      id: fields[0] as String,
      otherUserId: fields[1] as String?,
      otherUserName: fields[2] as String?,
      otherUserAvatar: fields[3] as String?,
      groupName: fields[4] as String?,
      groupAvatar: fields[5] as String?,
      lastMessagePreview: fields[6] as String?,
      lastMessageAt: fields[7] as DateTime?,
      unreadCount: fields[8] as int,
      isGroup: fields[9] as bool,
      participantIds: (fields[10] as List?)?.cast<String>(),
      isMuted: fields[11] as bool,
      isPinned: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalConversation obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.otherUserId)
      ..writeByte(2)
      ..write(obj.otherUserName)
      ..writeByte(3)
      ..write(obj.otherUserAvatar)
      ..writeByte(4)
      ..write(obj.groupName)
      ..writeByte(5)
      ..write(obj.groupAvatar)
      ..writeByte(6)
      ..write(obj.lastMessagePreview)
      ..writeByte(7)
      ..write(obj.lastMessageAt)
      ..writeByte(8)
      ..write(obj.unreadCount)
      ..writeByte(9)
      ..write(obj.isGroup)
      ..writeByte(10)
      ..write(obj.participantIds)
      ..writeByte(11)
      ..write(obj.isMuted)
      ..writeByte(12)
      ..write(obj.isPinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalFeedPostAdapter extends TypeAdapter<LocalFeedPost> {
  @override
  final int typeId = 7;

  @override
  LocalFeedPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalFeedPost(
      id: fields[0] as String,
      authorId: fields[1] as String,
      authorName: fields[2] as String,
      authorAvatar: fields[3] as String?,
      content: fields[4] as String,
      createdAt: fields[5] as DateTime,
      imagePaths: (fields[6] as List?)?.cast<String>(),
      likes: fields[7] as int,
      comments: fields[8] as int,
      isLiked: fields[9] as bool,
      relatedTripId: fields[10] as String?,
      location: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalFeedPost obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.authorId)
      ..writeByte(2)
      ..write(obj.authorName)
      ..writeByte(3)
      ..write(obj.authorAvatar)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.imagePaths)
      ..writeByte(7)
      ..write(obj.likes)
      ..writeByte(8)
      ..write(obj.comments)
      ..writeByte(9)
      ..write(obj.isLiked)
      ..writeByte(10)
      ..write(obj.relatedTripId)
      ..writeByte(11)
      ..write(obj.location);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalFeedPostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalEventAdapter extends TypeAdapter<LocalEvent> {
  @override
  final int typeId = 8;

  @override
  LocalEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalEvent(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      waterBodyId: fields[3] as String,
      waterBodyName: fields[4] as String?,
      startsAt: fields[5] as DateTime,
      endsAt: fields[6] as DateTime?,
      maxParticipants: fields[7] as int,
      currentParticipants: fields[8] as int,
      type: fields[9] as String,
      imagePath: fields[10] as String?,
      price: fields[11] as double?,
      difficulty: fields[12] as String,
      isParticipating: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalEvent obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.waterBodyId)
      ..writeByte(4)
      ..write(obj.waterBodyName)
      ..writeByte(5)
      ..write(obj.startsAt)
      ..writeByte(6)
      ..write(obj.endsAt)
      ..writeByte(7)
      ..write(obj.maxParticipants)
      ..writeByte(8)
      ..write(obj.currentParticipants)
      ..writeByte(9)
      ..write(obj.type)
      ..writeByte(10)
      ..write(obj.imagePath)
      ..writeByte(11)
      ..write(obj.price)
      ..writeByte(12)
      ..write(obj.difficulty)
      ..writeByte(13)
      ..write(obj.isParticipating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalUserSettingsAdapter extends TypeAdapter<LocalUserSettings> {
  @override
  final int typeId = 9;

  @override
  LocalUserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalUserSettings(
      userId: fields[0] as String,
      displayName: fields[1] as String?,
      email: fields[2] as String?,
      avatarPath: fields[3] as String?,
      language: fields[4] as String,
      units: fields[5] as String,
      darkMode: fields[6] as bool,
      notificationsEnabled: fields[7] as bool,
      locationTrackingEnabled: fields[8] as bool,
      autoSyncEnabled: fields[9] as bool,
      lastSyncAt: fields[10] as DateTime?,
      totalTrips: fields[11] as int,
      totalDistance: fields[12] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LocalUserSettings obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.avatarPath)
      ..writeByte(4)
      ..write(obj.language)
      ..writeByte(5)
      ..write(obj.units)
      ..writeByte(6)
      ..write(obj.darkMode)
      ..writeByte(7)
      ..write(obj.notificationsEnabled)
      ..writeByte(8)
      ..write(obj.locationTrackingEnabled)
      ..writeByte(9)
      ..write(obj.autoSyncEnabled)
      ..writeByte(10)
      ..write(obj.lastSyncAt)
      ..writeByte(11)
      ..write(obj.totalTrips)
      ..writeByte(12)
      ..write(obj.totalDistance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalUserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageStatusAdapter extends TypeAdapter<MessageStatus> {
  @override
  final int typeId = 5;

  @override
  MessageStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageStatus.sending;
      case 1:
        return MessageStatus.sent;
      case 2:
        return MessageStatus.delivered;
      case 3:
        return MessageStatus.read;
      case 4:
        return MessageStatus.failed;
      default:
        return MessageStatus.sending;
    }
  }

  @override
  void write(BinaryWriter writer, MessageStatus obj) {
    switch (obj) {
      case MessageStatus.sending:
        writer.writeByte(0);
        break;
      case MessageStatus.sent:
        writer.writeByte(1);
        break;
      case MessageStatus.delivered:
        writer.writeByte(2);
        break;
      case MessageStatus.read:
        writer.writeByte(3);
        break;
      case MessageStatus.failed:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
