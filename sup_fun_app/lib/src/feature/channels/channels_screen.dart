import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../widgets/widget.dart';
import 'channel_detail_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<Channel>? _channels;
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
      final list = await ApiClient.instance.getList('/channels', query: {'limit': 50});
      if (!mounted) return;
      setState(() {
        _channels = list.map((e) => Channel.fromJson(e)).toList();
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

  void _createDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateChannelDialog(onCreated: () => _load()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Каналы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createDialog,
          ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _channels!.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          EmptyState(
                              icon: Icons.lock_open,
                              text: 'Каналов пока нет'),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _channels!.length,
                          itemBuilder: (_, i) =>
                              _ChannelCard(channel: _channels![i]),
                        ),
                ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChannelDetailScreen(channelId: channel.id))),
        leading: channel.photoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(AppConfig.absUrl(channel.photoUrl),
                    width: 44, height: 44, fit: BoxFit.cover),
              )
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: AppColors.primary),
              ),
        title: Text(channel.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (channel.description != null &&
                channel.description!.isNotEmpty)
              Text(channel.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            Text('${channel.subscriberCount} подписчиков',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.55))),
          ],
        ),
        trailing: Icon(Icons.chevron_right,
            color: cs.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }
}

class _CreateChannelDialog extends StatefulWidget {
  const _CreateChannelDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<_CreateChannelDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _isPublic = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().length < 2) return;
    setState(() => _busy = true);
    try {
      await ApiClient.instance.post('/channels', data: <String, dynamic>{
        'name': _name.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'isPublic': _isPublic,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый канал'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Название')),
          const SizedBox(height: 12),
          TextField(
              controller: _desc,
              decoration: const InputDecoration(hintText: 'Описание'),
              maxLines: 2),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Публичный'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Создать'),
        ),
      ],
    );
  }
}