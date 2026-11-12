// Раздел «Карта» (ТЗ §8): тайловая карта OSM, слои маршрутов, заплывов,
// людей и водоёмов, единый поиск (ТЗ §25) и карточка по тапу на метку.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controllers/map_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../services/geo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'event_screen.dart';
import 'track_screen.dart';
import 'user_screen.dart';
import 'waterbody_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  final TextEditingController _searchController = TextEditingController();
  late final MapLayersController _controller;
  bool _centered = false;

  static const _defaultCenter = LatLng(61.7, 90.0);

  /// Опции создаются ОДИН РАЗ. flutter_map 7 в didUpdateWidget сравнивает
  /// MapOptions по значениям (там == по всем полям, включая initialCenter),
  /// и при отличии перезаписывает камеру. Если строить MapOptions в build()
  /// с center из GPS-контроллера, любое notifyListeners откатывал зум —
  /// карта «не масштабировалась».
  late final MapOptions _options;

  bool _mapReady = false;
  LatLng? _pendingCenter;
  double _pendingZoom = 11;

  @override
  void initState() {
    super.initState();
    _controller = context.read<MapLayersController>();
    _options = MapOptions(
      initialCenter: _defaultCenter,
      initialZoom: 5,
      minZoom: 2,
      maxZoom: 19,
      // Пинч, драг, двойной тап — всё включено; поворот и инерцию гасим,
      // чтобы на воде карта не «уезжала» от случайного жеста.
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.pinchZoom |
            InteractiveFlag.drag |
            InteractiveFlag.doubleTapZoom |
            InteractiveFlag.flingAnimation |
            InteractiveFlag.pinchMove,
      ),
      onMapReady: () {
        _mapReady = true;
        final pending = _pendingCenter;
        if (pending != null) {
          _pendingCenter = null;
          _map.move(pending, _pendingZoom);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// move() до onMapReady flutter_map игнорирует — поэтому ждём готовности.
  void _moveTo(LatLng point, double zoom) {
    if (!_mapReady) {
      _pendingCenter = point;
      _pendingZoom = zoom;
      return;
    }
    _map.move(point, zoom);
  }

  void _setZoom(double zoom) {
    if (!_mapReady) return;
    final camera = _map.camera;
    final minZ = (_options.minZoom ?? 2).toDouble();
    final maxZ = (_options.maxZoom ?? 19).toDouble();
    _map.move(camera.center, zoom.clamp(minZ, maxZ).toDouble());
  }

  Future<void> _bootstrap() async {
    await _controller.loadLayers();
    if (!mounted || _centered) return;
    final position = await const GeoService().current();
    if (position == null || !mounted) return;
    _centered = true;
    _controller.rememberPosition(position.latitude, position.longitude);
    _moveTo(LatLng(position.latitude, position.longitude), 11);
  }

  Future<void> _goToMe() async {
    final position = await const GeoService().current();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить позицию')));
      return;
    }
    _controller.rememberPosition(position.latitude, position.longitude);
    _moveTo(LatLng(position.latitude, position.longitude), 13);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MapLayersController>();
    final center = controller.latitude != null && controller.longitude != null
        ? LatLng(controller.latitude!, controller.longitude!)
        : _defaultCenter;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _map,
            options: _options,
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.supfun.sup_fun',
                maxZoom: 19,
              ),
              if (controller.layers.routes) _routesLayer(controller),
              if (controller.layers.waterbodies) _waterbodiesLayer(controller),
              if (controller.layers.events) _eventsLayer(controller),
              if (controller.layers.people) _peopleLayer(controller),
            ],
          ),
          // Оверлеи — только Positioned: невызованный Column в Stack тянется
          // на всю высоту и перекрывает карту.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SearchField(
                      controller: _searchController,
                      onSubmit: controller.search,
                      onClear: () => controller.search(''),
                    ),
                    _SearchResults(controller: controller),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 150,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomin',
                  onPressed: () => _setZoom(_map.camera.zoom + 2),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'zoomout',
                  onPressed: () => _setZoom(_map.camera.zoom - 2),
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: _goToMe,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'fit',
                  onPressed: () => _moveTo(center, 11),
                  child: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LayerBar(controller: controller),
          ),
        ],
      ),
    );
  }

  Widget _waterbodiesLayer(MapLayersController controller) {
    final items = controller.waterbodies.data ?? const <WaterBody>[];
    return MarkerLayer(
      markers: [
        for (final wb in items)
          if (wb.latitude != null && wb.longitude != null)
            Marker(
              point: LatLng(wb.latitude!, wb.longitude!),
              width: 44,
              height: 44,
              child: _MapPin(
                icon: Icons.water_drop_rounded,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WaterBodyScreen(waterBodyId: wb.id))),
              ),
            ),
      ],
    );
  }

  Widget _eventsLayer(MapLayersController controller) {
    final items = controller.events.data ?? const <SupEvent>[];
    return MarkerLayer(
      markers: [
        for (final event in items)
          if (event.startLat != null && event.startLng != null)
            Marker(
              point: LatLng(event.startLat!, event.startLng!),
              width: 44,
              height: 44,
              child: _MapPin(
                icon: Icons.surfing_rounded,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => EventScreen(eventId: event.id))),
              ),
            ),
      ],
    );
  }

  Widget _peopleLayer(MapLayersController controller) {
    // Людей показываем их «домашним» водоёмом, а не точной координатой —
    // так не нарушается приватность гео (ТЗ §28).
    final items = controller.people.data ?? const <AppUser>[];
    final bodies = {
      for (final wb in controller.waterbodies.data ?? const <WaterBody>[])
        wb.id: wb,
    };
    return MarkerLayer(
      markers: [
        for (final user in items)
          if (user.homeWaterBodyId != null &&
              bodies[user.homeWaterBodyId]?.latitude != null)
            Marker(
              point: LatLng(bodies[user.homeWaterBodyId]!.latitude!,
                  bodies[user.homeWaterBodyId]!.longitude!),
              width: 34,
              height: 34,
              child: _MapPin(
                icon: Icons.person_rounded,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserScreen(userId: user.id))),
              ),
            ),
      ],
    );
  }

  Widget _routesLayer(MapLayersController controller) {
    final routes = controller.routes.data ?? const <Track>[];
    return PolylineLayer(
      polylines: [
        for (final route in routes)
          if (route.routeLine.length > 1)
            Polyline(
              points: [
                for (final pair in route.routeLine)
                  if (pair.length >= 2) LatLng(pair[1], pair[0])
              ],
              color: const Color(0xFF00A6A6).withValues(alpha: .85),
              strokeWidth: 4,
            ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          hintText: 'Водоём, маршрут, заплыв, человек',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                  icon: const Icon(Icons.close)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.controller});

  final MapLayersController controller;

  @override
  Widget build(BuildContext context) {
    final found = controller.results.data;
    if (controller.results.isBusy) return const LoadingView();
    if (found == null || found.isEmpty) {
      return controller.results.hasData
          ? const _ResultCard(
              child: EmptyView(title: 'Ничего не найдено', compact: true))
          : const SizedBox.shrink();
    }
    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final wb in found.waterbodies.take(4))
            ListTile(
              dense: true,
              leading: const Text('💧'),
              title: Text(wb.name),
              subtitle: Text(wb.region ?? ''),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WaterBodyScreen(waterBodyId: wb.id))),
            ),
          for (final track in found.tracks.take(4))
            ListTile(
              dense: true,
              leading: const Text('🌊'),
              title: Text(track.title),
              subtitle: Text(distanceLabel(track.distanceMeters)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TrackScreen(trackId: track.id))),
            ),
          for (final event in found.events.take(4))
            ListTile(
              dense: true,
              leading: const Text('🏄'),
              title: Text(event.title),
              subtitle: Text(eventWhenLabel(event.eventDate)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventScreen(eventId: event.id))),
            ),
          for (final user in found.users.take(4))
            ListTile(
              dense: true,
              leading:
                  UserAvatar(name: user.name, url: user.avatarUrl, radius: 16),
              title: Text(user.name),
              subtitle: Text(user.displayCity),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserScreen(userId: user.id))),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 3,
          child: SingleChildScrollView(child: child),
        ),
      );
}

class _LayerBar extends StatelessWidget {
  const _LayerBar({required this.controller});

  final MapLayersController controller;

  @override
  Widget build(BuildContext context) {
    final layers = controller.layers;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: .45),
            Colors.transparent,
          ],
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _chip('Водоёмы', layers.waterbodies,
              () => controller.setLayers(layers.copyWith(waterbodies: !layers.waterbodies))),
          _chip('Маршруты', layers.routes,
              () => controller.setLayers(layers.copyWith(routes: !layers.routes))),
          _chip('Заплывы', layers.events,
              () => controller.setLayers(layers.copyWith(events: !layers.events))),
          _chip('Люди', layers.people,
              () => controller.setLayers(layers.copyWith(people: !layers.people))),
          if (layers.routes)
            for (final difficulty in TrackDifficulty.values)
              FilterChip(
                backgroundColor: Colors.white,
                label: Text(difficulty.label),
                selected: controller.difficultyFilter == difficulty,
                onSelected: (_) => controller.setDifficulty(
                    controller.difficultyFilter == difficulty
                        ? null
                        : difficulty),
              ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      );
}
