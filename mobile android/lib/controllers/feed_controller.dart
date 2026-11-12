// Социальная лента (ТЗ §15) и раздел «Сообщения» (ТЗ §20).
import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../core/api_client.dart';
import '../models/api_models.dart';
import 'load_state.dart';

class FeedController extends ChangeNotifier with LoadCoordinator {
  FeedController(this.api);

  final SupFunApi api;
  static const int _pageSize = 20;

  final Section<List<Post>> posts = Section();
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _loadingMore;
  String? actionError;

  Future<void> refresh() async {
    _offset = 0;
    _hasMore = true;
    await guard<List<Post>>(posts, () => api.posts.list(limit: _pageSize));
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || posts.data == null) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final next = await api.posts.list(
          limit: _pageSize, offset: _offset + _pageSize);
      _hasMore = next.length >= _pageSize;
      if (next.isNotEmpty) {
        _offset += _pageSize;
        posts.data = [...posts.data!, ...next];
        posts.state = LoadState.ready;
      }
    } catch (_) {
      _hasMore = false;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Лайк: сервер отвечает фактическое состояние, оптимистично не гадаем.
  Future<void> toggleLike(Post post) async {
    final current = posts.data;
    if (current == null) return;
    try {
      final result = await api.posts.toggleLike(post.id);
      posts.data = [
        for (final p in current)
          if (p.id == post.id)
            _withLike(p, result.liked, result.likeCount)
          else
            p,
      ];
      notifyListeners();
    } catch (e) {
      actionError = e is ApiException ? e.message : 'Не удалось оценить';
      notifyListeners();
    }
  }

  Future<Post?> createPost({String? title, String? body}) async {
    try {
      final post = await api.posts.create(title: title, body: body);
      posts.data = [post, ...?posts.data];
      posts.state = LoadState.ready;
      notifyListeners();
      return post;
    } catch (e) {
      actionError = e is ApiException ? e.message : 'Не удалось опубликовать';
      notifyListeners();
      return null;
    }
  }

  Post _withLike(Post post, bool liked, int likeCount) => Post(
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        authorAvatar: post.authorAvatar,
        type: post.type,
        title: post.title,
        body: post.body,
        photos: post.photos,
        refId: post.refId,
        refType: post.refType,
        likeCount: likeCount,
        commentCount: post.commentCount,
        shareCount: post.shareCount,
        likedByMe: liked,
        canDelete: post.canDelete,
        createdAt: post.createdAt,
      );
}

class ChatsController extends ChangeNotifier with LoadCoordinator {
  ChatsController(this.api);

  final SupFunApi api;

  final Section<List<ConversationSummary>> conversations = Section();
  final Section<List<ChatMessage>> messages = Section();

  String? actionError;
  bool busy = false;
  String? openedId;

  Future<void> refresh() => guard<List<ConversationSummary>>(
      conversations, () => api.chats.list());

  Future<void> open(String conversationId) async {
    openedId = conversationId;
    await guard<List<ChatMessage>>(
        messages, () => api.chats.messages(conversationId));
    try {
      await api.chats.markRead(conversationId);
    } catch (_) {
      // не критично для показа переписки
    }
  }

  Future<void> send(String text) async {
    final id = openedId;
    if (id == null || text.trim().isEmpty) return;
    busy = true;
    notifyListeners();
    try {
      final message = await api.chats.send(id, text.trim());
      messages.data = [...?messages.data, message];
      messages.state = LoadState.ready;
      actionError = null;
    } catch (e) {
      actionError = e is ApiException ? e.message : 'Сообщение не отправлено';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Открывает (или создаёт) личный чат с пользователем.
  Future<String?> directWith(String userId) async {
    try {
      return await api.chats.direct(userId);
    } catch (e) {
      actionError = e is ApiException ? e.message : 'Не удалось открыть чат';
      notifyListeners();
      return null;
    }
  }

  int get totalUnread =>
      (conversations.data ?? const <ConversationSummary>[])
          .fold<int>(0, (sum, c) => sum + c.unreadCount);
}
