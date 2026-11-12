// Создание заплыва (ТЗ §9.3 одиночный, §9.4 групповой).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/events_controller.dart';
import '../controllers/feeds_refresh.dart';
import '../controllers/feed_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/session_controller.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import 'event_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key, this.prefillFromTrack});

  final String? prefillFromTrack;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _distance = TextEditingController();
  final _duration = TextEditingController();
  final _maxParticipants = TextEditingController();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  String _level = 'beginner';
  String _visibility = 'public';
  String _access = 'open';
  bool _group = true;
  String? _waterBodyId;
  List<WaterBody> _waterBodies = const [];

  @override
  void initState() {
    super.initState();
    _maxParticipants.text = '10';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWaterBodies());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _distance.dispose();
    _duration.dispose();
    _maxParticipants.dispose();
    super.dispose();
  }

  Future<void> _loadWaterBodies() async {
    try {
      final api = context.read<SessionController>().api;
      final list = await api.waterbodies.list(limit: 200);
      if (mounted) setState(() => _waterBodies = list);
    } catch (_) {
      // список водоёмов не блокирует создание заплыва
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final controller = context.read<EventsController>();
    final when = DateTime(_date.year, _date.month, _date.day, _time.hour,
        _time.minute);
    final event = await controller.create({
      'title': _title.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      'eventDate': when.toUtc().toIso8601String(),
      'level': _level,
      'visibility': _visibility,
      'access': _access,
      if (_waterBodyId != null) 'waterBodyId': _waterBodyId,
      if (_prefillFromTrack != null) 'trackId': _prefillFromTrack,
      if (_distance.text.trim().isNotEmpty)
        'expectedDistanceMeters':
            (double.parse(_distance.text.trim()) * 1000).round(),
      if (_duration.text.trim().isNotEmpty)
        'expectedDurationMinutes': int.parse(_duration.text.trim()),
      if (_group && _maxParticipants.text.trim().isNotEmpty)
        'maxParticipants': int.parse(_maxParticipants.text.trim()),
    });
    if (!mounted) return;
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(controller.actionError ?? 'Не удалось создать заплыв')));
      return;
    }
    // Новый заплыв должен сразу появиться в лентах главного экрана.
    // Читаем контроллеры и запускаем обновление до pop(): после pop
    // это дерево уже неживое.
    refreshHomeFeeds(
        context.read<HomeController>(), context.read<FeedController>());
    Navigator.of(context)
      ..pop()
      ..push(MaterialPageRoute(builder: (_) => EventScreen(eventId: event.id)));
  }

  String? get _prefillFromTrack => widget.prefillFromTrack;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Новый заплыв')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            SwitchListTile(
              value: _group,
              onChanged: (value) => setState(() => _group = value),
              title: const Text('Групповой заплыв'),
              subtitle: Text(
                  _group ? 'Можно приглашать участников' : 'Только для себя'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Название', prefixIcon: Icon(Icons.title)),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Минимум 3 символа'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Описание', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                        '${_date.day}.${_date.month.toString().padLeft(2, '0')}.${_date.year}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _waterBodyId,
              decoration: const InputDecoration(
                labelText: 'Водоём',
                prefixIcon: Icon(Icons.waves_outlined),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Не указан')),
                for (final wb in _waterBodies)
                  DropdownMenuItem<String?>(
                      value: wb.id,
                      child: Text(wb.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _waterBodyId = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distance,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Дистанция, км'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'В пути, мин'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Уровень', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'beginner', label: Text('Начальный')),
                ButtonSegment(value: 'medium', label: Text('Средний')),
                ButtonSegment(value: 'pro', label: Text('Профи')),
              ],
              selected: {_level},
              onSelectionChanged: (v) => setState(() => _level = v.first),
            ),
            const SizedBox(height: 16),
            const Text('Видимость',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('Публичный')),
                ButtonSegment(value: 'friends', label: Text('Друзья')),
                ButtonSegment(value: 'private', label: Text('Приватный')),
              ],
              selected: {_visibility},
              onSelectionChanged: (v) => setState(() => _visibility = v.first),
            ),
            if (_group) ...[
              const SizedBox(height: 16),
              const Text('Допуск', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'open', label: Text('Свободный')),
                  ButtonSegment(value: 'invite', label: Text('По приглашению')),
                ],
                selected: {_access},
                onSelectionChanged: (v) => setState(() => _access = v.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxParticipants,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Максимум участников'),
              ),
            ],
            const SizedBox(height: 26),
            FilledButton(
              onPressed: controller.busy ? null : _submit,
              style:
                  FilledButton.styleFrom(padding: const EdgeInsets.all(18)),
              child: Text(controller.busy ? 'Создаём…' : 'СОЗДАТЬ ЗАПЛЫВ'),
            ),
            if (controller.actionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(controller.actionError!,
                    style: const TextStyle(color: AppTheme.errorColor)),
              ),
          ],
        ),
      ),
    );
  }
}
