class ChatConversation {
  final String id;
  final String peerId;
  final String peerName;
  final String peerRole;
  final String? peerAvatarUrl;
  final String? projectName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool lastMessageIsMine;

  const ChatConversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerRole,
    this.peerAvatarUrl,
    this.projectName,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.lastMessageIsMine = false,
  });

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24 && now.day == lastMessageTime.day) {
      final hour = lastMessageTime.hour.toString().padLeft(2, '0');
      final minute = lastMessageTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1 || (difference.inHours < 48 && now.day - lastMessageTime.day == 1)) {
      return 'Ayer';
    } else {
      final day = lastMessageTime.day.toString().padLeft(2, '0');
      final month = lastMessageTime.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
  }

  String get initials {
    final parts = peerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  ChatConversation copyWith({
    String? id,
    String? peerId,
    String? peerName,
    String? peerRole,
    String? peerAvatarUrl,
    String? projectName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    bool? lastMessageIsMine,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerRole: peerRole ?? this.peerRole,
      peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
      projectName: projectName ?? this.projectName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      lastMessageIsMine: lastMessageIsMine ?? this.lastMessageIsMine,
    );
  }
}

