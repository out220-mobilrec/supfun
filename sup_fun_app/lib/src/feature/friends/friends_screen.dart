import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../chat/chat_screen.dart';
import '../profile/user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<SimpleUser>? _friends;
  List<FriendRequest>? _incoming;
  List<FriendRequest>? _outgoing;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = await ApiClient.instance.getList('/friends');
      final inc = await ApiClient.instance.getList('/friends/requests/incoming');
      final out = await ApiClient.instance.getList('/friends/requests/outgoing');
      if (!mounted) return;
      setState(() {
        _friends = f.map((e) => SimpleUser.fromJson(e)).toList();
        _incoming = inc.map((e) => FriendRequest.fromJson(e)).toList();
        _outgoing = out.map((e) => FriendRequest.fromJson(e)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Ошибка сети');
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() {
      _error = m;
      _loading = false;
    });
  }

  Future<void> _respond(FriendRequest r, bool accept) async {
    try {
      if (accept) {
        await ApiClient.instance.post('/friends/requests/${r.id}/accept');
      } else {
        await ApiClient.instance.post('/friends/requests/${r.id}/reject');
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Друзья'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Друзья'),
              Tab(text: 'Заявки'),
              Tab(text: 'Отправленные'),
            ],
          ),
        ),
        body: _loading
            ? const AppLoading()
            : _error != null
                ? ErrorBanner(message: _error!, onRetry: _load)
                : TabBarView(
                    children: [
                      _friendsTab(),
                      _incomingTab(),
                      _outgoingTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _friendsTab() {
    final f = _friends ?? const [];
    if (f.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        EmptyState(icon: Icons.people_outline, text: 'Пока нет друзей'),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: f.length,
        itemBuilder: (_, i) {
          final u = f[i];
          return Card(
            child: ListTile(
              leading: AppAvatar(u.avatarUrl, size: 40),
              title: Text(u.name),
              subtitle: u.city != null ? Text(u.city!) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined,
                        color: AppColors.primary),
                    onPressed: () => _openDirect(u.id),
                  ),
                ],
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: u.id))),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDirect(String userId) async {
    try {
      final j = await ApiClient.instance
          .post('/conversations/direct', data: {'userId': userId});
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: j['id'] as String)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _incomingTab() {
    final inc = _incoming ?? const [];
    if (inc.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        EmptyState(icon: Icons.person_add_alt, text: 'Новых заявок нет'),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: inc.length,
      itemBuilder: (_, i) {
        final r = inc[i];
        return Card(
          child: ListTile(
            leading: AppAvatar(r.requester?.avatarUrl, size: 40),
            title: Text(r.requester?.name ?? ''),
            subtitle: const Text('хочет добавить вас в друзья'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green, size: 26),
                  onPressed: () => _respond(r, true),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.danger, size: 26),
                  onPressed: () => _respond(r, false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _outgoingTab() {
    final out = _outgoing ?? const [];
    if (out.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        EmptyState(icon: Icons.send, text: 'Отправленных заявок нет'),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: out.length,
      itemBuilder: (_, i) {
        final r = out[i];
        return Card(
          child: ListTile(
            leading: AppAvatar(r.addressee?.avatarUrl, size: 40),
            title: Text(r.addressee?.name ?? ''),
            subtitle: const Text('Заявка отправлена'),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: AppColors.danger),
              onPressed: () async {
                await ApiClient.instance
                    .delete('/friends/requests/${r.id}');
                _load();
              },
            ),
          ),
        );
      },
    );
  }
}