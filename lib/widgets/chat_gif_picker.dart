import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_gif.dart';
import '../models/chat_sticker.dart';
import '../services/gif_api_service.dart';
import '../theme/app_colors.dart';

class ChatGifPicker extends StatefulWidget {
  final ValueChanged<ChatGif> onGifSelected;
  final ValueChanged<ChatSticker> onStickerSelected;
  final ValueChanged<String>? onAnimatedStickerSelected;

  const ChatGifPicker({
    super.key,
    required this.onGifSelected,
    required this.onStickerSelected,
    this.onAnimatedStickerSelected,
  });

  @override
  State<ChatGifPicker> createState() => _ChatGifPickerState();
}

class _ChatGifPickerState extends State<ChatGifPicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final GifApiService _gifApiService = GifApiService();

  Timer? _debounceTimer;
  String _selectedCategory = 'Todos';
  String _selectedStickerCategory = 'Tendencias';
  List<ChatGif> _gifs = [];
  List<ChatGif> _apiStickers = [];
  bool _isLoadingGifs = false;
  bool _isLoadingStickers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _gifs = ChatGif.catalog;
    _apiStickers = ChatGif.stickerCatalog;
    _loadTrendingGifs();
    _loadTrendingStickers();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _triggerSearchForCurrentTab(_searchController.text);
      }
    });
  }

  Future<void> _loadTrendingGifs() async {
    setState(() => _isLoadingGifs = true);
    final results = await _gifApiService.getTrendingGifs();
    if (mounted) {
      setState(() {
        _gifs = results;
        _isLoadingGifs = false;
      });
    }
  }

  Future<void> _loadTrendingStickers() async {
    setState(() => _isLoadingStickers = true);
    final results = await _gifApiService.getTrendingStickers();
    if (mounted) {
      setState(() {
        _apiStickers = results;
        _isLoadingStickers = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 380), () {
      _triggerSearchForCurrentTab(query);
    });
  }

  void _triggerSearchForCurrentTab(String query) async {
    final clean = query.trim();
    final isStickersTab = _tabController.index == 1;

    if (isStickersTab) {
      setState(() => _isLoadingStickers = true);
      List<ChatGif> results;
      if (clean.isEmpty) {
        if (_selectedStickerCategory == 'Tendencias' || _selectedStickerCategory == 'Proyectos') {
          results = await _gifApiService.getTrendingStickers();
        } else {
          results = await _gifApiService.searchStickers(_selectedStickerCategory);
        }
      } else {
        results = await _gifApiService.searchStickers(clean);
      }
      if (mounted) {
        setState(() {
          _apiStickers = results;
          _isLoadingStickers = false;
        });
      }
    } else {
      setState(() => _isLoadingGifs = true);
      List<ChatGif> results;
      if (clean.isEmpty) {
        if (_selectedCategory == 'Todos') {
          results = await _gifApiService.getTrendingGifs();
        } else {
          results = await _gifApiService.searchGifs(_selectedCategory);
        }
      } else {
        results = await _gifApiService.searchGifs(clean);
      }
      if (mounted) {
        setState(() {
          _gifs = results;
          _isLoadingGifs = false;
        });
      }
    }
  }

  void _onStickerCategorySelected(String category) async {
    setState(() {
      _selectedStickerCategory = category;
      _isLoadingStickers = true;
    });

    List<ChatGif> results;
    if (category == 'Tendencias') {
      if (_searchController.text.trim().isNotEmpty) {
        results = await _gifApiService.searchStickers(_searchController.text.trim());
      } else {
        results = await _gifApiService.getTrendingStickers();
      }
    } else if (category == 'Proyectos') {
      results = [];
    } else {
      results = await _gifApiService.searchStickers(category);
    }

    if (mounted) {
      setState(() {
        _apiStickers = results;
        _isLoadingStickers = false;
      });
    }
  }

  void _onCategorySelected(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoadingGifs = true;
    });

    List<ChatGif> results;
    if (category == 'Todos') {
      if (_searchController.text.trim().isNotEmpty) {
        results = await _gifApiService.searchGifs(_searchController.text.trim());
      } else {
        results = await _gifApiService.getTrendingGifs();
      }
    } else {
      results = await _gifApiService.searchGifs(category);
    }

    if (mounted) {
      setState(() {
        _gifs = results;
        _isLoadingGifs = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Pestañas principales: GIFs y Stickers (Estilo WhatsApp)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gif_box_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('GIFs Animados'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 8),
                      Text('Stickers'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Buscador común en vivo para GIFs y Stickers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 12.5),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar en GIPHY (ej. gato, risa, trato, amor)...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _triggerSearchForCurrentTab('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Contenido de las pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGifsTab(),
                _buildStickersTab(),
              ],
            ),
          ),

          // Barra de atribución estilo WhatsApp
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Millones de stickers y GIFs potenciados por ',
                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                ),
                Text(
                  'GIPHY',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGifsTab() {
    return Column(
      children: [
        // Filtro de categorías para GIFs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ChatGif.categories.map((cat) {
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => _onCategorySelected(cat),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.background,
                  checkmarkColor: AppColors.primary,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),

        // Grilla de GIFs animados
        Expanded(
          child: _isLoadingGifs && _gifs.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : _gifs.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron GIFs para esa búsqueda',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: _gifs.length,
                      itemBuilder: (context, index) {
                        return _buildGifCard(_gifs[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStickersTab() {
    final localStickers = ChatSticker.catalog;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtro horizontal de categorías de stickers (WhatsApp style)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: ChatGif.stickerCategories.map((cat) {
              final isSelected = cat == _selectedStickerCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => _onStickerCategorySelected(cat),
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.background,
                  checkmarkColor: AppColors.primary,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),

        // Fila horizontal de stickers de proyectos (¡Trato hecho!, Aprobado, etc.)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text(
            'Stickers de Proyectos',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: localStickers.length,
            itemBuilder: (context, index) {
              final sticker = localStickers[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => widget.onStickerSelected(sticker),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sticker.backgroundColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sticker.backgroundColor.withOpacity(0.9),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sticker.icon, size: 22, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          sticker.name,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 8),

        // Grilla con stickers animados transparentes de GIPHY API (WhatsApp style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stickers Animados (${_selectedStickerCategory})',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_isLoadingStickers)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingStickers && _apiStickers.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : _apiStickers.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron stickers animados para esa búsqueda',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _apiStickers.length,
                      itemBuilder: (context, index) {
                        final sticker = _apiStickers[index];
                        return InkWell(
                          onTap: () {
                            if (widget.onAnimatedStickerSelected != null) {
                              widget.onAnimatedStickerSelected!(sticker.url);
                            } else {
                              widget.onGifSelected(sticker);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Transparente estilo WhatsApp
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.network(
                              sticker.url,
                              fit: BoxFit.contain, // Mantiene silueta del sticker
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildGifCard(ChatGif gif) {
    return InkWell(
      onTap: () => widget.onGifSelected(gif),
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // GIF animado
            Image.network(
              gif.url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),

            // Badge "GIF" estilo WhatsApp en la esquina superior izquierda
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GIF',
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Título inferior con degradado para lectura
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  gif.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
