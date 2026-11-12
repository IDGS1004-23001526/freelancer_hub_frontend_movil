enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
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
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {String? currentUserId}) {
    final sender =
        (json['senderId'] ?? json['sender'] ?? json['from'] ?? '').toString().trim();
    final isMineMsg = json['isMine'] == true ||
        (currentUserId != null &&
            currentUserId.trim().isNotEmpty &&
            sender.toLowerCase() == currentUserId.trim().toLowerCase());

    MessageStatus parseStatus(dynamic raw) {
      final s = raw?.toString().toLowerCase();
      if (s == 'read' || s == 'visto') return MessageStatus.read;
      if (s == 'delivered' || s == 'entregado') return MessageStatus.delivered;
      if (s == 'sending' || s == 'enviando') return MessageStatus.sending;
      return MessageStatus.sent;
    }

    return ChatMessage(
      id: (json['id'] ??
              json['_id'] ??
              json['messageId'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      conversationId:
          (json['conversationId'] ?? json['roomId'] ?? 'default_conversation')
              .toString(),
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'content': content,
      'message': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'isMine': isMine,
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
    );
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
