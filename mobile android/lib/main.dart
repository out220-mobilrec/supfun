// Точка входа и навигация SUP FUN.
//
// Нижняя панель — 5 разделов по ТЗ §3: Главная, Карта, «+», Сообщения,
// Профиль. Корень выбирает экран по состоянию сессии: сплеш во время
// тихого входа, форма входа либо шелл.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/events_controller.dart';
import 'controllers/feed_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/map_controller.dart';
import 'controllers/marketplace_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/session_controller.dart';
import 'controllers/tracking_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/chats_list_screen.dart';
import 'screens/community_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/events_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/prestart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_storage.dart';
import 'services/track_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.instance.init();
  await TrackStore.instance.init();
  runApp(const SupFunApp());
}

class SupFunApp extends StatelessWidget {
  const SupFunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionController()..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              HomeController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              MapLayersController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              WaterbodyController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              EventsController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              FeedController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ChatsController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ProfileController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              NotificationsController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              MarketplaceController(context.read<SessionController>().api),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              TrackingController(context.read<SessionController>()),
        ),
      ],
      child: Consumer<SessionController>(
        builder: (context, session, _) => MaterialApp(
          title: 'SUP FUN',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: switch (session.status) {
            SessionStatus.starting ||
            SessionStatus.restoring =>
              const SplashScreen(),
            SessionStatus.signedOut => const AuthScreen(),
            SessionStatus.signedIn => const Shell(),
          },
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<ChatsController>().totalUnread;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenProfile: () => _go(3)),
          const MapScreen(),
          const ChatsListScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => showQuickActions(context),
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add, size: 34, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 74,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              label: 'Главная',
              icon: Icons.home_rounded,
              selected: _index == 0,
              onTap: () => _go(0),
            ),
            _NavItem(
              label: 'Карта',
              icon: Icons.map_rounded,
              selected: _index == 1,
              onTap: () => _go(1),
            ),
            const SizedBox(width: 68),
            _NavItem(
              label: 'Сообщения',
              icon: Icons.mode_comment_outlined,
              selected: _index == 2,
              badge: unread,
              onTap: () => _go(2),
            ),
            _NavItem(
              label: 'Профиль',
              icon: Icons.person_rounded,
              selected: _index == 3,
              onTap: () => _go(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(
                  icon,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Быстрые действия по центральной кнопке (ТЗ §3.3).
Future<void> showQuickActions(BuildContext context) {
  final navigator = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Что хотите сделать?',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _Action(
              emoji: '🏄',
              title: 'Начать трекинг',
              subtitle: 'Записать заплыв по GPS',
              onTap: () => navigator.push(
                  MaterialPageRoute(builder: (_) => const PrestartScreen())),
            ),
            _Action(
              emoji: '📅',
              title: 'Создать заплыв',
              subtitle: 'Одиночный или групповой',
              onTap: () => navigator.push(
                  MaterialPageRoute(builder: (_) => const CreateEventScreen())),
            ),
            _Action(
              emoji: '🧭',
              title: 'Найти заплыв',
              subtitle: 'Присоединиться к компании',
              onTap: () => navigator.push(
                  MaterialPageRoute(builder: (_) => const EventsScreen())),
            ),
            _Action(
              emoji: '💬',
              title: 'Сообщество',
              subtitle: 'Лента активности',
              onTap: () => navigator.push(
                  MaterialPageRoute(builder: (_) => const CommunityScreen())),
            ),
            _Action(
              emoji: '🛒',
              title: 'Маркетплейс',
              subtitle: 'Купить или продать снаряжение',
              onTap: () => navigator.push(
                  MaterialPageRoute(builder: (_) => const MarketplaceScreen())),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: .08),
          child: Text(emoji, style: const TextStyle(fontSize: 21)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      );
}
