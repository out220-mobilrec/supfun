// Диалог «Найден незавершённый заплыв» (ТЗ §12.5): продолжить,
// завершить и сохранить, удалить.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tracking_controller.dart';
import '../core/formatting.dart';
import '../services/track_store.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';
import 'tracking_screen.dart';

Future<void> showResumeSwimSheet(
        BuildContext context, PendingRecording pending) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ResumeSwimSheet(pending: pending),
    );

class _ResumeSwimSheet extends StatefulWidget {
  const _ResumeSwimSheet({required this.pending});

  final PendingRecording pending;

  @override
  State<_ResumeSwimSheet> createState() => _ResumeSwimSheetState();
}

class _ResumeSwimSheetState extends State<_ResumeSwimSheet> {
  bool _busy = false;

  Future<void> _finishAndSave() async {
    final tracking = context.read<TrackingController>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final started = await tracking.resumeRecording(widget.pending.recording);
    if (!started) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tracking.permissionMessage ??
              'Не удалось продолжить запись')));
      return;
    }
    final outcome = await tracking.finish();
    if (!mounted) return;
    navigator
      ..pop()
      ..push(MaterialPageRoute(
          builder: (_) => ResultScreen(outcome: outcome)));
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.read<TrackingController>();
    final recording = widget.pending.recording;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Найден незавершённый заплыв',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${dayLabel(recording.startedAt)} • '
              '${distanceLabel(recording.distanceMeters)} • '
              '${durationLabel(Duration(seconds: recording.durationSeconds))}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (widget.pending.pendingPoints > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Ждут отправки ${countLabel(widget.pending.pendingPoints, 'точка', 'точки', 'точек')}',
                  style: const TextStyle(
                      color: AppTheme.warningColor, fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TrackingScreen(
                              resume: recording)));
                    },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Продолжить'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _finishAndSave,
              icon: const Icon(Icons.save_alt_rounded),
              label: Text(_busy
                  ? 'Завершаем…'
                  : 'Завершить и сохранить'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      await tracking.deleteUnfinished(recording.id);
                      navigator.pop();
                    },
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }
}
