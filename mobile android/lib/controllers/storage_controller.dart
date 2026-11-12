// Storage controller for managing local data state with Provider
import 'package:flutter/foundation.dart';
import '../models/local_models.dart';
import '../services/local_storage_service.dart';

class StorageController extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService.instance;

  List<LocalRoute> _routes = [];
  List<LocalWaterBody> _waterBodies = [];
  List<LocalConversation> _conversations = [];
  List<LocalFeedPost> _feedPosts = [];
  List<LocalEvent> _events = [];
  LocalUserSettings? _settings;

  bool _isLoading = false;

  List<LocalRoute> get routes => _routes;
  List<LocalWaterBody> get waterBodies => _waterBodies;
  List<LocalConversation> get conversations => _conversations;
  List<LocalFeedPost> get feedPosts => _feedPosts;
  List<LocalEvent> get events => _events;
  LocalUserSettings? get settings => _settings;
  bool get isLoading => _isLoading;

  int get totalUnreadMessages =>
      _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

  double get totalDistance =>
      _routes.fold<double>(0, (sum, r) => sum + r.distance);

  /// Load all data from local storage
  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      _routes = _storage.getAllRoutes();
      _waterBodies = _storage.getCachedWaterBodies();
      _conversations = _storage.getConversations();
      _feedPosts = _storage.getCachedFeed();
      _events = _storage.getEvents();
      _settings = _storage.getCurrentSettings();
    } catch (e) {
      debugPrint('Storage load failed: $e');
      _routes = [];
      _waterBodies = [];
      _conversations = [];
      _feedPosts = [];
      _events = [];
      _settings = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Save a route and refresh
  Future<void> saveRoute(LocalRoute route) async {
    await _storage.saveRoute(route);
    _routes = _storage.getAllRoutes();
    notifyListeners();
  }

  /// Delete route
  Future<void> deleteRoute(String id) async {
    await _storage.deleteRoute(id);
    _routes = _storage.getAllRoutes();
    notifyListeners();
  }

  /// Cache a water body
  Future<void> cacheWaterBody(LocalWaterBody waterBody) async {
    await _storage.cacheWaterBody(waterBody);
    _waterBodies = _storage.getCachedWaterBodies();
    notifyListeners();
  }

  /// Toggle water body favorite
  Future<void> toggleWaterBodyFavorite(String id) async {
    await _storage.toggleFavorite(id);
    _waterBodies = _storage.getCachedWaterBodies();
    notifyListeners();
  }

  List<LocalWaterBody> get favoriteWaterBodies =>
      _waterBodies.where((w) => w.isFavorite).toList();

  /// Save a chat message
  Future<void> saveMessage(LocalChatMessage message) async {
    await _storage.saveMessage(message);
    _conversations = _storage.getConversations();
    notifyListeners();
  }

  /// Get messages for a conversation
  List<LocalChatMessage> getMessages(String conversationId) {
    return _storage.getMessages(conversationId);
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    await _storage.markMessagesAsRead(conversationId);
    _conversations = _storage.getConversations();
    notifyListeners();
  }

  /// Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    await _storage.deleteConversation(conversationId);
    _conversations = _storage.getConversations();
    notifyListeners();
  }

  /// Save feed post
  Future<void> saveFeedPost(LocalFeedPost post) async {
    await _storage.saveFeedPost(post);
    _feedPosts = _storage.getCachedFeed();
    notifyListeners();
  }

  /// Toggle like on post
  Future<void> togglePostLike(String postId) async {
    await _storage.toggleLike(postId);
    _feedPosts = _storage.getCachedFeed();
    notifyListeners();
  }

  /// Save event
  Future<void> saveEvent(LocalEvent event) async {
    await _storage.saveEvent(event);
    _events = _storage.getEvents();
    notifyListeners();
  }

  /// Toggle participation
  Future<void> toggleEventParticipation(String eventId) async {
    await _storage.toggleParticipation(eventId);
    _events = _storage.getEvents();
    notifyListeners();
  }

  /// Save user settings
  Future<void> saveSettings(LocalUserSettings settings) async {
    await _storage.saveSettings(settings);
    _settings = settings;
    notifyListeners();
  }

  /// Search messages
  List<LocalChatMessage> searchMessages(String query) {
    return _storage.searchMessages(query);
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    return _storage.getLocalStatistics();
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _storage.clearCache();
    await loadAll();
  }

  /// Clear old messages
  Future<void> clearOldMessages({int daysToKeep = 90}) async {
    await _storage.clearOldMessages(daysToKeep: daysToKeep);
    _conversations = _storage.getConversations();
    notifyListeners();
  }
}
