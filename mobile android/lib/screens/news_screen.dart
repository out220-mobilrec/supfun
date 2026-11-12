// Новости (ТЗ §36 «Новости»): список и чтение.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/sup_fun_api.dart';
import '../controllers/home_controller.dart';
import '../core/formatting.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, this.openId});

  /// Если задан — сразу открываем карточку этой новости.
  final String? openId;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<HomeController>();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _controller.loadNews());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Новости')),
      body: RefreshIndicator(
        onRefresh: _controller.loadNews,
        child: SectionView<List<NewsItem>>(
          section: controller.news,
          onRetry: _controller.loadNews,
          emptyTitle: 'Новостей нет',
          builder: (items) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  side: const BorderSide(color: AppTheme.borderColor),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _NewsReader(item: item))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.coverUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSmall),
                              child: CachedNetworkImage(
                                imageUrl: item.coverUrl!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Text(item.title,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          item.body.length > 160
                              ? '${item.body.substring(0, 160)}…'
                              : item.body,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${relativeTimeLabel(item.createdAt)} • ${item.authorName}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NewsReader extends StatelessWidget {
  const _NewsReader({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(item.title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            if (item.coverUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: CachedNetworkImage(
                      imageUrl: item.coverUrl!, fit: BoxFit.cover),
                ),
              ),
            Text(item.title,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              '${fullDateLabel(item.createdAt)} • ${item.authorName}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(item.body, style: const TextStyle(height: 1.5)),
          ],
        ),
      );
}
