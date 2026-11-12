import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/track_offline_store.dart';
import '../../services/track_sync_service.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import 'track_complete_result_screen.dart';
import 'track_detail_screen.dart';
import 'track_live_screen.dart';

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  List<Track>? _tracks;
  bool _loading = true;
  String? _error;
  LocalTrackRecord? _unfinished;
  int _unsent = 0;
  bool _recoverBusy = false;

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
    await _checkUnfinished();
    try {
      final list = await ApiClient.instance.getList('/tracks/mine');
      if (!mounted) return;
      setState(() {
        _tracks = list.map((e) => Track.fromJson(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ошибка сети');
    }
  }

  Future<void> _checkUnfinished() async {
    final uid = Session.user.value?.id;
    if (uid == null) return;
    final u = await TrackOfflineStore.instance.findUnfinished(uid);
    int unsent = 0;
    if (u != null) unsent = await TrackOfflineStore.instance.unsentCount(u.localId);
    if (!mounted) return;
    setState(() {
      _unfinished = u;
      _unsent = unsent;
    });
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _loading = false;
    });
  }

  Future<void> _openLive({int? resumeLocalId}) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => TrackLiveScreen(resumeLocalId: resumeLocalId)));
    if (mounted) _load();
  }

  Future<void> _finishUnfinished() async {
    final u = _unfinished;
    if (u == null) return;
    setState(() => _recoverBusy = true);
    final res = await TrackSyncService.instance.completeTrack(
      u.localId,
      name: u.name,
      difficulty: u.difficulty,
    );
    if (!mounted) return;
    setState(() => _recoverBusy = false);
    if (res.ok && res.result != null) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => TrackCompleteResultScreen(result: res.result!)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.error ?? 'Не удалось завершить. Данные сохранены на устройстве.')));
    }
    _load();
  }

  Future<void> _discardUnfinished() async {
    final u = _unfinished;
    if (u == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить незавершённый заплыв?'),
        content: const Text('Локальные точки будут удалены. Черновик на сервере (если есть) тоже удалится.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Оставить')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (u.serverId != null) {
        await ApiClient.instance.delete('/tracks/${u.serverId}');
      }
    } catch (_) {}
    await TrackOfflineStore.instance.deleteTrack(u.localId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заплывы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openLive(),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (_unfinished != null) _recoveryBanner(),
                      if ((_tracks ?? []).isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: EmptyState(
                              icon: Icons.waves,
                              text: 'Пока нет заплывов. Начните первый!'),
                        )
                      else
                        ..._tracks!.map((t) => _TrackCard(track: t)),
                    ],
                  ),
                ),
    );
  }

  Widget _recoveryBanner() {
    final u = _unfinished!;
    final title = u.status == 'pending_complete'
        ? 'Заплыв ожидает отправки'
        : 'Найден незавершённый заплыв';
    final sub = _unsent > 0 ? 'Не отправлено точек: $_unsent' : 'Данные сохранены на устройстве';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (u.status == 'recording')
                  FilledButton(
                    onPressed: _recoverBusy ? null : () => _openLive(resumeLocalId: u.localId),
                    child: const Text('Продолжить'),
                  ),
                FilledButton.tonal(
                  onPressed: _recoverBusy ? null : _finishUnfinished,
                  child: _recoverBusy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Завершить и сохранить'),
                ),
                TextButton(
                  onPressed: _recoverBusy ? null : _discardUnfinished,
                  child: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dist = track.distanceMeters >= 1000
        ? '${(track.distanceMeters / 1000).toStringAsFixed(1)} км'
        : '${track.distanceMeters.round()} м';
    final dur = track.durationSeconds >= 60
        ? '${track.durationSeconds ~/ 60} мин'
        : '${track.durationSeconds} с';
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => TrackDetailScreen(trackId: track.id))),
        leading: const Icon(Icons.waves, color: AppColors.primary, size: 28),
        title: Text(track.name ?? 'Заплыв'),
        subtitle: Text(
            '$dist · $dur · ${_status(track.status)}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _status(String? s) {
    const m = {
      'draft': 'черновик',
      'private': 'приватный',
      'moderation': 'на модерации',
      'published': 'опубликован',
      'hidden': 'скрыт',
    };
    return m[s] ?? s ?? '';
  }
}
