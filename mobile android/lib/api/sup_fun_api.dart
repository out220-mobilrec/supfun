// Доменный доступ к API SUP FUN.
//
// Сгруппирован по модулям бэкенда (server/src/modules). Методы возвращают
// типизированные модели; списки сервер отдаёт массивом, агрегаторы — объектом,
// это учтено в каждом методе.
import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/api_models.dart';

class SupFunApi {
  final ApiClient client;

  SupFunApi(this.client);

  AuthApi get auth => AuthApi(client);
  UsersApi get users => UsersApi(client);
  WaterbodiesApi get waterbodies => WaterbodiesApi(client);
  EventsApi get events => EventsApi(client);
  TracksApi get tracks => TracksApi(client);
  GamificationApi get gamification => GamificationApi(client);
  FeedApi get feed => FeedApi(client);
  PostsApi get posts => PostsApi(client);
  MarketplaceApi get marketplace => MarketplaceApi(client);
  ChatsApi get chats => ChatsApi(client);
  NotificationsApi get notifications => NotificationsApi(client);
  GearApi get gear => GearApi(client);
  RatingsApi get ratings => RatingsApi(client);
  NewsApi get news => NewsApi(client);
  SearchApi get search => SearchApi(client);
}

// ---------------------------------------------------------------------- auth

class AuthApi {
  final ApiClient _c;
  AuthApi(this._c);

  Future<String> register({
    required String name,
    required String email,
    required String password,
    String? city,
    String? phone,
  }) async {
    final data = await _c.post('/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      if (city != null && city.isNotEmpty) 'city': city,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return asString(asMap(data)['message'],
        'Если email свободен, на него отправлен код подтверждения.');
  }

  /// Подтверждение email сразу выдаёт пару токенов (AuthResult).
  Future<AuthSession> verifyEmail(String email, String code) async {
    final data = asMap(await _c.post('/auth/verify-email',
        body: {'email': email, 'code': code}));
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> login(String email, String password) async {
    final data = asMap(await _c
        .post('/auth/login', body: {'email': email, 'password': password}));
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final data = asMap(
        await _c.post('/auth/refresh', body: {'refreshToken': refreshToken}));
    return AuthSession.fromJson(data);
  }

  Future<void> logout(String refreshToken) =>
      _c.post('/auth/logout', body: {'refreshToken': refreshToken});

  Future<void> logoutAll() => _c.post('/auth/logout-all');

  Future<void> resendVerification() => _c.post('/auth/resend-verification');

  Future<void> forgotPassword(String email) =>
      _c.post('/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword(
          {required String email,
          required String code,
          required String password}) =>
      _c.post('/auth/reset-password',
          body: {'email': email, 'code': code, 'password': password});

  Future<void> changePassword(
          {required String currentPassword, required String newPassword}) =>
      _c.post('/auth/change-password',
          body: {'currentPassword': currentPassword, 'newPassword': newPassword});
}

/// Ответ /auth/login, /auth/refresh, /auth/verify-email.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final AppUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: asString(json['accessToken']),
        refreshToken: asString(json['refreshToken']),
        user: AppUser.fromJson(asMap(json['user'])),
      );
}

// --------------------------------------------------------------------- users

class UsersApi {
  final ApiClient _c;
  UsersApi(this._c);

  Future<AppUser> me() async =>
      AppUser.fromJson(asMap(await _c.get('/users/me')));

  Future<AppUser> updateMe({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? region,
    String? country,
    String? bio,
    String? avatarUrl,
    String? profileVisibility,
    String? activityVisibility,
    String? geoVisibility,
    bool? showOnline,
  }) async {
    final body = <String, Object?>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (region != null) 'region': region,
      if (country != null) 'country': country,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (profileVisibility != null) 'profileVisibility': profileVisibility,
      if (activityVisibility != null)
        'activityVisibility': activityVisibility,
      if (geoVisibility != null) 'geoVisibility': geoVisibility,
      if (showOnline != null) 'showOnline': showOnline,
    };
    return AppUser.fromJson(asMap(await _c.patch('/users/me', body: body)));
  }

  Future<AppUser> byId(String id) async =>
      AppUser.fromJson(asMap(await _c.get('/users/$id')));

  /// Публичный профиль со статистикой — видимость учитывает сервер.
  Future<Map<String, dynamic>> profile(String id) async =>
      asMap(await _c.get('/users/$id/profile'));
}

