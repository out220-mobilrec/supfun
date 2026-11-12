import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'src/app_state.dart';
import 'src/core/session.dart';
import 'src/gate.dart';
import 'src/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  final appState = AppState();
  await appState.bootstrap();
  runApp(SuperFunApp(state: appState));
}

class SuperFunApp extends StatefulWidget {
  const SuperFunApp({super.key, required this.state});

  final AppState state;

  @override
  State<SuperFunApp> createState() => _SuperFunAppState();
}

class _SuperFunAppState extends State<SuperFunApp> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp(
          title: 'SUP FUN',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: widget.state.themeMode,
          locale: Locale(widget.state.locale),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        ),
      ),
    );
  }
}