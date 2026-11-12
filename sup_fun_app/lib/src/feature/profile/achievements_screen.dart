import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement>? _achievementsList;
  LevelInfo? _level;
  List<PointLog>? _pointsList;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await ApiClient.instance.getList('/gamification/achievements');
      final l = await ApiClient.instance.get('/gamification/me');
      final p = await ApiClient.instance.getList('/gamification/points');
      if (!mounted) return;
      setState(() {
        _achievementsList = a.map((e) => Achievement.fromJson(e)).toList();
        _level = LevelInfo.fromJson(l);
        _pointsList = p.map((e) => PointLog.fromJson(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ошибка сети');
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Достижения'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Достижения'),
            Tab(text: 'История очков'),
          ]),
        ),
        body: _loading
            ? const AppLoading()
            : _error != null
                ? ErrorBanner(message: _error!, onRetry: _load)
                : TabBarView(children: [
                    _achievements(_achievementsList ?? const []),
                    _points(_pointsList ?? const []),
                  ]),
      ),
    );
  }

  Widget _achievements(List<Achievement> list) {
    final unlocked = list.where((a) => a.unlocked).length;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Получено: $unlocked из ${list.length}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: list.isEmpty ? 0 : unlocked / list.length,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ),
        ),
        ...list.map(_achievementTile),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _achievementTile(Achievement a) {
    final cs = Theme.of(context).colorScheme;
    final done = a.unlocked;
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: done
                ? AppColors.accent.withValues(alpha: 0.18)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(a.icon ?? '🏆', style: const TextStyle(fontSize: 24))),
        ),
        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.description, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text('+${a.xp} XP', style: TextStyle(fontSize: 12, color: AppColors.accent)),
          ],
        ),
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.lock_outline, color: cs.onSurface.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _points(List<PointLog> list) {
    if (_level != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _levelCard(_level!),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  leading: const Icon(Icons.bolt, color: AppColors.accent),
                  title: Text(p.actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.refType != null) Text(p.refType!),
                      if (p.createdAt != null)
                        Text('${dayLabel(p.createdAt!)} ${timeLabel(p.createdAt!)}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Text('+${p.points}',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w800, fontSize: 16)),
                );
              },
            ),
          ),
        ],
      );
    }
    return const AppLoading();
  }

  Widget _levelCard(LevelInfo l) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Уровень ${l.level}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('${l.xp} XP', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: l.progress,
                minHeight: 10,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 8),
            Text('${l.nextLevelXp} XP до уровня ${l.level + 1}',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}