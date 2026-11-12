import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../core/api_client.dart';
import '../../models/auth.dart';
import '../waterbodies/waterbody_picker.dart';
import '../../models/models.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _country;
  late final TextEditingController _bio;
  late final TextEditingController _avatar;
  WaterBody? _homeWaterBody;
  String _profileVisibility = 'public';
  String _activityVisibility = 'public';
  String _geoVisibility = 'private';
  bool _showOnline = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    _name = TextEditingController(text: u?.name ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _city = TextEditingController(text: u?.city ?? '');
    _region = TextEditingController(text: u?.region ?? '');
    _country = TextEditingController(text: u?.country ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
    _avatar = TextEditingController(text: u?.avatarUrl ?? '');
    _profileVisibility = u?.profileVisibility ?? 'public';
    _activityVisibility = u?.activityVisibility ?? 'public';
    _geoVisibility = u?.geoVisibility ?? 'private';
    _showOnline = u?.showOnline ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _region.dispose();
    _country.dispose();
    _bio.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _pickHomeWaterBody() async {
    final wb = await showModalBottomSheet<WaterBody>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const WaterbodyPickerSheet(),
    );
    if (wb != null) setState(() => _homeWaterBody = wb);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ApiClient.instance.patch('/users/me', data: {
        'name': _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        if (_region.text.trim().isNotEmpty) 'region': _region.text.trim(),
        if (_country.text.trim().isNotEmpty) 'country': _country.text.trim(),
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        if (_avatar.text.trim().isNotEmpty) 'avatarUrl': _avatar.text.trim(),
        if (_homeWaterBody != null) 'homeWaterBodyId': _homeWaterBody!.id,
        'profileVisibility': _profileVisibility,
        'activityVisibility': _activityVisibility,
        'geoVisibility': _geoVisibility,
        'showOnline': _showOnline,
      });
      final updated = SessionUser.fromJson(j);
      await app.applyUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Профиль сохранён')));
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Ошибка сети');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать профиль')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Имя'),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Укажите имя' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(hintText: 'Телефон'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(hintText: 'Город')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                      controller: _region,
                      decoration: const InputDecoration(hintText: 'Регион')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _country,
              decoration: const InputDecoration(hintText: 'Страна'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              decoration: const InputDecoration(hintText: 'О себе'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _avatar,
              decoration: const InputDecoration(hintText: 'URL аватара'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickHomeWaterBody,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_homeWaterBody?.name ?? 'Домашний водоём')),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Видимость профиля',
                style: TextStyle(fontWeight: FontWeight.w700)),
            _visibilitySelector('profile', _profileVisibility, (v) {
              setState(() => _profileVisibility = v);
            }),
            const SizedBox(height: 12),
            const Text('Видимость активности',
                style: TextStyle(fontWeight: FontWeight.w700)),
            _visibilitySelector('activity', _activityVisibility, (v) {
              setState(() => _activityVisibility = v);
            }),
            const SizedBox(height: 12),
            const Text('Видимость геолокации',
                style: TextStyle(fontWeight: FontWeight.w700)),
            _visibilitySelector('geo', _geoVisibility, (v) {
              setState(() => _geoVisibility = v);
            }),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Показывать онлайн-статус'),
              value: _showOnline,
              onChanged: (v) => setState(() => _showOnline = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visibilitySelector(String key, String value, ValueChanged<String> onChanged) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'public', label: Text('Публично')),
        ButtonSegment(value: 'friends', label: Text('Друзья')),
        ButtonSegment(value: 'private', label: Text('Приватно')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}