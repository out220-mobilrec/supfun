// Центр уведомлений (ТЗ §26.1).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/profile_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<NotificationsController>();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _controller.refresh());
  }

  IconData _icon(String type) => switch (type) {
        'event' => Icons.calendar_month_rounded,
        'track' => Icons.route_rounded,
        'message' => Icons.forum_rounded,
        'achievement' => Icons.emoji_events_rounded,
        'friend' => Icons.person_add_alt_rounded,
        'moderation' => Icons.policy_outlined,
        _ => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (controller.unread > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: SectionView<List<AppNotification>>(
          section: controller.items,
          onRetry: controller.refresh,
          emptyTitle: 'Уведомлений нет',
          emptySubtitle: 'Здесь появятся ответы, заплывы и достижения',
          builder: (items) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final item in items)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.isRead
                        ? const Color(0xFFF0F2F4)
                        : AppTheme.primaryColor.withValues(alpha: .12),
                    child: Icon(_icon(item.type),
                        size: 20,
                        color: item.isRead
                            ? AppTheme.textSecondary
                            : AppTheme.primaryColor),
                  ),
                  title: Text(item.title,
                      style: TextStyle(
                        fontWeight:
                            item.isRead ? FontWeight.w500 : FontWeight.w800,
                      )),
                  subtitle: Text(
                    '${item.body ?? ''}\n${relativeTimeLabel(item.createdAt)}'
                        .trim(),
                  ),
                  isThreeLine: item.body != null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
