import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/api_constants.dart';
import '../firebase_options.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'notification_socket_service.dart';

export 'notification_socket_service.dart' show MessageNotification;

/// Manejador en segundo plano de Firebase Messaging (Top-Level para isolate en segundo plano).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
}

/// Servicio que integra Firebase Cloud Messaging (FCM) con el motor principal de
/// Socket.IO y notificaciones locales (`NotificationSocketService`).
class FirebaseNotificationService {
  FirebaseNotificationService._internal();

  static final FirebaseNotificationService instance =
      FirebaseNotificationService._internal();

  final AuthService _authService = AuthService();
  final NotificationSocketService _socketNotifications =
      NotificationSocketService.instance;

  Stream<MessageNotification> get onMessageNotification =>
      _socketNotifications.onMessageNotification;
  Stream<MessageNotification> get onNotificationTap =>
      _socketNotifications.onNotificationTap;

  String? get activeConversationId => _socketNotifications.activeConversationId;
  set activeConversationId(String? val) {
    _socketNotifications.activeConversationId = val;
  }

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  GlobalKey<NavigatorState>? navigatorKey;

  /// Inicializa Firebase Cloud Messaging (FCM) para recibir y gestionar notificaciones
  /// push en primer plano, segundo plano y cuando la app está completamente cerrada.
  Future<void> initializeFirebaseMessaging({GlobalKey<NavigatorState>? navKey}) async {
    if (navKey != null) {
      navigatorKey = navKey;
    }

    // Inicializar siempre notificaciones locales y Socket.IO en primer lugar
    await _socketNotifications.initializeLocalNotifications();
    unawaited(_socketNotifications.connectIfAuthenticated());

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

  /// Verifica si el usuario ya otorgó permisos de notificación push
  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Solicita de manera explícita los permisos al sistema operativo (Android 13+ / iOS).
  /// Si son concedidos, obtiene el token FCM y lo sincroniza de inmediato con el backend.
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        _fcmToken = await messaging.getToken();
        debugPrint('[FirebaseNotificationService] Permiso concedido. FCM Token: $_fcmToken');
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          await syncFcmTokenWithBackend(_fcmToken);
        }
      }
      return granted;
    } catch (e) {
      debugPrint('[FirebaseNotificationService] Error solicitando permisos: $e');
      return false;
    }
  }

  /// Sincroniza el token FCM con el backend para que el servidor envíe notificaciones push.
  Future<void> syncFcmTokenWithBackend([String? token]) async {
    final effectiveToken = token ?? _fcmToken;
    if (effectiveToken == null || effectiveToken.isEmpty) return;

    try {
      final jwt = await _authService.getToken();
      if (jwt == null || jwt.isEmpty) return;

      final base = AuthService.activeBaseUrl ?? ApiConstants.baseUrl;
      await ApiClient.instance.dio.post(
        '$base/users/fcm-token',
        data: {'fcmToken': effectiveToken},
      );
      debugPrint('[FirebaseNotificationService] FCM Token sincronizado exitosamente con el backend');
    } catch (e) {
      debugPrint('[FirebaseNotificationService] Error sincronizando FCM Token: $e');
    }
  }

  void _handleIncomingFcmMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;

    _socketNotifications.handleIncomingNotification(
      Map<String, dynamic>.from(data),
    );
  }

  void _handleFcmNotificationTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _socketNotifications.handleIncomingNotification(data, forceAlert: true);
  }
}
