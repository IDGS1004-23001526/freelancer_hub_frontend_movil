import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat_conversation.dart';
import '../../services/chat_api_service.dart';
import '../../theme/app_colors.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final List<ChatConversation>? initialConversations;

  const ConversationsScreen({
    super.key,
    this.initialConversations,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatApiService _chatApiService = ChatApiService();
  String _selectedFilter = 'Todos';
  late List<ChatConversation> _conversations;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _conversations = widget.initialConversations ?? [];
    _searchController.addListener(() => setState(() {}));
    if (widget.initialConversations == null) {
      _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final remote = await _chatApiService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = remote;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatConversation> get _filteredConversations {
    final query = _searchController.text.trim().toLowerCase();

    return _conversations.where((conv) {
      // Filtro de texto de búsqueda
      final matchesQuery = query.isEmpty ||
          conv.peerName.toLowerCase().contains(query) ||
          (conv.projectName?.toLowerCase().contains(query) ?? false) ||
          conv.lastMessage.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      // Filtro de pestañas
      switch (_selectedFilter) {
        case 'No leídos':
          return conv.unreadCount > 0;
        case 'Clientes':
          return conv.peerRole.toLowerCase().contains('cliente');
        case 'Freelancers':
          return conv.peerRole.toLowerCase().contains('freelancer');
        case 'Todos':
        default:
          return true;
      }
    }).toList();
  }

  int get _totalUnreadCount {
    return _conversations.fold<int>(0, (sum, item) => sum + item.unreadCount);
  }

  void _openChat(ChatConversation conversation) async {
    // Si tenía mensajes no leídos, marcarlos como leídos localmente al abrir
    if (conversation.unreadCount > 0) {
      setState(() {
        final index = _conversations.indexWhere((c) => c.id == conversation.id);
        if (index != -1) {
          _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
        }
      });
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          peerName: conversation.peerName,
          peerRole: conversation.peerRole,
          peerAvatarUrl: conversation.peerAvatarUrl,
          peerId: conversation.peerId,
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewChatContactPicker(
        onContactSelected: (newConv) {
          Navigator.pop(ctx);
          setState(() {
            _conversations.insert(0, newConv);
          });
          _openChat(newConv);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredConversations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 20,
        centerTitle: false,
        title: Row(
          children: [
            Text(
              'Mensajes',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (_totalUnreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.chatBubbleMine,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalUnreadCount',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nuevo chat',
            icon: const Icon(Icons.edit_square, color: AppColors.primary),
            onPressed: _showNewChatDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Input de búsqueda
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar contacto, proyecto o mensaje...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Chips de filtro rápido
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos'),
                      const SizedBox(width: 8),
                      _buildFilterChip('No leídos', badge: _totalUnreadCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Clientes'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Freelancers'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de conversaciones
          Expanded(
            child: _isLoading && _conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadConversations,
                        child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 76,
                        endIndent: 16,
                        color: AppColors.border,
                      ),
                      itemBuilder: (context, index) {
                        final conv = filtered[index];
                        return _buildConversationTile(conv);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.chatBubbleMine,
        foregroundColor: Colors.white,
        elevation: 3,
        onPressed: _showNewChatDialog,
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(
          'Nuevo chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {int badge = 0}) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.chatBubbleMine : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.chatBubbleMine : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.chatBubbleMine,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.chatBubbleMine : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation conv) {
    final hasUnread = conv.unreadCount > 0;

    return InkWell(
      onTap: () => _openChat(conv),
      child: Container(
        color: hasUnread ? AppColors.primaryLight.withOpacity(0.2) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar con indicador de conexión
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    conv.initials,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: AppColors.chatBubbleMine,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (conv.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981), // Verde esmeralda online
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Contenido central: Nombre, rol/proyecto, último mensaje
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          conv.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        conv.formattedTime,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color: hasUnread ? AppColors.chatBubbleMine : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Proyecto o Rol del contacto
                  if (conv.projectName != null)
                    Text(
                      conv.projectName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  const SizedBox(height: 4),

                  // Último mensaje y badge de no leídos
                  Row(
                    children: [
                      if (conv.lastMessageIsMine)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.done_all, size: 14, color: AppColors.chatReadCheck),
                        ),
                      Expanded(
                        child: Text(
                          conv.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.chatBubbleMine,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.chatBubbleMine,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Sin resultados para "${_searchController.text}"'
                  : 'No tienes mensajes aún',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Intenta buscar con otro término o limpia los filtros aplicados.'
                  : 'Inicia una conversación con los clientes o freelancers de tus convocatorias.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _searchController.clear(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Limpiar búsqueda'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Selector modal para iniciar una nueva conversación con contactos de la plataforma
class _NewChatContactPicker extends StatelessWidget {
  final ValueChanged<ChatConversation> onContactSelected;

  const _NewChatContactPicker({required this.onContactSelected});

  @override
  Widget build(BuildContext context) {
    final availableContacts = [
      {
        'id': 'conv_nuevo_paulo',
        'peerId': 'usr_paulo_001',
        'name': 'Paulo Rodríguez',
        'role': 'Cliente Contratante',
        'project': 'Plataforma E-Learning Mobile',
      },
      {
        'id': 'conv_nuevo_valeria',
        'peerId': 'usr_valeria_002',
        'name': 'Valeria Castro',
        'role': 'Freelancer Backend Node.js',
        'project': 'Microservicios FreelancerHub',
      },
      {
        'id': 'conv_nuevo_jorge',
        'peerId': 'usr_jorge_003',
        'name': 'Jorge Montes',
        'role': 'Cliente Contratante',
        'project': 'Integración MercadoPago y Stripe',
      },
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Iniciar nuevo chat',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Contactos relacionados a tus proyectos y postulaciones:',
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...availableContacts.map((contact) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  contact['name']!.substring(0, 1),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.chatBubbleMine),
                ),
              ),
              title: Text(
                contact['name']!,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '${contact['role']} • ${contact['project']}',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
              onTap: () {
                final newConv = ChatConversation(
                  id: contact['id']!,
                  peerId: contact['peerId']!,
                  peerName: contact['name']!,
                  peerRole: contact['role']!,
                  projectName: contact['project'],
                  lastMessage: 'Conversación iniciada',
                  lastMessageTime: DateTime.now(),
                  unreadCount: 0,
                  isOnline: true,
                  lastMessageIsMine: true,
                );
                onContactSelected(newConv);
              },
            );
          }),
        ],
      ),
    );
  }
}

