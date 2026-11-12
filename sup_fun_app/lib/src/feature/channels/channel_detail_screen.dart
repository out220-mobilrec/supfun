import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';

class ChannelDetailScreen extends StatefulWidget {
  const ChannelDetailScreen({super.key, required this.channelId});

  final String channelId;

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> {
  Channel? _channel;
  List<ChannelPost> _posts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ApiClient.instance.get('/channels/${widget.channelId}');
      final p = await ApiClient.instance.getList(
          '/channels/${widget.channelId}/posts', query: {'limit': 50});
      if (!mounted) return;
      setState(() {
        _channel = Channel.fromJson(j);
        _posts = p.map((e) => ChannelPost.fromJson(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ошибка сети');
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _loading = false;
    });
  }

  Future<void> _join() async {
    try {
      await ApiClient.instance.post('/channels/${widget.channelId}/join');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _leave() async {
    try {
      await ApiClient.instance.post('/channels/${widget.channelId}/leave');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _createPost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CreatePostSheet(channelId: widget.channelId, onPosted: () => _load()),
    );
  }

  Future<void> _toggleLike(ChannelPost p) async {
    try {
      final j = await ApiClient.instance
          .post('/channels/${widget.channelId}/posts/${p.id}/like');
      final liked = (j['liked'] ?? false) as bool;
      final count = (j['likeCount'] ?? 0) as int;
      setState(() {
        final idx = _posts.indexWhere((x) => x.id == p.id);
        if (idx >= 0) {
          final old = _posts[idx];
          _posts[idx] = ChannelPost(
            id: old.id,
            channelId: old.channelId,
            authorId: old.authorId,
            author: old.author,
            title: old.title,
            body: old.body,
            photos: old.photos,
            isPinned: old.isPinned,
            likeCount: count,
            commentCount: old.commentCount,
            likedByMe: liked,
            canDelete: old.canDelete,
            canPin: old.canPin,
            createdAt: old.createdAt,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _togglePin(ChannelPost p) async {
    try {
      await ApiClient.instance
          .post('/channels/${widget.channelId}/posts/${p.id}/pin');
      _load();
    } catch (_) {}
  }

  Future<void> _deletePost(ChannelPost p) async {
    try {
      await ApiClient.instance
          .delete('/channels/${widget.channelId}/posts/${p.id}');
      _load();
    } catch (_) {}
  }

  void _openComments(ChannelPost p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(channelId: widget.channelId, post: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: AppLoading());
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(), body: ErrorBanner(message: _error!, onRetry: _load));
    }
    final c = _channel!;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.description != null) Text(c.description!),
                  const SizedBox(height: 8),
                  Text('${c.subscriberCount} подписчиков',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  if (!c.isMember)
                    FilledButton(
                      onPressed: _join,
                      child: const Text('Подписаться'),
                    )
                  else if (c.myRole != 'owner')
                    OutlinedButton(
                      onPressed: _leave,
                      child: const Text('Отписаться'),
                    ),
                  if (c.isMember)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: _createPost,
                        icon: const Icon(Icons.add),
                        label: const Text('Новая публикация'),
                      ),
                    ),
                ],
              ),
            ),
            ..._posts.map((p) => _PostCard(
                  post: p,
                  onLike: () => _toggleLike(p),
                  onPin: p.canPin ? () => _togglePin(p) : null,
                  onDelete: p.canDelete ? () => _deletePost(p) : null,
                  onComments: () => _openComments(p),
                )),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLike,
    required this.onComments,
    this.onPin,
    this.onDelete,
  });

  final ChannelPost post;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                AppAvatar(post.author?.avatarUrl, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(post.author?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (post.isPinned)
                  const Icon(Icons.push_pin,
                      size: 16, color: AppColors.accent),
                if (onPin != null || onDelete != null)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'pin') onPin!();
                      if (v == 'del') onDelete!();
                    },
                    itemBuilder: (_) => [
                      if (onPin != null)
                        const PopupMenuItem(value: 'pin', child: Text('Закрепить')),
                      if (onDelete != null)
                        const PopupMenuItem(value: 'del', child: Text('Удалить')),
                    ],
                  ),
              ],
            ),
          ),
          if (post.title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(post.title!,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          if (post.body != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(post.body!,
                  style: const TextStyle(fontSize: 14, height: 1.4)),
            ),
          if (post.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(AppConfig.absUrl(post.photos.first),
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.likedByMe ? AppColors.danger : null,
                    size: 20,
                  ),
                ),
                Text('${post.likeCount}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onComments,
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                ),
                Text('${post.commentCount}',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant)),
                if (post.createdAt != null)
                  Expanded(
                    child: Text(
                      dayLabel(post.createdAt!),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.channelId, required this.onPosted});

  final String channelId;
  final VoidCallback onPosted;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ApiClient.instance.post(
        '/channels/${widget.channelId}',
        data: {
          if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
          if (_body.text.trim().isNotEmpty) 'body': _body.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onPosted();
    } on ApiException catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'Заголовок')),
          const SizedBox(height: 12),
          TextField(
              controller: _body,
              decoration: const InputDecoration(hintText: 'Текст'),
              maxLines: 4),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Опубликовать'),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.channelId, required this.post});

  final String channelId;
  final ChannelPost post;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _comment = TextEditingController();
  List<ChannelComment> _comments = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ApiClient.instance.getList(
        '/channels/${widget.channelId}/posts/${widget.post.id}/comments');
    if (!mounted) return;
    setState(() {
      _comments = list.map((e) => ChannelComment.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _send() async {
    if (_comment.text.trim().isEmpty) return;
    try {
      await ApiClient.instance.post(
          '/channels/${widget.channelId}/posts/${widget.post.id}/comments',
          data: {'body': _comment.text.trim()});
      _comment.clear();
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            const Text('Комментарии',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Expanded(
              child: _loading
                  ? const AppLoading()
                  : _comments.isEmpty
                      ? const EmptyState(icon: Icons.mode_comment_outlined,
                          text: 'Комментариев нет')
                      : ListView.builder(
                          itemCount: _comments.length,
                          itemBuilder: (_, i) {
                            final c = _comments[i];
                            return ListTile(
                              dense: true,
                              leading: AppAvatar(c.author?.avatarUrl, size: 32),
                              title: Text(c.author?.name ?? '',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(c.body,
                                  style: const TextStyle(fontSize: 13)),
                            );
                          },
                        ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                      controller: _comment,
                      decoration: const InputDecoration(
                          hintText: 'Комментарий', isDense: true),
                      onSubmitted: (_) => _send()),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChannelComment {
  final String id;
  final String authorId;
  final SimpleUser? author;
  final String body;

  ChannelComment({required this.id, required this.authorId, this.author, required this.body});

  factory ChannelComment.fromJson(Map<String, dynamic> j) => ChannelComment(
        id: j['id'] as String,
        authorId: j['authorId'] as String,
        author: j['author'] != null && j['author'] is Map
            ? SimpleUser.fromJson(Map<String, dynamic>.from(j['author']))
            : null,
        body: (j['body'] ?? '') as String,
      );
}