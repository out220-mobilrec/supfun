import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../auth/auth_service.dart';
import '../channels/channels_screen.dart';
import '../market/marketplace_screen.dart';
import '../news/news_screen.dart';
import '../tracks/tracks_screen.dart';
import '../waterbodies/waterbodies_screen.dart';
import 'achievements_screen.dart';
import 'edit_profile_screen.dart';
import 'gear_screen.dart';
import 'rating_screen.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  LevelInfo? _level;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    try {
      final j = await ApiClient.instance.get('/gamification/me');
      if (!mounted) return;
      setState(() => _level = LevelInfo.fromJson(j));
    } catch (_) {}
  }

  Future<void> _logout() async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
        ],
      ),
    );
    if (ok != true) return;
    await AuthApi.logout('');
    await app.logout();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    AppAvatar(u?.avatarUrl, size: 76),
                    if (!(u?.isEmailVerified ?? true))
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mail_outline,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u?.name ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      if (u != null && (u.city ?? '').isNotEmpty)
                        Text('${u.city}${u.region != null ? ', ${u.region}' : ''}',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (_level != null) LevelPill(level: _level!.level),
              ],
            ),
          ),
          if (!(u?.isEmailVerified ?? true))
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Email не подтверждён'),
                subtitle: const Text('Перейдите по ссылке из письма'),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      final r = await AuthApi.resendVerification();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Письмо отправлено'),
                            content: ShowDevToken(devToken: r.devToken),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('ОК')),
                            ],
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  child: const Text('Отправить'),
                ),
              ),
            ),
          _menu(context, Icons.person_outline, 'Мой профиль', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u?.id ?? '')));
          }),
          _menu(context, Icons.edit_outlined, 'Редактировать профиль', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()));
          }),
          _menu(context, Icons.emoji_events_outlined, 'Достижения', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen()));
          }),
          _menu(context, Icons.leaderboard_outlined, 'Рейтинг', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RatingScreen()));
          }),
          _menu(context, Icons.surfing_outlined, 'Моё снаряжение', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GearScreen()));
          }),
          _menu(context, Icons.waves, 'Мои заплывы', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TracksScreen()));
          }),
          _menu(context, Icons.storefront_outlined, 'Мои объявления', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MarketplaceScreen(mine: true)));
          }),
          _menu(context, Icons.lock_outline, 'Каналы', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChannelsScreen()));
          }),
          _menu(context, Icons.newspaper, 'Новости', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NewsScreen()));
          }),
          _menu(context, Icons.water, 'Водоёмы', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WaterbodiesScreen()));
          }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Выйти', style: TextStyle(color: AppColors.danger)),
            onTap: _logout,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.3)),
      onTap: onTap,
    );
  }
}