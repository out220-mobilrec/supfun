// Chat conversations list screen with offline support
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/local_models.dart';
import '../controllers/storage_controller.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<StorageController>(
          builder: (context, controller, _) {
            final conversations = controller.conversations;
            if (conversations.isEmpty) {
              return _buildEmptyState();
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                return _buildConversationTile(
                    context, conversations[index]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Нет сообщений',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Начните общение с друзьями',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
      BuildContext context, LocalConversation conv) {
    final controller = context.read<StorageController>();
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => controller.deleteConversation(conv.id),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: conv.isGroup
                  ? AppTheme.secondaryColor
                  : AppTheme.primaryColor,
              child: conv.isGroup
                  ? const Icon(Icons.group, color: Colors.white)
                  : Text(
                      _getInitials(conv.otherUserName ?? '?'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
            ),
            if (conv.unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(
                      minWidth: 18, minHeight: 18),
                  child: Text(
                    conv.unreadCount > 99
                        ? '99+'
                        : '${conv.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          conv.isGroup ? (conv.groupName ?? 'Группа') : (conv.otherUserName ?? 'Неизвестно'),
          style: TextStyle(
            fontWeight: conv.unreadCount > 0
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          conv.lastMessagePreview ?? 'Нет сообщений',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: conv.unreadCount > 0
                ? AppTheme.textPrimary
                : AppTheme.textSecondary,
            fontWeight: conv.unreadCount > 0
                ? FontWeight.w500
                : FontWeight.normal,
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (conv.lastMessageAt != null)
              Text(
                _formatTime(conv.lastMessageAt!),
                style: TextStyle(
                  fontSize: 11,
                  color: conv.unreadCount > 0
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight: conv.unreadCount > 0
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
            if (conv.isPinned)
              const Icon(Icons.push_pin,
                  size: 14, color: AppTheme.textSecondary),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: conv.id,
          );
          controller.markConversationAsRead(conv.id);
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) {
      return DateFormat('dd.MM').format(time);
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ч';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} мин';
    } else {
      return 'сейчас';
    }
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _ChatSearchDelegate(),
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final controller = context.read<StorageController>();
    final results = controller.searchMessages(query);
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final msg = results[index];
        return ListTile(
          leading: const Icon(Icons.message),
          title: Text(msg.content),
          subtitle: Text(
            DateFormat('dd.MM.yyyy HH:mm').format(msg.sentAt),
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(child: Text('Поиск сообщений'));
  }
}
