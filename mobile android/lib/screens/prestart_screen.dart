// Предстартовый экран (ТЗ §11): проверка GPS, параметры заплыва, чек-лист.
//
// Погодного эндпоинта на сервере нет, поэтому вместо погоды — состояние
// GPS и предупреждение, если чек-лист не отмечен: выход на воду без
// жилета опаснее, чем без прогноза.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../controllers/tracking_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../services/app_storage.dart';
import '../services/geo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import 'tracking_screen.dart';

class PrestartScreen extends StatefulWidget {
  const PrestartScreen({super.key, this.eventId, this.eventTitle});

  final String? eventId;
  final String? eventTitle;

  @override
  State<PrestartScreen> createState() => _PrestartScreenState();
}

class _PrestartScreenState extends State<PrestartScreen> {
  final _storage = AppStorage.instance;
  final _name = TextEditingController();

  late List<String> _checklist;
  final Set<String> _done = {};
  TrackDifficulty _difficulty = TrackDifficulty.easy;
  String? _waterBodyId;

  List<WaterBody> _waterBodies = const [];
  bool _loadingWaterBodies = false;
  String? _gpsStatus;
  bool _gpsOk = false;
  bool _checkingGps = false;

  @override
  void initState() {
    super.initState();
    _checklist = _storage.checklist;
    _name.text = widget.eventTitle ?? 'Заплыв ${dayLabel(DateTime.now())}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWaterBodies();
      _checkGps();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadWaterBodies() async {
    setState(() => _loadingWaterBodies = true);
    try {
      final api = context.read<SessionController>().api;
      _waterBodies = await api.waterbodies.list(limit: 200);
    } catch (_) {
      _waterBodies = const [];
    } finally {
      if (mounted) setState(() => _loadingWaterBodies = false);
    }
  }

  Future<void> _checkGps() async {
    setState(() {
      _checkingGps = true;
      _gpsStatus = null;
    });
    final result = await const GeoService().ensurePermission();
    if (!mounted) return;
    setState(() {
      _checkingGps = false;
      _gpsOk = result.isOk;
      _gpsStatus = result.isOk
          ? 'Геолокация разрешена — трекинг готов к запуску'
          : result.message;
    });
  }

  Future<void> _start() async {
    if (!_gpsOk) {
      await _checkGps();
      if (!_gpsOk || !mounted) return;
    }
    final tracking = context.read<TrackingController>();
    final started = await tracking.start(
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      waterBodyId: _waterBodyId,
      eventId: widget.eventId,
      difficulty: _difficulty,
    );
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tracking.permissionMessage ??
              'Не удалось начать запись')));
      return;
    }
    final navigator = Navigator.of(context);
    await _storage.setChecklistDone(_done.toList());
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const TrackingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missingChecks = _checklist.length - _done.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Перед выходом')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Готовы к выходу?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _GpsTile(
            ok: _gpsOk,
            checking: _checkingGps,
            message: _gpsStatus,
            onCheck: _checkGps,
          ),
          const SectionTitle('Параметры заплыва'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Название',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Сложность',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<TrackDifficulty>(
            segments: [
              for (final value in TrackDifficulty.values)
                ButtonSegment(value: value, label: Text(value.label)),
            ],
            selected: {_difficulty},
            onSelectionChanged: (values) =>
                setState(() => _difficulty = values.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _waterBodyId,
            decoration: const InputDecoration(
              labelText: 'Водоём (необязательно)',
              prefixIcon: Icon(Icons.waves_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Не привязывать')),
              for (final wb in _waterBodies)
                DropdownMenuItem<String?>(
                  value: wb.id,
                  child: Text(wb.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _loadingWaterBodies
                ? null
                : (value) => setState(() => _waterBodyId = value),
          ),
          if (widget.eventId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Row(
                children: [
                  Icon(Icons.groups_rounded, color: AppTheme.primaryColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Заплыв будет привязан к событию — трек увидят участники.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SectionTitle('Чек-лист'),
          for (final item in _checklist)
            CheckboxListTile(
              value: _done.contains(item),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _done.add(item);
                } else {
                  _done.remove(item);
                }
              }),
              title: Text(item),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          if (missingChecks > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                'Отмечено не всё: $missingChecks. Это можно сделать и на воде.',
                style: const TextStyle(
                    color: AppTheme.warningColor, fontSize: 13),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _checkingGps ? null : _start,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: AppTheme.successColor,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text(
              'НАЧАТЬ ЗАПЛЫВ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsTile extends StatelessWidget {
  const _GpsTile({
    required this.ok,
    required this.checking,
    required this.message,
    required this.onCheck,
  });

  final bool ok;
  final bool checking;
  final String? message;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(
              ok ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              color: ok ? AppTheme.successColor : AppTheme.warningColor,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message ?? 'Проверяем геолокацию…',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: checking ? null : onCheck,
              child: const Text('Проверить'),
            ),
          ],
        ),
      );
}
