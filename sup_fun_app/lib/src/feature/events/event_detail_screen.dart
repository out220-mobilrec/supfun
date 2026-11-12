import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../chat/chat_screen.dart';
import '../profile/user_profile_screen.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _event;
  List<EventParticipant>? _participants;
  bool _loading = true;
  String? _error;
  bool _busy = false;

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
      final j = await ApiClient.instance.get('/events/${widget.eventId}');
      final p = await ApiClient.instance
          .getList('/events/${widget.eventId}/participants');
      if (!mounted) return;
      setState(() {
        _event = Event.fromJson(j);
        _participants = p
            .map((e) => EventParticipant.fromJson(e))
            .toList();
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

  Future<void> _join(String status) async {
    setState(() => _busy = true);
    try {
      await ApiClient.instance
          .post('/events/${widget.eventId}/join', data: {'status': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Готово')));
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
    setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Отменить событие?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.delete('/events/${widget.eventId}');
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openChat() async {
    try {
      final convs = await ApiClient.instance.getList('/conversations');
      String? conversationId;
      for (final c in convs) {
        final m = c as Map<String, dynamic>;
        if (m['eventId'] == widget.eventId) {
          conversationId = m['id'] as String;
          break;
        }
      }
      conversationId ??= (await ApiClient.instance
              .post('/conversations',
                  data: {'type': 'event', 'eventId': widget.eventId}))['id']
          as String;
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conversationId!)));
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoading());
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorBanner(message: _error!, onRetry: _load),
      );
    }
    final e = _event!;
    final meId = Session.user.value?.id;
    final isOrganizer = e.organizerId == meId;
    final myParticipant = _participants?.where((p) => p.userId == meId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(e.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (e.photos.isNotEmpty)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(AppConfig.absUrl(e.photos.first), fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _statusChip(e.status),
                      const Spacer(),
                      if (e.maxParticipants != null)
                        Text('Участников: ${e.participantCount}/${e.maxParticipants}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(e.title,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (e.eventDate != null)
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_formatDate(e.eventDate!),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                  if (e.startPoint != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('${e.startLat!.toStringAsFixed(4)}, ${e.startLng!.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  if (e.waterBody != null)
                    Text('Водоём: ${e.waterBody!.name}',
                        style: const TextStyle(fontSize: 14, color: AppColors.secondary)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (e.level != null) Chip(label: Text('Уровень: ${_level(e.level!)}')),
                      if (e.expectedDistanceMeters != null)
                        Chip(label: Text('${e.expectedDistanceMeters} м')),
                      if (e.expectedDurationMinutes != null)
                        Chip(label: Text('~${e.expectedDurationMinutes} мин')),
                      Chip(label: Text(_access(e.access))),
                      Chip(label: Text(_visibility(e.visibility))),
                    ],
                  ),
                  if (e.description != null && e.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(e.description!,
                        style: const TextStyle(fontSize: 15, height: 1.4)),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppAvatar(e.organizer?.avatarUrl, size: 44),
                    title: Text(e.organizer?.name ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Организатор'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: e.organizerId))),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (isOrganizer) ...[
              SectionHeader('Участники (${_participants?.length ?? 0})'),
              ...?_participants?.map((p) => _participantTile(p)),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: isOrganizer ? _organizerBar(e) : _memberBar(myParticipant?.status),
        ),
      ),
    );
  }

  Widget _organizerBar(Event e) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: _busy ? null : _openChat,
          child: const Text('Чат события'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EventFormScreen(event: e))),
                child: const Text('Редактировать'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: _busy ? null : _cancel,
                child: const Text('Отменить'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _memberBar(String? myStatus) {
    final choices = <(String, String)>[
      ('going', 'Пойду'),
      ('maybe', 'Возможно'),
      ('not_going', 'Не пойду'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: choices
                    .map((c) => ButtonSegment(
                          value: c.$1,
                          label: Text(c.$2),
                        ))
                    .toList(),
                selected: {myStatus ?? (myStatus == null ? 'going' : 'going')},
                onSelectionChanged: (s) => _join(s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : _openChat, child: const Text('Чат события')),
      ],
    );
  }

  Widget _participantTile(EventParticipant p) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: AppAvatar(p.user?.avatarUrl, size: 36),
        title: Text(p.user?.name ?? ''),
        subtitle: Text(_statusLabel(p.status),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: p.userId))),
      ),
    );
  }

  Widget _statusChip(String s) {
    const map = {
      'scheduled': (AppColors.primary, 'Запланировано'),
      'on_water': (AppColors.accent, 'На воде'),
      'completed': (Colors.green, 'Завершено'),
      'cancelled': (AppColors.danger, 'Отменено'),
      'draft': (Colors.grey, 'Черновик'),
    };
    final (color, label) = map[s] ?? (Colors.grey, s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    const wd = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final m = months[d.month - 1];
    return '${wd[d.weekday - 1]}, ${d.day} $m · ${timeLabel(d)}';
  }

  String _level(String l) {
    const m = {'beginner': 'новичок', 'medium': 'средний', 'pro': 'профи'};
    return m[l] ?? l;
  }

  String _access(String? a) => a == 'invite' ? 'По приглашению' : 'Открытое';

  String _visibility(String? v) {
    const m = {'public': 'Публичное', 'friends': 'Для друзей', 'private': 'Приватное'};
    return m[v] ?? (v ?? '');
  }

  String _statusLabel(String s) {
    const m = {'going': 'Пойдёт', 'maybe': 'Возможно', 'not_going': 'Не пойдёт'};
    return m[s] ?? s;
  }
}