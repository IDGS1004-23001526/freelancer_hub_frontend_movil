import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/chat/chat_screen.dart';
import '../services/notification_socket_service.dart';
import '../theme/app_colors.dart';

class MessageNotificationOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const MessageNotificationOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<MessageNotificationOverlay> createState() => _MessageNotificationOverlayState();
}

class _MessageNotificationOverlayState extends State<MessageNotificationOverlay> {
  StreamSubscription<MessageNotification>? _subscription;
  StreamSubscription<MessageNotification>? _tapSubscription;
  Timer? _hideTimer;
  MessageNotification? _current;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationSocketService.instance.onMessageNotification.listen(_showBanner);
    _tapSubscription = NotificationSocketService.instance.onNotificationTap.listen((item) {
      _openConversationItem(item);
    });
  }

  void _showBanner(MessageNotification notification) {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() {
      _current = notification;
      _visible = true;
    });
    _hideTimer = Timer(const Duration(seconds: 4), _dismissBanner);
  }

  void _dismissBanner() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  void _openConversation() {
    final item = _current;
    _dismissBanner();
    if (item == null) return;
    _openConversationItem(item);
  }

  void _openConversationItem(MessageNotification item) {
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: item.conversationId,
          peerId: item.senderId,
          peerName: item.senderName,
          peerRole: item.senderRole,
          peerAvatarUrl: item.senderAvatarUrl,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    _tapSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Stack(
      children: [
        widget.child,
        if (item != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_visible,
              child: SafeArea(
                bottom: false,
                child: AnimatedSlide(
                  offset: _visible ? Offset.zero : const Offset(0, -1.4),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Material(
                        color: AppColors.surface,
                        elevation: 8,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _openConversation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primaryLight,
                                  backgroundImage: (item.senderAvatarUrl != null &&
                                          item.senderAvatarUrl!.isNotEmpty)
                                      ? NetworkImage(item.senderAvatarUrl!)
                                      : null,
                                  child: (item.senderAvatarUrl == null ||
                                          item.senderAvatarUrl!.isEmpty)
                                      ? Text(
                                          item.initials,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            fontSize: 13,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.senderName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.previewText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                  onPressed: _dismissBanner,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
