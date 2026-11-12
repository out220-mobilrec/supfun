import 'dart:async';

import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../events/event_detail_screen.dart';
import '../market/listing_detail_screen.dart';
import '../profile/user_profile_screen.dart';
import '../tracks/track_detail_screen.dart';
import '../waterbodies/waterbody_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  SearchResponse? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(v));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _result = null;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ApiClient.instance.get('/search', query: {'q': q});
      if (!mounted) return;
      setState(() {
        _result = SearchResponse.fromJson(j);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка сети';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _q,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Водоёмы, события, люди, снаряжение…',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
          ),
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return ErrorBanner(message: _error!, onRetry: () => _search(_q.text));
    }
    final r = _result;
    if (r == null || r.isEmpty) {
      return const EmptyState(icon: Icons.search, text: 'Ничего не найдено');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (r.users.isNotEmpty) ...[
          const SectionHeader('Люди'),
          ...r.users.map(_userTile),
        ],
        if (r.waterbodies.isNotEmpty) ...[
          const SectionHeader('Водоёмы'),
          ...r.waterbodies.map(_waterbodyTile),
        ],
        if (r.events.isNotEmpty) ...[
          const SectionHeader('События'),
          ...r.events.map(_eventTile),
        ],
        if (r.listings.isNotEmpty) ...[
          const SectionHeader('Снаряжение'),
          ...r.listings.map(_listingTile),
        ],
        if (r.tracks.isNotEmpty) ...[
          const SectionHeader('Заплывы'),
          ...r.tracks.map(_trackTile),
        ],
      ],
    );
  }

  Widget _userTile(SimpleUser u) {
    return ListTile(
      leading: AppAvatar(u.avatarUrl, size: 40),
      title: Text(u.name),
      subtitle: u.city != null ? Text(u.city!) : null,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => UserProfileScreen(userId: u.id))),
    );
  }

  Widget _waterbodyTile(WaterBody w) {
    return ListTile(
      leading: const Icon(Icons.water, color: AppColors.sea),
      title: Text(w.name),
      subtitle: w.region != null ? Text(w.region!) : null,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => WaterbodyDetailScreen(waterBodyId: w.id))),
    );
  }

  Widget _eventTile(FeedEvent e) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id))),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event, color: AppColors.primary),
        ),
        title: Text(e.title ?? 'Событие', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          e.eventDate != null
              ? '${dayLabel(e.eventDate!)} · ${timeLabel(e.eventDate!)}'
              : e.organizerName ?? '',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _listingTile(FeedListing l) {
    return ListTile(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: l.id))),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: l.photos.isNotEmpty
              ? Image.network(AppConfig.absUrl(l.photos.first), fit: BoxFit.cover)
              : Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
        ),
      ),
      title: Text(l.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: l.price != null
          ? Text('${l.price!.round()} ${l.currency ?? '₽'}')
          : null,
    );
  }

  Widget _trackTile(FeedRoute t) {
    return ListTile(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TrackDetailScreen(trackId: t.id))),
      leading: const Icon(Icons.waves, color: AppColors.primary),
      title: Text(t.name ?? 'Заплыв', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${t.userName ?? ''} · ${t.distanceMeters.round()} м'),
    );
  }
}