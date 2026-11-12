import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------
class AppAvatar extends StatelessWidget {
  const AppAvatar(this.url, {this.size = 40, this.border = false, super.key});

  final String? url;
  final double size;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final borderCol = border ? AppColors.primary : Colors.transparent;
    final resolved = AppConfig.absUrl(url);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: border ? Border.all(color: borderCol, width: 2.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: resolved.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              placeholder: (_, _) => Icon(Icons.person, size: size * 0.55, color: Colors.white54),
              errorWidget: (_, _, _) => Icon(Icons.person, size: size * 0.55, color: Colors.white54),
            )
          : Icon(Icons.person, size: size * 0.55, color: Colors.white54),
    );
  }
}

// ---------------------------------------------------------------------------
// Level pill
// ---------------------------------------------------------------------------
class LevelPill extends StatelessWidget {
  const LevelPill({required this.level, this.compact = false, super.key});

  final int level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 11.0 : 12.0;
    final padH = compact ? 6.0 : 8.0;
    final padV = compact ? 2.0 : 3.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Ур. $level',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: AppColors.accent),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat pill
// ---------------------------------------------------------------------------
class StatPill extends StatelessWidget {
  const StatPill({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.text, this.action, super.key});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onSurface.withValues(alpha: 0.22)),
            const SizedBox(height: 16),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.55))),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading indicator
// ---------------------------------------------------------------------------
class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8), fontSize: 14)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day label helper
// ---------------------------------------------------------------------------
String dayLabel(DateTime d) {
  final now = DateTime.now().toUtc();
  final day = DateTime.utc(d.year, d.month, d.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  if (day == today) return 'Сегодня';
  if (day == today.subtract(const Duration(days: 1))) return 'Вчера';
  return '${d.day}.${d.month.toString().padLeft(2, '0')}';
}

String timeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String rucase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';