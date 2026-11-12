import 'package:flutter/material.dart';

import '../channels/channels_screen.dart';
import '../chat/conversations_screen.dart';
import '../events/event_form_screen.dart';
import '../market/listing_form_screen.dart';
import '../tracks/track_live_screen.dart';

class QuickActions {
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Создать',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            _action(
              context,
              icon: Icons.event,
              title: 'Создать событие',
              onTap: () => _open(context, const EventFormScreen()),
            ),
            _action(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Добавить снаряжение',
              onTap: () => _open(context, const ListingFormScreen()),
            ),
            _action(
              context,
              icon: Icons.waves,
              title: 'Открыть заплыв',
              onTap: () => _open(context, const TrackLiveScreen()),
            ),
            _action(
              context,
              icon: Icons.lock_outline,
              title: 'Создать канал',
              onTap: () => _open(context, const ChannelsScreen()),
            ),
            _action(
              context,
              icon: Icons.message_outlined,
              title: 'Написать сообщение',
              onTap: () => _open(context, const ConversationsScreen()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Widget _action(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}