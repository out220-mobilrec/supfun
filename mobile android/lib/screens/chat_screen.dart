// Личный чат (ТЗ §20.2). Обновление — ручное/по возвращении на экран:
// websocket-канала на сервере пока нет (ТР §10 техдолг).
//
// Важно: прокрутка вниз планилась прямо в builder'е ListView, из-за чего
// jumpTo вызывал перерисовку, а перерисовка — снова jumpTo. Получался
// бесконечный цикл, и экран зависал. Теперь прокрутка планируются
// однократно (_scheduleScrollToEnd) и только по факту изменения данных.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/feed_controller.dart';
import '../controllers/session_controller.dart';
import '../core/formatting.dart';
import '../models/api_models.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.title = 'Чат',
  });

  final String conversationId;
  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ChatsController _controller;

  /// Сколько раз мы уже прокрутили к конкретному набору сообщений.
  int _scrolledForCount = -1;
  bool _scrollScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ChatsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.open(widget.conversationId);
      _scheduleScrollToEnd();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Однократная прокрутка в конец. Повторный вызов до завершения кадра
  /// игнорируется — это и разрывает цикл перерисовок.
  void _scheduleScrollToEnd() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final messenger = ScaffoldMessenger.of(context);
    await _controller.send(text);
    if (_controller.actionError != null) {
      messenger.showSnackBar(SnackBar(content: Text(_controller.actionError!)));
      return;
    }
    _scrolledForCount = -1;
    _scheduleScrollToEnd();
  }

  Future<void> _refresh() async {
    await _controller.open(widget.conversationId);
    _scrolledForCount = -1;
    _scheduleScrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatsController>();
    final me = context.watch<SessionController>().user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: controller.messages.isBusy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SectionView<List<ChatMessage>>(
              section: controller.messages,
              onRetry: _refresh,
              emptyTitle: 'Сообщений пока нет',
              emptySubtitle: 'Напишите первым — участник получит уведомление',
              builder: (messages) => _Messages(
                // Ключ = размер списка: новый набор сообщений = новый
                // экземпляр виджета, который сам попросит прокрутку вниз.
                key: ValueKey(messages.length),
                messages: messages,
                myId: me,
                scroll: _scroll,
                onNeedScroll: () {
                  if (_scrolledForCount == messages.length) return;
                  _scrolledForCount = messages.length;
                  _scheduleScrollToEnd();
                },
              ),
            ),
          ),
          if (me == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Нет данных о профиле'),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Сообщение',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: controller.busy ? null : _send,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
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

/// Список сообщений. Прокрутку просит один раз на новый набор — через
/// didChangeDependencies, а не из build, чтобы не зацикливать layout.
class _Messages extends StatefulWidget {
  const _Messages({
    super.key,
    required this.messages,
    required this.myId,
    required this.scroll,
    required this.onNeedScroll,
  });

  final List<ChatMessage> messages;
  final String? myId;
  final ScrollController scroll;
  final VoidCallback onNeedScroll;

  @override
  State<_Messages> createState() => _MessagesState();
}

class _MessagesState extends State<_Messages> {
  @override
  void initState() {
    super.initState();
    widget.onNeedScroll();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: widget.scroll,
        padding: const EdgeInsets.all(16),
        itemCount: widget.messages.length,
        itemBuilder: (_, index) {
          final message = widget.messages[index];
          return _Bubble(message: message, mine: message.senderId == widget.myId);
        },
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor),
                ),
              ),
            Text(
              message.displayText,
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
