import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../waterbodies/waterbody_picker.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final Event? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.event?.title ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.event?.description ?? '');
  late final TextEditingController _duration = TextEditingController(
      text: widget.event?.expectedDurationMinutes?.toString() ?? '');
  late final TextEditingController _distance =
      TextEditingController(text: widget.event?.expectedDistanceMeters?.toString() ?? '');
  late final TextEditingController _max =
      TextEditingController(text: widget.event?.maxParticipants?.toString() ?? '');
  late final TextEditingController _startLat =
      TextEditingController(text: widget.event?.startLat?.toString() ?? '');
  late final TextEditingController _startLng =
      TextEditingController(text: widget.event?.startLng?.toString() ?? '');

  DateTime? _eventDate;
  static const _gearItems = ['Жилет', 'Буй', 'Аптечка', 'Свисток', 'Компас'];
  final Set<String> _gear = {};
  String? _level;
  String _visibility = 'public';
  String _access = 'open';
  WaterBody? _waterBody;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _waterBody = widget.event?.waterBody;
    _eventDate = widget.event?.eventDate;
    _level = widget.event?.level ?? 'beginner';
    _visibility = widget.event?.visibility ?? 'public';
    _access = widget.event?.access ?? 'open';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _duration.dispose();
    _distance.dispose();
    _max.dispose();
    _startLat.dispose();
    _startLng.dispose();
    super.dispose();
  }

  Future<void> _pickWaterBody() async {
    final wb = await showModalBottomSheet<WaterBody>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WaterbodyPickerSheet(),
    );
    if (wb != null) setState(() => _waterBody = wb);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() => _eventDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      setState(() => _error = 'Выберите дату события');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'eventDate': _eventDate!.toUtc().toIso8601String(),
        'level': _level,
        'visibility': _visibility,
        'access': _access,
        if (_startLat.text.isNotEmpty) 'startLat': double.tryParse(_startLat.text),
        if (_startLng.text.isNotEmpty) 'startLng': double.tryParse(_startLng.text),
        if (_waterBody != null) 'waterBodyId': _waterBody!.id,
        if (_duration.text.isNotEmpty) 'expectedDurationMinutes': int.tryParse(_duration.text),
        if (_distance.text.isNotEmpty) 'expectedDistanceMeters': int.tryParse(_distance.text),
        if (_max.text.isNotEmpty) 'maxParticipants': int.tryParse(_max.text),
      };
      if (widget.event == null) {
        await ApiClient.instance.post('/events', data: data);
      } else {
        await ApiClient.instance.patch('/events/${widget.event!.id}', data: data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Ошибка сети');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? 'Новое событие' : 'Редактировать')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'Название'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Укажите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(hintText: 'Описание'),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startLat,
                    decoration: const InputDecoration(hintText: 'Широта старта'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _startLng,
                    decoration: const InputDecoration(hintText: 'Долгота старта'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 10),
                    Text(_eventDate == null
                        ? 'Дата и время'
                        : '${_eventDate!.day}.${_eventDate!.month}.${_eventDate!.year} '
                            '${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2, '0')}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickWaterBody,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_waterBody?.name ?? 'Водоём (необязательно)')),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Уровень', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'beginner', label: Text('Новичок')),
                ButtonSegment(value: 'medium', label: Text('Средний')),
                ButtonSegment(value: 'pro', label: Text('Профи')),
              ],
              selected: {_level ?? 'beginner'},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Видимость', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('Публично')),
                ButtonSegment(value: 'friends', label: Text('Друзья')),
                ButtonSegment(value: 'private', label: Text('Приватно')),
              ],
              selected: {_visibility},
              onSelectionChanged: (s) => setState(() => _visibility = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Доступ', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Свободно')),
                ButtonSegment(value: 'invite', label: Text('По приглашению')),
              ],
              selected: {_access},
              onSelectionChanged: (s) => setState(() => _access = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    decoration: const InputDecoration(hintText: 'Длительность, мин'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _distance,
                    decoration: const InputDecoration(hintText: 'Дистанция, м'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _max,
                    decoration: const InputDecoration(hintText: 'Макс. участн.'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Чек-лист снаряжения (§36)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Отправляйтесь на воду только с подходящим снаряжением:',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _gearItems.map((g) => FilterChip(
                    label: Text(g),
                    selected: _gear.contains(g),
                    onSelected: (sel) => setState(() => sel
                        ? _gear.add(g)
                        : _gear.remove(g)),
                  )).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.event == null ? 'Создать' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}