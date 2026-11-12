import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';

/// Persistent auth state: tokens + current user.
class Session {
  Session._();

  static const _kToken = 'sf_token';
  static const _kRefresh = 'sf_refresh';
  static const _kUser = 'sf_user';
  static const _kTheme = 'sf_theme_mode';
  static const _kLocale = 'sf_locale';

  static final ValueNotifier<SessionUser?> user = ValueNotifier(null);
  static final ValueNotifier<bool> initialized = ValueNotifier(false);

  static String? get accessToken => _token;

  static String? _token;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
    final userJson = prefs.getString(_kUser);
    user.value = userJson == null ? null : SessionUser.fromJson(_decode(userJson));
    initialized.value = true;
  }

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required SessionUser sessionUser,
  }) async {
    _token = accessToken;
    user.value = sessionUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, accessToken);
    await prefs.setString(_kRefresh, refreshToken);
    await prefs.setString(_kUser, _encode(sessionUser.toJson()));
  }

  static Future<void> saveUser(SessionUser sessionUser) async {
    user.value = sessionUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, _encode(sessionUser.toJson()));
  }

  static Future<void> clear() async {
    _token = null;
    user.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
  }

  // Theme + locale persistence
  static Future<ThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kTheme);
    if (v == 'dark') return ThemeMode.dark;
    if (v == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  static Future<void> saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kTheme, mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
  }

  static Future<String> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLocale) ?? 'ru';
  }

  static Future<void> saveLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, code);
  }

  static Map<String, dynamic> _decode(String s) => Map<String, dynamic>.from(jsonDecode(s));

  static String _encode(Map<String, dynamic> m) => jsonEncode(m);
}