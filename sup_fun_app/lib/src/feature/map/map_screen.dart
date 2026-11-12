import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../events/event_detail_screen.dart';
import '../tracks/track_live_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  LatLng _center = const LatLng(55.7517, 37.6173);
  List<Event> _events = const [];
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadNearby();
    _locate();
  }

  Future<Position?> _current() async {
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {
      return null;
    }
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final pos = await _current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) _center = LatLng(pos.latitude, pos.longitude);
    });
    _mapController.move(_center, 13);
    _loadNearby();
  }

  Future<void> _loadNearby() async {
    try {
      final list = await ApiClient.instance
          .getList('/events', query: {'status': 'scheduled', 'limit': 50});
      if (!mounted) return;
      setState(() {
        _events = list
            .map((e) => Event.fromJson(e))
            .where((e) => e.startPoint != null)
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Карта')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.supfun.sup_fun',
              ),
              if (_events.isNotEmpty)
                MarkerLayer(
                  markers: _events
                      .map((e) => Marker(
                            point: e.startPoint!,
                            width: 52,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) =>
                                      EventDetailScreen(eventId: e.id))),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(blurRadius: 6, color: Colors.black26)
                                  ],
                                ),
                                child:
                                    const Icon(Icons.event, color: Colors.white, size: 26),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors',
                      onTap: () {}),
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'locate',
                  mini: true,
                  onPressed: _locate,
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'swim',
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TrackLiveScreen())),
                  child: const Icon(Icons.directions_boat),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}