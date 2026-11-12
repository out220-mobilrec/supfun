import 'package:flutter/material.dart';

import 'core/session.dart';
import 'feature/auth/login_screen.dart';
import 'feature/root_shell.dart';
import 'models/auth.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionUser?>(
      valueListenable: Session.user,
      builder: (context, user, _) {
        if (!Session.initialized.value) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const LoginScreen();
        }
        return const RootShell();
      },
    );
  }
}