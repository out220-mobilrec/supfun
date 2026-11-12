// Данные раздела «Заплывы» (ТЗ §9): мои/все, карточка, участники, запись.
import 'package:flutter/foundation.dart';

import '../api/sup_fun_api.dart';
import '../core/api_client.dart';
import '../models/api_models.dart';
import 'load_state.dart';

class EventsController extends ChangeNotifier with LoadCoordinator {
  EventsController(this.api);

  final SupFunApi api;

  final Section<List<SupEvent>> mine = Section();
  final Section<List<SupEvent>> all = Section();
  final Section<SupEvent> detail = Section();
  final Section<List<EventParticipant>> participants = Section();
  final Section<List<Map<String, dynamic>>> eventTracks = Section();

  /// Вкладки раздела «Мои заплывы»: предстоящие / завершённые.
  bool showCompleted = false;

  String? actionError;
  bool busy = false;

  Future<void> loadMine() => guard<List<SupEvent>>(
      mine, () => api.events.mine(showCompleted ? 'all' : 'going'));

  Future<void> loadAll() => guard<List<SupEvent>>(
      all, () => api.events.list(status: showCompleted ? 'completed' : 'scheduled'));

  Future<void> setShowCompleted(bool value) async {
    showCompleted = value;
    notifyListeners();
    await Future.wait([loadMine(), loadAll()]);
  }

  Future<void> loadDetail(String id) async {
    await Future.wait([
      guard<SupEvent>(detail, () => api.events.byId(id)),
      guard<List<EventParticipant>>(
          participants, () => api.events.participants(id)),
      guard<List<Map<String, dynamic>>>(
          eventTracks, () => api.events.tracks(id)),
    ]);
  }

  Future<bool> join(String eventId, ParticipantStatus status) =>
      _action(() => api.events.join(eventId, status));

  Future<SupEvent?> create(Map<String, Object?> body) async {
    busy = true;
    actionError = null;
    notifyListeners();
    try {
      final event = await api.events.create(body);
      busy = false;
      notifyListeners();
      return event;
    } catch (e) {
      busy = false;
      actionError = _humanize(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancel(String eventId) => _action(() => api.events.cancel(eventId));

  Future<bool> _action(Future<void> Function() action) async {
    busy = true;
    actionError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      actionError = _humanize(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _humanize(Object e) =>
      e is ApiException ? e.message : 'Не удалось выполнить действие';
}
