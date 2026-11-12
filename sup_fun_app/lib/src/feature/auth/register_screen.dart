import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../app_state.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _city = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = context.read<AppState>();
    try {
      final r = await AuthApi.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        city: _city.text,
      );
      app.socket.connect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(r.user.isEmailVerified
              ? 'Аккаунт создан!'
              : 'Проверьте email для подтверждения'),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка сети');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Регистрация',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Имя'),
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().length < 2) ? 'Имя: 2–100 символов' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty || !v.contains('@')) ? 'Укажите email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(hintText: 'Пароль (≥ 8 символов)'),
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.length < 8) ? 'Пароль: минимум 8 символов' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(hintText: 'Город (необязательно)'),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Создать аккаунт'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Уже есть аккаунт? Войти'),
            ),
          ],
        ),
      ),
    );
  }
}