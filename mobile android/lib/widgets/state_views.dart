// Общий виджет состояний раздела: загрузка / ошибка / пусто / offline
// (ТЗ §30 требует различать эти три случая).
import 'package:flutter/material.dart';

import '../controllers/load_state.dart';
import '../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            if (label != null) ...[
              const SizedBox(height: 14),
              Text(label!, style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.isNetwork = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isNetwork;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 44,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              isNetwork
                  ? 'Нет подключения к интернету'
                  : 'Не удалось загрузить данные',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_rounded,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 28, vertical: compact ? 24 : 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 32 : 44, color: AppTheme.borderColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 15 : 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

/// Раздел, который сам решает, что показать: спиннер, ошибку, пустоту
/// или данные. [skipEmpty] — когда пустой список нормален и показывается
/// внутри обычного контента.
class SectionView<T> extends StatelessWidget {
  const SectionView({
    super.key,
    required this.section,
    required this.builder,
    this.onRetry,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon,
    this.actionLabel,
    this.onAction,
    this.loadingLabel,
    this.showOfflineHint = true,
  });

  final Section<T> section;
  final Widget Function(T value) builder;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptySubtitle;
  final IconData? emptyIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? loadingLabel;
  final bool showOfflineHint;

  @override
  Widget build(BuildContext context) {
    switch (section.state) {
      case LoadState.idle:
      case LoadState.loading:
        if (section.data != null) return builder(section.data as T);
        return LoadingView(label: loadingLabel);
      case LoadState.error:
        if (section.data != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfflineHint(),
              builder(section.data as T),
            ],
          );
        }
        return ErrorView(
          message: section.error ?? '',
          onRetry: onRetry,
          isNetwork: section.offline,
        );
      case LoadState.empty:
        return EmptyView(
          title: emptyTitle ?? 'Пока пусто',
          subtitle: emptySubtitle,
          actionLabel: actionLabel,
          onAction: onAction,
          icon: emptyIcon ?? Icons.inbox_rounded,
        );
      case LoadState.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (section.offline && showOfflineHint) const OfflineHint(),
            builder(section.data as T),
          ],
        );
    }
  }
}

class OfflineHint extends StatelessWidget {
  const OfflineHint({
    super.key,
    this.text = 'Нет сети — показаны сохранённые данные',
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 18, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}
