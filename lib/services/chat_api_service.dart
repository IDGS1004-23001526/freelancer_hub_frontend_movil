import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

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
}
