import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.status});

  final String? status;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _status = 'scheduled';
  List<Event>? _events;
  bool _loading = true;
  String? _error;

  static const _filters = <String, String>{
    'scheduled': 'Запланированы',
    'on_water': 'На воде',
    'completed': 'Завершены',
    'mine': 'Мои',
  };

  @override
  void initState() {
    super.initState();
    if (widget.status != null && widget.status != 'all') {
      _status = widget.status!;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> list;
      if (_status == 'mine') {
        list = await ApiClient.instance.getList('/events/mine/going');
      } else if (_status == 'completed') {
        list = await ApiClient.instance
            .getList('/events', query: {'status': 'completed', 'limit': 50});
      } else {
        list = await ApiClient.instance
            .getList('/events', query: {'status': _status, 'limit': 50});
      }
      if (!mounted) return;
      setState(() {
        _events = list.map((e) => Event.fromJson(e)).toList();
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
      appBar: AppBar(
        title: const Text('События'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Создать событие',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EventFormScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.entries.map((e) {
                final selected = _status == e.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _status = e.key);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _body(),
      floatingActionButton: null,
    );
  }

  Widget _body() {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return ErrorBanner(message: _error!, onRetry: _load);
    }
    final events = _events ?? const [];
    if (events.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        text: 'Пока нет событий. Создайте первое!',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: events.length,
        itemBuilder: (_, i) => _EventCard(event: events[i]),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = event.eventDate;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: event.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (d != null)
                      Text('${d.day}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    if (d != null)
                      Text(_month(d.month),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    if (d != null)
                      Text('${timeLabel(d)} · ${event.organizer?.name ?? ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    if (event.waterBody != null)
                      Text(event.waterBody!.name,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.group_outlined,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text('${event.participantCount}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.secondary)),
                        if (event.level != null) ...[
                          const SizedBox(width: 10),
                          Text(_levelLabel(event.level!),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.5))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(String l) {
    const m = {'beginner': 'Новичок', 'medium': 'Средний', 'pro': 'Профи'};
    return m[l] ?? l;
  }

  String _month(int m) {
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return months[m - 1];
  }
}