import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'chat_api_service.dart';
import 'chat_socket_service.dart';

class QueuedMessage {
  ChatMessage message;
  int attempts;
  DateTime lastAttempt;
  bool isProcessing;

  QueuedMessage({
    required this.message,
    this.attempts = 0,
    DateTime? lastAttempt,
    this.isProcessing = false,
  }) : lastAttempt = lastAttempt ?? DateTime.now();
}

class ChatMessageQueue {
  static final ChatMessageQueue _instance = ChatMessageQueue._internal();
  factory ChatMessageQueue() => _instance;
  ChatMessageQueue._internal();

  final ChatApiService _apiService = ChatApiService();
  final List<QueuedMessage> _queue = [];
  bool _isWorkerRunning = false;

  final _messageSentController = StreamController<ChatMessage>.broadcast();
  final _messageFailedController = StreamController<ChatMessage>.broadcast();
  final _queueUpdatedController = StreamController<int>.broadcast();

  Stream<ChatMessage> get onMessageSent => _messageSentController.stream;
  Stream<ChatMessage> get onMessageFailed => _messageFailedController.stream;
  Stream<int> get onQueueUpdated => _queueUpdatedController.stream;

  List<ChatMessage> get pendingMessages =>
      _queue.map((q) => q.message).toList();

  /// Encola un mensaje para ser procesado de manera secuencial (cuello de botella controlado)
  void enqueue(ChatMessage message, {ChatSocketService? socketService}) {
    // Si ya está en cola, no duplicar
    if (_queue.any((q) => q.message.id == message.id)) return;

    final queued = QueuedMessage(
      message: message.copyWith(status: MessageStatus.sending),
    );
    _queue.add(queued);
    _notifyQueueChange();

    _processQueue(socketService: socketService);
  }

  /// Reintenta un mensaje que falló previamente
  void retry(String messageId, {ChatSocketService? socketService}) {
    final index = _queue.indexWhere((q) => q.message.id == messageId);
    if (index != -1) {
      _queue[index].attempts = 0;
      _queue[index].isProcessing = false;
      _processQueue(socketService: socketService);
    }
  }

  /// Cancela o remueve un mensaje de la cola
  void remove(String messageId) {
    _queue.removeWhere((q) => q.message.id == messageId);
    _notifyQueueChange();
  }

  /// Limpia la cola y reinicia el worker (útil entre pruebas)
  void clear() {
    _queue.clear();
    _isWorkerRunning = false;
  }

  /// Llamado cuando la red o el socket se reconectan: procesa mensajes pendientes automáticamente
  void onNetworkRestored({ChatSocketService? socketService}) {
    for (final item in _queue) {
      if (item.message.status == MessageStatus.failed) {
        item.attempts = 0;
        item.isProcessing = false;
      }
    }
    _processQueue(socketService: socketService);
  }

  void _notifyQueueChange() {
    if (!_queueUpdatedController.isClosed) {
      _queueUpdatedController.add(_queue.length);
    }
  }

  /// Procesa la cola secuencialmente (evita sobrecarga de red y desorden de mensajes)
  Future<void> _processQueue({ChatSocketService? socketService}) async {
    if (_isWorkerRunning) return;
    _isWorkerRunning = true;

    while (_queue.isNotEmpty) {
      // Tomar el primer mensaje no procesado
      QueuedMessage? nextItem;
      try {
        nextItem = _queue.firstWhere(
          (q) => !q.isProcessing && q.message.status != MessageStatus.failed,
        );
      } catch (_) {
        nextItem = null;
      }

      if (nextItem == null) break;

      nextItem.isProcessing = true;
      final msg = nextItem.message;
      nextItem.attempts++;
      nextItem.lastAttempt = DateTime.now();

      try {
        ChatMessage? saved;

        // 1. Si el socket está conectado, emitir inmediatamente por WebSocket
        if (socketService != null &&
            socketService.currentState == SocketConnectionState.connected) {
          socketService.sendMessage(msg);
          saved = msg.copyWith(status: MessageStatus.sent);
          // Persistir por REST en background sin bloquear la cola
          _apiService.sendMessage(
            msg.conversationId,
            msg.content,
            currentUserId: msg.senderId,
            attachmentUrl: msg.attachmentUrl,
          ).catchError((_) => null);
        } else {
          // 2. Si el socket no está disponible, enviar sincrónicamente por REST
          saved = await _apiService.sendMessage(
            msg.conversationId,
            msg.content,
            currentUserId: msg.senderId,
            attachmentUrl: msg.attachmentUrl,
          );
        }

        if (saved != null) {
          // Éxito: remover de la cola y notificar mensaje confirmado sin duplicar
          _queue.remove(nextItem);
          _notifyQueueChange();

          final confirmed = saved.copyWith(isMine: true, status: MessageStatus.sent);
          if (!_messageSentController.isClosed) {
            _messageSentController.add(confirmed);
          }
        } else {
          // No hubo respuesta válida del servidor
          _handleSendFailure(nextItem);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error enviando mensaje en cola: $e');
        }
        _handleSendFailure(nextItem);
      }

      // Pequeño retardo entre mensajes para evitar congestión de paquetes
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isWorkerRunning = false;
  }

  void _handleSendFailure(QueuedMessage item) {
    item.isProcessing = false;

    // Si superó los 3 intentos, marcar como fallido para permitir reintento manual
    if (item.attempts >= 3) {
      final failedMessage = item.message.copyWith(status: MessageStatus.failed);
      item.message = failedMessage;
      if (!_messageFailedController.isClosed) {
        _messageFailedController.add(failedMessage);
      }
    }
  }
}
