// Профиль (ТЗ §16): уровень, статистика, маршруты, достижения, снаряжение,
// объявления, рейтинг, настройки.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/load_state.dart';
import '../controllers/profile_controller.dart';
import '../controllers/session_controller.dart';
import '../controllers/tracking_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'chats_list_screen.dart';
import 'events_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'track_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ProfileController>();
    final session = context.read<SessionController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.loadAll();
      await session.refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final controller = context.watch<ProfileController>();
    final user = session.user;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Загружаем профиль…'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await controller.loadAll();
        await session.refreshProfile();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          AppHeader(
            title: 'Профиль',
            unread: context.watch<NotificationsController>().unread,
            avatarUrl: user.avatarUrl,
            onNotifications: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                UserAvatar(name: user.name, url: user.avatarUrl, radius: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        [
                          user.displayCity,
                          if (user.role != UserRole.user) user.roleLabel,
                        ].where((s) => s.isNotEmpty).join(' • '),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Уровень ${session.level.level} • ${session.level.xp} XP',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                    child: StatTile(
                        label: 'Заплывы', value: '${controller.totalSwims}')),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        label: 'Километры',
                        value: num(controller.totalDistanceMeters / 1000))),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        label: 'Достижения',
                        value:
                            '${controller.unlockedAchievements}')),
              ],
            ),
          ),
          if (session.isOffline)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: OfflineHint(),
            ),
          const SectionTitle('Мой уровень'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LevelBar(level: session.level),
          ),
          _Section<Track>(
            title: 'Мои маршруты',
            section: controller.tracks,
            onRetry: controller.loadAll,
            emptyTitle: 'У вас пока нет маршрутов',
            emptySubtitle: 'Запишите первый заплыв — маршрут появится здесь',
            builder: (items) => [
              for (final track in items)
                RouteCard(
                  track: track,
                  showAuthor: false,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TrackScreen(trackId: track.id))),
                  trailing: track.isPublished
                      ? const Icon(Icons.public_rounded, size: 20)
                      : Text(track.statusLabel,
                          style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
          _Section<Achievement>(
            title: 'Достижения',
            section: controller.achievements,
            onRetry: controller.loadAll,
            emptyTitle: 'Достижений пока нет',
            builder: (items) => [
              SizedBox(
                height: 132,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final achievement in items)
                      _AchievementCard(achievement: achievement),
                  ],
                ),
              ),
            ],
          ),
          _Section<PointLogEntry>(
            title: 'Начисления',
            section: controller.points,
            onRetry: controller.loadAll,
            emptyTitle: 'Баллов пока нет',
            emptySubtitle: 'Завершите заплыв, чтобы получить первые',
            builder: (items) => [
              for (final entry in items.take(8))
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(entry.label),
                  subtitle: Text(relativeTimeLabel(entry.createdAt)),
                  trailing: Text('+${entry.points}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor)),
                ),
            ],
          ),
          _Section<GearItem>(
            title: 'Моё снаряжение',
            section: controller.gear,
            onRetry: controller.loadAll,
            emptyTitle: 'Снаряжение не добавлено',
            builder: (items) => [
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.surfing_rounded),
                  title: Text(item.title),
                  subtitle: Text(item.categoryLabel),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.calendar_month_rounded,
            title: 'Мои заплывы',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const EventsScreen())),
          ),
          _MenuTile(
            icon: Icons.forum_rounded,
            title: 'Сообщения',
            onTap: () async {
              final chats = context.read<ChatsController>();
              await chats.refresh();
              if (!context.mounted) return;
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ChatsListScreen()));
            },
          ),
          _MenuTile(
            icon: Icons.leaderboard_rounded,
            title: 'Рейтинг сообщества',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LeaderboardScreen())),
          ),
          _MenuTile(
            icon: Icons.notifications_none_rounded,
            title: 'Уведомления',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NotificationsScreen())),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Настройки и приватность',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SettingsScreen())),
          ),
          if (controller.totalSwims == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final tracking = context.read<TrackingController>();
                  final sent = await tracking.syncPendingRecordings();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(sent == 0
                          ? 'Нет несохранённых заплывов'
                          : 'Отправлено заплывов: $sent')));
                },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Досинхронизировать заплывы'),
              ),
            ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => session.logout(),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.section,
    required this.builder,
    this.onRetry,
    this.emptyTitle,
    this.emptySubtitle,
  });

  final String title;
  final Section<List<T>> section;
  final List<Widget> Function(List<T> items) builder;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) => SectionView<List<T>>(
        section: section,
        onRetry: onRetry,
        emptyTitle: emptyTitle ?? 'Пока пусто',
        emptySubtitle: emptySubtitle,
        builder: (items) => items.isEmpty
            ? EmptyView(
                title: emptyTitle ?? 'Пока пусто',
                subtitle: emptySubtitle,
                compact: true,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(title),
                  ...builder(items),
                ],
              ),
      );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) => Container(
        width: 132,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: achievement.unlocked ? Colors.white : const Color(0xFFF0F2F4),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 26)),
            const Spacer(),
            Text(
              achievement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: achievement.unlocked
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text('+${achievement.xp} XP',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

/// Рейтинг сообщества (ТЗ §18.4).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final ProfileController _controller;
  String _scope = 'all';

  @override
  void initState() {
    super.initState();
    _controller = context.read<ProfileController>();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _controller.loadLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Рейтинг')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Все')),
                ButtonSegment(value: 'friends', label: Text('Друзья')),
                ButtonSegment(value: 'week', label: Text('Неделя')),
              ],
              selected: {_scope},
              onSelectionChanged: (values) {
                setState(() => _scope = values.first);
                controller.loadLeaderboard(scope: _scope);
              },
            ),
          ),
          Expanded(
            child: SectionView<
                ({List<LeaderboardEntry> entries,
                LeaderboardEntry? me})>(
              section: controller.leaderboard,
              onRetry: () => controller.loadLeaderboard(scope: _scope),
              emptyTitle: 'Рейнг пустой',
              builder: (data) => ListView(
                children: [
                  for (final entry in data.entries)
                    ListTile(
                      leading: CircleAvatar(
                        child: Text('${entry.rank}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      title: Text(entry.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(entry.city ?? ''),
                      trailing: Text('${entry.xp} XP · ур. ${entry.level}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
