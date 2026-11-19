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

  ChatMessage({
    required this.id,
    this.conversationId = 'default_conversation',
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    required this.isMine,
    this.attachmentUrl,
  });

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
      content:
          (json['content'] ?? json['message'] ?? json['text'] ?? '').toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ??
                  DateTime.now()
              : DateTime.now()),
      status: parseStatus(json['status']),
      isMine: isMineMsg,
      attachmentUrl: attachment?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'contractId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'content': content,
      'message': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'isMine': isMine,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
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
    );
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
