// Список чатов (ТЗ §20.1): личные, групповые, чаты заплывов и сделок.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key, this.openEventId});

  /// Если задан — сразу открываем чат этого заплыва, когда он найдётся.
  final String? openEventId;

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  late final ChatsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ChatsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _controller.refresh();
    final eventId = widget.openEventId;
    if (eventId == null || !mounted) return;
    final chat = (_controller.conversations.data ?? const [])
        .where((c) => c.eventId == eventId)
        .firstOrNull;
    if (chat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Чат заплыва ещё не создан')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
            conversationId: chat.id, title: chat.title ?? 'Чат заплыва')));
  }

  String _title(ConversationSummary conversation) {
    if (conversation.title != null && conversation.title!.isNotEmpty) {
      return conversation.title!;
    }
    final others = conversation.participants
        .map((p) => p.name)
        .where((name) => name.isNotEmpty)
        .toList();
    return others.isEmpty ? 'Чат' : others.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: SectionView<List<ConversationSummary>>(
          section: controller.conversations,
          onRetry: controller.refresh,
          emptyTitle: 'Сообщений пока нет',
          emptySubtitle: 'Чаты появляются в заплывах и сделках',
          builder: (conversations) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (_, index) {
              final conversation = conversations[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE0E6E9)),
                ),
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                          conversationId: conversation.id,
                          title: _title(conversation)))),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        name: _title(conversation),
                        radius: 24,
                        url: conversation.participants.isEmpty
                            ? null
                            : conversation.participants.first.avatarUrl,
                      ),
                      if (conversation.unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: Theme.of(context).colorScheme.error,
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    _title(conversation),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    conversation.lastMessageText ?? conversation.typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: conversation.lastMessageAt == null
                      ? null
                      : Text(
                          relativeTimeLabel(conversation.lastMessageAt!),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
