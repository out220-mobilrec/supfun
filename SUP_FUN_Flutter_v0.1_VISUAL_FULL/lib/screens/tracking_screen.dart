// GPS tracking screen during active trip
import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Duration _elapsed = Duration.zero;
  double _distance = 0.0; // km
  double _speed = 0.0; // km/h
  Timer? _timer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsed = _elapsed + const Duration(seconds: 1);
          // Simulate distance and speed
          _distance += 0.005;
          _speed = 4.5 + (DateTime.now().millisecond % 10) / 10;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Map placeholder (dark mode)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A3A3A), Color(0xFF0A1A1A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Map content
            CustomPaint(
              painter: _TrackingMapPainter(),
              child: Container(),
            ),
            // Top status bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _buildStatusBadge(),
                  const Spacer(),
                  _buildPauseButton(),
                ],
              ),
            ),
            // Bottom stats panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStatsPanel(),
            ),
            // Current location marker
            const Center(
              child: Icon(Icons.my_location,
                  color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('ЗАПИСЬ',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPauseButton() {
    return IconButton(
      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
      color: Colors.white,
      iconSize: 32,
      onPressed: () => setState(() => _isPaused = !_isPaused),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Время', _formatDuration(_elapsed)),
              _buildStat('Дистанция', '${_distance.toStringAsFixed(2)} км'),
              _buildStat('Скорость', '${_speed.toStringAsFixed(1)} км/ч'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                _timer?.cancel();
                Navigator.pushReplacementNamed(context, '/result');
              },
              icon: const Icon(Icons.stop),
              label: const Text('Завершить заплыв'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TrackingMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00A6A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.4,
          size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.6,
          size.width * 0.7, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.3,
          size.width * 0.9, size.height * 0.4);

    canvas.drawPath(path, paint);

    // Draw start and current points
    final startPaint = Paint()..color = Colors.green;
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.6), 8, startPaint);

    final currentPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.4), 8, currentPaint);
    final currentInner = Paint()..color = const Color(0xFF00A6A6);
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.4), 5, currentInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
