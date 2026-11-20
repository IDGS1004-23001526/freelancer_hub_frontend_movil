import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../services/milestone_service.dart';
import '../../services/profile_service.dart' hide JsonMap;
import '../../theme/app_colors.dart';
import '../deliveries/submit_delivery_screen.dart';
import 'approve_milestone_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final MilestoneService _milestoneService = MilestoneService();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  bool _isFunding = false;
  String _userRole = 'FREELANCER';
  List<JsonMap> _contracts = [];

  @override
  void initState() {
    super.initState();
    _initScreenData();
  }

  Future<void> _initScreenData() async {
    setState(() => _isLoading = true);

    // 1. Obtener rol del usuario autenticado (CLIENT o FREELANCER)
    try {
      AuthBloc? authBloc;
      try {
        authBloc = BlocProvider.of<AuthBloc>(context, listen: false);
      } catch (_) {
        authBloc = null;
      }

      final blocRole = authBloc?.state.user?.role;
      if (blocRole != null && blocRole.isNotEmpty) {
        _userRole = blocRole.toUpperCase();
      } else {
        final profile = await _profileService.fetchProfile();
        if (profile != null && profile.role.isNotEmpty) {
          _userRole = profile.role.toUpperCase();
        }
      }
    } catch (e) {
      debugPrint('ContractsScreen: usando rol por defecto ($_userRole): $e');
    }

    // 2. Cargar contratos reales desde GET /api/v1/contracts
    try {
      final remoteContracts = await _milestoneService.getMyContracts();
      if (remoteContracts.isNotEmpty) {
        _contracts = remoteContracts;
      } else {
        _contracts = _fallbackContracts();
      }
    } catch (e) {
      debugPrint('ContractsScreen: cargando contrato de respaldo: $e');
      _contracts = _fallbackContracts();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<JsonMap> _fallbackContracts() {
    return [
      {
        'id': 'CT-2026-0418',
        'code': 'CT-2026-0418',
        'status': 'IN_EXECUTION',
        'project': {'title': 'Telemetría y Base de Datos TimescaleDB'},
        'client': {'name': 'Carlos Mendoza · Nexo Commerce'},
        'freelancer': {'name': 'Axel (Desarrollador Asignado)'},
        'milestones': [
          {
            'id': 'milestone-01',
            'order': 1,
            'title': 'Arquitectura y Telemetría',
            'amount': 1200.0,
            'status': 'FUNDED',
          },
          {
            'id': 'milestone-02',
            'order': 2,
            'title': 'Módulo de Facturación',
            'amount': 1800.0,
            'status': 'UNFUNDED',
          },
        ],
      },
    ];
  }

  Future<void> _handleFundContract(String contractId) async {
    setState(() => _isFunding = true);
    try {
      await _milestoneService.fundContract(contractId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contrato fondeado exitosamente en custodia Escrow (HU-05).',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _initScreenData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo fondear el contrato: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isFunding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isClient = _userRole == 'CLIENT';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contratos y Entregables',
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              isClient
                  ? 'Vista Contratante · Fondeo y Aprobación Biométrica'
                  : 'Vista Freelancer · Entrega de Evidencias',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Actualizar contratos',
            onPressed: _initScreenData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      )
          : RefreshIndicator(
        onRefresh: _initScreenData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Contratos Activos',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._contracts.map((c) => _buildContractCard(c, isClient)),
          ],
        ),
      ),
    );
  }

  Widget _buildContractCard(JsonMap contract, bool isClient) {
    final String contractId = contract['id']?.toString() ?? 'CT-2026-0418';
    final String code = contract['code']?.toString() ??
        (contractId.length > 12
            ? 'CT-${contractId.substring(0, 8).toUpperCase()}'
            : contractId);

    final dynamic rawProject = contract['project'];
    final String title = rawProject is Map
        ? (rawProject['title']?.toString() ?? 'Proyecto Activo')
        : (contract['title']?.toString() ?? 'Proyecto Activo');

    final dynamic rawFreelancer = contract['freelancer'];
    final dynamic rawClient = contract['client'];
    final String counterpart = isClient
        ? 'Freelancer: ${rawFreelancer is Map ? (rawFreelancer['name'] ?? 'Profesional Asignado') : 'Profesional Asignado'}'
        : 'Cliente: ${rawClient is Map ? (rawClient['name'] ?? 'Contratante') : 'Contratante'}';

    final dynamic rawMilestones = contract['milestones'];
    final List<JsonMap> milestones = rawMilestones is List
        ? rawMilestones
        .whereType()
        .map((m) => JsonMap.from(m))
        .toList()
        : [];

    // Primer hito activo / fondeado o en revisión
    final JsonMap activeMilestone = milestones.firstWhere(
          (m) {
        final st = (m['status'] ?? '').toString().toUpperCase();
        return st == 'FUNDED' ||
            st == 'IN_PROGRESS' ||
            st == 'IN_REVIEW' ||
            st == 'REVISION_DE_EVIDENCIAS';
      },
      orElse: () => milestones.isNotEmpty
          ? milestones.first
          : <String, dynamic>{'id': 'milestone-01', 'status': 'FUNDED'},
    );

    final String activeMilestoneId =
        activeMilestone['id']?.toString() ?? 'milestone-01';
    final bool hasUnfundedMilestones = milestones.any((m) {
      final st = (m['status'] ?? '').toString().toUpperCase();
      return st == 'UNFUNDED' || st == 'PENDING' || st == 'PENDIENTE_DE_PAGO';
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado Código + Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'En Ejecución',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            counterpart,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Lista de hitos sin overflow horizontal
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: List.generate(milestones.length, (idx) {
                final m = milestones[idx];
                final int order = (m['order'] as num?)?.toInt() ?? (idx + 1);
                final String mTitle =
                    m['title']?.toString() ?? 'Hito $order';
                final double amount =
                    (m['amount'] as num?)?.toDouble() ?? 0.0;
                final String status =
                (m['status'] ?? 'UNFUNDED').toString().toUpperCase();
                final bool isFunded = status == 'FUNDED' ||
                    status == 'IN_PROGRESS' ||
                    status == 'IN_REVIEW' ||
                    status == 'COMPLETED' ||
                    status == 'COMPLETADO';

                String statusLabel = 'Estado: Sin fondeo en custodia';
                Color statusColor = AppColors.textSecondary;
                if (status == 'COMPLETED' || status == 'COMPLETADO') {
                  statusLabel = 'Estado: Completado y Liberado';
                  statusColor = Colors.green.shade800;
                } else if (status == 'IN_REVIEW' ||
                    status == 'REVISION_DE_EVIDENCIAS') {
                  statusLabel = 'Estado: Entregado · En revisión';
                  statusColor = Colors.blue.shade800;
                } else if (isFunded) {
                  statusLabel = 'Estado: Fondeado en Escrow (Listo)';
                  statusColor = Colors.green.shade700;
                }

                return Column(
                  children: [
                    if (idx > 0) const Divider(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isFunded
                              ? Icons.check_circle
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: isFunded
                              ? Colors.green.shade600
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'H$order: $mTitle',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '\$${amount.toStringAsFixed(0)} USD',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isFunded
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                statusLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // ACCIONES EXCLUSIVAS SEGÚN EL ROL DEL USUARIO
          if (!isClient) ...[
            // ROL FREELANCER: Únicamente entrega de evidencias (HU-06)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubmitDeliveryScreen(),
                    ),
                  );
                  _initScreenData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: Text(
                  'Entregar Hito (HU-06)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ] else ...[
            // ROL CLIENT (CONTRATANTE): Aprobación biométrica (HU-07) y Fondeo (HU-05)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApproveMilestoneScreen(
                        milestoneId: activeMilestoneId,
                        contractId: contractId,
                      ),
                    ),
                  );
                  _initScreenData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.fingerprint_rounded, size: 22),
                label: Text(
                  'Revisar y Aprobar con Biometría (HU-07)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            if (hasUnfundedMilestones) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed:
                  _isFunding ? null : () => _handleFundContract(contractId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.account_balance_rounded, size: 18),
                  label: Text(
                    _isFunding
                        ? 'Fondeando en Escrow...'
                        : 'Fondear Contrato en Escrow (HU-05)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}