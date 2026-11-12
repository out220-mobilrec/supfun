import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import 'listing_detail_screen.dart';
import 'listing_form_screen.dart';

const kListingCategories = <String, String>{
  'boards': 'Доски',
  'paddles': 'Вёсла',
  'wetsuits': 'Гидрокостюмы',
  'accessories': 'Аксессуары',
  'services': 'Услуги',
  'other': 'Другое',
};

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key, this.mine = false});

  final bool mine;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<Listing>? _items;
  bool _loading = true;
  String? _error;
  final _q = TextEditingController();
  String? _category;
  String _sort = 'newest';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> list;
      if (widget.mine) {
        list = await ApiClient.instance.getList('/marketplace/listings/mine');
      } else {
        list = await ApiClient.instance.getList('/marketplace/listings', query: {
          if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
          if (_category != null) 'category': _category,
          'sort': _sort,
          'limit': 100,
        });
      }
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => Listing.fromJson(e)).toList();
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
      appBar: AppBar(
        title: Text(widget.mine ? 'Мои объявления' : 'Барахолка'),
        actions: [
          if (!widget.mine)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ListingFormScreen())),
            ),
        ],
        bottom: widget.mine
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _q,
                          decoration: const InputDecoration(
                              hintText: 'Поиск', isDense: true),
                          onSubmitted: (_) => _load(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort),
                        onSelected: (v) {
                          setState(() => _sort = v);
                          _load();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'newest', child: Text('Сначала новые')),
                          PopupMenuItem(value: 'price_asc', child: Text('Цена ↑')),
                          PopupMenuItem(value: 'price_desc', child: Text('Цена ↓')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          if (!widget.mine)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: const Text('Все'),
                      selected: _category == null,
                      onSelected: (_) {
                        setState(() => _category = null);
                        _load();
                      },
                    ),
                  ),
                  ...kListingCategories.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: _category == e.key,
                          onSelected: (_) {
                            setState(() => _category = e.key);
                            _load();
                          },
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const AppLoading()
                : _error != null
                    ? ErrorBanner(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _items!.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 120),
                                  EmptyState(
                                      icon: Icons.inventory_2_outlined,
                                      text: 'Объявлений пока нет'),
                                ],
                              )
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                                itemCount: _items!.length,
                                itemBuilder: (_, i) =>
                                    _ListingCard(listing: _items![i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listingId: listing.id))),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: listing.photos.isNotEmpty
                  ? Image.network(AppConfig.absUrl(listing.photos.first),
                      fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      width: double.infinity,
                      color: cs.surfaceContainerHighest,
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 40, color: Colors.white38),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(listing.priceLabel ?? 'Без цены',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  Text(listing.city ?? kListingCategories[listing.category] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}