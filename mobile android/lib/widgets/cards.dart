// Переиспользуемые карточки и элементы интерфейса SUP FUN.
// Визуальный язык — как в макетах SUP_FUN_Flutter_v0.1_VISUAL_FULL:
// крупные заголовки, скругления 20-28, бирюзово-синий градиент на акценте.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onNotifications,
    this.unread = 0,
    this.onProfile,
    this.avatarUrl,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onNotifications;
  final int unread;
  final VoidCallback? onProfile;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 52, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 12),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            if (onNotifications != null)
              IconButton(
                onPressed: onNotifications,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onProfile,
                child: UserAvatar(name: '', url: avatarUrl, radius: 19),
              ),
            ),
          ],
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 22,
  });

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryLight.withValues(alpha: .16),
      foregroundImage: url != null && url!.startsWith('http')
          ? CachedNetworkImageProvider(url!)
          : null,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: radius * .78,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryDark,
        ),
      ),
    );
  }
}

class EventHeroCard extends StatelessWidget {
  const EventHeroCard({super.key, required this.event, this.onTap});

  final SupEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final distance = event.expectedDistanceMeters;
    final meta = [
      eventWhenLabel(event.eventDate),
      if (distance != null) distanceLabel(distance),
      if (event.waterBodyName != null) event.waterBodyName!,
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF007F86), Color(0xFF003D62)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'БЛИЖАЙШИЙ ЗАПЛЫВ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      countdownLabel(event.eventDate),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meta,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.groups_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      countLabel(event.participantCount, 'участник',
                          'участника', 'участников'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Открыть'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap, this.trailing});

  final SupEvent event;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: _Thumb(
            emoji: '🏄',
            color: const Color(0xFF00A6A6),
          ),
          title: Text(
            event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                eventWhenLabel(event.eventDate),
                event.levelLabel,
                countLabel(event.participantCount, 'уч.', 'уч.', 'уч.'),
              ].join(' • '),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          trailing: trailing ?? const Icon(Icons.chevron_right),
        ),
      );
}

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.track,
    this.onTap,
    this.trailing,
    this.showAuthor = true,
  });

  final Track track;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Thumb(emoji: '🌊', color: const Color(0xFF006B8F)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          distanceLabel(track.distanceMeters),
                          durationLabel(Duration(seconds: track.durationSeconds)),
                          track.difficultyLabel,
                        ].join(' • '),
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      if (showAuthor && track.authorName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            track.authorName!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}

class WaterbodyTile extends StatelessWidget {
  const WaterbodyTile({
    super.key,
    required this.waterBody,
    this.distanceMeters,
    this.onTap,
  });

  final WaterBody waterBody;
  final double? distanceMeters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        child: ListTile(
          onTap: onTap,
          leading: const _Thumb(emoji: '💧', color: Color(0xFF2E6A92)),
          title: Text(
            waterBody.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              waterBody.region ?? '',
              if (distanceMeters != null)
                distanceLabel(distanceMeters!, fractionDigits: 0),
            ].where((s) => s.isNotEmpty).join(' • '),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class ListingTile extends StatelessWidget {
  const ListingTile({super.key, required this.listing, this.onTap});

  final Listing listing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(20, 5, 20, 5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        child: ListTile(
          onTap: onTap,
          leading: listing.photos.isEmpty
              ? const _Thumb(emoji: '🛶', color: AppTheme.primaryColor)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: CachedNetworkImage(
                    imageUrl: listing.photos.first,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const _Thumb(emoji: '🛶', color: AppTheme.primaryColor),
                  ),
                ),
          title: Text(
            listing.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${listing.priceLabel} • ${listing.sellerName}'
            '${listing.city == null ? '' : ' • ${listing.city}'}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          trailing: Text(
            listing.statusLabel,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      );
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onLike, this.onTap});

  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(20, 5, 20, 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(name: post.authorName, url: post.authorAvatar),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${post.typeLabel} • ${relativeTimeLabel(post.createdAt)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (post.title != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    post.title!,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
                if (post.body != null) ...[
                  const SizedBox(height: 6),
                  Text(post.body!),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: onLike,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        post.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: post.likedByMe ? Colors.red : null,
                      ),
                    ),
                    Text('${post.likeCount}'),
                    const SizedBox(width: 14),
                    const Icon(Icons.mode_comment_outlined, size: 20),
                    const SizedBox(width: 6),
                    Text('${post.commentCount}'),
                    const Spacer(),
                    Text(
                      fullDateLabel(post.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.level});

  final LevelInfo level;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Уровень ${level.level}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '${level.xp} XP',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 8,
                backgroundColor: AppTheme.borderColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${level.currentLevelXp} / ${level.nextLevelXp} XP до следующего уровня',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
}

class DifficultyChips extends StatelessWidget {
  const DifficultyChips({super.key, this.value, this.onChanged});

  final TrackDifficulty? value;
  final ValueChanged<TrackDifficulty?>? onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('Все'),
            selected: value == null,
            onSelected: (_) => onChanged?.call(null),
          ),
          for (final difficulty in TrackDifficulty.values)
            FilterChip(
              label: Text(difficulty.label),
              selected: value == difficulty,
              onSelected: (_) => onChanged?.call(difficulty),
            ),
        ],
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, AppTheme.primaryDark],
          ),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      );
}
