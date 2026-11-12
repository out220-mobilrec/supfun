// Map screen showing waterbodies with filters
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _selectedFilter = 'Маршруты';

  final List<String> _filters = [
    'Маршруты',
    'Ветровка',
    'Ветер',
    'Водоемы',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildFilterChips(),
            Expanded(child: _buildMapPlaceholder()),
            _buildBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск водоемов, маршрутов',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              icon: const Icon(Icons.tune), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = filter),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB8D4D4),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Stack(
        children: [
          // Map placeholder with markers
          CustomPaint(painter: _MapPainter(), child: Container()),
          // Markers
          Positioned(
            top: 100,
            left: 80,
            child: _buildMapMarker('Хабаровск'),
          ),
          Positioned(
            top: 180,
            right: 60,
            child: _buildMapMarker('Амур'),
          ),
          Positioned(
            bottom: 120,
            left: 100,
            child: _buildMapMarker('Залив'),
          ),
          // Current location button
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {},
              child: const Icon(Icons.my_location,
                  color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker(String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Container(
          width: 2,
          height: 8,
          color: Colors.white,
        ),
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Создать заплыв'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Избранное'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF88B5B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw some "rivers" or paths
    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.4,
          size.width * 0.6, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.3,
          size.width, size.height * 0.5);

    canvas.drawPath(path, paint);

    // Draw water area
    final waterPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.7,
          size.width, size.height * 0.6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final waterPaint = Paint()
      ..color = const Color(0xFF7AB5B5).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(waterPath, waterPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
