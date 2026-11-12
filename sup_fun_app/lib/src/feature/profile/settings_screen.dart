import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/auth.dart';
import '../auth/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _mode = ThemeMode.system;
  String _locale = 'ru';

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _mode = app.themeMode;
    _locale = app.user?.locale ?? app.locale;
  }

  Future<void> _changePasswordDialog() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сменить пароль'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Текущий пароль')),
            const SizedBox(height: 12),
            TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Новый пароль')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сменить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await AuthApi.changePassword(current.text, next.text);
      ApiClient.instance.attachRefresh(r.refreshToken);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Пароль изменён')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content:
            const Text('Все данные будут безвозвратно удалены. Это действие нельзя отменить.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.delete('/users/me');
      await app.logout();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Тема'),
            subtitle: Text(_mode == ThemeMode.dark
                ? 'Тёмная'
                : _mode == ThemeMode.light
                    ? 'Светлая'
                    : 'Системная'),
            trailing: DropdownButton<ThemeMode>(
              value: _mode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Система')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Светлая')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Тёмная')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _mode = v);
                context.read<AppState>().setThemeMode(v);
                await Session.saveTheme(v);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Язык'),
            subtitle: const Text('Сохраняется в профиле'),
            trailing: DropdownButton<String>(
              value: _locale == 'en' ? 'en' : 'ru',
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'ru', child: Text('Русский')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                final prev = _locale;
                setState(() => _locale = v);
                final app = context.read<AppState>();
                app.setLocale(v);
                await Session.saveLocale(v);
                try {
                  final j = await ApiClient.instance.patch('/users/me', data: {'locale': v});
                  if (!mounted) return;
                  await app.applyUser(SessionUser.fromJson(j));
                } catch (_) {
                  if (!mounted) return;
                  setState(() => _locale = prev);
                  app.setLocale(prev);
                  await Session.saveLocale(prev);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось сохранить язык в профиле')),
                  );
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Сменить пароль'),
            onTap: _changePasswordDialog,
          ),
          ListTile(
            leading: const Icon(Icons.safety_divider, color: Colors.red),
            title: const Text('Удалить аккаунт',
                style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}