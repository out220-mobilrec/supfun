// Local storage service using Hive for offline data persistence
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/local_models.dart';
import '../models/user_model.dart';

class LocalStorageService {
  static const String _routesBoxName = 'routes';
  static const String _waterBodiesBoxName = 'waterbodies';
  static const String _conversationsBoxName = 'conversations';
  static const String _messagesBoxName = 'messages';
  static const String _feedBoxName = 'feed';
  static const String _eventsBoxName = 'events';
  static const String _settingsBoxName = 'settings';
  static const String _tripPointsBoxName = 'trip_points';
  static const String _usersBoxName = 'users';
  static const String _authBoxName = 'auth';

  late Box<LocalRoute> _routesBox;
  late Box<LocalWaterBody> _waterBodiesBox;
  late Box<LocalConversation> _conversationsBox;
  late Box<LocalChatMessage> _messagesBox;
  late Box<LocalFeedPost> _feedBox;
  late Box<LocalEvent> _eventsBox;
  late Box<LocalUserSettings> _settingsBox;
  late Box _tripPointsBox;
  late Box _usersBox;
  late Box _authBox;
  late Database _tripPointsDb;

  static LocalStorageService? _instance;
  static LocalStorageService get instance {
    _instance ??= LocalStorageService._();
    return _instance!;
  }

  LocalStorageService._();

  /// Initialize Hive and SQLite
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    // Register adapters
    Hive.registerAdapter(LocalRoutePointAdapter());
    Hive.registerAdapter(LocalRouteAdapter());
    Hive.registerAdapter(LocalWaterBodyAdapter());
    Hive.registerAdapter(LocalChatMessageAdapter());
    Hive.registerAdapter(MessageStatusAdapter());
    Hive.registerAdapter(LocalConversationAdapter());
    Hive.registerAdapter(LocalFeedPostAdapter());
    Hive.registerAdapter(LocalEventAdapter());
    Hive.registerAdapter(LocalUserSettingsAdapter());

    // Open boxes
    _routesBox = await Hive.openBox<LocalRoute>(_routesBoxName);
    _waterBodiesBox =
        await Hive.openBox<LocalWaterBody>(_waterBodiesBoxName);
    _conversationsBox =
        await Hive.openBox<LocalConversation>(_conversationsBoxName);
    _messagesBox = await Hive.openBox<LocalChatMessage>(_messagesBoxName);
    _feedBox = await Hive.openBox<LocalFeedPost>(_feedBoxName);
    _eventsBox = await Hive.openBox<LocalEvent>(_eventsBoxName);
    _settingsBox =
        await Hive.openBox<LocalUserSettings>(_settingsBoxName);
    _usersBox = await Hive.openBox(_usersBoxName);
    _authBox = await Hive.openBox(_authBoxName);

