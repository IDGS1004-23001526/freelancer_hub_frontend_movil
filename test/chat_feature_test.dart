import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/models/chat_message.dart';
import 'package:freelance_hub_movil/screens/chat/chat_screen.dart';
import 'package:freelance_hub_movil/services/chat_socket_service.dart';
import 'package:freelance_hub_movil/theme/app_colors.dart';

class MockChatSocketService extends ChatSocketService {
  final _mockMessageController = StreamController<ChatMessage>.broadcast();
  final _mockConnectionController = StreamController<SocketConnectionState>.broadcast();
  final _mockStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _mockTypingController = StreamController<bool>.broadcast();

  final List<ChatMessage> sentMessages = [];

  @override
  Stream<ChatMessage> get onMessageReceived => _mockMessageController.stream;

  @override
  Stream<SocketConnectionState> get onConnectionStateChanged => _mockConnectionController.stream;

  @override
  Stream<Map<String, dynamic>> get onMessageStatusChanged => _mockStatusController.stream;

  @override
  Stream<bool> get onTypingChanged => _mockTypingController.stream;

  @override
  Future<void> connect({
    required String conversationId,
    String? explicitUrl,
    String? currentUserId,
  }) async {
    _mockConnectionController.add(SocketConnectionState.connected);
  }

  @override
  void sendMessage(ChatMessage message) {
    sentMessages.add(message);
  }

  void emitIncomingMessage(ChatMessage message) {
    _mockMessageController.add(message);
  }

  void emitConnectionState(SocketConnectionState state) {
    _mockConnectionController.add(state);
  }

  void emitMessageStatus(String messageId, String status) {
    _mockStatusController.add({'messageId': messageId, 'status': status});
  }

  void emitTyping(bool isTyping) {
    _mockTypingController.add(isTyping);
  }

  @override
  void triggerMessageFeedback() {}

  @override
  void dispose() {
    _mockMessageController.close();
    _mockConnectionController.close();
    _mockStatusController.close();
    _mockTypingController.close();
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FLH-MOB-CHAT (HU-11) - Chat en Vivo, Sockets y Notificaciones', () {
    test('ChatMessage model serializa correctamente y asigna status y tiempo', () {
      final now = DateTime(2026, 11, 6, 15, 30);
      final msg = ChatMessage(
        id: 'msg_123',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        senderName: 'Carlos',
        content: 'Presupuesto acordado',
        timestamp: now,
        status: MessageStatus.read,
        isMine: true,
      );

      expect(msg.formattedTime, equals('15:30'));
      expect(msg.isMine, isTrue);
      expect(msg.status, equals(MessageStatus.read));

      final json = msg.toJson();
      expect(json['content'], equals('Presupuesto acordado'));
      expect(json['status'], equals('read'));

      final parsed = ChatMessage.fromJson(json, currentUserId: 'user_a');
      expect(parsed.id, equals('msg_123'));
      expect(parsed.isMine, isTrue);
      expect(parsed.status, equals(MessageStatus.read));
    });

    testWidgets('Criterio 2: Burbujas diferenciadas por color y alineación', (
      WidgetTester tester,
    ) async {
      final mockSocket = MockChatSocketService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            peerName: 'Carlos Méndez',
            currentUserId: 'my_user_id',
            currentUserName: 'Yo',
            socketService: mockSocket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el título del contacto y rol
      expect(find.text('Carlos Méndez'), findsOneWidget);

      // Verificamos presencia de los mensajes iniciales
      expect(find.text('¡Hola! Revisé tu propuesta para el desarrollo móvil y me parece excelente.'), findsOneWidget);
      expect(find.text('Muchas gracias Carlos. Ya tengo listo el desglose de hitos para la custodia Escrow.'), findsOneWidget);

      // Verificamos los contenedores con colores oficiales requeridos
      // Mensaje propio: Vino #5A0F24
      final mineContainers = tester.widgetList<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.chatBubbleMine),
      );
      expect(mineContainers.isNotEmpty, isTrue);

      // Mensaje de la contraparte: Crema #F3EFE6
      final peerContainers = tester.widgetList<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.chatBubblePeer),
      );
      expect(peerContainers.isNotEmpty, isTrue);
    });

    testWidgets('Criterio 4: Indicadores visuales de entrega y lectura (Checks)', (
      WidgetTester tester,
    ) async {
      final mockSocket = MockChatSocketService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            peerName: 'Carlos Méndez',
            currentUserId: 'my_user_id',
            currentUserName: 'Yo',
            socketService: mockSocket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar iconos de estado de mensaje (done_all para read/delivered)
      expect(find.byIcon(Icons.done_all), findsWidgets);
    });

    testWidgets('Criterios de Aceptación: Envío instantáneo de mensaje sin refresco', (
      WidgetTester tester,
    ) async {
      final mockSocket = MockChatSocketService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            peerName: 'Carlos Méndez',
            currentUserId: 'my_user_id',
            currentUserName: 'Yo',
            socketService: mockSocket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Escribir mensaje en la barra inferior
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'Hito 1 fondeado y listo para comenzar.',
      );
      await tester.pump();

      // Pulsar botón de envío
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // El mensaje debe aparecer de inmediato en pantalla
      expect(find.text('Hito 1 fondeado y listo para comenzar.'), findsOneWidget);

      // El socket debe haber emitido el mensaje
      expect(mockSocket.sentMessages.length, equals(1));
      expect(mockSocket.sentMessages.first.content, equals('Hito 1 fondeado y listo para comenzar.'));
    });

    testWidgets('Criterios de Aceptación: Recepción en vivo por Socket.io y reconexión transparente', (
      WidgetTester tester,
    ) async {
      final mockSocket = MockChatSocketService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            peerName: 'Carlos Méndez',
            currentUserId: 'my_user_id',
            currentUserName: 'Yo',
            socketService: mockSocket,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simular llegada de mensaje entrante en tiempo real vía socket
      mockSocket.emitIncomingMessage(
        ChatMessage(
          id: 'incoming_test_1',
          senderId: 'user_peer_001',
          receiverId: 'my_user_id',
          senderName: 'Carlos Méndez',
          content: '¡Notificación instantánea recibida por socket!',
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
          isMine: false,
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrarse en pantalla inmediatamente sin refrescar
      expect(find.text('¡Notificación instantánea recibida por socket!'), findsOneWidget);

      // Simular desconexión / reconexión de red móvil transparente
      mockSocket.emitConnectionState(SocketConnectionState.reconnecting);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Debe visualizarse el banner de reconexión automática
      expect(find.text('Reconectando al servidor de chat automáticamente...'), findsOneWidget);

      // Al reconectarse exitosamente, el banner desaparece
      mockSocket.emitConnectionState(SocketConnectionState.connected);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text('Reconectando al servidor de chat automáticamente...'), findsNothing);
    });
  });
}
