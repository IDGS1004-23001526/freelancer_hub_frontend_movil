import 'dart:async';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_constants.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class ChatSocketService {
  IO.Socket? _socket;
  final AuthService _authService = AuthService();

  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionStateController = StreamController<SocketConnectionState>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<bool>.broadcast();

  Stream<ChatMessage> get onMessageReceived => _messageController.stream;
  Stream<SocketConnectionState> get onConnectionStateChanged => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get onMessageStatusChanged => _statusController.stream;
  Stream<bool> get onTypingChanged => _typingController.stream;

  SocketConnectionState _currentState = SocketConnectionState.disconnected;
  SocketConnectionState get currentState => _currentState;

  String? _currentConversationId;
  String? _currentUserId;
  String? _connectedToken;

  void _updateState(SocketConnectionState state) {
    _currentState = state;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(state);
    }
  }

  /// Inicializa la conexión con el servidor Socket.io con reconexión automática y autenticación
  Future<void> connect({
    required String conversationId,
    String? explicitUrl,
    String? currentUserId,
  }) async {
    final token = await _authService.getToken();
    final userChanged = _currentUserId != null &&
        currentUserId != null &&
        _currentUserId != currentUserId;
    final tokenChanged = _connectedToken != null && _connectedToken != token;

    if (userChanged || tokenChanged) {
      disconnect();
    }

    _currentConversationId = conversationId;
    _currentUserId = currentUserId;

    if (_socket != null && _socket!.connected) {
      _joinConversation(conversationId);
      return;
    }

    _updateState(SocketConnectionState.connecting);
    _connectedToken = token;

    final socketBaseUrl = ApiConstants.getSocketUrl(explicitUrl);

    try {
      _socket = IO.io(
        socketBaseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableForceNew()
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(double.infinity)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setAuth({'token': token ?? ''})
            .setExtraHeaders({
              if (token != null) 'Authorization': 'Bearer $token',
            })
            .build(),
      );

      _setupListeners();
      _socket!.connect();
    } catch (_) {
      _updateState(SocketConnectionState.reconnecting);
    }
  }

  void _setupListeners() {
    if (_socket == null) return;

    // Conectado con éxito
    _socket!.onConnect((_) {
      _updateState(SocketConnectionState.connected);
      if (_currentConversationId != null) {
        _joinConversation(_currentConversationId!);
      }
    });

    // Desconectado por pérdida de red
    _socket!.onDisconnect((_) {
      _updateState(SocketConnectionState.disconnected);
    });

    // Proceso de reconexión automática transparente
    _socket!.on('reconnecting', (_) {
      _updateState(SocketConnectionState.reconnecting);
    });

    _socket!.on('reconnect', (_) {
      _updateState(SocketConnectionState.connected);
      if (_currentConversationId != null) {
        _joinConversation(_currentConversationId!);
      }
    });

    _socket!.onConnectError((_) {
      _updateState(SocketConnectionState.reconnecting);
    });

    // Escucha de mensajes entrantes en tiempo real
    void handleIncomingMessage(dynamic data) {
      if (data is Map<String, dynamic>) {
        final message = ChatMessage.fromJson(data, currentUserId: _currentUserId);
        
        // Criterio 3: Feedback sonoro y háptico al recibir mensaje nuevo de la contraparte
        if (!message.isMine) {
          triggerMessageFeedback();
        }

        if (!_messageController.isClosed) {
          _messageController.add(message);
        }
      }
    }

    _socket!.on('new_message', handleIncomingMessage);
    _socket!.on('receive_message', handleIncomingMessage);
    _socket!.on('message', handleIncomingMessage);

    // Escucha de confirmaciones de entrega y lectura (Checks)
    void handleStatusUpdate(dynamic data) {
      if (data is Map<String, dynamic> && !_statusController.isClosed) {
        _statusController.add(data);
      }
    }

    _socket!.on('message_status', handleStatusUpdate);
    _socket!.on('message_read', handleStatusUpdate);
    _socket!.on('message_delivered', handleStatusUpdate);

    // Indicador de "escribiendo..."
    _socket!.on('typing', (data) {
      if (!_typingController.isClosed) {
        _typingController.add(true);
      }
    });

    _socket!.on('stop_typing', (data) {
      if (!_typingController.isClosed) {
        _typingController.add(false);
      }
    });
  }

  void _joinConversation(String conversationId) {
    _socket?.emit('join_room', {'roomId': conversationId, 'conversationId': conversationId});
    _socket?.emit('join_conversation', {'conversationId': conversationId});
  }

  /// Emite un mensaje al socket en tiempo real
  void sendMessage(ChatMessage message) {
    final payload = message.toJson();

    if (_socket != null && _socket!.connected) {
      _socket!.emit('send_message', payload);
      _socket!.emit('new_message', payload);
    }
  }

  /// Notifica que el mensaje fue leído por el usuario
  void markAsRead(String messageId, String conversationId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('mark_as_read', {
        'messageId': messageId,
        'conversationId': conversationId,
        'readAt': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Emite estado de tipeo
  void sendTyping(bool isTyping, String conversationId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit(isTyping ? 'typing' : 'stop_typing', {
        'conversationId': conversationId,
      });
    }
  }

  /// Proporciona retroalimentación háptica y auditiva al recibir un mensaje
  void triggerMessageFeedback() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Cierra la conexión de sockets de forma limpia
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
    _updateState(SocketConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
    _statusController.close();
    _typingController.close();
  }
}
