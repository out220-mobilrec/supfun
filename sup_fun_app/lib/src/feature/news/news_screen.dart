import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../widgets/widget.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ApiClient.instance.get('/news', query: {'limit': 50});
      if (!mounted) return;
      setState(() {
        final items = (j['items'] as List?) ?? [];
        _items = items.map((e) => NewsItem.fromJson(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ошибка сети');
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новости')),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items!.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyState(
                              icon: Icons.newspaper,
                              text: 'Новостей пока нет'),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _items!.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _NewsCard(item: _items![i]),
                        ),
                ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => NewsDetailScreen(newsId: item.id))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.coverUrl != null && item.coverUrl!.isNotEmpty)
              Image.network(AppConfig.absUrl(item.coverUrl),
                  height: 140, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  if (item.createdAt != null)
                    Text(dayLabel(item.createdAt!),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}