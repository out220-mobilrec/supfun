import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import '../channels/channels_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/events_screen.dart';
import '../friends/friends_screen.dart';
import '../market/listing_detail_screen.dart';
import '../market/marketplace_screen.dart';
import '../news/news_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/achievements_screen.dart';
import '../profile/rating_screen.dart';
import '../profile/user_profile_screen.dart';
import '../search/search_screen.dart';
import '../tracks/tracks_screen.dart';
import '../waterbodies/waterbodies_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FeedResponse? _feed;
  LevelInfo? _level;
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
      final j = await ApiClient.instance.get('/feed', query: {'limit': 10});
      final levelJ = await ApiClient.instance.get('/gamification/me');
      if (!mounted) return;
      setState(() {
        _feed = FeedResponse.fromJson(j);
        _level = LevelInfo.fromJson(levelJ);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка сети';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final unreadN = app.unreadNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SUP FUN',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadN > 0,
              label: Text(unreadN > 99 ? '99+' : '$unreadN'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [AppLoading()])
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                        const SizedBox(height: 24),
                        ErrorBanner(message: _error!, onRetry: _load),
                      ])
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final cs = Theme.of(context).colorScheme;
    final feed = _feed!;
    return ListView(
      children: [
        _hero(cs),
        _quickActions(cs),
        if (feed.events.isNotEmpty) ...[
          const SectionHeader('Предстоящие события'),
          ...feed.events.map((e) => _feedEventCard(e)),
        ],
        if (feed.routes.isNotEmpty) ...[
          const SectionHeader('Свежие заплывы'),
          ...feed.routes.map((r) => _feedRouteCard(r)),
        ],
        if (feed.listings.isNotEmpty) ...[
          const SectionHeader('Снаряжение на продажу'),
          ...feed.listings.map((l) => _feedListingCard(cs, l)),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _hero(ColorScheme cs) {
    final u = context.watch<AppState>().user;
    final level = _level;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00A389), Color(0xFF008A74)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Привет, ${u?.name ?? ''}!',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (level != null)
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text('Ур. ${level.level} · ${level.xp} XP',
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white24,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, size: 16),
                      SizedBox(width: 6),
                      Text('Достижения', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppAvatar(u?.avatarUrl, size: 64, border: true),
        ],
      ),
    );
  }

  Widget _quickActions(ColorScheme cs) {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.event, 'События', () => _openEvents()),
      (Icons.storefront_outlined, 'Барахолка', () => _openMarket()),
      (Icons.people_outline, 'Друзья', () => _openFriends()),
      (Icons.leaderboard_outlined, 'Рейтинг', () => _openRating()),
      (Icons.waves, 'Заплывы', () => _openTracks()),
      (Icons.lock_outline, 'Каналы', () => _openChannels()),
      (Icons.newspaper, 'Новости', () => _openNews()),
      (Icons.water, 'Водоёмы', () => _openWaterbodies()),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.95,
        children: actions
            .map((a) => InkWell(
                  onTap: a.$3,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(a.$1, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(a.$2, style: TextStyle(fontSize: 11, color: cs.onSurface)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _openEvents() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const EventsScreen()));
  }

  void _openMarket() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const MarketplaceScreen()));
  }

  void _openFriends() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const FriendsScreen()));
  }

  void _openRating() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const RatingScreen()));
  }

  void _openTracks() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TracksScreen()));
  }

  void _openChannels() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ChannelsScreen()));
  }

  void _openNews() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const NewsScreen()));
  }

  void _openWaterbodies() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const WaterbodiesScreen()));
  }

  Widget _feedEventCard(FeedEvent e) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: e.id))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event, color: AppColors.primary),
        ),
        title: Text(e.title ?? 'Без названия',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (e.eventDate != null)
              Text(
                  '${dayLabel(e.eventDate!)} · ${timeLabel(e.eventDate!)} · ${e.organizerName ?? ''}',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
            if (e.waterBodyName != null)
              Text(e.waterBodyName!,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
        trailing: Icon(Icons.chevron_right,
            color: cs.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _feedRouteCard(FeedRoute r) {
    final cs = Theme.of(context).colorScheme;
    final dist = r.distanceMeters >= 1000
        ? '${(r.distanceMeters / 1000).toStringAsFixed(1)} км'
        : '${r.distanceMeters.round()} м';
    return Card(
      child: ListTile(
        onTap: r.userId != null
            ? () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: r.userId!)))
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.waves, color: AppColors.primary, size: 28),
        title: Text(r.name ?? 'Заплыв',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${r.userName ?? ''} · $dist',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
        trailing: Icon(Icons.chevron_right,
            color: cs.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _feedListingCard(ColorScheme cs, FeedListing l) {
    final price = l.price != null
        ? '${_fmtNum(l.price!)} ${l.currency ?? '₽'}'
        : 'Без цены';
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listingId: l.id))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: l.photos.isNotEmpty
                ? Image.network(AppConfig.absUrl(l.photos.first),
                    fit: BoxFit.cover)
                : Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.inventory_2_outlined)),
          ),
        ),
        title: Text(l.title ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$price · ${l.city ?? ''}',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
      ),
    );
  }

  String _fmtNum(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1);
}