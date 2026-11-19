import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_constants.dart';
import 'auth_service.dart';

class MessageNotification {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String? senderAvatarUrl;
  final String content;
  final String? attachmentUrl;
  final DateTime createdAt;

  const MessageNotification({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderAvatarUrl,
    required this.content,
    this.attachmentUrl,
    required this.createdAt,
  });

  String get previewText {
    final trimmed = content.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (attachmentUrl != null && attachmentUrl!.isNotEmpty) {
      return 'Imagen adjunta';
    }
    return 'Nuevo mensaje';
  }

  String get initials {
    final parts = senderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory MessageNotification.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['senderRole'] ?? '').toString().toUpperCase();
    final formattedRole = rawRole == 'CLIENT'
        ? 'Cliente Contratante'
        : (rawRole == 'FREELANCER' ? 'Freelancer' : (json['senderRole']?.toString() ?? 'Usuario'));

    return MessageNotification(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? json['contractId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? 'Nuevo mensaje').toString(),
      senderRole: formattedRole,
      senderAvatarUrl: json['senderAvatarUrl']?.toString(),
      content: (json['content'] ?? '').toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

/// Servicio global de notificaciones en tiempo real para el usuario autenticado.
class NotificationSocketService {
  NotificationSocketService._internal();

  static final NotificationSocketService instance = NotificationSocketService._internal();

  final AuthService _authService = AuthService();
  final _notificationController = StreamController<MessageNotification>.broadcast();
  final _tapController = StreamController<MessageNotification>.broadcast();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Stream<MessageNotification> get onMessageNotification => _notificationController.stream;
  Stream<MessageNotification> get onNotificationTap => _tapController.stream;

  io.Socket? _socket;
  String? _connectedToken;
  String? _currentUserId;
  String? activeConversationId;
  bool _localInitDone = false;

  static const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
    'chat_messages',
    'Mensajes de chat',
    description: 'Notificaciones de nuevos mensajes en tus conversaciones',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initializeLocalNotifications() async {
    if (_localInitDone || kIsWeb) return;
    _localInitDone = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final map = jsonDecode(payload);
            if (map is Map<String, dynamic>) {
              final item = MessageNotification.fromJson(map);
              if (item.conversationId.isNotEmpty && !_tapController.isClosed) {
                _tapController.add(item);
              }
            }
          } catch (_) {}
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_chatChannel);
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      _localInitDone = false;
    }
  }

  Future<void> _showSystemNotification(MessageNotification notification) async {
    if (kIsWeb) return;
    if (!_localInitDone) {
      await initializeLocalNotifications();
    }

    final payloadJson = jsonEncode({
      'id': notification.id,
      'conversationId': notification.conversationId,
      'senderId': notification.senderId,
      'senderName': notification.senderName,
      'senderRole': notification.senderRole,
      'senderAvatarUrl': notification.senderAvatarUrl,
      'content': notification.content,
      'attachmentUrl': notification.attachmentUrl,
      'createdAt': notification.createdAt.toIso8601String(),
    });

    final androidDetails = AndroidNotificationDetails(
      _chatChannel.id,
      _chatChannel.name,
      channelDescription: _chatChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _localNotifications.show(
        notification.conversationId.hashCode,
        notification.senderName,
        notification.previewText,
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
        payload: payloadJson,
      );
    } catch (_) {}
  }

  Future<void> connectIfAuthenticated({String? explicitUrl}) async {
    final token = await _authService.getToken();
    if (token == null || token.trim().isEmpty) {
      disconnect();
      return;
    }

    if (_socket != null && _socket!.connected && _connectedToken == token) {
      return;
    }

    disconnect();
    _connectedToken = token;
    _currentUserId = _extractSubFromJwt(token);

    final socketBaseUrl = ApiConstants.getSocketUrl(explicitUrl);
    try {
      _socket = io.io(
        socketBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableForceNew()
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(double.infinity)
            .setReconnectionDelay(1500)
            .setReconnectionDelayMax(6000)
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _socket!.on('new_message_notification', _handleIncomingNotification);
      _socket!.connect();
    } catch (_) {
      // Silencioso para no interrumpir el arranque de la app
    }
  }

  void _handleIncomingNotification(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final notification = MessageNotification.fromJson(map);
    if (notification.conversationId.isEmpty) return;

    // No notificar mensajes propios ni mensajes de la conversación actualmente abierta
    if (_currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        notification.senderId.toLowerCase() == _currentUserId!.toLowerCase()) {
      return;
    }
    if (activeConversationId == notification.conversationId) {
      return;
    }

    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.lightImpact();
    } catch (_) {}

    unawaited(_showSystemNotification(notification));

    if (!_notificationController.isClosed) {
      _notificationController.add(notification);
    }
  }

  String? _extractSubFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        return (payload['sub'] ?? payload['userId'] ?? payload['id'])?.toString();
      }
    } catch (_) {}
    return null;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
    _currentUserId = null;
  }
}
