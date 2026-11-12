import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import 'auth_service.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _showResetSheet(String token) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _ResetPasswordForm(initialToken: token),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
    });
    try {
      final r = await AuthApi.forgotPassword(_email.text);
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка для восстановления отправлена на email')),
      );
      if (r.devToken != null && r.devToken!.isNotEmpty) {
        _showResetSheet(r.devToken!);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Восстановление пароля',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || v.trim().isEmpty || !v.contains('@')) ? 'Укажите email' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Отправить ссылку'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordForm extends StatefulWidget {
  const _ResetPasswordForm({required this.initialToken});

  final String initialToken;

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _token = TextEditingController(text: widget.initialToken);
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthApi.resetPassword(_token.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль изменён. Войдите заново')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Ошибка сети');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Новый пароль',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        TextField(
          controller: _token,
          decoration: const InputDecoration(hintText: 'Токен из письма'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _pass,
          decoration: const InputDecoration(hintText: 'Новый пароль'),
          obscureText: true,
          validator: (v) => (v == null || v.length < 8) ? 'Минимум 8 символов' : null,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}