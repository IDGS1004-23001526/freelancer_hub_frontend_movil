import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_constants.dart';
import '../models/notification_item.dart';
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
      return '📷 Imagen adjunta';
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
        : (rawRole == 'FREELANCER'
            ? 'Freelancer'
            : (json['senderRole']?.toString() ?? 'Usuario'));

    return MessageNotification(
      id: (json['id'] ?? '').toString(),
      conversationId:
          (json['conversationId'] ?? json['contractId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? 'Nuevo mensaje').toString(),
      senderRole: formattedRole,
      senderAvatarUrl: json['senderAvatarUrl']?.toString(),
      content: (json['content'] ?? '').toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  NotificationItem toNotificationItem({bool isRead = false}) {
    return NotificationItem(
      id: id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      senderAvatarUrl: senderAvatarUrl,
      title: senderName,
      content: previewText,
      attachmentUrl: attachmentUrl,
      createdAt: createdAt,
      isRead: isRead,
    );
  }
}

/// Servicio global y reactivo de notificaciones en tiempo real para la aplicación.
/// Integra Socket.io con el backend, FlutterLocalNotifications para el panel de Android/iOS
/// y persistencia en Hive para la "Sección de Notificaciones".
class NotificationSocketService {
  NotificationSocketService._internal();

  static final NotificationSocketService instance =
      NotificationSocketService._internal();

  final AuthService _authService = AuthService();
  final _notificationController =
      StreamController<MessageNotification>.broadcast();
  final _tapController = StreamController<MessageNotification>.broadcast();
  final _notificationsListController =
      StreamController<List<NotificationItem>>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Stream<MessageNotification> get onMessageNotification =>
      _notificationController.stream;
  Stream<MessageNotification> get onNotificationTap => _tapController.stream;
  Stream<List<NotificationItem>> get onNotificationsChanged =>
      _notificationsListController.stream;
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  io.Socket? _socket;
  String? _connectedToken;
  String? _currentUserId;
  String? activeConversationId;
  bool _localInitDone = false;
  final List<NotificationItem> _cachedNotifications = [];

  List<NotificationItem> get notifications =>
      List.unmodifiable(_cachedNotifications);
  int get unreadCount => _cachedNotifications.where((n) => !n.isRead).length;

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Mensajes y Notificaciones',
    description: 'Notificaciones de mensajes de chat y actividad en proyectos',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  @visibleForTesting
  bool disableSystemNotifications = false;

  bool get _isTestEnvironment {
    if (disableSystemNotifications) return true;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
      final binding = WidgetsBinding.instance.runtimeType.toString();
      if (binding.contains('Test')) return true;
    } catch (_) {}
    return false;
  }

  /// Inicializa notificaciones nativas de Android e iOS y carga el historial de Hive.
  Future<void> initializeLocalNotifications() async {
    _loadStoredNotifications();

    if (_localInitDone || kIsWeb || _isTestEnvironment) return;
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
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_chatChannel);
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[NotificationSocketService] Nota inicializando local: $e');
      _localInitDone = false;
    }
  }

  /// Carga el historial previo desde el box de Hive.
  void _loadStoredNotifications() {
    try {
      if (Hive.isBoxOpen('notificationsBox')) {
        final box = Hive.box('notificationsBox');
        final raw = box.get('history');
        if (raw is List) {
          _cachedNotifications.clear();
          for (final item in raw) {
            if (item is Map) {
              _cachedNotifications.add(
                NotificationItem.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
          _cachedNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _notifyListChanged();
        }
      }
    } catch (_) {}
  }

  /// Guarda el historial actual en Hive de forma asíncrona.
  Future<void> _persistNotifications() async {
    try {
      if (Hive.isBoxOpen('notificationsBox')) {
        final box = Hive.box('notificationsBox');
        final rawList = _cachedNotifications.map((n) => n.toJson()).toList();
        await box.put('history', rawList);
      }
    } catch (_) {}
  }

  void _notifyListChanged() {
    if (!_notificationsListController.isClosed) {
      _notificationsListController.add(List.unmodifiable(_cachedNotifications));
    }
    if (!_unreadCountController.isClosed) {
      _unreadCountController.add(unreadCount);
    }
  }

  /// Muestra una notificación emergente en la bandeja / panel del sistema operativo.
  Future<void> _showSystemNotification(MessageNotification notification) async {
    if (kIsWeb || _isTestEnvironment) return;
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
      final notifId = notification.conversationId.isNotEmpty
          ? notification.conversationId.hashCode
          : DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        notifId,
        notification.senderName,
        notification.previewText,
        NotificationDetails(android: androidDetails, iOS: darwinDetails),
        payload: payloadJson,
      );
    } catch (e) {
      debugPrint('[NotificationSocketService] Error mostrando notificación local: $e');
    }
  }

  /// Conecta el socket en tiempo real si el usuario tiene una sesión activa.
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

    final socketBaseUrl =
        ApiConstants.getSocketUrl(explicitUrl ?? AuthService.activeBaseUrl);

    try {
      debugPrint('[NotificationSocketService] Conectando a $socketBaseUrl...');
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

      _socket!.onConnect((_) {
        debugPrint('[NotificationSocketService] Socket conectado exitosamente.');
      });

      _socket!.on('new_message_notification', _handleIncomingNotification);

      _socket!.onDisconnect((_) {
        debugPrint('[NotificationSocketService] Socket desconectado.');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('[NotificationSocketService] Error al conectar socket: $e');
    }
  }

  /// Procesa cualquier notificación recibida en tiempo real desde el backend o simulada.
  void handleIncomingNotification(Map<String, dynamic> data, {bool forceAlert = false}) {
    final notification = MessageNotification.fromJson(data);
    if (notification.conversationId.isEmpty) return;

    final isOwnMessage = _currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        notification.senderId.toLowerCase() == _currentUserId!.toLowerCase();

    // Guardar siempre en el historial de la "Sección de Notificaciones"
    final item = notification.toNotificationItem(isRead: false);
    _cachedNotifications.removeWhere((existing) => existing.id == item.id);
    _cachedNotifications.insert(0, item);
    _persistNotifications();
    _notifyListChanged();

    // Si es un mensaje propio y no es forzado, no alertar con sonido para no molestar
    if (isOwnMessage && !forceAlert) {
      return;
    }

    // Si está viendo actualmente esa misma conversación, sólo emitir al stream interno
    if (activeConversationId == notification.conversationId && !forceAlert) {
      if (!_notificationController.isClosed) {
        _notificationController.add(notification);
      }
      return;
    }

    // Feedback táctil y sonoro
    if (!_isTestEnvironment) {
      try {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.lightImpact();
      } catch (_) {}
    }

    // Mostrar en el panel del sistema operativo (Android / iOS)
    unawaited(_showSystemNotification(notification));

    // Mostrar en el banner superior in-app
    if (!_notificationController.isClosed) {
      _notificationController.add(notification);
    }
  }

  void _handleIncomingNotification(dynamic data) {
    if (data is! Map) return;
    handleIncomingNotification(Map<String, dynamic>.from(data));
  }

  /// Registra una notificación en la sección interna cuando se recibe en el chat activo.
  void recordMessageFromChat({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    String? senderAvatarUrl,
    String? attachmentUrl,
  }) {
    final item = NotificationItem(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderRole: 'Usuario',
      senderAvatarUrl: senderAvatarUrl,
      title: senderName,
      content: content.isNotEmpty ? content : '📷 Imagen adjunta',
      attachmentUrl: attachmentUrl,
      createdAt: DateTime.now(),
      isRead: activeConversationId == conversationId,
    );

    _cachedNotifications.removeWhere((existing) => existing.id == item.id);
    _cachedNotifications.insert(0, item);
    _persistNotifications();
    _notifyListChanged();
  }

  /// Envía una notificación de prueba para verificar inmediatamente
  /// la bandeja del sistema, el banner superior y la sección de notificaciones.
  Future<void> sendTestNotification({
    String? title,
    String? message,
  }) async {
    final testData = {
      'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
      'conversationId': 'conv_proyecto_demo',
      'senderId': 'carlos_soporte_demo',
      'senderName': title ?? 'Soporte FreelancerHub',
      'senderRole': 'CLIENT',
      'content': message ??
          '¡Hola! Tu sistema de notificaciones está funcionando perfectamente en tiempo real.',
      'createdAt': DateTime.now().toIso8601String(),
    };

    handleIncomingNotification(testData, forceAlert: true);
  }

  /// Marca una notificación individual como leída.
  Future<void> markAsRead(String id) async {
    for (final notif in _cachedNotifications) {
      if (notif.id == id) {
        notif.isRead = true;
      }
    }
    await _persistNotifications();
    _notifyListChanged();
  }

  /// Marca todas las notificaciones como leídas.
  Future<void> markAllAsRead() async {
    for (final notif in _cachedNotifications) {
      notif.isRead = true;
    }
    await _persistNotifications();
    _notifyListChanged();
  }

  /// Elimina todo el historial de notificaciones.
  Future<void> clearAll() async {
    _cachedNotifications.clear();
    await _persistNotifications();
    _notifyListChanged();
  }

  String? _extractSubFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        return (payload['sub'] ?? payload['userId'] ?? payload['id'])
            ?.toString();
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
