// Waterbody detail screen
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaterBodyScreen extends StatelessWidget {
  final String waterBodyId;
  const WaterBodyScreen({super.key, required this.waterBodyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Якутск',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.accentColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.waves,
                      size: 80, color: Colors.white24),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWeatherInfo(),
                const SizedBox(height: 16),
                _buildTodayForecast(),
                const SizedBox(height: 16),
                _buildNearestEvents(),
                const SizedBox(height: 16),
                _buildDescription(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny,
              color: AppTheme.sunnyColor, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('+22°',
                    style: TextStyle(
                        fontSize: 42, fontWeight: FontWeight.w700)),
                Text('Ясно',
                    style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                Text('Ощущается как +24°',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _WeatherDetail('Ветер', '4 м/с'),
              SizedBox(height: 4),
              _WeatherDetail('Влажность', '57%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayForecast() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Сегодня',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildForecastItem('06:00', '+17°', Icons.wb_sunny),
              _buildForecastItem('09:00', '+20°', Icons.wb_sunny),
              _buildForecastItem('12:00', '+22°', Icons.wb_sunny),
              _buildForecastItem('15:00', '+23°', Icons.wb_cloudy),
              _buildForecastItem('18:00', '+21°', Icons.wb_sunny),
              _buildForecastItem('21:00', '+18°', Icons.nights_stay),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForecastItem(String time, String temp, IconData icon) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(height: 6),
          Text(temp,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNearestEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ближайшие заплывы',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildEventItem('Вилюйский восход',
            '10 мин • 22 окт, 06:00', 'Подходит для начинающих'),
        const SizedBox(height: 8),
        _buildEventItem('Амурский рассвет',
            '10 мин • 25 окт, 06:00', 'Вилюйский округ'),
        const SizedBox(height: 8),
        _buildEventItem('Вечерний круиз',
            '15 мин • 25 окт, 17:00', 'Без ограничений'),
      ],
    );
  }

  Widget _buildEventItem(
      String title, String dateTime, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(dateTime,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                Text(description,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('О водоеме',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'Живописное место для SUP-серфинга. Спокойная вода, '
            'отлично подходит как для начинающих, так и для опытных '
            'спортсменов. Есть прокат снаряжения и раздевалки.',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _WeatherDetail extends StatelessWidget {
  final String label;
  final String value;
  const _WeatherDetail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
