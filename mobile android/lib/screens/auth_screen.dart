// Экран авторизации (ТЗ §5).
//
// Реальный флоу бэкенда: регистрация не входит, а просит код из письма;
// вход возможен только для подтверждённого email. Поэтому здесь четыре
// режима: вход, регистрация, ввод кода, восстановление пароля.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../theme/app_theme.dart';

enum _AuthMode { login, register, verify, forgot }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode _mode = _AuthMode.login;
  bool _passwordVisible = false;
  bool _serverVisible = false;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _code = TextEditingController();
  final _server = TextEditingController();

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    _server.text = session.baseUrl;
    _email.text = session.storage.lastEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _city.dispose();
    _code.dispose();
    _server.dispose();
    super.dispose();
  }

  String get _title => switch (_mode) {
        _AuthMode.login => 'Вход в аккаунт',
        _AuthMode.register => 'Регистрация',
        _AuthMode.verify => 'Подтверждение email',
        _AuthMode.forgot => 'Восстановление пароля',
      };

  String get _submitLabel => switch (_mode) {
        _AuthMode.login => 'Войти',
        _AuthMode.register => 'Получить код',
        _AuthMode.verify => 'Подтвердить и войти',
        _AuthMode.forgot => 'Отправить инструкцию',
      };

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final session = context.read<SessionController>();
    final messenger = ScaffoldMessenger.of(context);
    final url = _server.text.trim();
    if (url.isNotEmpty && url != session.baseUrl) {
      await session.setBaseUrl(url);
    }
    final email = _email.text.trim();

    switch (_mode) {
      case _AuthMode.login:
        await session.login(email, _password.text);
      case _AuthMode.register:
        final message = await session.register(
          name: _name.text.trim(),
          email: email,
          password: _password.text,
          city: _city.text.trim(),
        );
        if (!mounted) return;
        setState(() => _mode = _AuthMode.verify);
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      case _AuthMode.verify:
        await session.verifyEmail(email, _code.text.trim());
      case _AuthMode.forgot:
        await session.forgotPassword(email);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(
            content:
                Text('Если email зарегистрирован, письмо с инструкцией отправлено.')));
        return;
    }
    if (!mounted) return;
    if (session.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(session.error!),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/splash/splash_1080.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: .55))),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  left: 24, right: 24, bottom: mq.viewInsets.bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 36),
                  const Center(
                    child: Text(
                      'SUP FUN',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(_title,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .85))),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_mode == _AuthMode.register) ...[
                            _field(
                              controller: _name,
                              label: 'Имя',
                              icon: Icons.person_outline,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Введите имя'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            _field(
                              controller: _city,
                              label: 'Город',
                              icon: Icons.location_city_outlined,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_mode == _AuthMode.verify) ...[
                            const Text(
                              'Мы отправили код на почту. Введите его — '
                              'и сразу войдёте в приложение.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            _field(
                              controller: _code,
                              label: 'Код из письма',
                              icon: Icons.pin_outlined,
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.length < 4)
                                  ? 'Введите код'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            _field(
                              controller: _email,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Введите email';
                                }
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'Некорректный email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_mode == _AuthMode.login ||
                              _mode == _AuthMode.register) ...[
                            _field(
                              controller: _password,
                              label: 'Пароль',
                              icon: Icons.lock_outline,
                              obscure: !_passwordVisible,
                              onSubmitted: () => _submit(),
                              suffix: IconButton(
                                onPressed: () => setState(() =>
                                    _passwordVisible = !_passwordVisible),
                                icon: Icon(_passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                color: AppTheme.textSecondary,
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Минимум 6 символов'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _serverRow(),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: session.busy ? null : _submit,
                              child: session.busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(_submitLabel),
                            ),
                          ),
                          _secondary(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (session.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(session.error!,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Адрес сервера меняется прямо здесь — удобно для '
                    'эмулятора (10.0.2.2) и тестового стенда.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: .6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondary() => switch (_mode) {
        _AuthMode.login => Column(
            children: [
              TextButton(
                onPressed: () => setState(() => _mode = _AuthMode.register),
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = _AuthMode.forgot),
                child: const Text('Забыли пароль?'),
              ),
            ],
          ),
        _AuthMode.register => TextButton(
            onPressed: () => setState(() => _mode = _AuthMode.login),
            child: const Text('Уже есть аккаунт? Войти'),
          ),
        _AuthMode.verify => Column(
            children: [
              TextButton(
                onPressed: () async {
                  final session = context.read<SessionController>();
                  await session.resendVerification();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Код отправлен ещё раз')));
                },
                child: const Text('Отправить код снова'),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = _AuthMode.login),
                child: const Text('Вернуться ко входу'),
              ),
            ],
          ),
        _AuthMode.forgot => TextButton(
            onPressed: () => setState(() => _mode = _AuthMode.login),
            child: const Text('Назад ко входу'),
          ),
      };

  Widget _serverRow() => Column(
        children: [
          InkWell(
            onTap: () => setState(() => _serverVisible = !_serverVisible),
            child: Row(
              children: [
                const Icon(Icons.dns_outlined,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _server.text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                Icon(_serverVisible
                    ? Icons.expand_less
                    : Icons.expand_more),
              ],
            ),
          ),
          if (_serverVisible) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _server,
                    label: 'Адрес сервера',
                    icon: Icons.link,
                  ),
                ),
                IconButton(
                  tooltip: 'Сбросить',
                  onPressed: () async {
                    final session = context.read<SessionController>();
                    await session.resetBaseUrl();
                    _server.text = session.baseUrl;
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ],
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    VoidCallback? onSubmitted,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        validator: validator,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          suffixIcon: suffix,
        ),
      );
}
