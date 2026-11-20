import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/models/chat_conversation.dart';
import 'package:freelance_hub_movil/models/chat_message.dart';
import 'package:freelance_hub_movil/screens/chat/chat_screen.dart';
import 'package:freelance_hub_movil/services/chat_message_queue.dart';
import 'package:freelance_hub_movil/services/chat_socket_service.dart';
import 'package:freelance_hub_movil/theme/app_colors.dart';

class MockChatSocketService extends ChatSocketService {
  final _mockMessageController = StreamController<ChatMessage>.broadcast();
  final _mockConnectionController = StreamController<SocketConnectionState>.broadcast();
  final _mockStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _mockTypingController = StreamController<bool>.broadcast();

  SocketConnectionState _state = SocketConnectionState.connected;
  @override
  SocketConnectionState get currentState => _state;

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
    _state = state;
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

  setUp(() {
    ChatMessageQueue().clear();
  });

  group('FLH-MOB-CHAT (HU-11) - Chat en Vivo, Sockets y Notificaciones', () {
    testWidgets('OBJETIVO: Iniciar/mantener conversación, verificar recepción de mensajes y envío de Sticker con la API', (
      WidgetTester tester,
    ) async {
      final mockSocket = MockChatSocketService();

      // 1. Iniciar la conversación con el cliente/freelancer (Carlos Méndez)
      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            conversationId: 'conv_proyecto_e2e',
            peerName: 'Carlos Méndez',
            currentUserId: 'user_freelancer_01',
            currentUserName: 'Mi Perfil',
            socketService: mockSocket,
            initialMessages: const [], // Comienza limpia para iniciar el hilo
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que se inició la interfaz del chat con el contacto
      expect(find.text('Carlos Méndez'), findsOneWidget);
      expect(find.byKey(const Key('chat_input_field')), findsOneWidget);
      expect(find.byKey(const Key('chat_send_button')), findsOneWidget);

      // 2. Enviar primer mensaje para iniciar la conversación
      const mensajeInicial = 'Hola Carlos, inicio el hito 1 del desarrollo de la app móvil.';
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        mensajeInicial,
      );
      await tester.pump();

      // Presionar el botón de enviar
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // VALIDACIÓN: El mensaje debe aparecer de inmediato en pantalla
      expect(find.text(mensajeInicial), findsOneWidget);

      // VALIDACIÓN: El socket/API de envío debe haber procesado y despachado el mensaje
      expect(mockSocket.sentMessages.length, equals(1));
      expect(mockSocket.sentMessages.first.content, equals(mensajeInicial));

      // 3. Mantener la conversación: Simular que la contraparte responde en tiempo real
      const respuestaCarlos = '¡Excelente noticia! Ya reviso los entregables para liberar el hito.';
      mockSocket.emitIncomingMessage(
        ChatMessage(
          id: 'incoming_carlos_001',
          conversationId: 'conv_proyecto_e2e',
          senderId: 'carlos_mendez_id',
          receiverId: 'user_freelancer_01',
          senderName: 'Carlos Méndez',
          content: respuestaCarlos,
          timestamp: DateTime.now(),
          status: MessageStatus.delivered,
          isMine: false,
        ),
      );
      await tester.pumpAndSettle();

      // VALIDACIÓN OBJETIVO: Comprobar que la respuesta SÍ llegó y se renderiza en la conversación
      expect(find.text(respuestaCarlos), findsOneWidget);

      // 4. Enviar un Sticker con la API implementada para cerrar o celebrar el acuerdo
      await tester.tap(find.byKey(const Key('chat_sticker_button')));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña de Stickers
      expect(find.text('Stickers'), findsOneWidget);
      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();

      // Seleccionar el sticker oficial "¡Trato Hecho!" (deal_done)
      expect(find.text('¡Trato Hecho!'), findsOneWidget);
      await tester.tap(find.text('¡Trato Hecho!'));
      await tester.pumpAndSettle();

      // VALIDACIÓN OBJETIVO: Verificar que el sticker se renderizó en la conversación
      expect(find.text('¡Trato Hecho!'), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsWidgets);

      // VALIDACIÓN OBJETIVO: Verificar que la API/Socket transmitió el sticker con el formato establecido
      expect(mockSocket.sentMessages.any((m) => m.content.contains('deal_done')), isTrue);
      expect(mockSocket.sentMessages.any((m) => m.attachmentUrl == 'sticker:deal_done'), isTrue);
    });

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
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Carlos Méndez')), findsOneWidget);

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

    testWidgets('Envío y visualización de Stickers en el chat', (
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

      // Abrir selector de GIFs y stickers pulsando el botón dedicado
      await tester.tap(find.byKey(const Key('chat_sticker_button')));
      await tester.pumpAndSettle();

      // Debe abrirse el selector estilo WhatsApp con pestañas de GIFs Animados y Stickers
      expect(find.text('GIFs Animados'), findsOneWidget);
      expect(find.text('Stickers'), findsOneWidget);

      // Cambiar a la pestaña de Stickers
      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();

      // Seleccionar el sticker "¡Trato Hecho!"
      expect(find.text('¡Trato Hecho!'), findsOneWidget);
      await tester.tap(find.text('¡Trato Hecho!'));
      await tester.pumpAndSettle();

      // El sticker seleccionado debe mostrarse en la conversación
      expect(find.text('¡Trato Hecho!'), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsWidgets);

      // El socket debe haber recibido el sticker
      expect(mockSocket.sentMessages.any((m) => m.content.contains('deal_done')), isTrue);
    });

    testWidgets('Envío y visualización de GIFs animados estilo WhatsApp', (
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

      // Abrir selector
      await tester.tap(find.byKey(const Key('chat_sticker_button')));
      await tester.pumpAndSettle();

      // Verificar pestaña de GIFs Animados
      expect(find.text('GIFs Animados'), findsOneWidget);
      expect(find.text('Programando a tope'), findsOneWidget);

      // Seleccionar el primer GIF animado
      await tester.tap(find.text('Programando a tope'));
      await tester.pumpAndSettle();

      // Debe mostrarse en el chat la burbuja del GIF con badge 'GIF'
      expect(find.text('GIF'), findsWidgets);

      // El socket debe haber emitido el GIF
      expect(mockSocket.sentMessages.any((m) => m.content.contains('[gif:')), isTrue);
    });

    testWidgets('Swipe to Reply estilo WhatsApp: deslizar mensaje, vista previa y cita en respuesta', (
      WidgetTester tester,
    ) async {
      final mockSocket = MockChatSocketService();

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            conversationId: 'conv_swipe_test',
            peerName: 'Carlos Méndez',
            currentUserId: 'my_user_id',
            currentUserName: 'Yo',
            socketService: mockSocket,
            initialMessages: [
              ChatMessage(
                id: 'msg_target_1',
                conversationId: 'conv_swipe_test',
                senderId: 'user_peer_001',
                receiverId: 'my_user_id',
                senderName: 'Carlos Méndez',
                content: '¿Puedes entregar el módulo para el viernes?',
                timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
                status: MessageStatus.read,
                isMine: false,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Mensaje inicial visible en pantalla
      final targetMessageFinder = find.text('¿Puedes entregar el módulo para el viernes?');
      expect(targetMessageFinder, findsOneWidget);

      // 2. Banner de respuesta no debe estar visible inicialmente
      expect(find.byKey(const Key('chat_replying_banner')), findsNothing);

      // 3. Deslizar horizontalmente el mensaje hacia la derecha (swipe to reply)
      await tester.drag(targetMessageFinder, const Offset(80.0, 0.0));
      await tester.pumpAndSettle();

      // 4. El banner estilo WhatsApp debe mostrarse con el autor y snippet
      expect(find.byKey(const Key('chat_replying_banner')), findsOneWidget);
      expect(find.text('Respondiendo a Carlos Méndez'), findsOneWidget);
      expect(find.text('¿Puedes entregar el módulo para el viernes?'), findsWidgets);

      // 5. Probar el botón de cancelar respuesta
      final cancelBtnFinder = find.byKey(const Key('chat_cancel_reply_button'));
      expect(cancelBtnFinder, findsOneWidget);
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      // Banner debe haber desaparecido
      expect(find.byKey(const Key('chat_replying_banner')), findsNothing);

      // 6. Volver a deslizar para responder y enviar mensaje
      await tester.drag(targetMessageFinder, const Offset(80.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_replying_banner')), findsOneWidget);

      // Escribir texto de respuesta
      await tester.enterText(find.byKey(const Key('chat_input_field')), '¡Sí, seguro! Lo tendré listo.');
      await tester.pumpAndSettle();

      // Enviar respuesta
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      // 7. El banner debe haberse cerrado automáticamente
      expect(find.byKey(const Key('chat_replying_banner')), findsNothing);

      // 8. El mensaje enviado debe aparecer en pantalla con su texto y la cita previa visible
      expect(find.text('¡Sí, seguro! Lo tendré listo.'), findsOneWidget);

      // 9. El socket debe haber recibido el mensaje con los campos replyTo
      expect(mockSocket.sentMessages.isNotEmpty, isTrue);
      final sentReply = mockSocket.sentMessages.last;
      expect(sentReply.replyToMessageId, equals('msg_target_1'));
      expect(sentReply.replyToSenderName, equals('Carlos Méndez'));
      expect(sentReply.replyToContent, contains('¿Puedes entregar el módulo'));
      expect(sentReply.hasReply, isTrue);

      // 10. La caja de cita en la burbuja del mensaje enviado debe estar presente
      expect(find.byKey(Key('quoted_reply_${sentReply.id}')), findsOneWidget);
    });

    test('ChatMessage model maneja replyTo fields, persistencia en content y snippets', () {
      final msg = ChatMessage(
        id: 'msg_99',
        senderId: 'user_1',
        receiverId: 'user_2',
        senderName: 'Ana',
        content: 'Hola mundo',
        timestamp: DateTime.now(),
        isMine: false,
        replyToMessageId: 'msg_88',
        replyToSenderName: 'Carlos',
        replyToContent: 'Mensaje anterior',
      );

      expect(msg.hasReply, isTrue);
      expect(msg.quoteSnippet, equals('Hola mundo'));
      expect(msg.replySnippet, equals('Mensaje anterior'));

      final json = msg.toJson();
      expect(json['replyToMessageId'], equals('msg_88'));
      expect(json['replyToSenderName'], equals('Carlos'));
      expect(json['replyToContent'], equals('Mensaje anterior'));
      expect(json['content'], contains('[reply:'));

      final reconstructed = ChatMessage.fromJson(json);
      expect(reconstructed.replyToMessageId, equals('msg_88'));
      expect(reconstructed.replyToSenderName, equals('Carlos'));
      expect(reconstructed.replyToContent, equals('Mensaje anterior'));
      expect(reconstructed.content, equals('Hola mundo'));

      // Probar decodificación de mensaje persistido en BD que solo almacena content
      final rawBackendJson = {
        'id': 'msg_from_db',
        'senderId': 'user_1',
        'receiverId': 'user_2',
        'senderName': 'Carlos',
        'content': '[reply:{"id":"msg_88","sender":"Carlos","text":"Mensaje anterior"}]\n¡Sí, seguro!',
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sent',
      };
      final fromDb = ChatMessage.fromJson(rawBackendJson);
      expect(fromDb.hasReply, isTrue);
      expect(fromDb.replyToMessageId, equals('msg_88'));
      expect(fromDb.replyToSenderName, equals('Carlos'));
      expect(fromDb.replyToContent, equals('Mensaje anterior'));
      expect(fromDb.content, equals('¡Sí, seguro!'));
    });

    test('ChatConversation sanitiza [reply:...] y no muestra JSON en vista previa de último mensaje', () {
      final conv = ChatConversation(
        id: 'conv_123',
        peerId: 'peer_1',
        peerName: 'Christopher Isaac Rivera',
        peerRole: 'Freelancer',
        lastMessage: '[reply:{"id":"d38db8cb-a2ef","sender":"Carlos","text":"¿Qué tal?"}]\nHola, todo bien!',
        lastMessageTime: DateTime.now(),
        lastMessageIsMine: true,
      );

      // No debe contener el JSON ni la etiqueta [reply:...]
      expect(conv.lastMessage, isNot(contains('[reply:')));
      expect(conv.lastMessage, isNot(contains('d38db8cb')));
      expect(conv.lastMessage, equals('Hola, todo bien!'));
      expect(conv.displayLastMessage, equals('Hola, todo bien!'));

      // Comprobar stickers y GIFs en vista previa
      expect(ChatConversation.cleanPreview('[reply:{"id":"1"}]\n[sticker:deal_done]'), equals('🏷️ Sticker'));
      expect(ChatConversation.cleanPreview('[reply:{"id":"2"}]\n[gif:https://tenor.com/view]'), equals('🎬 GIF'));
    });
  });
}
