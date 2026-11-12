import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';

class TrackDetailScreen extends StatefulWidget {
  const TrackDetailScreen({super.key, required this.trackId});

  final String trackId;

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  Track? _track;
  bool _loading = true;
  String? _error;
  bool _busy = false;

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
      final j = await ApiClient.instance.get('/tracks/${widget.trackId}');
      if (!mounted) return;
      setState(() {
        _track = Track.fromJson(j);
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

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      final j = await ApiClient.instance.post('/tracks/${widget.trackId}/publish');
      if (!mounted) return;
      setState(() {
        _track = Track.fromJson(j);
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Маршрут опубликован')));
    } on ApiException catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить заплыв?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.delete('/tracks/${widget.trackId}');
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: AppLoading());
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(), body: ErrorBanner(message: _error!, onRetry: _load));
    }
    final t = _track!;
    final isOwner = t.userId == Session.user.value?.id;
    return Scaffold(
      appBar: AppBar(title: Text(t.name ?? 'Заплыв')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF00A389)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Icon(Icons.waves, size: 72, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          _row('Дистанция', _distLabel(t.distanceMeters)),
          _row('Время', '${t.durationSeconds ~/ 60} мин'),
          _row('Средняя скорость', '${t.avgSpeedKph.toStringAsFixed(1)} км/ч'),
          _row('Макс. скорость', '${t.maxSpeedKph.toStringAsFixed(1)} км/ч'),
          if (t.elevationGainMeters > 0)
            _row('Набор высоты', '${t.elevationGainMeters.toStringAsFixed(0)} м'),
          if (t.calories > 0) _row('Калории', '${t.calories}'),
          if (t.waterBody != null) _row('Водоём', t.waterBody!.name),
          if (t.routeName != null) _row('Маршрут', t.routeName!),
          if (t.difficulty != null) _row('Сложность', _difficulty(t.difficulty!)),
          const SizedBox(height: 24),
          if (isOwner && t.status == 'private')
            FilledButton(
              onPressed: _busy ? null : _publish,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Опубликовать маршрут'),
            ),
          if (isOwner && t.status == 'published')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Маршрут опубликован',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            ),
          if (isOwner)
            TextButton(
              onPressed: _delete,
              child: const Text('Удалить', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _distLabel(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(2)} км'
      : '${m.round()} м';

  String _difficulty(String d) {
    const m = {'easy': 'лёгкий', 'medium': 'средний', 'hard': 'сложный'};
    return m[d] ?? d;
  }
}