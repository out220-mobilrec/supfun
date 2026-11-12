// Home screen with user data from auth controller
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildWeatherCard(),
              const SizedBox(height: 16),
              _buildEventsSection(),
              const SizedBox(height: 16),
              _buildQuickStats(),
              const SizedBox(height: 16),
              _buildActivityFeed(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        return Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: user?.localAvatarPath != null
                  ? AssetImage(user!.localAvatarPath!) as ImageProvider
                  : (user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!) as ImageProvider
                      : null),
              child: (user?.avatarUrl == null &&
                      user?.localAvatarPath == null)
                  ? Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user != null
                        ? 'Привет, ${user.name}!'
                        : 'Привет, Сьюпбордист!',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        user?.city ?? 'Хабаровск',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeatherCard() {
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
      child: Row(
        children: [
          const Icon(Icons.wb_sunny, color: AppTheme.sunnyColor, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('+22°',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('Ясно • Ветер 4 м/с',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text('Отличные условия для заплыва!',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Ближайшие заплывы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            TextButton(onPressed: () {}, child: const Text('Все')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildEventCard('Амурский рассвет', '6 окт, 06:00', '12/30'),
              const SizedBox(width: 12),
              _buildEventCard('Бухта Тихая', '12 окт, 10:00', '5/15'),
              const SizedBox(width: 12),
              _buildEventCard('Закат на Амуре', '15 окт, 19:00', '8/20'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(String title, String date, String participants) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Открытый',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(date,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(participants,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Всего заплывов', '128', Icons.waves),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Расстояние', '682 км', Icons.route),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActivityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Активность друзей',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildActivityItem('Алексей завершил заплыв в Бухта Тихая',
            'Сегодня, 14:30', '4.7 км • 56 мин'),
        const SizedBox(height: 8),
        _buildActivityItem('Мария создала маршрут "Залив Спокойный"',
            'Вчера, 19:20', 'Новый маршрут'),
        const SizedBox(height: 8),
        _buildActivityItem('Дмитрий выложил снаряжение на продажу',
            '2 дня назад', 'SUP доска 10\'6"'),
      ],
    );
  }

  Widget _buildActivityItem(String title, String time, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.secondaryColor,
            child: Icon(Icons.person, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
