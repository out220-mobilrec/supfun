// Экран активного трекинга (ТЗ §12): крупные цифры, крупные кнопки,
// высокий контраст, работа без сети и в landscape.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/feeds_refresh.dart';
import '../controllers/home_controller.dart';
import '../controllers/tracking_controller.dart';
import '../core/formatting.dart';
import '../services/track_store.dart';
import '../widgets/route_canvas.dart';
import 'result_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, this.resume});

  /// Если передан — продолжаем найденную незавершённую запись (ТЗ §12.5).
  final Recording? resume;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachResume());
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _attachResume() async {
    final recording = widget.resume;
    if (recording == null || _resumed) return;
    _resumed = true;
    final tracking = context.read<TrackingController>();
    if (tracking.phase != RecordingPhase.idle) return;
    await tracking.resumeRecording(recording);
  }

  Future<void> _stop() async {
    final tracking = context.read<TrackingController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить заплыв?'),
        content: Text(
          '${distanceLabel(tracking.distanceMeters)} • '
          '${clockLabel(tracking.elapsed)}\n'
          'Данные отправятся на сервер и начислятся баллы.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Продолжить')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Завершить')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final outcome = await tracking.finish();
    if (!mounted) return;
    // Финиш меняет серверные данные: трек, статистику, ленту.
    refreshHomeFeeds(context.read<HomeController>(), context.read<FeedController>());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(outcome: outcome)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingController>();
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF062D3B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('На воде'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _SyncPill(
                label: tracking.syncLabel,
                pending: tracking.pendingPoints,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _Metrics(tracking: tracking);
            final map = ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RouteCanvas(
                points: tracking.trail,
                dark: true,
              ),
            );
            if (isLandscape) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: metrics),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: Column(children: [
                      Expanded(child: map),
                      const SizedBox(height: 12),
                      _Controls(tracking: tracking, onStop: _stop),
                    ])),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  Expanded(flex: 4, child: metrics),
                  const SizedBox(height: 12),
                  Expanded(flex: 3, child: map),
                  const SizedBox(height: 12),
                  _Controls(tracking: tracking, onStop: _stop),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.tracking});

  final TrackingController tracking;

  @override
  Widget build(BuildContext context) {
    final paused = tracking.phase == RecordingPhase.paused;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          num(tracking.distanceMeters / 1000, 2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 78,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text('КМ',
            style: TextStyle(
                color: Colors.white54, letterSpacing: 4, fontSize: 13)),
        const SizedBox(height: 18),
        Text(clockLabel(tracking.elapsed),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 12,
          children: [
            _Metric(label: 'СКОРОСТЬ', value: speedLabel(tracking.currentSpeedKph)),
            _Metric(
                label: 'СР. СКОРОСТЬ', value: speedLabel(tracking.avgSpeedKph)),
            _Metric(label: 'МАКС', value: speedLabel(tracking.maxSpeedKph)),
            _Metric(label: 'ТОЧЕК', value: '${tracking.pointCount}'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tracking.hasFix ? Icons.gps_fixed : Icons.gps_off_rounded,
              size: 16,
              color: tracking.hasFix
                  ? const Color(0xFF4FD1D1)
                  : const Color(0xFFFFB400),
            ),
            const SizedBox(width: 6),
            Text(
              tracking.hasFix
                  ? 'GPS · точность ${num(tracking.accuracyMeters, 0)} м'
                  : 'Ищем спутники…',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        if (paused)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Пауза ${durationLabel(Duration(seconds: tracking.pausedSeconds))}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11, letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800),
          ),
        ],
      );
}

/// Кнопки нарочно крупные и далеко друг от друга (ТЗ §12.2).
class _Controls extends StatelessWidget {
  const _Controls({required this.tracking, required this.onStop});

  final TrackingController tracking;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final paused = tracking.phase == RecordingPhase.paused;
    final busy = tracking.isBusy;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => paused ? tracking.resume() : tracking.pause(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54, width: 1.4),
              padding: const EdgeInsets.symmetric(vertical: 22),
            ),
            icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 28),
            label: Text(
              paused ? 'Продолжить' : 'Пауза',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : () => onStop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              padding: const EdgeInsets.symmetric(vertical: 22),
            ),
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.stop_rounded, size: 28),
            label: Text(
              busy ? 'Сохраняем' : 'Стоп',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.label, required this.pending});

  final String label;
  final int pending;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          pending > 0 ? '$label · $pending' : label,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      );
}
