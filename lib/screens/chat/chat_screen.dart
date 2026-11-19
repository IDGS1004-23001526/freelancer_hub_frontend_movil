import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_message.dart';
import '../../models/chat_sticker.dart';
import '../../models/chat_gif.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';
import '../../services/chat_message_queue.dart';
import '../../services/chat_socket_service.dart';
import '../../services/notification_socket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/chat_sticker_picker.dart';
import '../../widgets/chat_gif_picker.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String peerRole;
  final String? peerAvatarUrl;
  final String peerId;
  final ChatSocketService? socketService;
  final String? currentUserId;
  final String? currentUserName;
  final List<ChatMessage>? initialMessages;

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
    this.initialMessages,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatSocketService _socketService;
  final AuthService _authService = AuthService();
  final ChatApiService _chatApiService = ChatApiService();
  final ChatMessageQueue _messageQueue = ChatMessageQueue();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _queueSentSubscription;
  StreamSubscription? _queueFailedSubscription;
  StreamSubscription? _notificationSubscription;
  Timer? _softSyncTimer;

  SocketConnectionState _connectionState = SocketConnectionState.connected;
  bool _isPeerTyping = false;
  late String _currentUserId;
  late String _currentUserName;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    NotificationSocketService.instance.activeConversationId = widget.conversationId;
    _socketService = widget.socketService ?? ChatSocketService();
    _currentUserId = widget.currentUserId ?? 'my_user_id';
    _currentUserName = widget.currentUserName ?? 'Yo';

    if (widget.initialMessages != null) {
      _messages.addAll(widget.initialMessages!);
    } else if (widget.conversationId == 'conv_proyecto_demo') {
      _loadDemoFallbackMessages();
    }

    _setupSocketStreams();
    _setupQueueListeners();
    _initConnection();

    // Sincronización suave periódica en segundo plano (cada 4 segundos) para evitar pérdidas por desconexión en emuladores
    _softSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _syncLatestMessagesSilently();
      }
    });
  }

  void _loadDemoFallbackMessages() {
    final now = DateTime.now();
    _messages.addAll([
      ChatMessage(
        id: 'msg_seed_1',
        conversationId: widget.conversationId,
        senderId: widget.peerId,
        receiverId: _currentUserId,
        senderName: widget.peerName,
        content: '¡Hola! Revisé tu propuesta para el desarrollo móvil y me parece excelente.',
        timestamp: now.subtract(const Duration(minutes: 15)),
        status: MessageStatus.read,
        isMine: false,
      ),
      ChatMessage(
        id: 'msg_seed_2',
        conversationId: widget.conversationId,
        senderId: _currentUserId,
        receiverId: widget.peerId,
        senderName: _currentUserName,
        content: 'Muchas gracias Carlos. Ya tengo listo el desglose de hitos para la custodia Escrow.',
        timestamp: now.subtract(const Duration(minutes: 10)),
        status: MessageStatus.read,
        isMine: true,
      ),
      ChatMessage(
        id: 'msg_seed_3',
        conversationId: widget.conversationId,
        senderId: widget.peerId,
        receiverId: _currentUserId,
        senderName: widget.peerName,
        content: 'Perfecto, podemos empezar en cuanto autorice el primer fondo.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        status: MessageStatus.delivered,
        isMine: false,
      ),
    ]);
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

    // Marcar como leídos tanto en backend REST como vía socket
    unawaited(_chatApiService.markAsRead(widget.conversationId));

    await _socketService.connect(
      conversationId: widget.conversationId,
      currentUserId: _currentUserId,
    );

    // Emitir confirmación de lectura en tiempo real al conectarse
    _socketService.markAsRead('', widget.conversationId);
  }

  /// Sincroniza silenciosamente nuevos mensajes de la conversación sin parpadear la pantalla
  Future<void> _syncLatestMessagesSilently() async {
    try {
      final latest = await _chatApiService.getMessages(
        widget.conversationId,
        currentUserId: _currentUserId,
      );
      if (!mounted || latest.isEmpty) return;

      bool hasNewOrUpdated = false;
      for (final msg in latest) {
        final existingIdx = _messages.indexWhere((m) => m.id == msg.id);
        if (existingIdx == -1) {
          // Si hay un mensaje temporal optimista que coincide en contenido y remitente, actualizarlo en vez de duplicarlo
          final tempIdx = _messages.lastIndexWhere(
            (m) =>
                m.isMine &&
                (m.id.startsWith('msg_') || m.status == MessageStatus.sending) &&
                m.content == msg.content,
          );
          if (tempIdx != -1) {
            _messages[tempIdx] = msg;
          } else {
            _messages.add(msg);
          }
          hasNewOrUpdated = true;
        } else {
          if (_messages[existingIdx].status != msg.status) {
            _messages[existingIdx] = _messages[existingIdx].copyWith(status: msg.status);
            hasNewOrUpdated = true;
          }
        }
      }

      if (hasNewOrUpdated && mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _setupQueueListeners() {
    _queueSentSubscription = _messageQueue.onMessageSent.listen((sentMsg) {
      if (!mounted) return;
      setState(() {
        // Reemplazar mensaje optimista temporal
        final tempIdx = _messages.lastIndexWhere(
          (m) =>
              m.isMine &&
              (m.id.startsWith('msg_') || m.status == MessageStatus.sending) &&
              m.content == sentMsg.content,
        );
        if (tempIdx != -1) {
          _messages[tempIdx] = sentMsg;
        } else {
          final alreadyIdx = _messages.indexWhere((m) => m.id == sentMsg.id);
          if (alreadyIdx != -1) {
            _messages[alreadyIdx] = sentMsg;
          }
          // Si no está el temporal ni por ID, ya fue procesado o sincronizado, no duplicar
        }
      });
      _scrollToBottom();
    });

    _queueFailedSubscription = _messageQueue.onMessageFailed.listen((failedMsg) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == failedMsg.id);
        if (idx != -1) {
          _messages[idx] = failedMsg;
        }
      });
    });
  }

  void _setupSocketStreams() {
    // 1. Mensajes recibidos en tiempo real
    _messageSubscription = _socketService.onMessageReceived.listen((rawMessage) {
      if (!mounted) return;
      if (rawMessage.conversationId.isNotEmpty &&
          rawMessage.conversationId != 'default_conversation' &&
          rawMessage.conversationId != widget.conversationId) {
        return;
      }

      final hasValidUserIds = rawMessage.senderId.trim().isNotEmpty &&
          _currentUserId.trim().isNotEmpty &&
          _currentUserId != 'my_user_id';
      final isMineResolved = hasValidUserIds
          ? rawMessage.senderId.trim().toLowerCase() ==
              _currentUserId.trim().toLowerCase()
          : rawMessage.isMine;
      final message = rawMessage.copyWith(isMine: isMineResolved);

      setState(() {
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);
        if (existingIndex != -1) {
          _messages[existingIndex] = message;
          return;
        }

        // Si es nuestro propio mensaje confirmado por el servidor, reemplazar el mensaje optimista local
        if (message.isMine) {
          final optimisticIndex = _messages.lastIndexWhere(
            (m) =>
                m.isMine &&
                (m.id.startsWith('msg_') || m.status == MessageStatus.sending) &&
                m.content == message.content,
          );
          if (optimisticIndex != -1) {
            _messages[optimisticIndex] = message;
            return;
          }

          final recentDuplicate = _messages.lastIndexWhere(
            (m) =>
                m.isMine &&
                m.content == message.content &&
                message.timestamp.difference(m.timestamp).inSeconds.abs() < 8,
          );
          if (recentDuplicate != -1) {
            _messages[recentDuplicate] = message;
            return;
          }
        }

        _messages.add(message);
      });
      _scrollToBottom();

      // Notificar lectura inmediata al contraparte
      if (!message.isMine) {
        _socketService.markAsRead(message.id, widget.conversationId);
      }
    });

    // 2. Reconexión y estado de red transparente
    _connectionSubscription = _socketService.onConnectionStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);

      // Si la red se restableció, procesar cualquier mensaje encolado
      if (state == SocketConnectionState.connected) {
        _messageQueue.onNetworkRestored(socketService: _socketService);
        _socketService.markAsRead('', widget.conversationId);
      }
    });

    // 3. Confirmaciones de entrega y lectura de mensajes (Doble Check azul / gris)
    _statusSubscription = _socketService.onMessageStatusChanged.listen((data) {
      if (!mounted) return;
      final messageId = data['messageId']?.toString();
      final statusStr = data['status']?.toString().toLowerCase();
      final readerId = data['readerId']?.toString();

      setState(() {
        final isReadEvent = statusStr == 'read' || data.containsKey('readAt');
        if (isReadEvent) {
          // Si el lector no soy yo, marcar todos mis mensajes o el mensaje indicado como leídos (doble check azul)
          final isFromPeer = readerId == null ||
              readerId.isEmpty ||
              readerId.toLowerCase() != _currentUserId.toLowerCase();

          if (isFromPeer) {
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i].isMine &&
                  (messageId == null || messageId.isEmpty || _messages[i].id == messageId)) {
                _messages[i] = _messages[i].copyWith(status: MessageStatus.read);
              }
            }
          }
        } else if (messageId != null) {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            MessageStatus nextStatus = _messages[index].status;
            if (statusStr == 'delivered') {
              nextStatus = MessageStatus.delivered;
            }
            _messages[index] = _messages[index].copyWith(status: nextStatus);
          }
        }
      });
    });

    // 4. Indicador de escritura
    _typingSubscription = _socketService.onTypingChanged.listen((typing) {
      if (!mounted) return;
      setState(() => _isPeerTyping = typing);
      if (typing) _scrollToBottom();
    });

    // 5. Escuchar notificaciones de mensajes entrantes para recarga instantánea en emuladores
    _notificationSubscription =
        NotificationSocketService.instance.onMessageNotification.listen((notif) {
      if (!mounted) return;
      if (notif.conversationId == widget.conversationId) {
        _syncLatestMessagesSilently();
      }
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

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_currentUserId == 'my_user_id' || _currentUserId.isEmpty) {
      final tokenUserId = await _extractUserIdFromToken();
      if (tokenUserId != null && tokenUserId.isNotEmpty && mounted) {
        setState(() => _currentUserId = tokenUserId);
      }
    }

    final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.peerId,
      senderName: _currentUserName,
      content: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending, // Indicador optimista de envío inicial
      isMine: true,
    );

    _textController.clear();
    if (mounted) {
      setState(() {
        _messages.add(newMessage);
      });
    }

    if (_socketService.currentState == SocketConnectionState.connected) {
      _socketService.sendTyping(false, widget.conversationId);
    }

    _scrollToBottom();

    // Enviar a través de la cola secuencial (cuello de botella de salida con reintentos automáticos)
    _messageQueue.enqueue(newMessage, socketService: _socketService);
  }

  void _sendSticker(ChatSticker sticker) {
    if (_currentUserId == 'my_user_id' || _currentUserId.isEmpty) {
      _extractUserIdFromToken().then((val) {
        if (val != null && mounted) setState(() => _currentUserId = val);
      });
    }

    final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.peerId,
      senderName: _currentUserName,
      content: '[sticker:${sticker.id}]',
      attachmentUrl: 'sticker:${sticker.id}',
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isMine: true,
    );

    if (mounted) {
      setState(() {
        _messages.add(newMessage);
      });
    }
    _scrollToBottom();

    _messageQueue.enqueue(newMessage, socketService: _socketService);
  }

  void _sendGif(ChatGif gif) {
    if (_currentUserId == 'my_user_id' || _currentUserId.isEmpty) {
      _extractUserIdFromToken().then((val) {
        if (val != null && mounted) setState(() => _currentUserId = val);
      });
    }

    final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.peerId,
      senderName: _currentUserName,
      content: '[gif:${gif.url}]',
      attachmentUrl: gif.url,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isMine: true,
    );

    if (mounted) {
      setState(() {
        _messages.add(newMessage);
      });
    }
    _scrollToBottom();

    _messageQueue.enqueue(newMessage, socketService: _socketService);
  }

  void _sendAnimatedSticker(String stickerUrl) {
    if (_currentUserId == 'my_user_id' || _currentUserId.isEmpty) {
      _extractUserIdFromToken().then((val) {
        if (val != null && mounted) setState(() => _currentUserId = val);
      });
    }

    final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = ChatMessage(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      receiverId: widget.peerId,
      senderName: _currentUserName,
      content: '[sticker:$stickerUrl]',
      attachmentUrl: 'sticker:$stickerUrl',
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isMine: true,
    );

    if (mounted) {
      setState(() {
        _messages.add(newMessage);
      });
    }
    _scrollToBottom();

    _messageQueue.enqueue(newMessage, socketService: _socketService);
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatGifPicker(
        onGifSelected: (gif) {
          Navigator.pop(ctx);
          _sendGif(gif);
        },
        onStickerSelected: (sticker) {
          Navigator.pop(ctx);
          _sendSticker(sticker);
        },
        onAnimatedStickerSelected: (stickerUrl) {
          Navigator.pop(ctx);
          _sendAnimatedSticker(stickerUrl);
        },
      ),
    );
  }

  void _onFailedMessageTapped(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'No se pudo enviar el mensaje',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifica tu conexión a internet o reintenta el envío.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              title: Text('Reintentar envío ahora', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  final idx = _messages.indexWhere((m) => m.id == message.id);
                  if (idx != -1) {
                    _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sending);
                  }
                });
                _messageQueue.retry(message.id, socketService: _socketService);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Eliminar mensaje', style: GoogleFonts.poppins(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _messages.removeWhere((m) => m.id == message.id);
                });
                _messageQueue.remove(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (NotificationSocketService.instance.activeConversationId == widget.conversationId) {
      NotificationSocketService.instance.activeConversationId = null;
    }
    _softSyncTimer?.cancel();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingSubscription?.cancel();
    _queueSentSubscription?.cancel();
    _queueFailedSubscription?.cancel();
    _notificationSubscription?.cancel();

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

  /// Burbujas diferenciadas:
  /// - Mensajes propios: Alineados a la derecha con color Vino #5A0F24 y texto blanco.
  /// - Mensajes contraparte: Alineados a la izquierda con fondo Crema #F3EFE6 y texto oscuro.
  /// - Mensajes de Stickers: Renderizados con tarjeta visual interactiva destacada.
  Widget _buildMessageBubble(ChatMessage message) {
    final isMine = message.isMine;
    final isSticker = message.isSticker;
    final isGif = message.isGif;

    if (isGif) {
      return _buildGifBubble(message);
    }

    if (isSticker) {
      return _buildStickerBubble(message);
    }

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
          child: GestureDetector(
            onTap: () {
              if (message.status == MessageStatus.failed) {
                _onFailedMessageTapped(message);
              }
            },
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
                border: message.status == MessageStatus.failed
                    ? Border.all(color: Colors.redAccent, width: 1.2)
                    : null,
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
      ),
    );
  }

  /// Renderizado especial para GIFs animados estilo WhatsApp
  Widget _buildGifBubble(ChatMessage message) {
    final isMine = message.isMine;
    final gifUrl = message.mediaUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            if (message.status == MessageStatus.failed) {
              _onFailedMessageTapped(message);
            }
          },
          child: Container(
            width: 230,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              border: message.status == MessageStatus.failed
                  ? Border.all(color: Colors.redAccent, width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              child: Stack(
                children: [
                  // Imagen o GIF animado
                  if (gifUrl != null && gifUrl.isNotEmpty)
                    Image.network(
                      gifUrl,
                      width: 230,
                      height: 160,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 230,
                          height: 160,
                          color: isMine ? AppColors.chatBubbleMine : AppColors.chatBubblePeer,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 230,
                        height: 120,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),

                  // Badge "GIF" estilo WhatsApp en la esquina superior izquierda
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'GIF',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Pill flotante con la hora y estado de entrega en la esquina inferior derecha
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.formattedTime,
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Renderizado especial para Stickers en el chat (estilo WhatsApp con soporte de API y badges)
  Widget _buildStickerBubble(ChatMessage message) {
    final isMine = message.isMine;
    final stickerUrl = message.stickerUrl;

    // Si es un sticker animado de la API (GIPHY) estilo WhatsApp: sin caja rectangular, silueta transparente
    if (stickerUrl != null && stickerUrl.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              if (message.status == MessageStatus.failed) {
                _onFailedMessageTapped(message);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      stickerUrl,
                      width: 145,
                      height: 145,
                      fit: BoxFit.contain, // Mantiene la transparencia y forma del sticker
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 120,
                          height: 120,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                        ),
                      ),
                    ),
                  ),
                  // Timestamp y doble check flotante semitransparente estilo WhatsApp
                  Positioned(
                    bottom: 2,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.formattedTime,
                            style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 3),
                            _buildStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Sticker oficial de proyecto (badge local)
    final stickerId = message.stickerId;
    final sticker = stickerId != null ? ChatSticker.findById(stickerId) : null;
    final icon = sticker?.icon ?? Icons.auto_awesome;
    final name = sticker?.name ?? 'Sticker';
    final bgColor = sticker?.backgroundColor ?? (isMine ? AppColors.chatBubbleMine : AppColors.chatBubblePeer);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            if (message.status == MessageStatus.failed) {
              _onFailedMessageTapped(message);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMine ? AppColors.chatBubbleMine : bgColor.withOpacity(0.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isMine ? AppColors.chatBubbleMine : bgColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: isMine ? Colors.white : AppColors.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.formattedTime,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: isMine ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
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

  /// Indicador visual de lectura o estado de entrega del mensaje
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
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.redAccent,
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
          // Botón selector de stickers
          IconButton(
            key: const Key('chat_sticker_button'),
            icon: const Icon(
              Icons.sticky_note_2_outlined,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: 'Enviar Sticker',
            onPressed: _showStickerPicker,
          ),
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
