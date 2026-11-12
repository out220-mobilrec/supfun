// Marketplace screen for buying/selling equipment
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _selectedCategory = 'Все';

  final List<String> _categories = [
    'Все',
    'SUP доски',
    'Весла',
    'Аксессуары',
    'Запчасти',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Маркетплейс'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildCategoryTabs(),
            Expanded(child: _buildListings()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск снаряжения',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: AppTheme.primaryColor, size: 32),
            onPressed: () {
              // Show create listing
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _selectedCategory = cat),
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

  Widget _buildListings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildListingCard(
          'SUP доска 10\'6"',
          '95 000 ₽',
          'Отличное состояние, использовался 1 сезон',
          '1 280 км',
          '128 гребков',
          Icons.waves,
        ),
        const SizedBox(height: 12),
        _buildListingCard(
          'Весло карбоновое',
          '18 000 ₽',
          'Лёгкое, профессиональное',
          '682 км',
          '56 часов',
          Icons.rowing,
        ),
        const SizedBox(height: 12),
        _buildListingCard(
          'SUP доска 9\'8"',
          '25 000 ₽',
          'Для начинающих, почти новая',
          '128 км',
          '12 часов',
          Icons.waves,
        ),
        const SizedBox(height: 12),
        _buildListingCard(
          'Гидрокостюм',
          '5 500 ₽',
          'Размер L, тёмно-синий',
          '128 км',
          '8 часов',
          Icons.checkroom,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildListingCard(
    String title,
    String price,
    String description,
    String distance,
    String usage,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        children: [
          // Image placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radius)),
            ),
            child: Center(
              child: Icon(icon, size: 60, color: AppTheme.primaryColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    Text(price,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('Хабаровск',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                    const SizedBox(width: 16),
                    Text(distance,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text(usage,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
