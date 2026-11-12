import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';
import '../tracks/track_detail_screen.dart';

class TrackCompleteResultScreen extends StatelessWidget {
  const TrackCompleteResultScreen({super.key, required this.result});

  final TrackCompleteResult result;

  @override
  Widget build(BuildContext context) {
    final t = result.track;
    final dist = t.distanceMeters >= 1000
        ? '${(t.distanceMeters / 1000).toStringAsFixed(2)} км'
        : '${t.distanceMeters.round()} м';
    final min = t.durationSeconds ~/ 60;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events,
                    size: 72, color: AppColors.accent),
                const SizedBox(height: 16),
                const Text('Заплыв завершён!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (result.award.points > 0)
                  Text('+${result.award.points} XP',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                const SizedBox(height: 24),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('Дистанция', dist),
                        Container(width: 1, height: 40, color: Colors.white12),
                        _stat('Время', '$min мин'),
                        Container(width: 1, height: 40, color: Colors.white12),
                        _stat('Средняя', '${t.avgSpeedKph.toStringAsFixed(1)} км/ч'),
                      ],
                    ),
                  ),
                ),
                if (result.award.unlocked.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ...result.award.unlocked.map(
                    (a) => Badge(
                      label: Text(a.icon ?? '🏆'),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(a.title),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TrackDetailScreen(trackId: t.id)),
                          (route) => false,
                        ),
                        child: const Text('Маршрут'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                        child: const Text('Готово'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}