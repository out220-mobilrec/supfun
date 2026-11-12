import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _subNew;
  StreamSubscription<Map<String, dynamic>>? _subStatus;
  StreamSubscription<Map<String, dynamic>>? _subTyping;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _title;
  bool _otherTyping = false;
  Timer? _typingDebounce;
  int _nonce = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conv =
          await ApiClient.instance.get('/conversations/${widget.conversationId}');
      final msgs = await ApiClient.instance.getList(
          '/conversations/${widget.conversationId}/messages',
          query: {'limit': 100});
      final selfId = Session.user.value?.id;
      final participants =
          ((conv['participants'] as List?) ?? const []).cast<Map<String, dynamic>>();
      String? otherName;
      for (final p in participants) {
        final u = p['user'] as Map<String, dynamic>?;
        if (u != null && p['userId'] != selfId) {
          otherName = u['name'] as String?;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs.map((e) => Message.fromJson(e)));
        _title = (conv['title'] as String?) ??
            ((conv['type'] as String?) == 'event' ? 'Чат события' : otherName);
        _loading = false;
      });
      _scrollToBottom();
      await ApiClient.instance
          .post('/conversations/${widget.conversationId}/read');
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

  void _connectSocket() {
    final app = context.read<AppState>();
    app.socket.joinConversation(widget.conversationId);
    _subNew = app.socket.events('chat:new').listen((data) {
      final message =
          Message.fromJson(Map<String, dynamic>.from(data['message']));
      if (data['conversationId'] != widget.conversationId) return;
      if (_messages.any((m) => m.id == message.id)) return;
      setState(() => _messages.add(message));
      app.socket.markDelivered(widget.conversationId, message.id);
      app.socket.markRead(widget.conversationId);
      _scrollToBottom();
    });
    _subStatus = app.socket.events('chat:status').listen((data) {
      if (data['conversationId'] != widget.conversationId) return;
      final messageId = data['messageId'] as String?;
      final status = data['status'] as String?;
      if (messageId != null && status != null) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx >= 0) {
            final m = _messages[idx];
            _messages[idx] = Message(
              id: m.id,
              conversationId: m.conversationId,
              senderId: m.senderId,
              sender: m.sender,
              type: m.type,
              content: m.content,
              latitude: m.latitude,
              longitude: m.longitude,
              replyToId: m.replyToId,
              replyTo: m.replyTo,
              status: status,
              createdAt: m.createdAt,
            );
          }
        });
      }
    });
    _subTyping = app.socket.events('chat:typing').listen((data) {
      if (data['conversationId'] != widget.conversationId) return;
      final myId = Session.user.value?.id;
      if (data['userId'] == myId) return;
      setState(() => _otherTyping = (data['isTyping'] ?? false) as bool);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final nonce = '${DateTime.now().millisecondsSinceEpoch}-${_nonce++}';
    final tempId = 'local-$nonce';
    setState(() {
      _sending = true;
      _messages.add(Message(
        id: tempId,
        conversationId: widget.conversationId,
        senderId: Session.user.value?.id ?? '',
        sender: SimpleUser(
            id: Session.user.value?.id ?? '',
            name: Session.user.value?.name ?? ''),
        type: 'text',
        content: text,
        status: 'sent',
        createdAt: DateTime.now(),
      ));
    });
    _input.clear();
    _scrollToBottom();
    final app = context.read<AppState>();
    try {
      final result = await app.socket.sendMessage(widget.conversationId, {
        'type': 'text',
        'content': text,
        'nonce': nonce,
      });
      if (!mounted) return;
      setState(() {
        if (result != null) {
          final serverMsg = Message.fromJson(result);
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx >= 0) {
            _messages[idx] = serverMsg;
          } else {
            _messages.add(serverMsg);
          }
        }
        _sending = false;
      });
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onTyping(String _) {
    final app = context.read<AppState>();
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 500),
        () => app.socket.sendTyping(widget.conversationId, true));
    _typingDebounce = Timer(const Duration(seconds: 2),
        () => app.socket.sendTyping(widget.conversationId, false));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    final app = context.read<AppState>();
    app.socket.leaveConversation(widget.conversationId);
    _subNew?.cancel();
    _subStatus?.cancel();
    _subTyping?.cancel();
    _typingDebounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title ?? 'Чат')),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? ErrorBanner(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (_otherTyping)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('печатает…',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                            message: _messages[i],
                            selfId: Session.user.value?.id ?? ''),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                onChanged: _onTyping,
                                onSubmitted: (_) => _send(),
                                textInputAction: TextInputAction.send,
                                decoration: InputDecoration(
                                  hintText: 'Сообщение',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.selfId});

  final Message message;
  final String selfId;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderId == selfId;
    final bgColor = mine ? const Color(0xFF008A74) : const Color(0xFF17201E);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints:
                      BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: radius,
                  ),
                  child: _content(context),
                ),
                if (mine)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Text(
                      _statusIcon(message.status),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (message.type == 'photo') {
      return message.content != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(AppConfig.absUrl(message.content),
                  width: 180, fit: BoxFit.cover),
            )
          : const Text('📷 Фото');
    }
    if (message.type == 'location') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.place, size: 16), SizedBox(width: 6), Text('Локация')],
      );
    }
    return Text(message.content ?? '');
  }

  String _statusIcon(String s) {
    switch (s) {
      case 'read':
        return '✓✓';
      case 'delivered':
        return '✓✓';
      case 'sent':
        return '✓';
      case 'error':
        return '⚠';
      default:
        return '✓';
    }
  }
}