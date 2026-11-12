import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/track_offline_store.dart';
import '../../services/track_sync_service.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../waterbodies/waterbody_picker.dart';
import 'track_complete_result_screen.dart';

enum _Stage { form, active, finishing }

const _kChecklistEnabled = 'sf_prestart_checklist';
const _kChecklistState = 'sf_prestart_checklist_state';

class _ChecklistItem {
  final String key;
  final String label;
  bool checked;
  _ChecklistItem(this.key, this.label, this.checked);
}

class TrackLiveScreen extends StatefulWidget {
  const TrackLiveScreen({super.key, this.eventId, this.resumeLocalId, this.routeId});

  final String? eventId;
  final int? resumeLocalId;
  final String? routeId;

  @override
  State<TrackLiveScreen> createState() => _TrackLiveScreenState();
}

class _TrackLiveScreenState extends State<TrackLiveScreen> with WidgetsBindingObserver {
  _Stage _stage = _Stage.form;

  // form / prestart
  final _name = TextEditingController();
  WaterBody? _waterBody;
  String? _routeId;
  String? _routeName;
  List<Map<String, dynamic>> _routes = const [];
  bool _loadingRoutes = false;
  String _difficulty = 'easy';
  bool _checklistEnabled = true;
  bool _loadingWeather = false;
  Map<String, dynamic>? _weather;
  final List<_ChecklistItem> _checklist = [
    _ChecklistItem('vest', 'Спасательный жилет', false),
    _ChecklistItem('leash', 'Лиш', false),
    _ChecklistItem('case', 'Телефон в гермокейсе', false),
    _ChecklistItem('water', 'Вода', false),
    _ChecklistItem('battery', 'Заряд телефона', false),
  ];

  // recording
  int? _localId;
  String? _serverId;
  LocalTrackRecord? _local;
  StreamSubscription<Position>? _sub;
  Timer? _flushTimer;
  Timer? _ticker;
  DateTime _started = DateTime.now();
  int _lastSeq = -1;
  double _distanceMeters = 0;
  double _maxSpeedKph = 0;
  double _currentSpeedKph = 0;
  double? _lastLat;
  double? _lastLng;
  bool _busy = false;
  String? _syncHint;