// ----------------------------------------------------------------- waterbodies

class WaterbodiesApi {
  final ApiClient _c;
  WaterbodiesApi(this._c);

  Future<List<WaterBody>> list({String? q, int limit = 50, int offset = 0}) async {
    final data = await _c.get('/waterbodies',
        query: {'q': q, 'limit': limit, 'offset': offset});
    return asMapList(data).map(WaterBody.fromJson).toList();
  }

  Future<List<NearbyWaterBody>> nearby(
      double lat, double lng, int radiusMeters) async {
    final data = await _c.get('/waterbodies/nearby',
        query: {'lat': lat, 'lng': lng, 'radius': radiusMeters});
    return asMapList(data).map(NearbyWaterBody.fromJson).toList();
  }

  Future<WaterBody> byId(String id) async =>
      WaterBody.fromJson(asMap(await _c.get('/waterbodies/$id')));
}

// -------------------------------------------------------------------- events

class EventsApi {
  final ApiClient _c;
  EventsApi(this._c);

  Future<List<SupEvent>> list({
    String? status,
    String? waterBodyId,
    String? trackId,
    String? date,
    String? level,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _c.get('/events', query: {
      'status': status,
      'waterBodyId': waterBodyId,
      'trackId': trackId,
      'date': date,
      'level': level,
      'limit': limit,
      'offset': offset,
    });
    return asMapList(data).map(SupEvent.fromJson).toList();
  }

  /// Запланированные заплывы (опционально — на конкретном водоёме).
  Future<List<SupEvent>> upcoming({
    String? waterBodyId,
    int limit = 50,
  }) =>
      list(status: 'scheduled', waterBodyId: waterBodyId, limit: limit);

  Future<List<SupEvent>> nearby(double lat, double lng, [int radius = 30000]) async {
    final data = await _c.get('/events/nearby',
        query: {'lat': lat, 'lng': lng, 'radius': radius});
    return asMapList(data).map(SupEvent.fromJson).toList();
  }

  /// status: going | maybe | not_going | all
  Future<List<SupEvent>> mine(String status) async {
    final data = await _c.get('/events/mine/$status');
    return asMapList(data).map(SupEvent.fromJson).toList();
  }

  Future<SupEvent> byId(String id) async =>
      SupEvent.fromJson(asMap(await _c.get('/events/$id')));

  Future<SupEvent> create(Map<String, Object?> body) async =>
      SupEvent.fromJson(asMap(await _c.post('/events', body: body)));

  Future<SupEvent> update(String id, Map<String, Object?> body) async =>
      SupEvent.fromJson(asMap(await _c.patch('/events/$id', body: body)));

  Future<void> cancel(String id) => _c.delete('/events/$id');

  Future<void> join(String id, ParticipantStatus status) =>
      _c.post('/events/$id/join', body: {'status': status.apiValue});

  Future<List<EventParticipant>> participants(String id,
      {String? status}) async {
    final data = await _c.get('/events/$id/participants',
        query: {'status': status});
    return asMapList(data).map(EventParticipant.fromJson).toList();
  }

  /// Треки участников заплыва (для карты и списка на странице заплыва).
  Future<List<Map<String, dynamic>>> tracks(String id) async =>
      asMapList(await _c.get('/events/$id/tracks'));

  /// Старт записи своего трека в заплыве — идемпотентен до финиша.
  Future<Track> startTrack(String eventId, {String? name}) async {
    final data = await _c.post('/events/$eventId/tracks', body: {
      if (name != null) 'name': name,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return Track.fromJson(asMap(data));
  }

  Future<void> appendTrackPoints(
          String eventId, String trackId, List<GpsPoint> points) =>
      _c.post('/events/$eventId/tracks/$trackId/points',
          body: {
            'points': points.map((p) => p.toJson()).toList()
          });

  Future<AwardResult> finishTrack(
      String eventId, String trackId, DateTime endedAt,
      {String? name, TrackDifficulty? difficulty}) async {
    final data = asMap(await _c.post('/events/$eventId/tracks/$trackId/finish',
        body: {
          'endedAt': endedAt.toUtc().toIso8601String(),
          if (name != null) 'name': name,
          if (difficulty != null) 'difficulty': difficulty.apiValue,
        }));
    return AwardResult.fromJson(asMap(data['award']));
  }
}

// -------------------------------------------------------------------- tracks

class TracksApi {
  final ApiClient _c;
  TracksApi(this._c);

  Future<List<Track>> list({
    String? scope,
    String? waterBodyId,
    String? difficulty,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _c.get('/tracks', query: {
      'scope': scope,
      'waterBodyId': waterBodyId,
      'difficulty': difficulty,
      'limit': limit,
      'offset': offset,
    });
    return asMapList(data).map(Track.fromJson).toList();
  }

  Future<List<Track>> mine() async =>
      asMapList(await _c.get('/tracks/mine')).map(Track.fromJson).toList();

  Future<Track> byId(String id) async =>
      Track.fromJson(asMap(await _c.get('/tracks/$id')));

  Future<List<TrackPoint>> points(String id) async =>
      asMapList(await _c.get('/tracks/$id/points'))
          .map(TrackPoint.fromJson)
          .toList();

  /// Новый трек; `startedAt` обязателен на сервере.
  Future<Track> create({
    String? name,
    String? waterBodyId,
    String? eventId,
    TrackDifficulty? difficulty,
    DateTime? startedAt,
  }) async {
    final data = await _c.post('/tracks', body: {
      if (name != null) 'name': name,
      if (waterBodyId != null) 'waterBodyId': waterBodyId,
      if (eventId != null) 'eventId': eventId,
      if (difficulty != null) 'difficulty': difficulty.apiValue,
      'startedAt': (startedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
    return Track.fromJson(asMap(data));
  }

  Future<Map<String, dynamic>> update(String id, Map<String, Object?> body) async =>
      asMap(await _c.patch('/tracks/$id', body: body));

  /// Пачка точек. Внимание: у этого эндпоинта нет дедупликации по seq
  /// (она есть только у /events/:id/tracks/:trackId/points), поэтому
  /// клиент отправляет точку ровно один раз и помнит подтверждённый seq.
  Future<int> addPoints(String trackId, List<GpsPoint> points) async {
    final data = await _c.post('/tracks/$trackId/points',
        body: {
          'points': points.map((p) => p.toJson()).toList()
        });
    return asInt(asMap(data)['added']);
  }

  Future<TrackFinishResult> complete(
      String trackId, DateTime endedAt,
      {String? name, TrackDifficulty? difficulty}) async {
    final data = asMap(await _c.post('/tracks/$trackId/complete', body: {
      'endedAt': endedAt.toUtc().toIso8601String(),
      if (name != null) 'name': name,
      if (difficulty != null) 'difficulty': difficulty.apiValue,
    }));
    return TrackFinishResult(
      track: Track.fromJson(asMap(data['track'])),
      award: AwardResult.fromJson(asMap(data['award'])),
    );
  }

  Future<Track> publish(String trackId) async =>
      Track.fromJson(asMap(await _c.post('/tracks/$trackId/publish')));

  Future<void> remove(String trackId) => _c.delete('/tracks/$trackId');
}

class TrackFinishResult {
  final Track track;
  final AwardResult award;
  const TrackFinishResult({required this.track, required this.award});
}

// -------------------------------------------------------------- gamification

class GamificationApi {
  final ApiClient _c;
  GamificationApi(this._c);

  Future<LevelInfo> me() async =>
      LevelInfo.fromJson(asMap(await _c.get('/gamification/me')));

  Future<List<PointLogEntry>> points() async =>
      asMapList(await _c.get('/gamification/points'))
          .map(PointLogEntry.fromJson)
          .toList();

  Future<List<Achievement>> achievements() async =>
      asMapList(await _c.get('/gamification/achievements'))
          .map(Achievement.fromJson)
          .toList();

  Future<Map<String, dynamic>> rules() async =>
      asMap(await _c.get('/gamification/rules'));
}

// ---------------------------------------------------------------------- feed

class FeedApi {
  final ApiClient _c;
  FeedApi(this._c);

  Future<FeedSnapshot> feed({int limit = 20}) async =>
      FeedSnapshot.fromJson(asMap(await _c.get('/feed', query: {'limit': limit})));

  Future<Map<String, dynamic>> search(String q, {int limit = 10}) async =>
      asMap(await _c.get('/search', query: {'q': q, 'limit': limit}));
}

/// Единый поиск (ТЗ §25): GET /search отдаёт объект с пятью группами.
class SearchResults {
  final List<WaterBody> waterbodies;
  final List<AppUser> users;
  final List<SupEvent> events;
  final List<Track> tracks;
  final List<Listing> listings;

  const SearchResults({
    this.waterbodies = const [],
    this.users = const [],
    this.events = const [],
    this.tracks = const [],
    this.listings = const [],
  });

  int get total =>
      waterbodies.length +
      users.length +
      events.length +
      tracks.length +
      listings.length;

  bool get isEmpty => total == 0;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        waterbodies: asMapList(json['waterbodies'])
            .map(WaterBody.fromJson)
            .toList(growable: false),
        users: asMapList(json['users'])
            .map(AppUser.fromJson)
            .toList(growable: false),
        events: asMapList(json['events'])
            .map(SupEvent.fromJson)
            .toList(growable: false),
        tracks: asMapList(json['tracks'])
            .map(trackLite)
            .toList(growable: false),
        listings: asMapList(json['listings'])
            .map(Listing.fromJson)
            .toList(growable: false),
      );
}

class SearchApi {
  final ApiClient _c;
  SearchApi(this._c);

  Future<SearchResults> all(String query, {int limit = 5}) async {
    final data =
        asMap(await _c.get('/search', query: {'q': query, 'limit': limit}));
    return SearchResults.fromJson(data);
  }
}

class PostsApi {
  final ApiClient _c;
  PostsApi(this._c);

  Future<List<Post>> list({int limit = 20, int offset = 0, String? authorId}) async {
    final data = await _c.get('/posts',
        query: {'limit': limit, 'offset': offset, 'authorId': authorId});
    // /posts отдаёт {items, hasMore}
    return asMapList(asMap(data)['items']).map(Post.fromJson).toList();
  }

  Future<Post> create({String? title, String? body, String visibility = 'public'}) async =>
      Post.fromJson(asMap(await _c.post('/posts', body: {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        'visibility': visibility,
      })));

  Future<({bool liked, int likeCount})> toggleLike(String postId) async {
    final data = asMap(await _c.patch('/posts/$postId/like'));
    return (
      liked: asBool(data['liked']),
      likeCount: asInt(data['likeCount'])
    );
  }

  Future<void> share(String postId) => _c.post('/posts/$postId/share');
}

// ---------------------------------------------------------------- marketplace

class MarketplaceApi {
  final ApiClient _c;
  MarketplaceApi(this._c);

  Future<List<String>> categories() async {
    final data = await _c.get('/marketplace/categories');
    if (data is List) return data.map((e) => '$e').toList();
    return const [];
  }

  Future<List<Listing>> listings({
    String? category,
    String? city,
    String? q,
    String? sort,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _c.get('/marketplace/listings', query: {
      'category': category,
      'city': city,
      'q': q,
      'sort': sort,
      'limit': limit,
      'offset': offset,
    });
    return asMapList(data).map(Listing.fromJson).toList();
  }

  Future<List<Listing>> mine() async =>
      asMapList(await _c.get('/marketplace/listings/mine'))
          .map(Listing.fromJson)
          .toList();

  Future<Listing> byId(String id) async =>
      Listing.fromJson(asMap(await _c.get('/marketplace/listings/$id')));

  Future<Listing> create(Map<String, Object?> body) async =>
      Listing.fromJson(
          asMap(await _c.post('/marketplace/listings', body: body)));

  Future<void> markSold(String id) =>
      _c.post('/marketplace/listings/$id/complete');
}

// --------------------------------------------------------------------- chats

class ChatsApi {
  final ApiClient _c;
  ChatsApi(this._c);

  Future<List<ConversationSummary>> list() async =>
      asMapList(await _c.get('/conversations'))
          .map(ConversationSummary.fromJson)
          .toList();

  Future<String> direct(String userId) async {
    final data = asMap(await _c.post('/conversations/direct', body: {'userId': userId}));
    return asString(data['id']);
  }

  Future<ConversationSummary> byId(String id) async =>
      ConversationSummary.fromJson(asMap(await _c.get('/conversations/$id')));

  Future<List<ChatMessage>> messages(String id, {int limit = 50}) async =>
      asMapList(await _c.get('/conversations/$id/messages',
              query: {'limit': limit}))
          .map(ChatMessage.fromJson)
          .toList();

  Future<ChatMessage> send(String conversationId, String text) async =>
      ChatMessage.fromJson(asMap(await _c.post(
          '/conversations/$conversationId/messages',
          body: {'type': 'text', 'content': text})));

  Future<void> markRead(String conversationId) =>
      _c.post('/conversations/$conversationId/read');
}

// -------------------------------------------------------------- notifications

class NotificationsApi {
  final ApiClient _c;
  NotificationsApi(this._c);

  Future<List<AppNotification>> list() async =>
      asMapList(await _c.get('/notifications'))
          .map(AppNotification.fromJson)
          .toList();

  Future<int> unreadCount() async {
    final data = asMap(await _c.get('/notifications/unread-count'));
    return asInt(data['count'] ?? data['unreadCount']);
  }

  Future<void> markAllRead() => _c.post('/notifications/read');

  Future<List<Map<String, dynamic>>> settings() async =>
      asMapList(await _c.get('/notifications/settings'));

  Future<void> updateSetting(String category,
          {bool? inApp, bool? push}) =>
      _c.patch('/notifications/settings/$category',
          body: {if (inApp != null) 'inApp': inApp, if (push != null) 'push': push});
}

// ---------------------------------------------------------------------- gear

class GearApi {
  final ApiClient _c;
  GearApi(this._c);

  Future<List<GearItem>> mine() async =>
      asMapList(await _c.get('/gear/mine')).map(GearItem.fromJson).toList();

  Future<List<GearItem>> forUser(String userId) async =>
      asMapList(await _c.get('/gear/$userId')).map(GearItem.fromJson).toList();
}

// ------------------------------------------------------------------- ratings

class RatingsApi {
  final ApiClient _c;
  RatingsApi(this._c);

  Future<({List<LeaderboardEntry> entries, LeaderboardEntry? me})> leaderboard(
      {String scope = 'all', int limit = 50}) async {
    final data = asMap(
        await _c.get('/ratings/leaderboard', query: {'scope': scope, 'limit': limit}));
    return (
      entries: asMapList(data['entries'])
          .map(LeaderboardEntry.fromJson)
          .toList(),
      me: data['me'] == null
          ? null
          : LeaderboardEntry.fromJson(asMap(data['me'])),
    );
  }
}

// ----------------------------------------------------------------------- новости

class NewsItem {
  final String id;
  final String title;
  final String body;
  final String? coverUrl;
  final String authorName;
  final DateTime createdAt;

  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    this.coverUrl,
    required this.authorName,
    required this.createdAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final author = asMap(json['author']);
    return NewsItem(
      id: asString(json['id']),
      title: asString(json['title']),
      body: asString(json['body']),
      coverUrl: absoluteUrl(asStringOrNull(json['coverUrl'])),
      authorName: asString(author['name'], 'SUP FUN'),
      createdAt: asDate(json['createdAt']),
    );
  }
}

class NewsApi {
  final ApiClient _c;
  NewsApi(this._c);

  /// GET /news отдаёт {items, hasMore}.
  Future<List<NewsItem>> list({int limit = 10, int offset = 0}) async {
    final data =
        asMap(await _c.get('/news', query: {'limit': limit, 'offset': offset}));
    return asMapList(data['items']).map(NewsItem.fromJson).toList();
  }

  Future<NewsItem> byId(String id) async =>
      NewsItem.fromJson(asMap(await _c.get('/news/$id')));
}
