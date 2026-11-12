// Маркетплейс (ТЗ §23): каталог, фильтры, мои объявления, создание.
import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../core/api_client.dart';
import '../models/api_models.dart';
import 'load_state.dart';

class MarketplaceController extends ChangeNotifier with LoadCoordinator {
  MarketplaceController(this.api);

  final SupFunApi api;

  final Section<List<Listing>> listings = Section();
  final Section<List<Listing>> mine = Section();
  List<String> categories = const [];
  String? category;
  String query = '';
  String sort = 'recent';

  String? actionError;
  bool busy = false;

  Future<void> loadCategories() async {
    try {
      categories = await api.marketplace.categories();
    } on ApiException {
      categories = const [];
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([
      guard<List<Listing>>(listings, () => api.marketplace.listings(
            category: category,
            q: query.isEmpty ? null : query,
            sort: sort,
            limit: 60,
          )),
      guard<List<Listing>>(mine, () => api.marketplace.mine()),
    ]);
  }

  Future<void> setCategory(String? value) async {
    category = value;
    notifyListeners();
    await refresh();
  }

  Future<void> setQuery(String value) async {
    query = value.trim();
    notifyListeners();
    await guard<List<Listing>>(listings, () => api.marketplace.listings(
          category: category,
          q: query.isEmpty ? null : query,
          sort: sort,
          limit: 60,
        ));
  }

  Future<Listing?> create({
    required String title,
    required String category,
    String? description,
    double? price,
    String? city,
  }) async {
    busy = true;
    actionError = null;
    notifyListeners();
    try {
      final listing = await api.marketplace.create({
        'title': title,
        'category': category,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (price != null) 'price': price,
        if (city != null && city.isNotEmpty) 'city': city,
        'currency': 'RUB',
      });
      mine.data = [listing, ...?mine.data];
      mine.state = LoadState.ready;
      return listing;
    } on ApiException catch (e) {
      actionError = e.message;
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> markSold(String id) async {
    try {
      await api.marketplace.markSold(id);
      mine.data = (mine.data ?? const <Listing>[])
          .map((l) => l.id == id ? _asSold(l) : l)
          .toList();
      notifyListeners();
      return true;
    } on ApiException {
      return false;
    }
  }

  Listing _asSold(Listing l) => Listing(
        id: l.id,
        sellerId: l.sellerId,
        sellerName: l.sellerName,
        category: l.category,
        title: l.title,
        description: l.description,
        price: l.price,
        currency: l.currency,
        photos: l.photos,
        city: l.city,
        status: 'sold',
        createdAt: l.createdAt,
      );
}
