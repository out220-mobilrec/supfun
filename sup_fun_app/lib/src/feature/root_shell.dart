import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/track_sync_service.dart';
import 'chat/conversations_screen.dart';
import 'create/quick_actions.dart';
import 'home/home_screen.dart';
import 'map/map_screen.dart';
import 'profile/profile_screen.dart';
import 'tracks/track_live_screen.dart';
import 'tracks/tracks_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  bool _recoveryPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptRecovery());
  }

  Future<void> _maybePromptRecovery() async {
    if (!mounted || _recoveryPrompted) return;
    final app = context.read<AppState>();
    final u = app.unfinishedTrack;
    if (u == null) return;
    _recoveryPrompted = true;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.status == 'pending_complete'
            ? 'Заплыв ожидает отправки'
            : 'Незавершённый заплыв'),
        content: const Text(
            'Найдена запись заплыва на устройстве. Можно продолжить, завершить и отправить, или открыть список заплывов.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'later'), child: const Text('Позже')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'tracks'), child: const Text('К списку')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'continue'), child: const Text('Продолжить')),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'continue') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => TrackLiveScreen(resumeLocalId: u.localId)));
      if (mounted) await context.read<AppState>().refreshUnfinishedTrack();
    } else if (action == 'tracks') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TracksScreen()));
      if (mounted) await context.read<AppState>().refreshUnfinishedTrack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AppState>().socketUnread;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          MapScreen(),
          SizedBox.shrink(),
          ConversationsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 2) {
            QuickActions.show(context);
            return;
          }
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          const NavigationDestination(
              icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Карта'),
          NavigationDestination(
            icon: Icon(Icons.add_circle,
                color: Theme.of(context).colorScheme.primary, size: 32),
            label: 'Создать',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.message_outlined),
            ),
            selectedIcon: const Icon(Icons.message),
            label: 'Чаты',
          ),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
