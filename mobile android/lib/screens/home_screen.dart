// Главный экран (ТЗ §6): шапка, герой, быстрый старт, условия, ближайшие
// заплывы, статистика, активность. Material-иконки вместо эмодзи.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/load_state.dart';
import '../controllers/session_controller.dart';
import '../controllers/tracking_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'create_event_screen.dart';
import 'event_screen.dart';
import 'events_screen.dart';
import 'notifications_screen.dart';
import 'prestart_screen.dart';
import 'resume_swim_sheet.dart';

// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final tracking = context.read<TrackingController>();
    unawaited(tracking.refreshPendingSummary());
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    final home = context.read<HomeController>();
    final feed = context.read<FeedController>();
    await Future.wait([
      home.refreshAll(),
      feed.refresh(),
    ]);
  }

  void _openEvent(String eventId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EventScreen(eventId: eventId)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final home = context.watch<HomeController>();
    final feed = context.watch<FeedController>();
    final tracking = context.watch<TrackingController>();
    final user = session.user;
    final next = home.nextOwnEvent ?? home.nextNearbyEvent;
    final pending = tracking.pendingCount;
    final name = user?.name.split(' ').first ?? 'серфер';
    final city = user?.city ?? 'Хабаровск';

    final myTracks = home.myTracks.data ?? const <Track>[];
    final totalSwims = myTracks.where((t) => t.status == TrackStatus.published).length;
    final totalKm = myTracks.fold<double>(0, (s, t) => s + t.distanceMeters) / 1000;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // ─── SliverAppBar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: user?.avatarUrl != null
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Привет, $name!',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 2),
                              Text(
                                city,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 16, right: 8),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Badge(
                  isLabelVisible: session.level.level > 0,
                  label: Text('${session.level.level}'),
                  child: const Icon(Icons.workspace_premium, size: 20),
                ),
              ),
            ],
          ),

          // ─── Body ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Оффлайн / очередь / продолжить
                  if (session.isOffline)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: OfflineHint(),
                    ),
                  if (pending > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OfflineHint(
                        text: 'Записей в очереди: $pending',
                        actionLabel: 'Отправить',
                        onAction: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final sent = await tracking.syncPendingRecordings();
                          messenger.showSnackBar(
                              SnackBar(
                                  content: Text('Отправлено заплывов: $sent')));
                        },
                      ),
                    ),
                  if (tracking.resumeCandidate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        onPressed: () => showResumeSwimSheet(
                            context, tracking.resumeCandidate!),
                        icon: const Icon(Icons.history_rounded),
                        label: const Text(
                            'Есть незавершённая запись — продолжить'),
                      ),
                    ),

                  // ─── Hero: ближайший заплыв ───────────────────────
                  if (next != null) ...[
                    EventHeroCard(
                      event: next,
                      onTap: () => _openEvent(next.id),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── Быстрый старт (ТЗ §6.3) ──────────────────────
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PrestartScreen())),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text(
                      'НАЧАТЬ ЗАПЛЫВ',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const CreateEventScreen())),
                          icon: const Icon(Icons.event_rounded),
                          label: const Text('Создать заплыв'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const EventsScreen())),
                          icon: const Icon(Icons.explore_rounded),
                          label: const Text('Найти заплыв'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Условия (ТЗ §6.4, погода) ────────────────────
                  // На сервере нет погоды — показываем статистику
                  // в стиле погодной карточки из макета.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radius),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.wb_sunny,
                            color: AppTheme.sunnyColor, size: 48),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalKm км',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                              Text(
                                'Ваше расстояние • $totalSwims заплывов',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                              Text(
                                'Продолжай тренироваться, $name!',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Ближайшие заплывы (горизонтальная карусель) ──
                  _UpcomingEvents(
                    events: home.nearbyEvents,
                    onOpen: _openEvent,
                  ),
                  const SizedBox(height: 16),

                  // ─── Быстрая статистика ───────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.waves,
                          label: 'Всего заплывов',
                          value: '$totalSwims',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.route,
                          label: 'Расстояние',
                          value: '$totalKm км',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Активность друзей ────────────────────────────
                  _ActivityFeed(feed: feed),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ближайшие заплывы ────────────────────────────────────────────────────

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({
    required this.events,
    required this.onOpen,
  });

  final Section<List<SupEvent>> events;
  final void Function(String) onOpen;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ближайшие заплывы',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const EventsScreen())),
                child: const Text('Все'),
              ),
            ],
          ),
          SizedBox(
            height: 140,
            child: SectionView<List<SupEvent>>(
              section: events,
              emptyTitle: 'Заплывов не найдено',
              builder: (list) => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 4),
                itemCount: list.length,
                itemBuilder: (_, index) => SizedBox(
                  width: 180,
                  child: _EventCard(
                    event: list[index],
                    onTap: () => onOpen(list[index].id),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final SupEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.access == 'open'
                      ? 'Открытый'
                      : 'Закрытый',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                event.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${event.eventDate.day} ${monthLabel(event.eventDate.month)}, ${event.eventDate.hour}:${event.eventDate.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${event.participantCount}/${event.maxParticipants ?? '?' }',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

String monthLabel(int m) => ['янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'][m - 1];

// ─── Быстрая статистика ───────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
}

// ─── Активность друзей ────────────────────────────────────────────────────

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.feed});

  final FeedController feed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Активность друзей',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SectionView<List<Post>>(
            section: feed.posts,
            emptyTitle: 'Активности пока нет',
            emptySubtitle: 'Друзья начнут делиться результатами',
            builder: (posts) => Column(
              children: [
                for (final post in posts)
                  _ActivityItem(
                    author: post.authorName,
                    title: post.typeLabel,
                    subtitle: post.title ?? post.body ?? 'Новый результат',
                    time: post.createdAt,
                  ),
              ],
            ),
          ),
        ],
      );
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.author,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final String author;
  final String title;
  final String subtitle;
  final DateTime time;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.secondaryColor,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$author $title',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  Text(relativeTimeLabel(time),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}