  final _store = TrackOfflineStore.instance;
  final _sync = TrackSyncService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initForegroundTask();
    _loadChecklistPrefs();
    if (widget.resumeLocalId != null) {
      _resume(widget.resumeLocalId!);
    }
  }

  void _initForegroundTask() {
    if (kIsWeb) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sup_fun_track',
        channelName: 'Запись заплыва',
        channelDescription: 'Уведомление активной записи GPS-трека',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    if (kIsWeb) return;
    try {
      // Android 13+: foreground-service notification requires runtime permission.
      try {
        final perm = await FlutterForegroundTask.checkNotificationPermission();
        if (perm != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      } catch (_) {}
      final running = await FlutterForegroundTask.isRunningService;
      if (running == true) return;
      await FlutterForegroundTask.startService(
        notificationTitle: 'SUP FUN',
        notificationText: 'GPS tracking active',
      );
    } catch (_) {}
  }

  Future<void> _stopForegroundService() async {
    if (kIsWeb) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _sub?.cancel();
    _flushTimer?.cancel();
    _ticker?.cancel();
    _stopForegroundService();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _persistProgress();
      if (_localId != null) _sync.trySyncRecording(_localId!);
    }
  }

  Future<void> _loadChecklistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kChecklistEnabled);
    final state = prefs.getStringList(_kChecklistState);
    if (!mounted) return;
    setState(() {
      _checklistEnabled = enabled ?? true;
      if (state != null) {
        final checked = state.toSet();
        for (final item in _checklist) {
          item.checked = checked.contains(item.key);
        }
      }
    });
  }

  Future<void> _saveChecklistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kChecklistEnabled, _checklistEnabled);
    await prefs.setStringList(
      _kChecklistState,
      _checklist.where((c) => c.checked).map((c) => c.key).toList(),
    );
  }

  Future<void> _loadRoutesForWaterbody(String waterBodyId) async {
    setState(() { _loadingRoutes = true; _routes = const []; _routeId = widget.routeId; _routeName = null; });
    try {
      final j = await ApiClient.instance.get('/routes', query: {'waterbodyId': waterBodyId, 'limit': '100'});
      final list = (j is List ? j : (j is Map && j['data'] is List ? j['data'] : <dynamic>[])) as List;
      final routes = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (mounted) setState(() { _routes = routes; _loadingRoutes = false; });
    } catch (_) {
      if (mounted) setState(() { _routes = const []; _loadingRoutes = false; });
    }
  }

  Future<void> _loadWeather(double lat, double lon) async {
    setState(() {
      _loadingWeather = true;
      _weather = null;
    });
    try {
      final j = await ApiClient.instance.get('/weather',
          query: {'lat': lat.toString(), 'lon': lon.toString()});
      if (mounted) setState(() => _weather = j);
    } catch (_) {
      if (mounted) setState(() => _weather = null);
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  Future<void> _resume(int localId) async {
    final local = await _store.getTrack(localId);
    if (local == null || !local.isUnfinished) {
      if (mounted) _snack('Запись не найдена');
      return;
    }
    final points = await _store.getAllPoints(localId);
    final last = points.isNotEmpty ? points.last : null;
    if (!mounted) return;
    setState(() {
      _localId = local.localId;
      _serverId = local.serverId;
      _local = local;
      _name.text = local.name ?? '';
      _difficulty = local.difficulty;
      _started = local.startedAt.toLocal();
      _lastSeq = local.lastSeq;
      _distanceMeters = local.distanceMeters;
      _lastLat = last?.lat;
      _lastLng = last?.lng;
      _stage = local.status == 'pending_complete' ? _Stage.finishing : _Stage.active;
    });
    if (local.status == 'pending_complete') {
      _finish(silent: true);
    } else {
      _beginTracking();
    }
  }

  Future<bool> _requestPermission() async {
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        _snack('Включите геолокацию');
        return false;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('Доступ к геолокации запрещён в настройках');
        return false;
      }
      return perm != LocationPermission.denied;
    } catch (_) {
      _snack('Не удалось запросить геолокацию');
      return false;
    }
  }

  Future<void> _start() async {
    final userId = Session.user.value?.id;
    if (userId == null) {
      _snack('Требуется авторизация');
      return;
    }
    await _saveChecklistPrefs();
    final ok = await _requestPermission();
    if (!ok) return;

    setState(() => _busy = true);
    final startedAt = DateTime.now();
    String? serverId;
    try {
      final j = await ApiClient.instance.post('/tracks', data: <String, dynamic>{
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        if (_waterBody != null) 'waterBodyId': _waterBody!.id,
        if (widget.eventId != null) 'eventId': widget.eventId,
        if ((widget.routeId ?? _routeId) != null) 'routeId': widget.routeId ?? _routeId,
        'difficulty': _difficulty,
        'startedAt': startedAt.toUtc().toIso8601String(),
      });
      serverId = j['id'] as String?;
    } on ApiException catch (e) {
      _snack('Сервер недоступен — запись сохранится на устройстве (${e.message})');
    } catch (_) {
      _snack('Нет связи — запись сохранится на устройстве');
    }

    final local = await _store.createTrack(
      userId: userId,
      serverId: serverId,
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      waterBodyId: _waterBody?.id,
      eventId: widget.eventId,
      routeId: widget.routeId ?? _routeId,
      difficulty: _difficulty,
      startedAt: startedAt,
    );
    if (!mounted) return;
    setState(() {
      _localId = local.localId;
      _serverId = local.serverId;
      _local = local;
      _started = startedAt;
      _lastSeq = -1;
      _distanceMeters = 0;
      _stage = _Stage.active;
      _busy = false;
    });
    _beginTracking();
  }

  void _beginTracking() {
    _ticker?.cancel();
    _flushTimer?.cancel();
    _sub?.cancel();
    _startForegroundService();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _flushTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_localId != null) _sync.trySyncRecording(_localId!);
      _refreshSyncHint();
    });
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((p) async {
      if (!mounted || _localId == null || _stage != _Stage.active) return;
      final speedKph = p.speed > 0 ? p.speed * 3.6 : null;
      setState(() {
        _currentSpeedKph = speedKph ?? 0;
        if ((_currentSpeedKph) > _maxSpeedKph) _maxSpeedKph = _currentSpeedKph;
      });
      if (_lastLat != null && _lastLng != null) {
        _distanceMeters += _haversine(_lastLat!, _lastLng!, p.latitude, p.longitude);
      }
      _lastLat = p.latitude;
      _lastLng = p.longitude;
      _lastSeq += 1;
      final point = LocalPointRecord(
        trackLocalId: _localId!,
        seq: _lastSeq,
        lat: p.latitude,
        lng: p.longitude,
        altitude: p.altitude.isNaN ? null : p.altitude,
        speedKph: speedKph,
        recordedAt: DateTime.now(),
      );
      await _store.insertPoint(point);
      await _persistProgress();
      if (mounted) setState(() {});
    }, onError: (e) {
      _snack('Ошибка GPS: $e');
    });
  }

  Future<void> _persistProgress() async {
    if (_localId == null) return;
    final elapsed = DateTime.now().difference(_started).inSeconds;
    await _store.updateTrackProgress(
      _localId!,
      lastSeq: _lastSeq,
      distanceMeters: _distanceMeters,
      durationSeconds: elapsed < 0 ? 0 : elapsed,
    );
  }

  Future<void> _refreshSyncHint() async {
    if (_localId == null) return;
    final n = await _store.unsentCount(_localId!);
    if (!mounted) return;
    setState(() {
      _syncHint = n > 0 ? 'Не отправлено точек: $n' : 'Синхронизировано';
    });
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  Future<void> _finish({bool silent = false}) async {
    if (_localId == null) return;
    _sub?.cancel();
    _flushTimer?.cancel();
    _ticker?.cancel();
    setState(() => _stage = _Stage.finishing);
    await _persistProgress();

    final res = await _sync.completeTrack(
      _localId!,
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      difficulty: _difficulty,
    );
    if (!mounted) return;
    if (res.ok && res.result != null) {
      await _stopForegroundService();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TrackCompleteResultScreen(result: res.result!)),
      );
      return;
    }
    setState(() => _stage = _Stage.active);
    if (!silent) {
      _snack(res.error ?? 'Не удалось завершить заплыв. Данные сохранены на устройстве.');
    } else {
      _snack(res.error ?? 'Синхронизация не удалась — попробуйте завершить снова.');
    }
    _beginTracking();
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить запись заплыва?'),
        content: const Text('Локальные данные и черновик на сервере (если создан) будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Оставить')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    _sub?.cancel();
    _flushTimer?.cancel();
    _ticker?.cancel();
    await _stopForegroundService();
    try {
      final serverId = _serverId ?? (await _store.getTrack(_localId ?? -1))?.serverId;
      if (serverId != null) {
        await ApiClient.instance.delete('/tracks/$serverId');
      }
    } catch (_) {}
    if (_localId != null) await _store.deleteTrack(_localId!);
    if (mounted) Navigator.pop(context, true);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_stage) {
      _Stage.form => _buildForm(),
      _Stage.active => _buildActive(),
      _Stage.finishing => const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Сохраняем и синхронизируем заплыв…'),
              ],
            ),
          ),
        ),
    };
    return WithForegroundTask(child: child);
  }

  Widget _buildForm() {
    return Scaffold(
      appBar: AppBar(title: const Text('Готовы к выходу?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _weatherCard(),
          const SizedBox(height: 12),
          if (_checklistEnabled) _checklistCard(),
          if (_checklistEnabled) const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показывать чек-лист', style: TextStyle(fontSize: 14)),
            value: _checklistEnabled,
            onChanged: (v) {
              setState(() => _checklistEnabled = v);
              _saveChecklistPrefs();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'Название заплыва (необязательно)'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final wb = await showModalBottomSheet<WaterBody>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const WaterbodyPickerSheet(),
              );
              if (wb != null) {
                setState(() { _waterBody = wb; _routeId = widget.routeId; _routeName = null; _routes = const []; });
                _loadRoutesForWaterbody(wb.id);
                if (wb.latitude != null && wb.longitude != null) {
                  _loadWeather(wb.latitude!, wb.longitude!);
                }
              }
            },
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
                  Expanded(child: Text(_waterBody?.name ?? 'Водоём (для погоды и привязки)')),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
          if (_waterBody != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _loadingRoutes
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _routes.any((r) => r['id'] == _routeId) ? _routeId : null,
                        hint: Text(_routes.isEmpty ? 'Route (optional)' : 'Route (optional)'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('No route')),
                          ..._routes.map((r) => DropdownMenuItem<String?>(
                                value: r['id'] as String?,
                                child: Text((r['name'] ?? 'Route').toString(), overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setState(() {
                          _routeId = v;
                          _routeName = v == null ? null : (_routes.firstWhere((r) => r['id'] == v, orElse: () => const {})['name'] as String?);
                        }),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'easy', label: Text('Лёгкий')),
              ButtonSegment(value: 'medium', label: Text('Средний')),
              ButtonSegment(value: 'hard', label: Text('Сложный')),
            ],
            selected: {_difficulty},
            onSelectionChanged: (s) => setState(() => _difficulty = s.first),
          ),
          const SizedBox(height: 8),
          const Text(
            'GPS-точки сохраняются на устройстве и отправляются при появлении сети.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: const Text('НАЧАТЬ ЗАПЛЫВ'),
          ),
        ],
      ),
    );
  }

  Widget _weatherCard() {
    final cs = Theme.of(context).colorScheme;
    if (_loadingWeather) {
      return Card(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [SizedProgress(), SizedBox(width: 12), Text('Загрузка погоды…')]),
        ),
      );
    }
    final w = _weather;
    if (w == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _waterBody == null
                ? 'Выберите водоём, чтобы увидеть погоду и условия'
                : (_waterBody!.latitude == null
                    ? 'У водоёма нет координат — погода недоступна'
                    : 'Не удалось загрузить погоду'),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    final current = (w['current'] as Map?)?.cast<String, dynamic>() ?? const {};
    final safety = w['safety'] as String? ?? 'normal';
    final reasons = (w['safetyReasons'] as List?)?.whereType<String>().join(' · ') ?? '';
    final temp = current['temperatureC'];
    final wind = current['windSpeedKph'];
    final gusts = current['windGustsKph'];
    final wave = current['waveHeightM'];
    Color safetyColor;
    String safetyLabel;
    switch (safety) {
      case 'danger':
        safetyColor = Colors.red;
        safetyLabel = 'Опасные условия';
        break;
      case 'caution':
        safetyColor = Colors.amber.shade800;
        safetyLabel = 'Повышенное внимание';
        break;
      default:
        safetyColor = Colors.green;
        safetyLabel = 'Условия благоприятные';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_outlined, color: safetyColor),
                const SizedBox(width: 8),
                Text('Погода', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
                const Spacer(),
                Text(safetyLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: safetyColor)),
              ],
            ),
            if (reasons.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(reasons, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _wMetric('Воздух', temp != null ? '${(temp as num).round()}°C' : '—'),
                _wMetric('Ветер', wind != null ? '${(wind as num).round()} км/ч' : '—'),
                _wMetric('Порывы', gusts != null ? '${(gusts as num).round()} км/ч' : '—'),
                _wMetric('Волна', wave != null ? '${(wave as num).toStringAsFixed(1)} м' : 'нет данных'),
              ],
            ),
            if (safety == 'danger') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Погодное предупреждение: выход на воду опасен',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _wMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _checklistCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Чек-лист', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
            ),
            ..._checklist.map((item) => CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label, style: const TextStyle(fontSize: 14)),
                  value: item.checked,
                  onChanged: (v) {
                    setState(() => item.checked = v ?? false);
                    _saveChecklistPrefs();
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildActive() {
    final elapsed = DateTime.now().difference(_started);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final km = _distanceMeters / 1000;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Идёт заплыв'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 62, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Время', style: TextStyle(fontSize: 13, color: Colors.white54)),
            const SizedBox(height: 12),
            Text(
              _serverId == null ? 'Нет связи — запись на устройстве' : (_syncHint ?? 'Запись идёт'),
              style: TextStyle(
                fontSize: 12,
                color: (_syncHint != null && _syncHint!.startsWith('Не отправлено'))
                    ? Colors.amberAccent
                    : Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _metric(km.toStringAsFixed(2), 'км'),
                _metric(_currentSpeedKph.toStringAsFixed(1), 'км/ч'),
                _metric(_maxSpeedKph.toStringAsFixed(1), 'макс км/ч'),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: _discard,
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                  onPressed: () => _finish(),
                  child: const Text('Завершить'),
                ),
              ],
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF008A74),
    );
  }

  Widget _metric(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class SizedProgress extends StatelessWidget {
  const SizedProgress({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
