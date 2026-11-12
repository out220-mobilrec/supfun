import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../chat/chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
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
      final list = await ApiClient.instance.getList('/notifications', query: {'limit': 50});
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => AppNotification.fromJson(e)).toList();
        _loading = false;
      });
      await ApiClient.instance.post('/notifications/read');
      if (mounted) {
        context.read<AppState>().resetUnread();
      }
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

  void _open(AppNotification n) {
    final conversationId = n.data?['conversationId'] as String?;
    if (conversationId != null && n.type == 'message') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conversationId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items!.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyState(
                              icon: Icons.notifications_none,
                              text: 'Уведомлений пока нет'),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _items!.length,
                          itemBuilder: (_, i) {
                            final n = _items![i];
                            return ListTile(
                              onTap: n.type == 'message' ? () => _open(n) : null,
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: n.isRead
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                      : AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_icon(n.type),
                                    color: n.isRead
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : AppColors.primary,
                                    size: 22),
                              ),
                              title: Text(n.title ?? '',
                                  style: TextStyle(
                                      fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600)),
                              subtitle: Text(n.body ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                              trailing: n.createdAt != null
                                  ? Text(timeLabel(n.createdAt!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11))
                                  : null,
                            );
                          },
                        ),
                ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'message':
        return Icons.message;
      case 'friend_request':
      case 'friend_accepted':
        return Icons.person_add;
      case 'achievement':
        return Icons.emoji_events;
      case 'event_invite':
      case 'event_joined':
      case 'event_reminder':
        return Icons.event;
      case 'marketplace':
        return Icons.storefront;
      case 'news':
        return Icons.newspaper;
      case 'weather':
        return Icons.wb_sunny;
      default:
        return Icons.notifications;
    }
  }
}