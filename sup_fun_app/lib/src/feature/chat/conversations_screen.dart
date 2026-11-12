import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation>? _convs;
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
      final list = await ApiClient.instance.getList('/conversations');
      if (!mounted) return;
      setState(() {
        _convs = list.map((e) => Conversation.fromJson(e)).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Чаты')),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _convs!.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyState(
                              icon: Icons.forum_outlined,
                              text: 'Чатов пока нет'),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _convs!.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _ConversationCard(conv: _convs![i]),
                        ),
                ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conv});

  final Conversation conv;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selfId = Session.user.value?.id;
    final other = conv.otherParticipant(selfId ?? '');
    final title = conv.title ??
        other?.name ??
        (conv.type == 'event' ? 'Чат события' : 'Чат');
    final subtitle =
        conv.lastMessage?.content ?? conv.lastMessage?.type ?? 'Чат создан';
    final time = conv.lastMessageAt;
    final unread = conv.unreadCount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(conversationId: conv.id)));
          // refresh unread on return
          if (context.mounted) {
            _reload(context);
          }
        },
        leading: AppAvatar(other?.avatarUrl, size: 48),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              color: unread > 0
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.6),
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (time != null)
              Text(timeLabel(time),
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            if (unread > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text('$unread',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _reload(BuildContext context) {
    // triggers parent refresh through a callback registered by parent
    final s = context.findAncestorStateOfType<_ConversationsScreenState>();
    s?._load();
  }
}