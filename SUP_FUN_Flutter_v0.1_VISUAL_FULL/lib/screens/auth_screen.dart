// Authentication screen - полупрозрачный поверх сплеш-картинки
// Поддерживает смену адреса сервера на лету (для LAN/эмулятора/деплоя).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../services/local_storage_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _serverUrlController =
      TextEditingController(text: AuthController.apiBaseUrl);
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _serverUrlFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _serverUrlController.text =
        LocalStorageService.instance.getApiBaseUrl() ??
            AuthController.apiBaseUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _serverUrlController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();
    _cityFocus.dispose();
    _serverUrlFocus.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;
    await LocalStorageService.instance.saveApiBaseUrl(url);
    // Force controller to re-read the new URL for next request
    AuthController.overrideApiBaseUrl(url);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _emailFocus.unfocus();
    _passwordFocus.unfocus();
    _nameFocus.unfocus();
    _cityFocus.unfocus();
    _serverUrlFocus.unfocus();

    await _saveServerUrl();

    setState(() => _isLoading = true);

    final auth = context.read<AuthController>();
    bool success;
    if (_isLogin) {
      success = await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Ошибка'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 6),
        ),
      );
    }
    // При успехе ничего не делаем: AuthController.notifyListeners()
    // перестроит MaterialApp.
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/splash/splash_1080.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF1A4A6E),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: mq.viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: mq.size.height -
                      mq.padding.vertical -
                      mq.viewInsets.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.kayaking,
                            size: 48, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'SUP FUN',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLogin ? 'Вход в аккаунт' : 'Регистрация',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isLogin) ...[
                                _input(
                                  c: _nameController,
                                  focusNode: _nameFocus,
                                  nextFocus: _cityFocus,
                                  label: 'Имя',
                                  icon: Icons.person_outline,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Введите имя'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                _input(
                                  c: _cityController,
                                  focusNode: _cityFocus,
                                  nextFocus: _emailFocus,
                                  label: 'Город',
                                  icon: Icons.location_city,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Введите город'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _input(
                                c: _emailController,
                                focusNode: _emailFocus,
                                nextFocus: _passwordFocus,
                                label: 'Email',
                                icon: Icons.email_outlined,
                                keyboardType:
                                    TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Введите email';
                                  }
                                  if (!v.contains('@') ||
                                      !v.contains('.')) {
                                    return 'Некорректный email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _input(
                                c: _passwordController,
                                focusNode: _passwordFocus,
                                label: 'Пароль',
                                icon: Icons.lock_outline,
                                obscure: !_isPasswordVisible,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                suffix: IconButton(
                                  icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppTheme.textSecondary),
                                  onPressed: () => setState(() =>
                                      _isPasswordVisible =
                                          !_isPasswordVisible),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Введите пароль';
                                  }
                                  if (v.length < 6) {
                                    return 'Минимум 6 символов';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Поле адреса сервера (раскрывается)
                              _serverRow(),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _submit,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(_isLogin
                                          ? 'Войти'
                                          : 'Зарегистрироваться'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(
                            () => _isLogin = !_isLogin),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _isLogin
                              ? 'Нет аккаунта? Зарегистрироваться'
                              : 'Уже есть аккаунт? Войти',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'После первой успешной авторизации\nвход будет выполняться автоматически.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.dns_outlined,
              size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _serverUrlController,
              focusNode: _serverUrlFocus,
              style: const TextStyle(
                  fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                hintText: 'http://10.0.2.2:3000/api',
                hintStyle: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppTheme.textSecondary),
                labelText: 'Адрес сервера',
                labelStyle: TextStyle(fontSize: 11),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Сбросить',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () async {
              _serverUrlController.text = AuthController.apiBaseUrl;
              await LocalStorageService.instance
                  .deleteApiBaseUrl();
              AuthController.overrideApiBaseUrl(
                  AuthController.apiBaseUrl);
            },
          ),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController c,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    FocusNode? nextFocus,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: nextFocus != null
          ? (_) => nextFocus.requestFocus()
          : onSubmitted,
      validator: validator,
      enabled: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }
}
