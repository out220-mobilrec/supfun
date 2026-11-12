// Страница водоёма (ТЗ §7.2): описание, маршруты, заплывы, подписка.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../controllers/map_controller.dart';
import '../controllers/session_controller.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'create_event_screen.dart';
import 'event_screen.dart';
import 'prestart_screen.dart';
import 'track_screen.dart';

class WaterBodyScreen extends StatefulWidget {
  const WaterBodyScreen({super.key, required this.waterBodyId});

  final String waterBodyId;

  @override
  State<WaterBodyScreen> createState() => _WaterBodyScreenState();
}

class _WaterBodyScreenState extends State<WaterBodyScreen> {
  late final WaterbodyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<WaterbodyController>();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _controller.load(widget.waterBodyId));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WaterbodyController>();
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.waterbody.data?.name ?? 'Водоём'),
      ),
      body: SectionView<WaterBody>(
        section: controller.waterbody,
        onRetry: () => controller.load(widget.waterBodyId),
        builder: (waterBody) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              waterBody.name,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900),
            ),
            if (waterBody.region != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(waterBody.region!,
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ),
            const SizedBox(height: 16),
            if (waterBody.latitude != null && waterBody.longitude != null)
              SizedBox(
                height: 190,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                          waterBody.latitude!, waterBody.longitude!),
                      initialZoom: 11,
                      interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'app.supfun.sup_fun',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                                waterBody.latitude!, waterBody.longitude!),
                            width: 44,
                            height: 44,
                            child: const Center(
                                child: Text('💧',
                                    style: TextStyle(fontSize: 26))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (waterBody.description != null) ...[
              const SizedBox(height: 18),
              Text(waterBody.description!),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PrestartScreen()),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Заплыв здесь'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CreateEventScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать'),
                  ),
                ),
              ],
            ),
            const SectionTitle('Маршруты'),
            SectionView<List<Track>>(
              section: controller.routes,
              onRetry: () => controller.load(widget.waterBodyId),
              emptyTitle: 'Маршрутов пока нет',
              emptySubtitle: 'Запишите первым и опубликуйте его',
              builder: (tracks) => Column(
                children: [
                  for (final track in tracks)
                    RouteCard(
                      track: track,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TrackScreen(trackId: track.id))),
                    ),
                ],
              ),
            ),
            const SectionTitle('Заплывы здесь'),
            SectionView<List<SupEvent>>(
              section: controller.events,
              onRetry: () => controller.load(widget.waterBodyId),
              emptyTitle: 'Заплывов нет',
              builder: (events) => Column(
                children: [
                  for (final event in events)
                    EventCard(
                      event: event,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EventScreen(eventId: event.id))),
                    ),
                ],
              ),
            ),
            if (session.user != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Ваш уровень: ${session.level.level} · ${session.level.xp} XP',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
