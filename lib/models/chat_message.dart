import 'dart:convert';

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isMine;
  final String? attachmentUrl;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToContent;

  ChatMessage({
    required this.id,
    this.conversationId = 'default_conversation',
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required String content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    required this.isMine,
    this.attachmentUrl,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToContent,
  }) : content = cleanContent(content);

  /// Remueve cualquier prefijo técnico [reply:...] del texto legible del mensaje
  static String cleanContent(String raw) {
    if (raw.isEmpty) return raw;
    String text = raw;
    while (text.startsWith('[reply:')) {
      final closeIdx = text.indexOf(']');
      if (closeIdx != -1) {
        text = text.substring(closeIdx + 1).trimLeft();
      } else {
        break;
      }
    }
    return text;
  }

  /// Determina si el mensaje contiene una respuesta/cita citada
  bool get hasReply =>
      replyToContent != null && replyToContent!.trim().isNotEmpty;

  /// Texto descriptivo resumido para mostrar cuando se cita este mensaje
  String get quoteSnippet {
    if (isSticker) return '🏷️ Sticker';
    if (isGif) return '🎬 GIF';
    final clean = cleanContent(content).trim();
    if (clean.isEmpty) return 'Archivo adjunto';
    return clean;
  }

  /// Empaqueta el prefijo de metadatos de respuesta dentro del campo content para persistencia agnóstica de base de datos
  static String encodeContentWithReply({
    required String? replyToMessageId,
    required String? replyToSenderName,
    required String? replyToContent,
    required String content,
  }) {
    if (replyToContent == null || replyToContent.trim().isEmpty) {
      return content;
    }
    final meta = jsonEncode({
      'id': replyToMessageId ?? '',
      'sender': replyToSenderName ?? '',
      'text': cleanContent(replyToContent).trim(),
    });
    return '[reply:$meta]\n${cleanContent(content)}';
  }

  /// Texto formateado del mensaje citado
  String get replySnippet {
    if (replyToContent == null) return '';
    final clean = cleanContent(replyToContent!).trim();
    if (clean.startsWith('[sticker:') && clean.endsWith(']')) return '🏷️ Sticker';
    if (clean.startsWith('[gif:') && clean.endsWith(']')) return '🎬 GIF';
    return clean;
  }

  /// Determina si el mensaje corresponde a un Sticker
  bool get isSticker {
    if (attachmentUrl != null && attachmentUrl!.startsWith('sticker:')) {
      return true;
    }
    final trimmed = content.trim();
    return trimmed.startsWith('[sticker:') && trimmed.endsWith(']');
  }

  /// Retorna la URL del sticker si es un sticker animado de internet (GIPHY / Tenor)
  String? get stickerUrl {
    final sId = stickerId;
    if (sId != null && (sId.startsWith('http://') || sId.startsWith('https://'))) {
      return sId;
    }
    return null;
  }

  /// Determina si el mensaje corresponde a un GIF animado o vídeo corto (excluyendo stickers)
  bool get isGif {
    if (isSticker) return false;
    if (attachmentUrl != null && attachmentUrl!.isNotEmpty && !attachmentUrl!.startsWith('sticker:')) {
      final lower = attachmentUrl!.toLowerCase();
      return lower.contains('.gif') ||
          lower.contains('giphy.com') ||
          lower.contains('tenor.com') ||
          lower.contains('gph.is');
    }
    final trimmed = content.trim();
    return trimmed.startsWith('[gif:') && trimmed.endsWith(']');
  }

  /// Obtiene la URL multimedia del GIF o imagen
  String? get mediaUrl {
    if (attachmentUrl != null && attachmentUrl!.isNotEmpty && !attachmentUrl!.startsWith('sticker:')) {
      return attachmentUrl;
    }
    final trimmed = content.trim();
    if (trimmed.startsWith('[gif:') && trimmed.endsWith(']')) {
      return trimmed.substring(5, trimmed.length - 1);
    }
    return null;
  }

  /// Extrae el identificador o URL del sticker si aplica
  String? get stickerId {
    if (attachmentUrl != null && attachmentUrl!.startsWith('sticker:')) {
      return attachmentUrl!.substring(8);
    }
    final trimmed = content.trim();
    if (trimmed.startsWith('[sticker:') && trimmed.endsWith(']')) {
      return trimmed.substring(9, trimmed.length - 1);
    }
    return null;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    final sender =
        (json['senderId'] ?? json['sender'] ?? json['from'] ?? '').toString().trim();
    final isMineMsg = json['isMine'] == true ||
        (currentUserId != null &&
            currentUserId.trim().isNotEmpty &&
            sender.toLowerCase() == currentUserId.trim().toLowerCase());

    MessageStatus parseStatus(dynamic raw) {
      if (json['isRead'] == true || json['read'] == true) return MessageStatus.read;
      final s = raw?.toString().toLowerCase();
      if (s == 'read' || s == 'visto') return MessageStatus.read;
      if (s == 'delivered' || s == 'entregado') return MessageStatus.delivered;
      if (s == 'sending' || s == 'enviando') return MessageStatus.sending;
      if (s == 'failed' || s == 'fallido' || s == 'error') return MessageStatus.failed;
      return MessageStatus.sent;
    }

    final convId = (json['conversationId'] ??
            json['contractId'] ??
            json['roomId'] ??
            'default_conversation')
        .toString();

    final attachment = json['attachmentUrl'] ?? json['attachment'] ?? json['imageUrl'];

    String resolvedContent =
        (json['content'] ?? json['message'] ?? json['text'] ?? '').toString();

    String? replyId = json['replyToMessageId'] ??
        json['replyTo'] ??
        json['reply_to_message_id'];
    String? replySender = json['replyToSenderName'] ??
        json['reply_to_sender_name'] ??
        json['replySenderName'];
    String? replyText = json['replyToContent'] ??
        json['reply_to_content'] ??
        json['replyContent'] ??
        json['replySnippet'];

    // Decodificar metadatos de respuesta embebidos en el contenido si existen y limpiar resolvedContent
    while (resolvedContent.startsWith('[reply:')) {
      final closeIdx = resolvedContent.indexOf(']');
      if (closeIdx != -1) {
        final metaRaw = resolvedContent.substring(7, closeIdx);
        try {
          final decoded = jsonDecode(metaRaw);
          if (decoded is Map) {
            replyId ??= decoded['id']?.toString();
            replySender ??= decoded['sender']?.toString();
            replyText ??= decoded['text']?.toString();
          }
        } catch (_) {}
        resolvedContent = resolvedContent.substring(closeIdx + 1).trimLeft();
      } else {
        break;
      }
    }

    return ChatMessage(
      id: (json['id'] ??
              json['_id'] ??
              json['messageId'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      conversationId: convId,
      senderId: sender,
      receiverId: (json['receiverId'] ?? json['recipient'] ?? json['to'] ?? '')
          .toString(),
      senderName: (json['senderName'] ?? json['name'] ?? 'Usuario').toString(),
      content: resolvedContent,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ??
                  DateTime.now()
              : DateTime.now()),
      status: parseStatus(json['status']),
      isMine: isMineMsg,
      attachmentUrl: attachment?.toString(),
      replyToMessageId: replyId?.toString(),
      replyToSenderName: replySender?.toString(),
      replyToContent: replyText?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveContent = hasReply && !content.startsWith('[reply:')
        ? ChatMessage.encodeContentWithReply(
            replyToMessageId: replyToMessageId,
            replyToSenderName: replyToSenderName,
            replyToContent: replyToContent,
            content: content,
          )
        : content;

    return {
      'id': id,
      'conversationId': conversationId,
      'contractId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'content': effectiveContent,
      'message': effectiveContent,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'isMine': isMine,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (replyToContent != null) 'replyToContent': replyToContent,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isMine,
    String? attachmentUrl,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isMine: isMine ?? this.isMine,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToContent: replyToContent ?? this.replyToContent,
    );
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
