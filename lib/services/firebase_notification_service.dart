import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';
import '../screens/chat/chat_screen.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Manejador en segundo plano de Firebase Messaging (Top-Level para isolate en segundo plano).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

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

/// Servicio oficial de notificaciones móviles basado exclusivamente en Firebase Cloud Messaging (FCM).
class FirebaseNotificationService {
  FirebaseNotificationService._internal();

  static final FirebaseNotificationService instance =
      FirebaseNotificationService._internal();

  final AuthService _authService = AuthService();
  final _notificationController = StreamController<MessageNotification>.broadcast();
  final _tapController = StreamController<MessageNotification>.broadcast();

  Stream<MessageNotification> get onMessageNotification => _notificationController.stream;
  Stream<MessageNotification> get onNotificationTap => _tapController.stream;

  String? activeConversationId;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  GlobalKey<NavigatorState>? navigatorKey;

  /// Inicializa Firebase Cloud Messaging (FCM) para recibir y gestionar notificaciones
  /// push en primer plano, segundo plano y cuando la app está completamente cerrada.
  Future<void> initializeFirebaseMessaging({GlobalKey<NavigatorState>? navKey}) async {
    if (navKey != null) navigatorKey = navKey;
    if (kIsWeb) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Solicitar permisos de notificación (Android 13+ / iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('Permisos de Firebase Notifications: ${settings.authorizationStatus}');

      // 2. Configurar presentación nativa de notificaciones en primer plano
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Obtener y registrar el token FCM del dispositivo
      _fcmToken = await messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('FCM Token registrado: $_fcmToken');
        unawaited(syncFcmTokenWithBackend(_fcmToken!));
      }

      // 4. Escuchar rotación o renovación del token FCM
      messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        unawaited(syncFcmTokenWithBackend(newToken));
      });

      // 5. Mensajes entrantes mientras la app está en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingFcmMessage(message);
      });

      // 6. Apertura de notificación cuando la app estaba en segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleFcmNotificationTap(message.data);
      });

      // 7. Apertura cuando la app estaba completamente cerrada (Cold start)
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleFcmNotificationTap(initialMessage.data);
      }
    } catch (e) {
      debugPrint('Aviso: FirebaseMessaging no disponible en este entorno: $e');
    }
  }

  /// Sincroniza el token FCM con el backend para que el servidor envíe notificaciones push.
  Future<void> syncFcmTokenWithBackend([String? token]) async {
    final effectiveToken = token ?? _fcmToken;
    if (effectiveToken == null || effectiveToken.isEmpty) return;

    try {
      final jwt = await _authService.getToken();
      if (jwt == null || jwt.isEmpty) return;

      await ApiClient.instance.dio.post(
        '/users/fcm-token',
        data: {'fcmToken': effectiveToken},
      );
      debugPrint('FCM Token sincronizado exitosamente con el backend');
    } catch (_) {
      // Falla silenciosa si no hay conexión en ese instante
    }
  }

  void _handleIncomingFcmMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    final notification = MessageNotification.fromJson(data);
    if (notification.conversationId.isEmpty) return;

    // Si el usuario ya está viendo esa misma conversación, omitir feedback
    if (activeConversationId == notification.conversationId) return;

    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.lightImpact();
    } catch (_) {}

    if (!_notificationController.isClosed) {
      _notificationController.add(notification);
    }
  }

  void _handleFcmNotificationTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    try {
      final item = MessageNotification.fromJson(data);
      if (item.conversationId.isNotEmpty) {
        if (!_tapController.isClosed) {
          _tapController.add(item);
        }
        _navigateToConversation(item);
      }
    } catch (_) {}
  }

  void _navigateToConversation(MessageNotification item) {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: item.conversationId,
          peerId: item.senderId,
          peerName: item.senderName,
          peerAvatarUrl: item.senderAvatarUrl,
        ),
      ),
    );
  }
}
