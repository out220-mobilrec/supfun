// Маркетплейс (ТЗ §23): каталог, фильтры по категории/поиску, мои объявления.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/marketplace_controller.dart';
import '../controllers/session_controller.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'chat_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final MarketplaceController _controller;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _controller = context.read<MarketplaceController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadCategories();
      _controller.refresh();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CreateListingSheet(),
    );
    if (created == true && mounted) await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MarketplaceController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Маркетплейс'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Каталог'), Tab(text: 'Мои')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: controller.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Доска, весло, гидрокостюм…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => controller.setQuery(_search.text),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Все'),
                        selected: controller.category == null,
                        onSelected: (_) => controller.setCategory(null),
                      ),
                    ),
                    for (final category in controller.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_categoryLabel(category)),
                          selected: controller.category == category,
                          onSelected: (_) => controller.setCategory(category),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: SectionView<List<Listing>>(
                    section: controller.listings,
                    onRetry: controller.refresh,
                    emptyTitle: 'Объявлений нет',
                    emptySubtitle: 'Добавьте первым — продажа без комиссии',
                    actionLabel: 'Добавить',
                    onAction: _create,
                    builder: (listings) => ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: listings.length,
                      itemBuilder: (_, index) => ListingTile(
                        listing: listings[index],
                        onTap: () => showListingSheet(context, listings[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          RefreshIndicator(
            onRefresh: controller.refresh,
            child: SectionView<List<Listing>>(
              section: controller.mine,
              onRetry: controller.refresh,
              emptyTitle: 'У вас нет объявлений',
              emptySubtitle: 'Продайте доску, которую уже не используете',
              actionLabel: 'Добавить',
              onAction: _create,
              builder: (listings) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  for (final listing in listings)
                    Card(
                      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                      child: ListTile(
                        title: Text(listing.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${listing.priceLabel} • ${listing.statusLabel}'),
                        trailing: listing.status == 'active'
                            ? TextButton(
                                onPressed: () => controller.markSold(listing.id),
                                child: const Text('Продано'),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Объявление'),
      ),
    );
  }

  static String _categoryLabel(String category) => switch (category) {
        'board' => 'Доски',
        'paddle' => 'Вёсла',
        'wetsuit' => 'Гидрокостюмы',
        'vest' => 'Жилеты',
        'accessory' => 'Аксессуары',
        'other' => 'Другое',
        _ => category,
      };
}

Future<void> showListingSheet(BuildContext context, Listing listing) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(listing.title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(listing.priceLabel,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            if (listing.description != null) ...[
              const SizedBox(height: 12),
              Text(listing.description!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                UserAvatar(name: listing.sellerName, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${listing.sellerName} • ${listing.statusLabel}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final chats = context.read<ChatsController>();
                  final id = await chats.directWith(listing.sellerId);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (id == null) return;
                  await chats.open(id);
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversationId: id,
                      title: listing.sellerName,
                    ),
                  ));
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Написать продавцу'),
              ),
            ),
          ],
        ),
      ),
    );

class _CreateListingSheet extends StatefulWidget {
  const _CreateListingSheet();

  @override
  State<_CreateListingSheet> createState() => _CreateListingSheetState();
}

class _CreateListingSheetState extends State<_CreateListingSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  String _category = 'board';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MarketplaceController>();
    final user = context.watch<SessionController>().user;
    _city.text = _city.text.isEmpty ? (user?.city ?? '') : _city.text;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Новое объявление',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Категория'),
              items: const [
                DropdownMenuItem(value: 'board', child: Text('Доска')),
                DropdownMenuItem(value: 'paddle', child: Text('Весло')),
                DropdownMenuItem(value: 'wetsuit', child: Text('Гидрокостюм')),
                DropdownMenuItem(value: 'vest', child: Text('Жилет')),
                DropdownMenuItem(value: 'accessory', child: Text('Аксессуар')),
                DropdownMenuItem(value: 'other', child: Text('Другое')),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? 'other'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Цена, ₽'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Город'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      final created = await controller.create(
                        title: _title.text.trim(),
                        category: _category,
                        description: _description.text.trim(),
                        price: double.tryParse(_price.text.trim()),
                        city: _city.text.trim(),
                      );
                      if (!context.mounted) return;
                      if (created != null) {
                        Navigator.of(context).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(controller.actionError ??
                                'Не удалось создать объявление')));
                      }
                    },
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(controller.busy ? 'Публикуем…' : 'ОПУБЛИКОВАТЬ'),
            ),
          ],
        ),
      ),
    );
  }
}
