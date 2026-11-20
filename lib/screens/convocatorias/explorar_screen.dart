import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/convocatoria.dart';
import '../../services/connectivity_service.dart';
import '../../services/convocatoria_service.dart';
import '../../services/offline_queue_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/convocatoria_card.dart';
import '../../widgets/offline_badge.dart';

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  final ConvocatoriaService _service = ConvocatoriaService();
  final ConnectivityService _connectivity = ConnectivityService();
  final OfflineQueueService _queue = OfflineQueueService();

  List<Convocatoria> _allConvocatorias = [];
  List<Convocatoria> _filteredConvocatorias = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _selectedSkill = 'Todos';
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<String>? _notificationSub;

  final List<String> _skillsList = const [
    'Todos',
    'Flutter',
    '.NET Core',
    'React',
    'SQL Server',
    'UI/UX',
    'Java',
  ];

  @override
  void initState() {
    super.initState();
    _loadConvocatorias();

    // Escuchar cambios de conectividad
    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
        });
        if (isOnline) {
          _loadConvocatorias(silent: true);
        }
      }
    });

    // Escuchar notificaciones de sincronización
    _notificationSub = _queue.syncNotificationStream.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _notificationSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConvocatorias({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    final result = await _service.getConvocatorias();

    if (mounted) {
      setState(() {
        _allConvocatorias = result.convocatorias;
        _isOffline = result.isOffline;
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredConvocatorias = _allConvocatorias.where((c) {
        final matchesQuery = query.isEmpty ||
            c.title.toLowerCase().contains(query) ||
            c.companyName.toLowerCase().contains(query) ||
            c.category.toLowerCase().contains(query);

        final matchesSkill = _selectedSkill == 'Todos' ||
            c.skills.any((s) => s.toLowerCase() == _selectedSkill.toLowerCase());

        return matchesQuery && matchesSkill;
      }).toList();
    });
  }

  void _openProposalDialog(Convocatoria c) {
    final montoController = TextEditingController(text: c.budgetFormatted.replaceAll(RegExp(r'[^0-9]'), ''));
    final mensajeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Postular Propuesta',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c.title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monto de tu propuesta (USD)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mensajeController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Mensaje de propuesta o experiencia',
                  hintText: 'Explica brevemente tu experiencia con el stack...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final monto = '\$${montoController.text.trim()} USD';
                    final mensaje = mensajeController.text.trim();

                    final result = await _service.postularAConvocatoria(
                      convocatoriaId: c.id,
                      propuestaMonto: monto,
                      mensaje: mensaje,
                    );

                    await _loadConvocatorias(silent: true);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor: result.success
                            ? Colors.green
                            : (result.isOffline
                                ? Colors.deepOrange
                                : Colors.red.shade700),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                  child: Text(
                    'Enviar Postulación',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explorar',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Tu próximo proyecto empieza aquí.',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Botón para simular / toggle offline para evaluación rápida
          IconButton(
            tooltip: _connectivity.isSimulatingOffline
                ? 'Volver a modo Online'
                : 'Simular Modo Offline',
            icon: Icon(
              _connectivity.isSimulatingOffline
                  ? Icons.wifi_off_rounded
                  : Icons.wifi_rounded,
              color: _connectivity.isSimulatingOffline
                  ? Colors.deepOrange
                  : Colors.green,
            ),
            onPressed: () {
              _connectivity.toggleSimulatedOffline();
              setState(() {
                _isOffline = _connectivity.lastKnownStatus == false;
              });
              _loadConvocatorias(silent: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_connectivity.isSimulatingOffline
                      ? 'Simulación Offline activada'
                      : 'Simulación finalizada (Modo Online)'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadConvocatorias(),
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Banner / Badge de Modo Offline si aplica
            OfflineBadge(
              isOffline: _isOffline,
              onRetry: () => _loadConvocatorias(),
            ),

            // Barra de Búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Buscar convocatorias...',
                    hintStyle: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Filtros horizontales por Habilidades
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _skillsList.length,
                itemBuilder: (context, index) {
                  final skill = _skillsList[index];
                  final isSelected = _selectedSkill == skill;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        skill,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedSkill = skill;
                        });
                        _applyFilters();
                      },
                    ),
                  );
                },
              ),
            ),

            // Contador de resultados
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredConvocatorias.length} convocatorias activas',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Recientes',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Lista de tarjetas
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_filteredConvocatorias.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.work_off_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No hay convocatorias que coincidan',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Intenta cambiar la búsqueda o el filtro de habilidades.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._filteredConvocatorias.map(
                (c) => ConvocatoriaCard(
                  convocatoria: c,
                  onApply: () => _openProposalDialog(c),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
