import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/models/notification_item.dart';
import 'package:freelance_hub_movil/screens/notifications/notifications_screen.dart';
import 'package:freelance_hub_movil/services/notification_socket_service.dart';
import 'package:freelance_hub_movil/widgets/message_notification_overlay.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    NotificationSocketService.instance.disableSystemNotifications = true;
  });

  setUp(() async {
    await NotificationSocketService.instance.clearAll();
  });

  group('NotificationSocketService & NotificationItem', () {
    test('handleIncomingNotification almacena en historial y actualiza contador reactivo',
        () async {
      final service = NotificationSocketService.instance;
      expect(service.unreadCount, 0);

      final states = <int>[];
      final sub = service.unreadCountStream.listen(states.add);

      service.handleIncomingNotification({
        'id': 'notif_101',
        'conversationId': 'conv_123',
        'senderId': 'client_peer_456',
        'senderName': 'Carlos Slim',
        'senderRole': 'CLIENT',
        'content': 'Hola, ¿cómo va el desarrollo del hito?',
        'createdAt': DateTime.now().toIso8601String(),
      }, forceAlert: true);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(service.notifications.length, 1);
      expect(service.notifications.first.senderName, 'Carlos Slim');
      expect(service.notifications.first.content,
          'Hola, ¿cómo va el desarrollo del hito?');
      expect(service.notifications.first.isRead, isFalse);
      expect(service.unreadCount, 1);

      // Probar markAsRead
      await service.markAsRead('notif_101');
      expect(service.unreadCount, 0);
      expect(service.notifications.first.isRead, isTrue);

      await sub.cancel();
    });

    test('sendTestNotification genera y registra una notificación de prueba',
        () async {
      final service = NotificationSocketService.instance;
      await service.sendTestNotification(
        title: 'Prueba de Sistema',
        message: 'Mensaje de prueba exitoso',
      );

      expect(service.notifications.isNotEmpty, isTrue);
      expect(service.notifications.first.title, 'Prueba de Sistema');
      expect(service.notifications.first.content, 'Mensaje de prueba exitoso');
    });

    test('markAllAsRead y clearAll administran la lista correctamente',
        () async {
      final service = NotificationSocketService.instance;

      service.handleIncomingNotification({
        'id': 'n1',
        'conversationId': 'c1',
        'senderId': 's1',
        'senderName': 'User 1',
        'content': 'Mensaje 1',
      }, forceAlert: true);

      service.handleIncomingNotification({
        'id': 'n2',
        'conversationId': 'c2',
        'senderId': 's2',
        'senderName': 'User 2',
        'content': 'Mensaje 2',
      }, forceAlert: true);

      expect(service.notifications.length, 2);
      expect(service.unreadCount, 2);

      await service.markAllAsRead();
      expect(service.unreadCount, 0);

      await service.clearAll();
      expect(service.notifications.isEmpty, isTrue);
    });
  });

  group('NotificationsScreen Widget', () {
    testWidgets('Muestra estado vacío con opción de prueba cuando no hay notificaciones',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsScreen(),
        ),
      );

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('No tienes notificaciones pendientes'), findsOneWidget);
      expect(find.text('Generar notificación de prueba'), findsOneWidget);

      // Tocar botón de prueba
      await tester.tap(find.text('Generar notificación de prueba'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Debe aparecer la notificación generada en la lista
      expect(find.text('Soporte FreelancerHub'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('Muestra la lista de notificaciones con remitente y preview',
        (tester) async {
      final service = NotificationSocketService.instance;
      service.handleIncomingNotification({
        'id': 'notif_screen_1',
        'conversationId': 'conv_screen_1',
        'senderId': 'peer_007',
        'senderName': 'María Diseñadora',
        'senderRole': 'FREELANCER',
        'content': 'Adjunto las maquetas finales en Figma.',
        'createdAt': DateTime.now().toIso8601String(),
      }, forceAlert: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('María Diseñadora'), findsOneWidget);
      expect(find.text('Adjunto las maquetas finales en Figma.'), findsOneWidget);
      expect(find.text('Freelancer'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });

  group('MessageNotificationOverlay Banner', () {
    testWidgets('Despliega banner animado superior al emitir mensaje',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: MessageNotificationOverlay(
            navigatorKey: navKey,
            child: const Scaffold(
              body: Center(child: Text('Contenido Principal')),
            ),
          ),
        ),
      );

      expect(find.text('Contenido Principal'), findsOneWidget);
      expect(find.text('Nuevo mensaje de Pedro'), findsNothing);

      // Disparar notificación entrante
      NotificationSocketService.instance.handleIncomingNotification({
        'id': 'banner_1',
        'conversationId': 'conv_banner_1',
        'senderId': 'sender_pedro',
        'senderName': 'Pedro Cliente',
        'senderRole': 'CLIENT',
        'content': 'Nuevo mensaje de Pedro para ti.',
      }, forceAlert: true);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pedro Cliente'), findsOneWidget);
      expect(find.text('Nuevo mensaje de Pedro para ti.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  });
}
