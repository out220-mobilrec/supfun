// Список заплывов (ТЗ §9.1): «Мои» и «Все», грядущие и завершённые.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/events_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'create_event_screen.dart';
import 'event_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.initialMy = true});

  final bool initialMy;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final EventsController _controller;
  bool _mine = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _mine = widget.initialMy;
    _controller = context.read<EventsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadMine();
      _controller.loadAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    final section = _mine ? controller.mine : controller.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заплывы'),
        bottom: TabBar(
          controller: _tabs,
          onTap: (index) => setState(() => controller.setShowCompleted(index == 1)),
          tabs: const [
            Tab(text: 'Предстоящие'),
            Tab(text: 'Завершённые'),
          ],
        ),
        actions: [
          SegmentedButton<bool>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: true, label: Text('Мои')),
              ButtonSegment(value: false, label: Text('Все')),
            ],
            selected: {_mine},
            onSelectionChanged: (values) => setState(() => _mine = values.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            Future.wait([controller.loadMine(), controller.loadAll()]),
        child: SectionView<List<SupEvent>>(
          section: section,
          onRetry: () => Future.wait(
              [controller.loadMine(), controller.loadAll()]),
          emptyTitle: _mine
              ? 'У вас пока нет заплывов'
              : 'Заплывов рядом нет',
          emptySubtitle: _mine
              ? 'Присоединитесь к чужому или создайте свой'
              : 'Создайте первый — к вам могут присоединиться',
          actionLabel: 'Создать заплыв',
          onAction: _create,
          builder: (events) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            children: [
              if (events.isEmpty)
                EmptyView(
                  title: _mine
                      ? 'У вас пока нет заплывов'
                      : 'Заплывов рядом нет',
                  subtitle: _mine
                      ? 'Присоединитесь к чужому или создайте свой'
                      : 'Создайте первый — к вам могут присоединиться',
                  actionLabel: 'Создать заплыв',
                  onAction: _create,
                ),
              for (final event in events)
                EventCard(
                  event: event,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EventScreen(eventId: event.id))),
                  trailing: _Countdown(date: event.eventDate),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Заплыв'),
      ),
    );
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const CreateEventScreen()));
    if (!mounted) return;
    await Future.wait([_controller.loadMine(), _controller.loadAll()]);
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Text(
        countdownLabel(date),
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      );
}
