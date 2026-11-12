// Local data management screen showing cached routes, waterbodies, chats
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/local_models.dart';
import '../controllers/storage_controller.dart';

class LocalDataScreen extends StatelessWidget {
  const LocalDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Локальные данные'),
      ),
      body: SafeArea(
        child: Consumer<StorageController>(
          builder: (context, controller, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context, controller),
                const SizedBox(height: 16),
                _buildStatisticsCard(controller),
                const SizedBox(height: 16),
                _buildRoutesList(controller),
                const SizedBox(height: 16),
                _buildWaterBodiesList(controller),
                const SizedBox(height: 16),
                _buildSettingsCard(context, controller),
                const SizedBox(height: 16),
                _buildActionsCard(context, controller),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StorageController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.storage, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text('Офлайн-хранилище',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Маршруты, чаты, водоемы и события\n'
            'хранятся локально для работы без интернета',
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '${controller.routes.length}',
                  'маршрутов',
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  '${controller.conversations.length}',
                  'чатов',
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  '${controller.waterBodies.length}',
                  'водоемов',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.8), fontSize: 11)),
      ],
    );
  }

  Widget _buildStatisticsCard(StorageController controller) {
    final stats = controller.getStatistics();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Статистика',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildStatRow(
              'Всего пройдено',
              '${(stats['totalDistance'] as double).toStringAsFixed(1)} км'),
          _buildStatRow(
              'GPS-точек записано', '${stats['totalPoints']}'),
          _buildStatRow(
              'Средняя дистанция',
              '${(stats['avgDistance'] as double).toStringAsFixed(2)} км'),
          _buildStatRow(
              'Общее время',
              _formatDuration(
                  Duration(seconds: stats['totalDuration'] as int))),
          _buildStatRow(
              'Кэш водоемов', '${stats['cachedWaterBodies']}'),
          _buildStatRow(
              'Сохраненных сообщений', '${stats['cachedMessages']}'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRoutesList(StorageController controller) {
    if (controller.routes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Сохраненные маршруты',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${controller.routes.length}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ...controller.routes.take(5).map((route) {
            return _buildRouteItem(route, controller);
          }),
        ],
      ),
    );
  }

  Widget _buildRouteItem(
      LocalRoute route, StorageController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.route,
                size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.name,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    '${route.distance.toStringAsFixed(2)} км • ${_formatDuration(route.duration)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppTheme.errorColor, size: 20),
            onPressed: () => controller.deleteRoute(route.id),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterBodiesList(StorageController controller) {
    if (controller.waterBodies.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Кэшированные водоемы',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...controller.waterBodies.take(5).map((wb) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    wb.isFavorite
                        ? Icons.favorite
                        : Icons.water_drop_outlined,
                    color: wb.isFavorite
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wb.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        Text(wb.city,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border, size: 20),
                    onPressed: () =>
                        controller.toggleWaterBodyFavorite(wb.id),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      BuildContext context, StorageController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Настройки хранения',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          SwitchListTile(
            title: const Text('Автосинхронизация'),
            subtitle: const Text('Синхронизировать при подключении к сети'),
            value: controller.settings?.autoSyncEnabled ?? true,
            onChanged: (v) async {
              final s = controller.settings;
              if (s != null) {
                s.autoSyncEnabled = v;
                await controller.saveSettings(s);
              }
            },
          ),
          SwitchListTile(
            title: const Text('GPS-трекинг в фоне'),
            subtitle: const Text('Записывать маршрут даже без открытия приложения'),
            value:
                controller.settings?.locationTrackingEnabled ?? true,
            onChanged: (v) async {
              final s = controller.settings;
              if (s != null) {
                s.locationTrackingEnabled = v;
                await controller.saveSettings(s);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Уведомления'),
            subtitle: const Text('О новых событиях и сообщениях'),
            value: controller.settings?.notificationsEnabled ?? true,
            onChanged: (v) async {
              final s = controller.settings;
              if (s != null) {
                s.notificationsEnabled = v;
                await controller.saveSettings(s);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(
      BuildContext context, StorageController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(Icons.cleaning_services, color: AppTheme.warningColor),
            title: const Text('Очистить старые сообщения'),
            subtitle: const Text('Удалить сообщения старше 90 дней'),
            onTap: () async {
              await controller.clearOldMessages();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Старые сообщения удалены')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever,
                color: AppTheme.errorColor),
            title: const Text('Очистить весь кэш'),
            subtitle: const Text('Удалить водоемы, события, ленту'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить кэш?'),
                  content: const Text(
                      'Это удалит кэшированные водоемы и события. '
                      'Сохраненные маршруты и чаты останутся.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Очистить',
                          style: TextStyle(color: AppTheme.errorColor)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await controller.clearCache();
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}ч ${m}мин';
    return '${m}мин';
  }
}
