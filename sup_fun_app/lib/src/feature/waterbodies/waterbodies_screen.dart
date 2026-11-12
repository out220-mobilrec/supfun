import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import 'waterbody_detail_screen.dart';

class WaterbodiesScreen extends StatefulWidget {
  const WaterbodiesScreen({super.key});

  @override
  State<WaterbodiesScreen> createState() => _WaterbodiesScreenState();
}

class _WaterbodiesScreenState extends State<WaterbodiesScreen> {
  final _q = TextEditingController();
  List<WaterBody> _items = const [];
  List<NearbyWb> _nearbyList = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiClient.instance.getList('/waterbodies', query: {
        if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
        'limit': 100,
      });
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => WaterBody.fromJson(e)).toList();
        _loading = false;
      });
      _nearby();
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

  Future<void> _nearby() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final list = await ApiClient.instance.getList('/waterbodies/nearby', query: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'radius': 50000,
      });
      if (!mounted) return;
      setState(() => _nearbyList = list.map((e) => NearbyWb.fromJson(e)).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final list = [
      ..._nearbyList.map((w) => WaterBody(id: w.id, name: w.name, region: w.region)),
      ..._items,
    ];
    final seen = <String>{};
    final dedup = list.where((w) => seen.add(w.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Водоёмы')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(
                  hintText: 'Поиск водоёма', isDense: true, prefixIcon: Icon(Icons.search)),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_nearbyList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Рядом с вами · ${_nearbyList.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ),
            ),
          Expanded(
            child: _loading
                ? const AppLoading()
                : _error != null
                    ? ErrorBanner(message: _error!, onRetry: _load)
                    : dedup.isEmpty
                        ? const EmptyState(
                            icon: Icons.water,
                            text: 'Водоёмы не найдены')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: dedup.length,
                              itemBuilder: (_, i) {
                                final w = dedup[i];
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.water,
                                        color: AppColors.sea),
                                    title: Text(w.name),
                                    subtitle: w.region != null
                                        ? Text(w.region!)
                                        : null,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.push(context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                WaterbodyDetailScreen(
                                                    waterBodyId: w.id))),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class NearbyWb {
  final String id;
  final String name;
  final String? region;

  NearbyWb({required this.id, required this.name, this.region});

  factory NearbyWb.fromJson(Map<String, dynamic> j) => NearbyWb(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        region: j['region'] as String?,
      );
}