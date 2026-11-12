import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/auth.dart';

class AuthApi {
  static Future<void> persist(AuthResult r) async {
    ApiClient.instance.attachRefresh(r.refreshToken);
    await Session.save(
      accessToken: r.accessToken,
      refreshToken: r.refreshToken,
      sessionUser: r.user,
    );
  }

  static Future<AuthResult> login(String email, String password) async {
    final j = await ApiClient.instance.post('/auth/login', data: {
      'email': email.trim(),
      'password': password,
    });
    final r = AuthResult.fromJson(j);
    await persist(r);
    return r;
  }

  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? city,
  }) async {
    final j = await ApiClient.instance.post('/auth/register', data: {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (city != null && city.isNotEmpty) 'city': city.trim(),
    });
    final r = AuthResult.fromJson(j);
    await persist(r);
    return r;
  }

  static Future<MessageResult> resendVerification() async {
    final j = await ApiClient.instance.post('/auth/resend-verification');
    return MessageResult.fromJson(j);
  }

  static Future<bool> verifyEmail(String token) async {
    final j = await ApiClient.instance.post('/auth/verify-email', data: {'token': token});
    return (j['ok'] ?? false) as bool;
  }

  static Future<MessageResult> forgotPassword(String email) async {
    final j = await ApiClient.instance.post('/auth/forgot-password', data: {'email': email.trim()});
    return MessageResult.fromJson(j);
  }

  static Future<bool> resetPassword(String token, String password) async {
    final j = await ApiClient.instance
        .post('/auth/reset-password', data: {'token': token, 'password': password});
    return (j['ok'] ?? false) as bool;
  }

  static Future<AuthResult> changePassword(String currentPassword, String newPassword) async {
    final j = await ApiClient.instance.post('/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    final r = AuthResult.fromJson(j);
    await persist(r);
    return r;
  }

  static Future<void> logout(String refreshToken) async {
    try {
      if (refreshToken.isNotEmpty) {
        await ApiClient.instance.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
  }
}

class ShowDevToken extends StatelessWidget {
  const ShowDevToken({required this.devToken, super.key});

  final String? devToken;

  @override
  Widget build(BuildContext context) {
    if (devToken == null || devToken!.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF22302D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Тестовый токен:',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: devToken!)),
            child: Text(
              devToken!,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    required this.title,
    super.key,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.kayaking,
                      size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'SUP FUN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}