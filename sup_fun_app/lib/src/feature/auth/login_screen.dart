import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../app_state.dart';
import 'auth_service.dart';
import 'register_screen.dart';
import 'forgot_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppState>();
      await AuthApi.login(_email.text, _password.text);
      app.socket.connect();
      await app.refreshUnread();
      if (!mounted) return;
      // AuthGate will react to Session.user change
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
      title: 'Войдите в аккаунт',
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
              decoration: const InputDecoration(hintText: 'Пароль'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => (v == null || v.isEmpty) ? 'Введите пароль' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Войти'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const RegisterScreen(),
              )),
              child: const Text('Создать аккаунт'),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ForgotScreen(),
              )),
              child: const Text('Забыли пароль?'),
            ),
          ],
        ),
      ),
    );
  }
}