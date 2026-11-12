// Публичный профиль (ТЗ §16.4): статистика, снаряжение, лента автора, чат.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/session_controller.dart';
import '../core/api_client.dart';
import '../core/json_utils.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/state_views.dart';
import 'chat_screen.dart';
import 'track_screen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  Map<String, dynamic>? _profile;
  List<Track> _tracks = const [];
  List<Post> _posts = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<SessionController>().api;
      final results = await Future.wait([
        api.users.profile(widget.userId),
        api.tracks.list(scope: 'published', limit: 20),
        api.posts.list(authorId: widget.userId, limit: 10),
      ]);
      if (!mounted) return;
      final tracks = (results[1] as List<Track>)
          .where((t) => t.userId == widget.userId)
          .toList();
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _tracks = tracks;
        _posts = results[2] as List<Post>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final user =
        profile == null ? null : AppUser.fromJson(asMap(profile['user']));
    final stats = profile == null ? null : asMap(profile['stats']);
    final canView = profile == null ? true : asBool(profile['canView'], true);
    final isSelf = profile != null && asBool(profile['isSelf']);
    final session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(title: Text(user?.name ?? 'Профиль')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : user == null
                  ? const EmptyView(title: 'Профиль недоступен')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                                name: user.name,
                                url: user.avatarUrl,
                                radius: 34),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name,
                                      style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900)),
                                  Text(
                                    [
                                      user.displayCity,
                                      '${user.xp} XP',
                                    ].where((s) => s.isNotEmpty).join(' • '),
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary),
                                  ),
                                  if (user.bio != null) ...[
                                    const SizedBox(height: 6),
                                    Text(user.bio!),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (!canView)
                          const EmptyView(
                            title: 'Профиль скрыт настройками приватности',
                            compact: true,
                          )
                        else if (stats != null) ...[
                          Row(
                            children: [
                              Expanded(
                                  child: StatTile(
                                      label: 'Заплывов',
                                      value:
                                          '${asInt(stats['eventsAttended'])}')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: StatTile(
                                      label: 'Маршрутов',
                                      value:
                                          '${asInt(stats['tracksPublished'])}')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: StatTile(
                                      label: 'Друзей',
                                      value: '${asInt(stats['friends'])}')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: StatTile(
                                      label: 'Организовано',
                                      value:
                                          '${asInt(stats['eventsOrganized'])}')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: StatTile(
                                      label: 'Объявлений',
                                      value:
                                          '${asInt(stats['listingsActive'])}')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: StatTile(
                                      label: 'Рейтинг',
                                      value: asDouble(stats['ratingAverage'])
                                          .toStringAsFixed(1))),

                            ],
                          ),
                        ],
                        if (!isSelf && user.id != session.user?.id) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => _openChat(user),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('НАПИСАТЬ'),
                          ),
                        ],
                        if (_tracks.isNotEmpty) ...[
                          const SectionTitle('Маршруты'),
                          for (final track in _tracks)
                            RouteCard(
                              track: track,
                              showAuthor: false,
                              onTap: () =>
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          TrackScreen(trackId: track.id))),
                            ),
                        ],
                        if (_posts.isNotEmpty) ...[
                          const SectionTitle('Записи'),
                          for (final post in _posts) PostCard(post: post),
                        ],
                        if (profile != null &&
                            asBool(profile['isFriend']) &&
                            !isSelf)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'В друзьях • ${user.roleLabel}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                      ],
                    ),
    );
  }

  Future<void> _openChat(AppUser user) async {
    final chats = context.read<ChatsController>();
    final id = await chats.directWith(user.id);
    if (id == null) {
      if (mounted && chats.actionError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(chats.actionError!)));
      }
      return;
    }
    await chats.open(id);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: id, title: user.name),
    ));
  }
}
