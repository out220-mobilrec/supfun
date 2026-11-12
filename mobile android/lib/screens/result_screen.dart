// Результат заплыва (ТЗ §13): статистика, линия маршрута, награда,
// публикация. Если сети не было — честно говорим, что данные досинхронизируются.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/feeds_refresh.dart';
import '../controllers/home_controller.dart';
import '../controllers/session_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/route_canvas.dart';
import 'track_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.outcome});

  final ({Track track, AwardResult award, bool synced})? outcome;

  @override
  Widget build(BuildContext context) {
    final data = outcome;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Заплыв не завершён')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Запись не была начата. Вернитесь и нажмите «Начать заплыв».',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final track = data.track;
    final award = data.award;
    final duration = Duration(seconds: track.durationSeconds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заплыв завершён'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Готово',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF007F86), Color(0xFF004B72)],
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'ДИСТАНЦИЯ',
                  style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 1.4,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  distanceLabel(track.distanceMeters),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '${clockLabel(duration)} • ${speedLabel(track.avgSpeedKph)}',
                  style: const TextStyle(color: Colors.white),
                ),
                if (!data.synced)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.cloud_off_rounded,
                            color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Нет связи — заплыв сохранён на устройстве '
                            'и уйдёт на сервер при первой возможности',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: RouteCanvas(points: _pointsOf(track)),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              StatTile(label: 'Средняя скорость', value: speedLabel(track.avgSpeedKph)),
              StatTile(label: 'Максимальная', value: speedLabel(track.maxSpeedKph)),
              StatTile(label: 'Темп', value: paceLabel(track.avgSpeedKph)),
              StatTile(
                  label: 'Калории',
                  value: track.calories > 0 ? '${track.calories} ккал' : '—'),
              StatTile(
                  label: 'Набор высоты',
                  value: track.elevationGainMeters > 0
                      ? '${track.elevationGainMeters.round()} м'
                      : '—'),
              StatTile(
                  label: 'Сброс высоты',
                  value: track.elevationLossMeters > 0
                      ? '${track.elevationLossMeters.round()} м'
                      : '—'),
            ],
          ),
          const SectionTitle('Награда'),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: AppTheme.secondaryColor, size: 30),
                    const SizedBox(width: 12),
                    Text(
                      award.points > 0 ? '+${award.points} баллов' : 'Без баллов',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      'всего ${award.userXp} XP',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                if (award.unlocked.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Новое достижение!',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final achievement in award.unlocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(achievement.icon,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${achievement.title} · ${achievement.description}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text('+${achievement.xp}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryColor)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (data.synced && !track.isPublished)
            FilledButton.icon(
              onPressed: () => _publish(context, track.id),
              icon: const Icon(Icons.public_rounded),
              label: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('ОПУБЛИКОВАТЬ В СООБЩЕСТВО'),
              ),
            ),
          if (data.synced && track.isPublished)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => TrackScreen(trackId: track.id)),
              ),
              icon: const Icon(Icons.route_rounded),
              label: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('ОТКРЫТЬ МАРШРУТ'),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _share(context, track),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('ПОДЕЛИТЬСЯ'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('На главную'),
          ),
        ],
      ),
    );
  }

  List<GpsPoint> _pointsOf(Track track) => [
        for (var i = 0; i < track.routeLine.length; i++)
          if (track.routeLine[i].length >= 2)
            GpsPoint(
              seq: i,
              lng: track.routeLine[i][0],
              lat: track.routeLine[i][1],
              recordedAt: track.startedAt,
            ),
      ];

  Future<void> _publish(BuildContext context, String trackId) async {
    final session = context.read<SessionController>();
    final home = context.read<HomeController>();
    final feed = context.read<FeedController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.api.tracks.publish(trackId);
      // Опубликованный маршрут должен появиться в лентах сразу.
      refreshHomeFeeds(home, feed);
      messenger.showSnackBar(const SnackBar(
          content: Text('Маршрут отправлен на модерацию и появится в сообществе')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e is Exception ? '$e'.replaceFirst('ApiException: ', '') : 'Не удалось опубликовать')));
    }
  }

  Future<void> _share(BuildContext context, Track track) async {
    final session = context.read<SessionController>();
    final user = session.user?.name ?? 'Я';
    final text =
        '$user прошёл заплыв ${distanceLabel(track.distanceMeters)} '
        '(${clockLabel(Duration(seconds: track.durationSeconds))}) на SUP FUN';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скопировано в буфер обмена')));
  }
}
