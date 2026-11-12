// Community/Feed screen showing social posts
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Сообщество'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPostCard(
              'Лолита',
              '2 часа назад',
              'Бухта Тихая. SUP на закате с моими новыми SUPами',
              true,
              42,
            ),
            const SizedBox(height: 12),
            _buildPostCard(
              'Михаил',
              '4 часа назад',
              'Старый костюм для SUP, завтра новый завоз',
              false,
              18,
            ),
            const SizedBox(height: 12),
            _buildPostCard(
              'Катерина',
              'Вчера',
              'Прошёл SUP по Амуру, красивая погода была',
              true,
              78,
            ),
            const SizedBox(height: 12),
            _buildEventCard(
              'Начало сезона SUP',
              'Через 2 недели',
              'Открытие SUP-сезона в нашем городе. Приходите встречать рассвет на воде!',
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(
    String author,
    String time,
    String content,
    bool hasImage,
    int likes,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.secondaryColor,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(time,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          if (hasImage)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 14),
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
              child: const Center(
                child: Icon(Icons.image,
                    size: 60, color: Colors.white54),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content,
                    style: const TextStyle(
                        fontSize: 14, height: 1.4)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border,
                          size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    Text('$likes',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.mode_comment_outlined,
                          size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    Text('Комментарии',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
      String title, String time, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondaryColor.withOpacity(0.2),
            AppTheme.primaryColor.withOpacity(0.2)
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(time,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Участвовать'),
            ),
          ),
        ],
      ),
    );
  }
}
