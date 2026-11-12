// Profile screen for user account - syncs with auth controller and backend
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditProfileDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AuthController>().refreshProfile();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<AuthController>(
          builder: (context, auth, _) {
            final user = auth.currentUser;
            if (user == null) {
              return const Center(
                child: Text('Необходима авторизация'),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileHeader(context, user),
                  const SizedBox(height: 16),
                  _buildStatsRow(user),
                  const SizedBox(height: 16),
                  _buildExperienceCard(user),
                  const SizedBox(height: 16),
                  _buildFavoriteWaterbodies(),
                  const SizedBox(height: 16),
                  _buildAchievements(),
                  const SizedBox(height: 16),
                  _buildMenuList(),
                  const SizedBox(height: 16),
                  _buildLogoutButton(context, auth),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, user) {
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
        children: [
          GestureDetector(
            onTap: () => _showEditProfileDialog(context),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  backgroundImage: user.localAvatarPath != null
                      ? AssetImage(user.localAvatarPath!) as ImageProvider
                      : (user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!) as ImageProvider
                          : null),
                  child: (user.avatarUrl == null &&
                          user.localAvatarPath == null)
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primaryColor, width: 2),
                    ),
                    child: Icon(Icons.edit,
                        size: 14, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified,
                    color: Colors.lightBlueAccent, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text('${user.city ?? "Не указан"} • ${user.rank}',
              style: const TextStyle(
                  fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(user.email,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(user) {
    return Row(
      children: [
        Expanded(
            child: _buildStatBox(
                '${user.totalTrips}', 'Заплывов', Icons.waves)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatBox(
                '${user.totalDistance.toStringAsFixed(0)}', 'км', Icons.route)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatBox(
                '${user.daysOnWater}', 'Дней', Icons.water)),
      ],
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildExperienceCard(user) {
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
              Text('Уровень ${user.level}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${user.experience} / ${user.experienceToNext}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: user.experienceProgress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.borderColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteWaterbodies() {
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
              const Text('Любимые водоемы',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () {}, child: const Text('Все >')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildWaterbodyCard('Амур', '4.8★', Icons.water),
                const SizedBox(width: 12),
                _buildWaterbodyCard('Уссури', '4.6★', Icons.water),
                const SizedBox(width: 12),
                _buildWaterbodyCard('Японское море', '4.9★', Icons.water),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterbodyCard(String name, String rating, IconData icon) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.7),
            AppTheme.accentColor.withOpacity(0.7)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const Spacer(),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(rating,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
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
              const Text('Достижения',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () {}, child: const Text('Все >')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAchievementBadge('🏆', 'Марафонец', true),
              const SizedBox(width: 8),
              _buildAchievementBadge('⚡', 'Спидстер', false),
              const SizedBox(width: 8),
              _buildAchievementBadge('🌅', 'Ранняя пташка', true),
              const SizedBox(width: 8),
              _buildAchievementBadge('🏅', 'Ветеран', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(
      String emoji, String name, bool isUnlocked) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUnlocked
              ? AppTheme.secondaryColor.withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: isUnlocked ? 1.0 : 0.3,
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 4),
            Text(name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    final menuItems = [
      _MenuItem('Мои заплывы', Icons.waves),
      _MenuItem('Любимые маршруты', Icons.favorite),
      _MenuItem('Мои объявления', Icons.shopping_bag),
      _MenuItem('Друзья', Icons.people),
      _MenuItem('Уведомления', Icons.notifications),
      _MenuItem('Помощь и поддержка', Icons.help_outline),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: menuItems
            .map((item) => ListTile(
                  leading: Icon(item.icon, color: AppTheme.primaryColor),
                  title: Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.textSecondary),
                  onTap: () {},
                ))
            .toList(),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthController auth) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Выйти из аккаунта?'),
              content: const Text(
                  'Вы сможете войти снова в любое время'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Выйти',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await auth.logout();
            if (context.mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/auth', (route) => false);
            }
          }
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Выйти', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final auth = context.read<AuthController>();
    final user = auth.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final cityController = TextEditingController(text: user.city ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'Город'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'О себе'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.updateProfile(
                name: nameController.text.trim(),
                city: cityController.text.trim(),
                bio: bioController.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Профиль обновлен')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  _MenuItem(this.title, this.icon);
}
