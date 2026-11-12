// Состояния загрузки для экранов (ТЗ §30: «нет данных», «ошибка загрузки»,
// «нет сети» — три разных состояния, а не один спиннер).
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';

enum LoadState { idle, loading, ready, empty, error }

class Section<T> {
  LoadState state = LoadState.idle;
  T? data;
  String? error;

  /// Данные есть, но обновить их с сервера не удалось — показываем кеш.
  bool offline = false;

  bool get isBusy => state == LoadState.loading;
  T? get value => data;
  bool get hasData => data != null;
}

mixin LoadCoordinator on ChangeNotifier {
  Future<void> guard<T>(
    Section<T> section,
    Future<T> Function() loader, {
    bool silent = false,
  }) async {
    if (!silent) {
      section.state = LoadState.loading;
      section.error = null;
      notifyListeners();
    }
    try {
      final value = await loader();
      section.data = value;
      section.error = null;
      section.offline = false;
      section.state = _isEmpty(value) ? LoadState.empty : LoadState.ready;
    } on ApiException catch (e) {
      if (e.isNetwork && section.data != null) {
        section.offline = true;
        section.state = LoadState.ready;
      } else if (e.isNetwork) {
        section.state = LoadState.error;
        section.error = 'Нет подключения к интернету';
      } else {
        section.state = LoadState.error;
        section.error = e.message;
      }
    } catch (e) {
      debugPrint('load failed: $e');
      section.state = LoadState.error;
      section.error = 'Не удалось загрузить данные';
    }
    notifyListeners();
  }

  bool _isEmpty(Object? value) {
    if (value == null) return true;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    if (value is String) return value.isEmpty;
    return false;
  }
}
