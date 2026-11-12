import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../profile/user_profile_screen.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  String _scope = 'all';
  RatingResponse? _data;
  bool _loading = true;
  String? _error;

  static const _scopes = <String, String>{
    'all': 'Все',
    'friends': 'Друзья',
    'city': 'Город',
    'region': 'Регион',
    'country': 'Страна',
    'season': 'Сезон',
  };

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
      final j = await ApiClient.instance
          .get('/ratings/leaderboard', query: {'scope': _scope, 'limit': 100});
      if (!mounted) return;
      setState(() {
        _data = RatingResponse.fromJson(j);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рейтинг'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _scopes.entries.map((e) {
                final selected = _scope == e.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _scope = e.key);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (_data?.seasonYear != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text('Сезон ${_data!.seasonYear}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white54)),
                        ),
                      if (_data?.me != null) _rankingRow(_data!.me!, me: true),
                      ...?(_data?.entries.map((e) => _rankingRow(e))),
                    ],
                  ),
                ),
    );
  }

  Widget _rankingRow(RatingEntry e, {bool me = false}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: me ? AppColors.primary.withValues(alpha: 0.14) : null,
      child: ListTile(
        leading: SizedBox(
          width: 34,
          child: Text('${e.rank}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: e.rank == 1
                      ? const Color(0xFFFFB000)
                      : cs.onSurfaceVariant)),
        ),
        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(e.city ?? e.region ?? e.country ?? '',
            style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${e.xp}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('уровень ${e.level}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: e.id))),
      ),
    );
  }
}