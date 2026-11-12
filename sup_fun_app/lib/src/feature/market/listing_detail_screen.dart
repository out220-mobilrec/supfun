import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../profile/user_profile_screen.dart';
import 'listing_form_screen.dart';
import 'marketplace_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Listing? _listing;
  bool _loading = true;
  String? _error;
  bool _favorite = false;

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
      final j =
          await ApiClient.instance.get('/marketplace/listings/${widget.listingId}');
      if (!mounted) return;
      setState(() {
        _listing = Listing.fromJson(j);
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

  Future<void> _toggleFavorite() async {
    try {
      final j = await ApiClient.instance
          .post('/marketplace/listings/${widget.listingId}/favorite');
      setState(() => _favorite = (j['favorite'] ?? false) as bool);
    } catch (_) {}
  }

  Future<void> _sendLead() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Написать продавцу'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Сообщение'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiClient.instance.post(
                    '/marketplace/listings/${widget.listingId}/leads',
                    data: {'message': controller.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заявка отправлена')));
                }
              } on ApiException catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    try {
      await ApiClient.instance
          .delete('/marketplace/listings/${widget.listingId}');
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
    final l = _listing!;
    final isSeller = l.sellerId == Session.user.value?.id;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(kListingCategories[l.category] ?? l.category),
        actions: [
          IconButton(
            icon: Icon(
                _favorite ? Icons.favorite : Icons.favorite_border,
                color: _favorite ? AppColors.danger : null),
            onPressed: _toggleFavorite,
          ),
          if (isSeller)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'del') _delete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'del', child: Text('Удалить'))
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (l.photos.isNotEmpty)
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Image.network(AppConfig.absUrl(l.photos.first),
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(l.priceLabel ?? 'Цена не указана',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                if (l.city != null)
                  Text('${l.city}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 12),
                if (l.description != null)
                  Text(l.description!,
                      style: const TextStyle(fontSize: 15, height: 1.4)),
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AppAvatar(l.seller?.avatarUrl, size: 44),
                  title: Text(l.seller?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Продавец'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: l.sellerId))),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: isSeller
              ? OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ListingFormScreen(listing: l))),
                  child: const Text('Редактировать'),
                )
              : FilledButton(
                  onPressed: _sendLead,
                  child: const Text('Написать продавцу'),
                ),
        ),
      ),
    );
  }
}