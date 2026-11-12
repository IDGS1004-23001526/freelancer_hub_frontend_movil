import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

class ChatContact {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  const ChatContact({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Usuario',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Usuario',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

class ChatApiService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene únicamente las conversaciones del usuario autenticado.
  Future<List<ChatConversation>> getConversations() async {
    final headers = await _getHeaders();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await http
            .get(Uri.parse('$base/chats'), headers: headers)
            .timeout(const Duration(seconds: 5));
        AuthService.activeBaseUrl = base;

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final list = (body is Map<String, dynamic> ? body['data'] : body) as List<dynamic>? ?? [];
          return list.whereType<Map<String, dynamic>>().map((item) {
            return ChatConversation(
              id: item['id']?.toString() ?? '',
              peerId: item['peerId']?.toString() ?? '',
              peerName: item['peerName']?.toString() ?? 'Usuario',
              peerRole: item['peerRole']?.toString() ?? 'Usuario',
              peerAvatarUrl: item['peerAvatarUrl']?.toString(),
              projectName: item['projectName']?.toString(),
              lastMessage: item['lastMessage']?.toString() ?? '',
              lastMessageTime: DateTime.tryParse(item['lastMessageTime']?.toString() ?? '') ?? DateTime.now(),
              unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
              isOnline: item['isOnline'] == true,
              lastMessageIsMine: item['lastMessageIsMine'] == true,
            );
          }).toList();
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          return [];
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception('No se pudo cargar la lista de chats.');
  }

  /// Obtiene el historial de mensajes de una conversación (validando pertenencia en el backend).
  Future<List<ChatMessage>> getMessages(String conversationId, {required String currentUserId}) async {
    final headers = await _getHeaders();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await http
            .get(Uri.parse('$base/chats/$conversationId/messages'), headers: headers)
            .timeout(const Duration(seconds: 5));
        AuthService.activeBaseUrl = base;

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final list = (body is Map<String, dynamic> ? body['data'] : body) as List<dynamic>? ?? [];
          return list
              .whereType<Map<String, dynamic>>()
              .map((m) => ChatMessage.fromJson(m, currentUserId: currentUserId))
              .toList();
        }
        if (response.statusCode == 403 || response.statusCode == 404) {
          return [];
        }
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  /// Envía un mensaje vía REST (respaldo y persistencia garantizada).
  Future<ChatMessage?> sendMessage(
    String conversationId,
    String content, {
    required String currentUserId,
  }) async {
    final headers = await _getHeaders();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/chats/$conversationId/messages'),
              headers: headers,
              body: jsonEncode({'content': content}),
            )
            .timeout(const Duration(seconds: 5));
        AuthService.activeBaseUrl = base;

        if (response.statusCode == 201 || response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final payload = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
          if (payload is Map<String, dynamic>) {
            return ChatMessage.fromJson(payload, currentUserId: currentUserId);
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Marca los mensajes de la conversación como leídos.
  Future<void> markAsRead(String conversationId) async {
    final headers = await _getHeaders();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        await http
            .patch(Uri.parse('$base/chats/$conversationId/read'), headers: headers)
            .timeout(const Duration(seconds: 4));
        return;
      } catch (_) {
        continue;
      }
    }
  }

  /// Busca perfiles/usuarios existentes en la plataforma para iniciar un nuevo chat.
  Future<List<ChatContact>> searchContacts({String query = ''}) async {
    final headers = await _getHeaders();
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final path = encodedQuery.isEmpty ? '/chats/contacts' : '/chats/contacts?search=$encodedQuery';

    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await http
            .get(Uri.parse('$base$path'), headers: headers)
            .timeout(const Duration(seconds: 5));
        AuthService.activeBaseUrl = base;

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final list = (body is Map<String, dynamic> ? body['data'] : body) as List<dynamic>? ?? [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(ChatContact.fromJson)
              .toList();
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          return [];
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception('No se pudieron buscar los perfiles.');
  }

  /// Crea o recupera una conversación real en el backend con el perfil seleccionado.
  Future<ChatConversation?> createOrGetConversation({
    required String peerId,
    String? projectId,
    String? projectName,
  }) async {
    final headers = await _getHeaders();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/chats'),
              headers: headers,
              body: jsonEncode({
                'peerId': peerId,
                if (projectId != null) 'projectId': projectId,
                if (projectName != null) 'projectName': projectName,
              }),
            )
            .timeout(const Duration(seconds: 5));
        AuthService.activeBaseUrl = base;

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          final item = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
          if (item is Map<String, dynamic>) {
            return ChatConversation(
              id: item['id']?.toString() ?? '',
              peerId: item['peerId']?.toString() ?? peerId,
              peerName: item['peerName']?.toString() ?? 'Usuario',
              peerRole: item['peerRole']?.toString() ?? 'Usuario',
              peerAvatarUrl: item['peerAvatarUrl']?.toString(),
              projectName: item['projectName']?.toString(),
              lastMessage: 'Conversación iniciada',
              lastMessageTime: DateTime.now(),
              unreadCount: 0,
              isOnline: false,
              lastMessageIsMine: true,
            );
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
