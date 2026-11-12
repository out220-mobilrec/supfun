// Карточка маршрута (ТЗ §14.2): линия, статистика, автор, действия.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/api_client.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/route_canvas.dart';
import '../widgets/state_views.dart';
import 'prestart_screen.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, required this.trackId});

  final String trackId;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  Track? _track;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SessionController>().api;
      final track = await api.tracks.byId(widget.trackId);
      if (!mounted) return;
      setState(() {
        _track = track;
        _loading = false;
      });
      // Линия в профиле у трека может не прийти — дотягиваем точки.
      if (track.routeLine.isEmpty) {
        final points = await api.tracks.points(widget.trackId);
        if (!mounted) return;
        setState(() {
          _track = Track(
            id: track.id,
            userId: track.userId,
            authorName: track.authorName,
            name: track.name,
            status: track.status,
            difficulty: track.difficulty,
            waterBodyId: track.waterBodyId,
            waterBodyName: track.waterBodyName,
            eventId: track.eventId,
            distanceMeters: track.distanceMeters,
            durationSeconds: track.durationSeconds,
            avgSpeedKph: track.avgSpeedKph,
            maxSpeedKph: track.maxSpeedKph,
            elevationGainMeters: track.elevationGainMeters,
            elevationLossMeters: track.elevationLossMeters,
            calories: track.calories,
            startedAt: track.startedAt,
            endedAt: track.endedAt,
            routeLine: [
              for (final p in points) [p.lng, p.lat]
            ],
          );
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _publish(Track track) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = context.read<SessionController>().api;
      final updated = await api.tracks.publish(track.id);
      if (!mounted) return;
      setState(() => _track = updated);
      messenger.showSnackBar(
          const SnackBar(content: Text('Маршрут отправлен на модерацию')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    final session = context.watch<SessionController>();
    final isMine = track != null && track.userId == session.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(track?.title ?? 'Маршрут'),
        actions: [
          if (track != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'publish') return _publish(track);
                if (value == 'delete') {
                  final api = context.read<SessionController>().api;
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await api.tracks.remove(track.id);
                    navigator.pop();
                  } on ApiException catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              itemBuilder: (_) => [
                if (isMine && !track.isPublished)
                  const PopupMenuItem(value: 'publish', child: Text('Опубликовать')),
                if (isMine)
                  const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : track == null
                  ? const EmptyView(title: 'Маршрут не найден')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      children: [
                        SizedBox(
                          height: 240,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            child: RouteCanvas(points: _points(track)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          track.title,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${dayLabel(track.startedAt)} • '
                          '${track.authorName ?? 'Автор неизвестен'}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            StatusChip(text: track.statusLabel),
                            const SizedBox(width: 8),
                            StatusChip(text: track.difficultyLabel),
                            if (track.waterBodyName != null) ...[
                              const SizedBox(width: 8),
                              StatusChip(text: track.waterBodyName!),
                            ],
                          ],
                        ),
                        const SectionTitle('Статистика'),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.4,
                          children: [
                            StatTile(
                                label: 'Дистанция',
                                value: distanceLabel(track.distanceMeters)),
                            StatTile(
                                label: 'Время',
                                value: durationLabel(
                                    Duration(seconds: track.durationSeconds))),
                            StatTile(
                                label: 'Средняя',
                                value: speedLabel(track.avgSpeedKph)),
                            StatTile(
                                label: 'Максимальная',
                                value: speedLabel(track.maxSpeedKph)),
                            StatTile(
                                label: 'Темп',
                                value: paceLabel(track.avgSpeedKph)),
                            StatTile(
                                label: 'Высота',
                                value: track.elevationGainMeters > 0
                                    ? '+${track.elevationGainMeters.round()} м'
                                    : '—'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (isMine && !track.isPublished)
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _publish(track),
                            icon: const Icon(Icons.public_rounded),
                            label: const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text('ОПУБЛИКОВАТЬ'),
                            ),
                          ),
                        if (isMine && !track.isPublished) const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PrestartScreen()),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('ПОВТОРИТЬ МАРШРУТ'),
                          ),
                        ),
                      ],
                    ),
    );
  }

  List<GpsPoint> _points(Track track) => [
        for (var i = 0; i < track.routeLine.length; i++)
          if (track.routeLine[i].length >= 2)
            GpsPoint(
              seq: i,
              lng: track.routeLine[i][0],
              lat: track.routeLine[i][1],
              recordedAt: track.startedAt,
            ),
      ];
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}
