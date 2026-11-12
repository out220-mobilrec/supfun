// Trip result screen with statistics
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Результат заплыва'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSuccessCard(),
              const SizedBox(height: 16),
              _buildStatsGrid(),
              const SizedBox(height: 16),
              _buildRouteCard(),
              const SizedBox(height: 16),
              _buildAchievements(),
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.successColor,
            AppTheme.successColor.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(Icons.check,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Заплыв завершен!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 8),
          const Text('+68 баллов за активность',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: const [
        _StatTile('12.8 км', 'Дистанция', Icons.route),
        _StatTile('2:45:32', 'Время', Icons.timer),
        _StatTile('4.7 км/ч', 'Скорость', Icons.speed),
        _StatTile('128', 'Гребков', Icons.waves),
        _StatTile('56', 'Калорий', Icons.local_fire_department),
        _StatTile('682', 'Очков', Icons.stars),
      ],
    );
  }

  Widget _buildRouteCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFB8D4D4),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Stack(
        children: [
          CustomPaint(painter: _RoutePainter(), child: Container()),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: const [
                  Icon(Icons.map, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Маршрут сохранен',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
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
          const Text('Достижения',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAchievementBadge('🏆', 'Марафонец', true),
              const SizedBox(width: 12),
              _buildAchievementBadge('⚡', 'Спидстер', false),
              const SizedBox(width: 12),
              _buildAchievementBadge('🌅', 'Ранняя пташка', true),
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
        padding: const EdgeInsets.all(12),
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
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 4),
            Text(name,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share),
            label: const Text('Поделиться'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Builder(
            builder: (innerContext) => ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  innerContext, '/home', (route) => false),
              icon: const Icon(Icons.home),
              label: const Text('На главную'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatTile(this.value, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00A6A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.2,
          size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.7,
          size.width * 0.9, size.height * 0.4);

    canvas.drawPath(path, paint);

    // Start point
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.5), 8,
        Paint()..color = Colors.green);
    // End point
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.4), 8,
        Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
