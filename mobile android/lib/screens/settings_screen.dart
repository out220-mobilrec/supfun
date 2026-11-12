// Настройки: профиль, приватность (ТЗ §28), адрес сервера, выход.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/profile_controller.dart';
import '../controllers/session_controller.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  late final TextEditingController _server;

  String? _profileVisibility;
  String? _activityVisibility;
  String? _geoVisibility;
  bool? _showOnline;
  bool _saving = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _city = TextEditingController(text: user?.city ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _server = TextEditingController(
        text: context.read<SessionController>().baseUrl);
    _profileVisibility = user?.profileVisibility;
    _activityVisibility = user?.activityVisibility;
    _geoVisibility = user?.geoVisibility;
    _showOnline = user?.showOnline;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _bio.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    final session = context.read<SessionController>();
    final profile = context.read<ProfileController>();
    final updated = await profile.updateProfile({
      'name': _name.text.trim(),
      'city': _city.text.trim(),
      'bio': _bio.text.trim(),
      if (_profileVisibility != null) 'profileVisibility': _profileVisibility,
      if (_activityVisibility != null)
        'activityVisibility': _activityVisibility,
      if (_geoVisibility != null) 'geoVisibility': _geoVisibility,
      if (_showOnline != null) 'showOnline': _showOnline,
    });
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        _saving = false;
        _isError = true;
        _message = 'Не удалось сохранить изменения';
      });
      return;
    }
    session.applyUser(updated);
    setState(() {
      _saving = false;
      _isError = false;
      _message = 'Сохранено';
    });
  }

  Future<void> _applyServer() async {
    final session = context.read<SessionController>();
    await session.setBaseUrl(_server.text);
    if (!mounted) return;
    setState(() {
      _isError = false;
      _message = 'Адрес сервера обновлён: ${session.baseUrl}';
    });
    await session.refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          if (user != null) ...[
            Row(
              children: [
                UserAvatar(name: user.name, url: user.avatarUrl, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        user.isEmailVerified
                            ? 'Email подтверждён'
                            : 'Email не подтверждён',
                        style: TextStyle(
                            color: user.isEmailVerified
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!user.isEmailVerified)
                  TextButton(
                    onPressed: () async {
                      await session.resendVerification();
                      if (!mounted) return;
                      setState(() {
                        _isError = false;
                        _message = 'Код подтверждения отправлен повторно';
                      });
                    },
                    child: const Text('Выслать код'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const SectionTitle('Профиль'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Город'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'О себе'),
          ),
          const SectionTitle('Приватность'),
          _VisibilityTile(
            label: 'Кто видит профиль',
            value: _profileVisibility,
            onChanged: (v) => setState(() => _profileVisibility = v),
          ),
          _VisibilityTile(
            label: 'Кто видит ваши заплывы',
            value: _activityVisibility,
            onChanged: (v) => setState(() => _activityVisibility = v),
          ),
          _VisibilityTile(
            label: 'Кто видит ваше местоположение',
            value: _geoVisibility,
            onChanged: (v) => setState(() => _geoVisibility = v),
          ),
          SwitchListTile(
            value: _showOnline ?? true,
            onChanged: (value) => setState(() => _showOnline = value),
            title: const Text('Показывать статус «онлайн»'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(_saving ? 'Сохраняем…' : 'СОХРАНИТЬ'),
          ),
          const SectionTitle('Сервер'),
          Text(
            'По умолчанию 10.0.2.2 — это хостовая машина для Android-эмулятора. '
            'Для устройства по Wi-Fi укажите LAN-адрес компьютера.',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _server,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                      labelText: 'Адрес API', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _applyServer,
                child: const Text('Применить'),
              ),
            ],
          ),
          TextButton(
            onPressed: () async {
              final session = context.read<SessionController>();
              await session.resetBaseUrl();
              if (!mounted) return;
              _server.text = session.baseUrl;
              setState(() {
                _isError = false;
                _message = 'Адрес сброшен на ${session.baseUrl}';
              });
            },
            child: const Text('Сбросить адрес сервера'),
          ),
          if (_message != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isError ? AppTheme.errorColor : AppTheme.successColor)
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(_message!),
            ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded,
                color: AppTheme.errorColor),
            title: const Text('Выйти из аккаунта'),
            onTap: () async {
              final navigator = Navigator.of(context);
              await session.logout();
              navigator.popUntil((route) => route.isFirst);
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'SUP FUN • клиент v0.2.0\n${session.baseUrl}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (session.user?.role != UserRole.user)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Роль в системе: ${session.user!.roleLabel}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisibilityTile extends StatelessWidget {
  const _VisibilityTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  static const _values = <String, String>{
    'public': 'Все',
    'friends': 'Друзья',
    'private': 'Только я',
  };

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: DropdownButton<String>(
          value: value != null && _values.containsKey(value) ? value : 'public',
          underline: const SizedBox.shrink(),
          items: [
            for (final entry in _values.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      );
}
