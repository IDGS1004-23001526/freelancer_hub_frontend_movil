import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';
import '../../services/chat_socket_service.dart';
import '../../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String peerRole;
  final String? peerAvatarUrl;
  final String peerId;
  final ChatSocketService? socketService;
  final String? currentUserId;
  final String? currentUserName;

  const ChatScreen({
    super.key,
    this.conversationId = 'conv_proyecto_demo',
    this.peerName = 'Carlos Méndez',
    this.peerRole = 'Cliente Contratante',
    this.peerAvatarUrl,
    this.peerId = 'user_peer_001',
    this.socketService,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatSocketService _socketService;
  final AuthService _authService = AuthService();
  final ChatApiService _chatApiService = ChatApiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _typingSubscription;

  SocketConnectionState _connectionState = SocketConnectionState.connected;
  bool _isPeerTyping = false;
  late String _currentUserId;
  late String _currentUserName;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _socketService = widget.socketService ?? ChatSocketService();
    _currentUserId = widget.currentUserId ?? 'my_user_id';
    _currentUserName = widget.currentUserName ?? 'Yo';

    _setupSocketStreams();
    _initConnection();
  }

  Future<String?> _extractUserIdFromToken() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map<String, dynamic>) {
        return payload['sub']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _initConnection() async {
    if (widget.currentUserId == null) {
      final cached = await _authService.getCachedUserProfile();
      final tokenUserId = await _extractUserIdFromToken();
      final resolvedId = (tokenUserId != null && tokenUserId.isNotEmpty)
          ? tokenUserId
          : (cached != null && cached.id.isNotEmpty ? cached.id : _currentUserId);

      if (mounted) {
        setState(() {
          _currentUserId = resolvedId;
          if (cached != null && cached.fullName.isNotEmpty) {
            _currentUserName = cached.fullName;
          }
        });
      }
    }

    final history = await _chatApiService.getMessages(
      widget.conversationId,
      currentUserId: _currentUserId,
    );
    if (mounted && history.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
      });
      _scrollToBottom();
    }
    unawaited(_chatApiService.markAsRead(widget.conversationId));

    await _socketService.connect(
      conversationId: widget.conversationId,
      currentUserId: _currentUserId,
    );
  }

  void _setupSocketStreams() {
    // 1. Mensajes recibidos en tiempo real
    _messageSubscription = _socketService.onMessageReceived.listen((message) {
      if (!mounted) return;
      setState(() {
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);
        if (existingIndex != -1) {
          _messages[existingIndex] = message;
          return;
        }

        // Si es nuestro propio mensaje confirmado por el servidor, reemplazar el mensaje optimista local
        if (message.isMine) {
          final optimisticIndex = _messages.lastIndexWhere(
            (m) => m.isMine && m.id.startsWith('msg_') && m.content == message.content,
          );
          if (optimisticIndex != -1) {
            _messages[optimisticIndex] = message;
            return;
          }
        }

        _messages.add(message);
      });
      _scrollToBottom();

      // Notificar lectura al contraparte
      if (!message.isMine) {
        _socketService.markAsRead(message.id, widget.conversationId);
      }
    });

    // 2. Reconexión y estado de red transparente
    _connectionSubscription = _socketService.onConnectionStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
    });

    // 3. Confirmaciones de entrega y lectura de mensajes
    _statusSubscription = _socketService.onMessageStatusChanged.listen((data) {
      if (!mounted) return;
      final messageId = data['messageId']?.toString();
      final statusStr = data['status']?.toString().toLowerCase();

      if (messageId != null) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            MessageStatus nextStatus = _messages[index].status;
            if (statusStr == 'read') {
              nextStatus = MessageStatus.read;
            } else if (statusStr == 'delivered') {
              nextStatus = MessageStatus.delivered;
            }
            _messages[index] = _messages[index].copyWith(status: nextStatus);
          }
        });
      }
    });

    // 4. Indicador de escritura
    _typingSubscription = _socketService.onTypingChanged.listen((typing) {
      if (!mounted) return;
      setState(() => _isPeerTyping = typing);
      if (typing) _scrollToBottom();
    });
  }

  void _scrollToBottom({bool isImmediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (isImmediate) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.peerId,
      senderName: _currentUserName,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      isMine: true,
    );

    _textController.clear();
    setState(() {
      _messages.add(newMessage);
    });

    // Emisión en tiempo real por Socket.io
    _socketService.sendMessage(newMessage);
    _socketService.sendTyping(false, widget.conversationId);

    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingSubscription?.cancel();

    _textController.dispose();
    _scrollController.dispose();

    if (widget.socketService == null) {
      _socketService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Banner de reconexión transparente
            if (_connectionState == SocketConnectionState.reconnecting)
              _buildReconnectingBanner(),

            // Lista de mensajes con autoscroll
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView.builder(
                  key: const Key('chat_messages_list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),
            ),

            // Indicador de "Escribiendo..."
            if (_isPeerTyping) _buildTypingIndicator(),

            // Barra inferior para redactar y enviar mensajes
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: widget.peerAvatarUrl != null
                    ? NetworkImage(widget.peerAvatarUrl!)
                    : null,
                child: widget.peerAvatarUrl == null
                    ? const Icon(Icons.person, color: AppColors.primary, size: 24)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: _connectionState == SocketConnectionState.connected
                        ? AppColors.accentGreen
                        : (_connectionState == SocketConnectionState.reconnecting
                            ? Colors.amber
                            : Colors.grey),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _connectionState == SocketConnectionState.connected
                      ? (_isPeerTyping ? 'Escribiendo...' : 'En línea • ${widget.peerRole}')
                      : (_connectionState == SocketConnectionState.reconnecting
                          ? 'Reconectando red...'
                          : widget.peerRole),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _isPeerTyping ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: _isPeerTyping ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
          tooltip: 'Chat protegido con custodia Escrow',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Este chat cuenta con respaldo y protección para acuerdos formales.'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReconnectingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.amber.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sync, size: 14, color: Colors.brown),
          const SizedBox(width: 8),
          Text(
            'Reconectando al servidor de chat automáticamente...',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.brown.shade800, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Criterio 2: Burbujas diferenciadas:
  /// - Mensajes propios: Alineados a la derecha con color Vino #5A0F24 y texto blanco.
  /// - Mensajes contraparte: Alineados a la izquierda con fondo Crema #F3EFE6 y texto oscuro.
  Widget _buildMessageBubble(ChatMessage message) {
    final isMine = message.isMine;
    final bubbleColor = isMine ? AppColors.chatBubbleMine : AppColors.chatBubblePeer;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final timeColor = isMine ? Colors.white70 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 3),
                bottomRight: Radius.circular(isMine ? 3 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMine ? 'Tú' : (message.senderName.isNotEmpty ? message.senderName : widget.peerName),
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isMine ? Colors.white70 : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      message.formattedTime,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: timeColor,
                      ),
                    ),
                    // Criterio 4: Indicador visual de lectura / entrega en mensajes propios
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Criterio 4: Indicador visual de lectura o estado de entrega del mensaje
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(
          Icons.access_time,
          size: 13,
          color: Colors.white70,
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: AppColors.chatReadCheck,
        );
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 6.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.chatBubblePeer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.more_horiz, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${widget.peerName} está escribiendo...',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                key: const Key('chat_input_field'),
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                ),
                onChanged: (text) {
                  _socketService.sendTyping(text.trim().isNotEmpty, widget.conversationId);
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.chatBubbleMine,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              key: const Key('chat_send_button'),
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
