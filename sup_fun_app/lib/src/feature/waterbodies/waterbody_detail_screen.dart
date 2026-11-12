import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../events/event_detail_screen.dart';

class WaterbodyDetailScreen extends StatefulWidget {
  const WaterbodyDetailScreen({super.key, required this.waterBodyId});

  final String waterBodyId;

  @override
  State<WaterbodyDetailScreen> createState() =>
      _WaterbodyDetailScreenState();
}

class _WaterbodyDetailScreenState extends State<WaterbodyDetailScreen> {
  WaterBody? _wb;
  List<Event> _events = const [];
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
      final j = await ApiClient.instance.get('/waterbodies/${widget.waterBodyId}');
      final events = await ApiClient.instance.getList('/events', query: {
        'waterBodyId': widget.waterBodyId,
        'status': 'scheduled',
        'limit': 20,
      });
      if (!mounted) return;
      setState(() {
        _wb = WaterBody.fromJson(j);
        _events = events.map((e) => Event.fromJson(e)).toList();
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
    if (_loading) return const Scaffold(body: AppLoading());
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(), body: ErrorBanner(message: _error!, onRetry: _load));
    }
    final wb = _wb!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(wb.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF00A389)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            margin: const EdgeInsets.all(16),
            child: const Center(
              child: Icon(Icons.water, size: 64, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wb.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                if (wb.region != null)
                  Text(wb.region!,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                if (wb.description != null) ...[
                  const SizedBox(height: 10),
                  Text(wb.description!,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ],
                const SizedBox(height: 16),
                const Text('События на этом водоёме',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (_events.isEmpty)
                  Text('Пока нет запланированных событий',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          ..._events.map((e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.event, color: AppColors.primary),
                  title: Text(e.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: e.eventDate != null
                      ? Text('${dayLabel(e.eventDate!)} · ${timeLabel(e.eventDate!)}')
                      : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EventDetailScreen(eventId: e.id))),
                ),
              )),
        ],
      ),
    );
  }
}