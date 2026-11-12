import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelancer_hub_frontend_movil/models/chat_conversation.dart';
import 'package:freelancer_hub_frontend_movil/screens/chat/chat_screen.dart';
import 'package:freelancer_hub_frontend_movil/screens/chat/conversations_screen.dart';

void main() {
  final testConversations = [
    ChatConversation(
      id: 'conv_1',
      peerId: 'peer_1',
      peerName: 'Carlos Méndez',
      peerRole: 'Cliente Contratante',
      projectName: 'App Flutter Fintech',
      lastMessage: '¿Pudiste revisar los mockups?',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 2,
      isOnline: true,
      lastMessageIsMine: false,
    ),
    ChatConversation(
      id: 'conv_2',
      peerId: 'peer_2',
      peerName: 'Ana Sofía López',
      peerRole: 'Freelancer UI/UX',
      projectName: 'Rediseño Sistema de Diseño',
      lastMessage: 'Subí los componentes a Figma.',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
      unreadCount: 0,
      isOnline: false,
      lastMessageIsMine: true,
    ),
  ];

  Widget createWidgetUnderTest({List<ChatConversation>? conversations}) {
    return MaterialApp(
      home: ConversationsScreen(
        initialConversations: conversations ?? testConversations,
      ),
    );
  }

  testWidgets('ConversationsScreen renders title, search and conversations list', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Mensajes'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Carlos Méndez'), findsOneWidget);
    expect(find.text('Ana Sofía López'), findsOneWidget);
    expect(find.text('App Flutter Fintech'), findsOneWidget);
    expect(find.text('¿Pudiste revisar los mockups?'), findsOneWidget);
  });

  testWidgets('Search input filters contacts dynamically', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Buscar "Ana"
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pumpAndSettle();

    expect(find.text('Ana Sofía López'), findsOneWidget);
    expect(find.text('Carlos Méndez'), findsNothing);

    // Buscar algo que no existe
    await tester.enterText(find.byType(TextField), 'InexistenteXYZ');
    await tester.pumpAndSettle();

    expect(find.text('Carlos Méndez'), findsNothing);
    expect(find.text('Ana Sofía López'), findsNothing);
    expect(find.text('Sin resultados para "InexistenteXYZ"'), findsOneWidget);
  });

  testWidgets('Filter chip "No leídos" filters correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Seleccionar filtro "No leídos"
    await tester.tap(find.text('No leídos'));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Méndez'), findsOneWidget);
    expect(find.text('Ana Sofía López'), findsNothing);
  });

  testWidgets('Tapping a conversation navigates to ChatScreen with peer name', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap en la conversación de Carlos Méndez
    await tester.tap(find.text('Carlos Méndez'));
    await tester.pumpAndSettle();

    // Debe abrir ChatScreen mostrando a Carlos Méndez
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Carlos Méndez'), findsOneWidget);
  });
}

