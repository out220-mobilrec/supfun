import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../chat/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  ProfileView? _view;
  bool _loading = true;
  String? _error;
  bool _busy = false;

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
      final j = await ApiClient.instance.get('/users/${widget.userId}/profile');
      if (!mounted) return;
      setState(() {
        _view = ProfileView.fromJson(j);
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

  Future<void> _addFriend() async {
    setState(() => _busy = true);
    try {
      await ApiClient.instance.post('/friends/requests', data: {'userId': widget.userId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    setState(() => _busy = false);
  }

  void _openChat() {
    // Open or create direct conversation
    _openDirectConversation();
  }

  Future<void> _openDirectConversation() async {
    setState(() => _busy = true);
    try {
      final j = await ApiClient.instance.post('/conversations/direct',
          data: {'userId': widget.userId});
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatScreen(conversationId: j['id'] as String)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: AppLoading());
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(), body: ErrorBanner(message: _error!, onRetry: _load));
    }
    final v = _view!;
    final u = v.user;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              AppAvatar(u.avatarUrl, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name,
                        style:
                            const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (u.city != null || u.region != null)
                      Text([u.city, u.region].whereType<String>().join(', '),
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant)),
                    if (v.isSelf) const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
          if (u.bio != null && u.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(u.bio!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (u.homeWaterBody != null) ...[
            const SizedBox(height: 8),
            Text('Домашний водоём: ${u.homeWaterBody!.name}',
                style: const TextStyle(fontSize: 13, color: AppColors.secondary)),
          ],
          if (v.blocked) ...[
            const SizedBox(height: 20),
            const EmptyState(icon: Icons.block, text: 'Профиль заблокирован'),
          ] else if (!v.canView) ...[
            const SizedBox(height: 20),
            const EmptyState(
                icon: Icons.lock_outline, text: 'Профиль скрыт его владельцем'),
          ] else ...[
            const SizedBox(height: 20),
            if (v.stats != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatPill(value: '${v.stats!.friends}', label: 'Друзья'),
                    StatPill(value: '${v.stats!.tracksPublished}', label: 'Заплывы'),
                    StatPill(value: '${v.stats!.eventsOrganized}', label: 'События'),
                    if (v.stats!.ratingAverage > 0)
                      StatPill(value: v.stats!.ratingAverage.toStringAsFixed(1), label: 'Рейтинг'),
                  ],
                ),
              ),
            _actions(v),
          ],
        ],
      ),
    );
  }

  Widget _actions(ProfileView v) {
    if (v.isSelf) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 8),
        if (!v.isFriend)
          FilledButton(
            onPressed: _busy ? null : _addFriend,
            child: const Text('Добавить в друзья'),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Вы — друзья',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        OutlinedButton(
          onPressed: _openChat,
          child: const Text('Написать сообщение'),
        ),
      ],
    );
  }
}