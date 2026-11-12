import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';
import '../core/session.dart';

class SocketService {
  io.Socket? _socket;
  final _byName = <String, StreamController<Map<String, dynamic>>>{};

  bool get connected => _socket?.connected ?? false;

  Stream<Map<String, dynamic>> events(String name) {
    return _byName.putIfAbsent(name, StreamController<Map<String, dynamic>>.broadcast).stream;
  }

  void connect() {
    final token = Session.accessToken;
    if (token == null || _socket != null) return;
    final s = io.io(
      '${AppConfig.serverOrigin}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    s.onConnect((_) {});
    s.on('chat:new', (data) => _emit('chat:new', data));
    s.on('chat:status', (data) => _emit('chat:status', data));
    s.on('chat:typing', (data) => _emit('chat:typing', data));
    s.on('presence:change', (data) => _emit('presence:change', data));
    s.on('notify:new', (data) => _emit('notify:new', data));
    _socket = s;
  }

  /// Hard-reconnect after token refresh.
  void reconnect() {
    disconnect();
    connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void _emit(String name, dynamic data) {
    final c = _byName[name];
    if (c != null && !c.isClosed) c.add(data);
  }

  Future<bool> joinConversation(String id) => _ack('conversation:join', {'conversationId': id});

  Future<bool> leaveConversation(String id) =>
      _ack('conversation:leave', {'conversationId': id});

  Future<Map<String, dynamic>?> sendMessage(
      String conversationId, Map<String, dynamic> message) {
    final comp = Completer<Map<String, dynamic>?>();
    final timer = Timer(const Duration(seconds: 20), () {
      if (!comp.isCompleted) comp.complete(null);
    });
    _socket?.emitWithAck('chat:send', {
      'conversationId': conversationId,
      'message': message,
    }, ack: (data) {
      timer.cancel();
      if (data is Map && data['message'] != null) {
        final m = Map<String, dynamic>.from(data['message']);
        // ensure sender relation present for local rendering
        final selfId = Session.user.value?.id;
        m['sender'] ??= {'id': selfId, 'name': Session.user.value?.name};
        comp.complete(m);
      } else {
        comp.complete(null);
      }
    });
    return comp.future;
  }

  Future<void> sendTyping(String conversationId, bool isTyping) =>
      _ack('chat:typing', {'conversationId': conversationId, 'isTyping': isTyping});

  Future<void> markRead(String conversationId) =>
      _ack('chat:read', {'conversationId': conversationId});

  Future<void> markDelivered(String conversationId, String messageId) =>
      _ack('chat:delivered', {'conversationId': conversationId, 'messageId': messageId});

  Future<List<String>> presence() async {
    final comp = Completer<List<String>>();
    final timer = Timer(const Duration(seconds: 10), () {
      if (!comp.isCompleted) comp.complete([]);
    });
    _socket?.emitWithAck('presence:list', null, ack: (data) {
      timer.cancel();
      if (data is Map) {
        comp.complete((data['online'] as List?)?.cast<String>() ?? []);
      } else {
        comp.complete([]);
      }
    });
    return comp.future;
  }

  Future<bool> _ack(String event, [Map<String, dynamic>? body]) {
    final comp = Completer<bool>();
    final timer = Timer(const Duration(seconds: 15), () {
      if (!comp.isCompleted) comp.complete(false);
    });
    _socket?.emitWithAck(event, body ?? {}, ack: (data) {
      timer.cancel();
      if (data is Map && data['ok'] == true) {
        comp.complete(true);
      } else if (data is Map && data['status'] == 403) {
        comp.complete(false);
      } else {
        comp.complete(true);
      }
    });
    return comp.future;
  }
}