// Страница заплыва (ТЗ §9.5): описание, участники, реакция, чат, старт трекинга.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/events_controller.dart';
import '../controllers/feed_controller.dart';
import '../controllers/feeds_refresh.dart';
import '../controllers/home_controller.dart';
import '../controllers/session_controller.dart';
import '../core/formatting.dart';
import '../core/json_utils.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'chats_list_screen.dart';
import 'prestart_screen.dart';
import 'track_screen.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  late final EventsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<EventsController>();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _controller.loadDetail(widget.eventId));
  }

  /// Реакция на заплыв. Контроллеры читаем до await — после него
  /// пользоваться BuildContext нельзя.
  Future<void> _respond(String eventId, ParticipantStatus status) async {
    final home = context.read<HomeController>();
    final feed = context.read<FeedController>();
    final ok = await _controller.join(eventId, status);
    if (!mounted || !ok) return;
    await _controller.loadDetail(eventId);
    if (!mounted) return;
    refreshHomeFeeds(home, feed);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final session = context.watch<SessionController>();
    final event = controller.detail.data;
    final isOrganizer = event?.organizerId == session.user?.id;

    return Scaffold(
      appBar: AppBar(title: Text(event?.title ?? 'Заплыв')),
      body: SectionView<SupEvent>(
        section: controller.detail,
        onRetry: () => controller.loadDetail(widget.eventId),
        builder: (event) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              event.title,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                    icon: Icons.schedule_rounded,
                    text: eventWhenLabel(event.eventDate)),
                _Pill(icon: Icons.speed_rounded, text: event.levelLabel),
                _Pill(
                    icon: Icons.lock_outline,
                    text: switch (event.visibility) {
                      'private' => 'Приватный',
                      'friends' => 'Для друзей',
                      _ => 'Публичный',
                    }),
                if (event.status != EventStatus.scheduled)
                  _Pill(
                      icon: Icons.info_outline, text: event.statusLabel),
              ],
            ),
            const SizedBox(height: 18),
            _Facts(event: event),
            if (event.description != null) ...[
              const SectionTitle('Описание'),
              Text(event.description!),
            ],
            const SectionTitle('Участники'),
            SectionView<List<EventParticipant>>(
              section: controller.participants,
              onRetry: () => controller.loadDetail(widget.eventId),
              emptyTitle: 'Пока никто не записался',
              builder: (participants) => Column(
                children: [
                  for (final p in participants)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          UserAvatar(name: p.name, url: p.avatarUrl, radius: 18),
                      title: Text(p.name),
                      subtitle: Text(p.status.label),
                      trailing: p.userId == session.user?.id
                          ? const Icon(Icons.person_rounded, size: 18)
                          : null,
                    ),
                ],
              ),
            ),
            if ((controller.eventTracks.data ?? const []).isNotEmpty) ...[
              const SectionTitle('Треки участников'),
              for (final row in controller.eventTracks.data!)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  child: ListTile(
                    onTap: () {
                      final id = row['id']?.toString() ??
                          row['trackId']?.toString();
                      if (id == null) return;
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TrackScreen(trackId: id)));
                    },
                    title: Text(row['name']?.toString() ?? 'Трек'),
                    subtitle: Text(
                      '${row['userName'] ?? row['author'] ?? ''} • '
                      '${distanceLabel(asDouble(row['distanceMeters']))}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
            ],
            const SizedBox(height: 26),
            if (event.isUpcoming || isOrganizer) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PrestartScreen(
                    eventId: event.id,
                    eventTitle: event.title,
                  ),
                )),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('НАЧАТЬ ЗАПЛЫВ'),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        controller.busy ? null : () => _respond(event.id, ParticipantStatus.going),
                    child: const Padding(
                      padding: EdgeInsets.all(13),
                      child: Text('Иду'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () => _respond(event.id, ParticipantStatus.maybe),
                    child: const Padding(
                      padding: EdgeInsets.all(13),
                      child: Text('Может быть'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ChatsListScreen(openEventId: null))),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('ЧАТ ЗАПЛЫВА'),
            ),
            if (isOrganizer) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: controller.busy
                    ? null
                    : () async {
                        final cancelled = await controller.cancel(event.id);
                        if (!context.mounted) return;
                        if (cancelled) {
                          Navigator.of(context).pop();
                          refreshHomeFeeds(
                              context.read<HomeController>(),
                              context.read<FeedController>());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(controller.actionError ??
                                  'Не удалось отменить')));
                        }
                      },
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Отменить заплыв'),
              ),
            ],
            if (controller.actionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  controller.actionError!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.event});

  final SupEvent event;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            _row(context, 'Когда', eventWhenLabel(event.eventDate)),
            if (event.expectedDistanceMeters != null)
              _row(context, 'Дистанция',
                  distanceLabel(event.expectedDistanceMeters!)),
            if (event.expectedDurationMinutes != null)
              _row(context, 'В пути',
                  durationLabel(Duration(minutes: event.expectedDurationMinutes!))),
            if (event.waterBodyName != null)
              _row(context, 'Водоём', event.waterBodyName!),
            if (event.trackName != null)
              _row(context, 'Маршрут', event.trackName!),
            _row(
              context,
              'Участников',
              event.maxParticipants == null
                  ? '${event.participantCount}'
                  : '${event.participantCount} из ${event.maxParticipants}',
            ),
            if (event.organizerName != null)
              _row(context, 'Организатор', event.organizerName!),
          ],
        ),
      );

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
