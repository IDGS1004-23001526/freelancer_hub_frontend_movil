import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'api_client.dart';
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
  final ApiClient _apiClient;

  ChatApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Normaliza cualquier respuesta de Dio (sea String, Map<dynamic, dynamic> o Map<String, dynamic>)
  dynamic _normalizeResponseData(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return raw;
        }
      }
    }
    return raw;
  }

  /// Extrae con seguridad una lista de mapas desde la respuesta del backend
  List<Map<String, dynamic>> _extractListOfMaps(dynamic raw) {
    final body = _normalizeResponseData(raw);
    List<dynamic> list = [];

    if (body is Map) {
      final dataField = body['data'];
      if (dataField is List) {
        list = dataField;
      } else if (dataField is Map) {
        list = [dataField];
      }
    } else if (body is List) {
      list = body;
    }

    final List<Map<String, dynamic>> result = [];
    for (final item in list) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      }
    }
    return result;
  }

  /// Obtiene las conversaciones del usuario autenticado de forma directa y rápida.
  Future<List<ChatConversation>> getConversations() async {
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _apiClient.dio.get('$base/chats');

        if (response.statusCode == 200) {
          AuthService.activeBaseUrl = base;
          final listMaps = _extractListOfMaps(response.data);

          return listMaps.map((item) {
            return ChatConversation(
              id: item['id']?.toString() ?? '',
              peerId: item['peerId']?.toString() ?? '',
              peerName: item['peerName']?.toString() ?? 'Usuario',
              peerRole: item['peerRole']?.toString() ?? 'Usuario',
              peerAvatarUrl: item['peerAvatarUrl']?.toString(),
              projectName: item['projectName']?.toString(),
              lastMessage: item['lastMessage']?.toString() ?? '',
              lastMessageTime: DateTime.tryParse(
                      item['lastMessageTime']?.toString() ?? '') ??
                  DateTime.now(),
              unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
              isOnline: item['isOnline'] == true,
              lastMessageIsMine: item['lastMessageIsMine'] == true,
            );
          }).toList();
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          AuthService.activeBaseUrl = base;
          return [];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Fallo al conectar con base $base: $e');
        }
        continue;
      }
    }
    return [];
  }

  /// Obtiene el historial de mensajes de una conversación.
  Future<List<ChatMessage>> getMessages(String conversationId,
      {required String currentUserId}) async {
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response =
            await _apiClient.dio.get('$base/chats/$conversationId/messages');

        if (response.statusCode == 200) {
          AuthService.activeBaseUrl = base;
          final listMaps = _extractListOfMaps(response.data);

          return listMaps
              .map((m) =>
                  ChatMessage.fromJson(m, currentUserId: currentUserId))
              .toList();
        }

        if (response.statusCode == 403 || response.statusCode == 404) {
          AuthService.activeBaseUrl = base;
          return [];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Fallo al obtener mensajes con base $base: $e');
        }
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
    String? attachmentUrl,
  }) async {
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _apiClient.dio.post(
          '$base/chats/$conversationId/messages',
          data: {
            'content': content,
            if (attachmentUrl != null && attachmentUrl.isNotEmpty)
              'attachmentUrl': attachmentUrl,
          },
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          AuthService.activeBaseUrl = base;
          final body = _normalizeResponseData(response.data);
          Map<String, dynamic>? payload;

          if (body is Map) {
            final dataField = body['data'];
            if (dataField is Map) {
              payload = Map<String, dynamic>.from(dataField);
            } else {
              payload = Map<String, dynamic>.from(body);
            }
          }

          if (payload != null) {
            return ChatMessage.fromJson(payload, currentUserId: currentUserId);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Fallo al enviar mensaje con base $base: $e');
        }
        continue;
      }
    }
    return null;
  }

  /// Marca los mensajes de la conversación como leídos.
  Future<void> markAsRead(String conversationId) async {
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response =
            await _apiClient.dio.patch('$base/chats/$conversationId/read');
        if (response.statusCode == 200) {
          AuthService.activeBaseUrl = base;
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  /// Busca perfiles/usuarios existentes en la plataforma para iniciar un nuevo chat.
  Future<List<ChatContact>> searchContacts({String query = ''}) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final path = encodedQuery.isEmpty
        ? '/chats/contacts'
        : '/chats/contacts?search=$encodedQuery';

    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _apiClient.dio.get('$base$path');

        if (response.statusCode == 200) {
          AuthService.activeBaseUrl = base;
          final listMaps = _extractListOfMaps(response.data);
          return listMaps.map(ChatContact.fromJson).toList();
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          AuthService.activeBaseUrl = base;
          return [];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Fallo al buscar contactos con base $base: $e');
        }
        continue;
      }
    }
    return [];
  }

  /// Crea o recupera una conversación real en el backend con el perfil seleccionado.
  Future<ChatConversation?> createOrGetConversation({
    required String peerId,
    String? projectId,
    String? projectName,
  }) async {
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _apiClient.dio.post(
          '$base/chats',
          data: {
            'peerId': peerId,
            if (projectId != null) 'projectId': projectId,
            if (projectName != null) 'projectName': projectName,
          },
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          AuthService.activeBaseUrl = base;
          final body = _normalizeResponseData(response.data);
          Map<String, dynamic>? item;

          if (body is Map) {
            final dataField = body['data'];
            if (dataField is Map) {
              item = Map<String, dynamic>.from(dataField);
            } else {
              item = Map<String, dynamic>.from(body);
            }
          }

          if (item != null) {
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
      } catch (e) {
        if (kDebugMode) {
          print('Fallo al crear conversación con base $base: $e');
        }
        continue;
      }
    }
    return null;
  }
}
