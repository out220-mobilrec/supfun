// Социальная лента (ТЗ §15): посты сообщества, лайки, публикация.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final FeedController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = context.read<FeedController>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.posts.hasData) _controller.refresh();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _controller.loadMore();
    }
  }

  Future<void> _compose() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Что нового?'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Расскажите о заплыве, маршруте или находке'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Опубликовать')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;
    await _controller.createPost(body: text);
    if (!mounted) return;
    if (_controller.actionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_controller.actionError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FeedController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщество'),
        actions: [
          IconButton(
              onPressed: _compose, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: SectionView<List<Post>>(
          section: controller.posts,
          onRetry: controller.refresh,
          emptyTitle: 'В ленте пока пусто',
          emptySubtitle: 'Поделитесь первым заплывом',
          actionLabel: 'Написать',
          onAction: _compose,
          builder: (posts) => ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 30),
            itemCount: posts.length + (controller.hasMore ? 1 : 0),
            itemBuilder: (_, index) {
              if (index >= posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: LoadingView(),
                );
              }
              final post = posts[index];
              return PostCard(
                post: post,
                onLike: () => controller.toggleLike(post),
              );
            },
          ),
        ),
      ),
    );
  }
}

class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          countLabel(count, 'запись', 'записи', 'записей'),
          style: const TextStyle(color: Colors.black54),
        ),
      );
}