    // SQLite for high-frequency GPS point writes (faster than Hive)
    final dbPath = '${dir.path}/trip_points.db';
    _tripPointsDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trip_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp INTEGER NOT NULL,
            speed REAL,
            altitude REAL,
            accuracy REAL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_trip_points_trip_id ON trip_points(trip_id)');
      },
    );
  }

  // ==================== USERS ====================

  /// Save user to local storage (as JSON in typed Box)
  Future<void> saveUser(AppUser user) async {
    final jsonStr = jsonEncode(user.toJson());
    await _usersBox.put(user.id, jsonStr);
  }

  /// Get user by ID
  AppUser? getUser(String userId) {
    final raw = _usersBox.get(userId);
    if (raw == null) return null;
    try {
      if (raw is String) {
        return AppUser.fromJson(jsonDecode(raw));
      }
      if (raw is Map) {
        return AppUser.fromJson(
            raw.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {}
    return null;
  }

  /// Get user by email
  AppUser? getUserByEmail(String email) {
    for (final raw in _usersBox.values) {
      AppUser? user;
      try {
        if (raw is String) {
          user = AppUser.fromJson(jsonDecode(raw));
        }
      } catch (_) {}
      if (user != null && user.email.toLowerCase() == email.toLowerCase()) {
        return user;
      }
    }
    return null;
  }

  /// Get all cached users
  List<AppUser> getAllUsers() {
    final users = <AppUser>[];
    for (final raw in _usersBox.values) {
      try {
        if (raw is String) {
          users.add(AppUser.fromJson(jsonDecode(raw)));
        }
      } catch (_) {}
    }
    return users;
  }

  /// Delete user
  Future<void> deleteUser(String userId) async {
    await _usersBox.delete(userId);
  }

  // ==================== AUTH TOKENS ====================

  /// Save authentication token
  Future<void> saveAuthToken(String token) async {
    await _authBox.put('token', token);
    await _authBox.put('savedAt', DateTime.now().toIso8601String());
  }

  /// Get saved auth token
  String? getAuthToken() {
    return _authBox.get('token') as String?;
  }

  /// Get token save time
  DateTime? getAuthTokenSavedAt() {
    final value = _authBox.get('savedAt') as String?;
    if (value != null) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Save current user id (linked to auth token)
  Future<void> saveCurrentUserId(String userId) async {
    await _authBox.put('userId', userId);
  }

  /// Get current user id
  String? getCurrentUserId() {
    return _authBox.get('userId') as String?;
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    await _authBox.put('refreshToken', token);
  }

  /// Get refresh token
  String? getRefreshToken() {
    return _authBox.get('refreshToken') as String?;
  }

  /// Clear auth token (logout)
  Future<void> clearAuthToken() async {
    await _authBox.clear();
  }

  // ==================== API BASE URL ====================

  static const _apiBaseUrlKey = 'api_base_url';

  /// Get saved API base URL (null if not set).
  String? getApiBaseUrl() {
    try {
      final box = _authBox;
      return box.get(_apiBaseUrlKey) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Persist API base URL for next launch
  Future<void> saveApiBaseUrl(String url) async {
    await _authBox.put(_apiBaseUrlKey, url);
  }

  /// Remove saved API base URL (revert to default)
  Future<void> deleteApiBaseUrl() async {
    await _authBox.delete(_apiBaseUrlKey);
  }

  // ==================== ROUTES ====================

  /// Save a route to local storage
  Future<void> saveRoute(LocalRoute route) async {
    await _routesBox.put(route.id, route);

    // Save all route points to SQLite for fast access
    final batch = _tripPointsDb.batch();
    for (final point in route.points) {
      batch.insert('trip_points', {
        'trip_id': route.id,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': point.timestamp.millisecondsSinceEpoch,
        'speed': point.speed,
        'altitude': point.altitude,
        'accuracy': point.accuracy,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Get all routes
  List<LocalRoute> getAllRoutes() {
    final routes = _routesBox.values.toList();
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return routes;
  }

  /// Get route by ID
  LocalRoute? getRoute(String id) => _routesBox.get(id);

  /// Get points for a specific trip from SQLite
  Future<List<Map<String, dynamic>>> getTripPoints(String tripId) async {
    return await _tripPointsDb.query(
      'trip_points',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'timestamp ASC',
    );
  }

  /// Delete route
  Future<void> deleteRoute(String id) async {
    await _routesBox.delete(id);
    await _tripPointsDb.delete(
      'trip_points',
      where: 'trip_id = ?',
      whereArgs: [id],
    );
  }

  /// Get total distance across all routes
  double getTotalDistance() {
    return _routesBox.values.fold<double>(
        0, (sum, route) => sum + route.distance);
  }

  /// Get routes by waterbody
  List<LocalRoute> getRoutesByWaterBody(String waterBodyId) {
    return _routesBox.values
        .where((r) => r.waterBodyId == waterBodyId)
        .toList();
  }

  // ==================== WATER BODIES ====================

  /// Cache waterbodies for offline access
  Future<void> cacheWaterBody(LocalWaterBody waterBody) async {
    await _waterBodiesBox.put(waterBody.id, waterBody);
  }

  /// Cache multiple waterbodies
  Future<void> cacheWaterBodies(List<LocalWaterBody> waterBodies) async {
    final map = {for (final wb in waterBodies) wb.id: wb};
    await _waterBodiesBox.putAll(map);
  }

  /// Get all cached waterbodies
  List<LocalWaterBody> getCachedWaterBodies() {
    return _waterBodiesBox.values.toList();
  }

  /// Get cached waterbody by ID
  LocalWaterBody? getCachedWaterBody(String id) =>
      _waterBodiesBox.get(id);

  /// Toggle favorite
  Future<void> toggleFavorite(String waterBodyId) async {
    final wb = _waterBodiesBox.get(waterBodyId);
    if (wb != null) {
      wb.isFavorite = !wb.isFavorite;
      await wb.save();
    }
  }

  /// Get favorite waterbodies
  List<LocalWaterBody> getFavoriteWaterBodies() {
    return _waterBodiesBox.values
        .where((wb) => wb.isFavorite)
        .toList();
  }

  // ==================== CHATS ====================

  /// Save a conversation
  Future<void> saveConversation(LocalConversation conversation) async {
    await _conversationsBox.put(conversation.id, conversation);
  }

  /// Get all conversations
  List<LocalConversation> getConversations() {
    final list = _conversationsBox.values.toList();
    // Sort by pinned first, then last message time
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    return list;
  }

  /// Save a message
  Future<void> saveMessage(LocalChatMessage message) async {
    await _messagesBox.put(message.id, message);

    // Update conversation's last message
    final conversation = _conversationsBox.get(message.conversationId);
    if (conversation != null) {
      conversation.lastMessagePreview = message.content;
      conversation.lastMessageAt = message.sentAt;
      if (!message.isFromMe) {
        conversation.unreadCount++;
      }
      await conversation.save();
    }
  }

  /// Get messages for a conversation
  List<LocalChatMessage> getMessages(String conversationId) {
    final messages = _messagesBox.values
        .where((m) => m.conversationId == conversationId)
        .toList();
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return messages;
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    final messages = getMessages(conversationId)
        .where((m) => !m.isRead && !m.isFromMe)
        .toList();
    for (final msg in messages) {
      msg.isRead = true;
      await msg.save();
    }
    final conv = _conversationsBox.get(conversationId);
    if (conv != null) {
      conv.unreadCount = 0;
      await conv.save();
    }
  }

  /// Delete a conversation and its messages
  Future<void> deleteConversation(String conversationId) async {
    await _conversationsBox.delete(conversationId);
    final messages = getMessages(conversationId);
    for (final msg in messages) {
      await msg.delete();
    }
  }

  /// Get total unread messages count
  int getTotalUnreadCount() {
    return _conversationsBox.values
        .fold<int>(0, (sum, conv) => sum + conv.unreadCount);
  }

  /// Search messages
  List<LocalChatMessage> searchMessages(String query) {
    final lower = query.toLowerCase();
    return _messagesBox.values
        .where((m) => m.content.toLowerCase().contains(lower))
        .toList();
  }

  // ==================== FEED ====================

  /// Save feed posts
  Future<void> saveFeedPost(LocalFeedPost post) async {
    await _feedBox.put(post.id, post);
  }

  Future<void> saveFeedPosts(List<LocalFeedPost> posts) async {
    final map = {for (final p in posts) p.id: p};
    await _feedBox.putAll(map);
  }

  /// Get cached feed
  List<LocalFeedPost> getCachedFeed() {
    final posts = _feedBox.values.toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  /// Toggle like on post
  Future<void> toggleLike(String postId) async {
    final post = _feedBox.get(postId);
    if (post != null) {
      post.isLiked = !post.isLiked;
      post.likes += post.isLiked ? 1 : -1;
      await post.save();
    }
  }

  // ==================== EVENTS ====================

  Future<void> saveEvent(LocalEvent event) async {
    await _eventsBox.put(event.id, event);
  }

  Future<void> saveEvents(List<LocalEvent> events) async {
    final map = {for (final e in events) e.id: e};
    await _eventsBox.putAll(map);
  }

  List<LocalEvent> getEvents({bool onlyParticipating = false}) {
    final events = _eventsBox.values.toList();
    events.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (onlyParticipating) {
      return events.where((e) => e.isParticipating).toList();
    }
    return events;
  }

  Future<void> toggleParticipation(String eventId) async {
    final event = _eventsBox.get(eventId);
    if (event != null) {
      event.isParticipating = !event.isParticipating;
      if (event.isParticipating) {
        event.currentParticipants++;
      } else {
        event.currentParticipants--;
      }
      await event.save();
    }
  }

  // ==================== SETTINGS ====================

  Future<void> saveSettings(LocalUserSettings settings) async {
    await _settingsBox.put(settings.userId, settings);
  }

  LocalUserSettings? getSettings(String userId) =>
      _settingsBox.get(userId);

  LocalUserSettings? getCurrentSettings() {
    if (_settingsBox.isEmpty) return null;
    return _settingsBox.values.first;
  }

  // ==================== STATISTICS ====================

  Map<String, dynamic> getLocalStatistics() {
    final routes = getAllRoutes();
    final totalDistance = routes.fold<double>(
        0, (sum, r) => sum + r.distance);
    final totalDuration = routes.fold<int>(
        0, (sum, r) => sum + r.durationSeconds);
    final totalPoints = routes.fold<int>(
        0, (sum, r) => sum + r.points.length);

    return {
      'totalRoutes': routes.length,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'totalPoints': totalPoints,
      'avgDistance':
          routes.isEmpty ? 0 : totalDistance / routes.length,
      'cachedWaterBodies': _waterBodiesBox.length,
      'cachedConversations': _conversationsBox.length,
      'cachedMessages': _messagesBox.length,
      'cachedFeedPosts': _feedBox.length,
      'cachedEvents': _eventsBox.length,
    };
  }

  // ==================== CLEANUP ====================

  /// Clear all cached data
  Future<void> clearCache() async {
    await _waterBodiesBox.clear();
    await _feedBox.clear();
    await _eventsBox.clear();
  }

  /// Clear old messages (keep last N days)
  Future<void> clearOldMessages({int daysToKeep = 90}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    final oldMessages = _messagesBox.values
        .where((m) => m.sentAt.isBefore(cutoff))
        .toList();
    for (final msg in oldMessages) {
      await msg.delete();
    }
  }

  /// Get storage usage in bytes
  Future<int> getStorageSize() async {
    int size = 0;
    size += await _routesBox.length * 1024;
    size += await _waterBodiesBox.length * 512;
    size += await _messagesBox.length * 256;
    size += await _feedBox.length * 1024;
    size += await _eventsBox.length * 512;
    return size;
  }

  /// Close all boxes
  Future<void> close() async {
    await Hive.close();
    await _tripPointsDb.close();
  }
}
