import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'models/auth.dart';
import 'services/socket_service.dart';
import 'services/track_offline_store.dart';

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  String locale = 'ru';
  int unreadNotifications = 0;
  int socketUnread = 0;
  LocalTrackRecord? unfinishedTrack;

  final SocketService socket = SocketService();

  SessionUser? get user => Session.user.value;

  Future<void> bootstrap() async {
    themeMode = await Session.loadTheme();
    locale = Session.user.value?.locale ?? await Session.loadLocale();
    if (Session.user.value != null) {
      socket.connect();
      try {
        final me = await ApiClient.instance.get('/users/me');
        final fresh = SessionUser.fromJson(me);
        locale = fresh.locale;
        await Session.saveLocale(locale);
        await Session.saveUser(fresh);
        notifyListeners();
      } catch (_) {}
      try {
        unreadNotifications = (await ApiClient.instance
                .get('/notifications/unread-count'))['count'] as int? ??
            0;
      } catch (_) {}
      socket.events('notify:new').listen((_) {
        unreadNotifications++;
        notifyListeners();
      });
      socket.events('chat:new').listen((_) {
        socketUnread++;
        notifyListeners();
      });
      await refreshUnfinishedTrack();
    }
  }

  Future<void> applyUser(SessionUser u) async {
    await Session.saveUser(u);
    if (u.locale == 'ru' || u.locale == 'en') {
      locale = u.locale;
      await Session.saveLocale(locale);
    }
    await refreshUnfinishedTrack();
    notifyListeners();
  }

  Future<void> logout() async {
    socket.disconnect();
    unreadNotifications = 0;
    socketUnread = 0;
    unfinishedTrack = null;
    await Session.clear();
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    try {
      final j = await ApiClient.instance.get('/notifications/unread-count');
      unreadNotifications = (j['count'] as int?) ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUnfinishedTrack() async {
    final uid = Session.user.value?.id;
    if (uid == null) {
      unfinishedTrack = null;
    } else {
      try {
        unfinishedTrack = await TrackOfflineStore.instance.findUnfinished(uid);
      } catch (_) {
        unfinishedTrack = null;
      }
    }
    notifyListeners();
  }

  void resetUnread() {
    unreadNotifications = 0;
    notifyListeners();
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    notifyListeners();
  }

  void setLocale(String code) {
    locale = code;
    notifyListeners();
  }
}
