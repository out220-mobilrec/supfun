import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/widget.dart';

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({super.key, required this.newsId});

  final String newsId;

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  NewsItem? _item;
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
      final j = await ApiClient.instance.get('/news/${widget.newsId}');
      if (!mounted) return;
      setState(() {
        _item = NewsItem.fromJson(j);
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

  Future<void> _delete() async {
    try {
      await ApiClient.instance.delete('/news/${widget.newsId}');
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: AppLoading());
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(), body: ErrorBanner(message: _error!, onRetry: _load));
    }
    final n = _item!;
    final isStaff = (Session.user.value?.role ?? 'user') == 'admin' ||
        (Session.user.value?.role ?? 'user') == 'moderator';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новости'),
        actions: [
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (n.coverUrl != null && n.coverUrl!.isNotEmpty)
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.network(AppConfig.absUrl(n.coverUrl),
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (n.createdAt != null)
                  Text(
                    '${dayLabel(n.createdAt!)} · ${n.author?.name ?? ''}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 16),
                Text(n.body,
                    style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}