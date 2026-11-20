class NotificationItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String? senderAvatarUrl;
  final String title;
  final String content;
  final String? attachmentUrl;
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderAvatarUrl,
    required this.title,
    required this.content,
    this.attachmentUrl,
    required this.createdAt,
    this.isRead = false,
  });

  String get previewText {
    final trimmed = content.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (attachmentUrl != null && attachmentUrl!.isNotEmpty) {
      return '📷 Imagen adjunta';
    }
    return 'Nuevo mensaje';
  }

  String get initials {
    final parts = senderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'senderAvatarUrl': senderAvatarUrl,
        'title': title,
        'content': content,
        'attachmentUrl': attachmentUrl,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id']?.toString() ?? '',
        conversationId: json['conversationId']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? '',
        senderName: json['senderName']?.toString() ?? 'Nuevo mensaje',
        senderRole: json['senderRole']?.toString() ?? 'Usuario',
        senderAvatarUrl: json['senderAvatarUrl']?.toString(),
        title: json['title']?.toString() ??
            (json['senderName']?.toString() ?? 'Notificación'),
        content: json['content']?.toString() ?? '',
        attachmentUrl: json['attachmentUrl']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        isRead: json['isRead'] == true,
      );
}
