// Pre-trip checklist screen
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrestartScreen extends StatefulWidget {
  const PrestartScreen({super.key});

  @override
  State<PrestartScreen> createState() => _PrestartScreenState();
}

class _PrestartScreenState extends State<PrestartScreen> {
  final Map<String, bool> _checklist = {
    'Спасательный жилет': true,
    'Лич': false,
    'Телефон в герметичной упаковке': true,
    'Солнцезащитный крем': true,
    'Вода (минимум 1л)': false,
    'Запасная одежда': false,
  };

  int get _completedCount => _checklist.values.where((v) => v).length;
  int get _totalCount => _checklist.length;
  double get _progress => _completedCount / _totalCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Готовы к выходу?'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressCard(),
                    const SizedBox(height: 16),
                    _buildGearList(),
                  ],
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final percent = (_progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.85)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Text('$percent%',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Проверьте снаряжение',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('$_completedCount из $_totalCount пунктов готовы',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGearList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Список снаряжения',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._checklist.keys.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildChecklistItem(item, _checklist[item]!),
          );
        }),
      ],
    );
  }

  Widget _buildChecklistItem(String title, bool isChecked) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _checklist[title] = !isChecked;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: isChecked
              ? Border.all(color: AppTheme.successColor, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isChecked
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isChecked
                  ? AppTheme.successColor
                  : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  decoration:
                      isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Отменить'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _progress == 1.0
                  ? () => Navigator.pushNamed(context, '/tracking')
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Начать заплыв'),
            ),
          ),
        ],
      ),
    );
  }
}
