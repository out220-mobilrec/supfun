// Individual chat screen with offline message storage
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/local_models.dart';
import '../controllers/storage_controller.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final controller = context.read<StorageController>();
    final message = LocalChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: 'me',
      senderName: 'Я',
      content: text,
      sentAt: DateTime.now(),
      isFromMe: true,
      status: MessageStatus.sending,
    );

    _messageController.clear();

    await controller.saveMessage(message);

    // Simulate status update
    Future.delayed(const Duration(milliseconds: 500), () async {
      message.status = MessageStatus.sent;
      await controller.saveMessage(message);
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Consumer<StorageController>(
          builder: (context, controller, _) {
            final conv = controller.conversations.firstWhere(
              (c) => c.id == widget.conversationId,
              orElse: () => LocalConversation(id: widget.conversationId),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.isGroup
                      ? (conv.groupName ?? 'Группа')
                      : (conv.otherUserName ?? 'Чат'),
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'в сети',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Storage indicator
            _buildOfflineIndicator(),
            // Messages list
            Expanded(
              child: Consumer<StorageController>(
                builder: (context, controller, _) {
                  final messages =
                      controller.getMessages(widget.conversationId);
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Начните общение',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(messages[index]);
                    },
                  );
                },
              ),
            ),
            // Input area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.successColor.withOpacity(0.1),
      child: Row(
        children: const [
          Icon(Icons.offline_bolt,
              size: 14, color: AppTheme.successColor),
          SizedBox(width: 6),
          Text('Сообщения хранятся локально',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.successColor)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(LocalChatMessage msg) {
    final isMine = msg.isFromMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.person, size: 14, color: Colors.white),
            ),
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.content,
                      style: TextStyle(
                          fontSize: 14,
                          color:
                              isMine ? Colors.white : AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(msg.sentAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMine
                              ? Colors.white70
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.status == MessageStatus.read
                              ? Icons.done_all
                              : Icons.done,
                          size: 12,
                          color: msg.status == MessageStatus.read
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
          if (isMine)
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.secondaryColor,
              child: const Icon(Icons.person, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          IconButton(
              icon: const Icon(Icons.attach_file), onPressed: () {}),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: () {}),
          FloatingActionButton.small(
            onPressed: _sendMessage,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
