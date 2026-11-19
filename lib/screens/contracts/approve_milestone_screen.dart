import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/milestone.dart';
import '../../services/biometric_service.dart';
import '../../services/milestone_service.dart';
import '../../theme/app_colors.dart';

class ApproveMilestoneScreen extends StatefulWidget {
  final String milestoneId;
  final String contractId;

  const ApproveMilestoneScreen({
    super.key,
    this.milestoneId = 'milestone-01',
    this.contractId = 'CT-2026-0418',
  });

  @override
  State<ApproveMilestoneScreen> createState() => _ApproveMilestoneScreenState();
}

class _ApproveMilestoneScreenState extends State<ApproveMilestoneScreen>
    with SingleTickerProviderStateMixin {
  final MilestoneService _milestoneService = MilestoneService();
  final BiometricService _biometricService = BiometricService();

  Milestone? _milestone;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _statusOverride;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _loadMilestone();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadMilestone() async {
    setState(() => _isLoading = true);
    final m = await _milestoneService.getMilestoneDetail(widget.milestoneId);
    if (mounted) {
      setState(() {
        _milestone = m;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApproveWithBiometrics() async {
    // 1. Criterio de Aceptación: Solicitar autenticación biométrica (Huella / FaceID) o PIN
    final bool authenticated = await _biometricService.authenticate(
      reason: 'Confirma con tu huella o PIN para liberar ${_milestone?.amount ?? "los fondos"} al freelancer.',
    );

    // Si la biometría es cancelada o incorrecta, NO se ejecuta ninguna llamada al backend
    if (!authenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Autenticación biométrica cancelada. No se realizó ningún cargo ni liberación.',
            style: GoogleFonts.poppins(fontSize: 12.5),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Feedback háptico
    await HapticFeedback.heavyImpact();

    // 3. Validación biométrica exitosa -> Enviar petición al backend
    setState(() => _isProcessing = true);

    final response = await _milestoneService.approveAndReleaseFunds(
      milestoneId: widget.milestoneId,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (response.success) {
      setState(() {
        _statusOverride = 'COMPLETADO';
      });
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showAdjustmentsDialog() {
    final TextEditingController reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Solicitar Ajustes (HU-07)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indica las correcciones necesarias antes de liberar los fondos en custodia:',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ej. Faltó documentar las variables de entorno en el README.',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isProcessing = true);
                final res = await _milestoneService.requestAdjustments(
                  milestoneId: widget.milestoneId,
                  justification: reason,
                );
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                    _statusOverride = 'EN_CORRECCION';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.message),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              },
              child: Text(
                'Enviar a Corrección',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    _animController.forward(from: 0.0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 54,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '¡Fondos Liberados!',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La autenticación biométrica fue exitosa. Se han transferido ${_milestone?.amount} a la billetera del freelancer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Cierra modal
                    Navigator.pop(context, true); // Regresa a la vista anterior
                  },
                  child: Text(
                    'Entendido',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final milestone = _milestone!;
    final effectiveStatus = _statusOverride ?? milestone.status;
    final bool isCompleted = effectiveStatus == 'COMPLETADO';
    final bool isCorrection = effectiveStatus == 'EN_CORRECCION';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Revisión de Hito (HU-07)',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Tarjeta principal del hito
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5D9CB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${milestone.label} · ${widget.contractId}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        _buildStatusBadge(effectiveStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      milestone.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Freelance: ${milestone.clientName} · Fondos en Escrow: ${milestone.amount}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sección: Repositorio y Demostración
              _buildSectionCard(
                title: 'Repositorio y Código Fuente',
                icon: Icons.code_rounded,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0EA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          milestone.repositoryUrl ?? 'https://github.com/freelancer/repo',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sección: Notas Técnicas
              _buildSectionCard(
                title: 'Notas Técnicas de Entrega',
                icon: Icons.notes_rounded,
                child: Text(
                  milestone.technicalNotes ?? 'Sin notas adicionales.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sección: Evidencias y Documentos
              _buildSectionCard(
                title: 'Evidencias Adjuntas (${milestone.attachments.length})',
                icon: Icons.attach_file_rounded,
                child: Column(
                  children: milestone.attachments.map((file) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            file.endsWith('.pdf')
                                ? Icons.picture_as_pdf
                                : file.endsWith('.png') || file.endsWith('.jpg')
                                    ? Icons.image
                                    : Icons.insert_drive_file,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              file,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.grey),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),
              // Alerta informativa de seguridad Escrow
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Colors.blue, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Al presionar "Aprobar y Liberar Fondos", se solicitará tu confirmación biométrica (Huella o FaceID) o PIN para transferir el saldo en garantía.',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Botones inferiores de acción
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: isCompleted
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '✓ Hito Aprobado y Fondos Liberados',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Botón Solicitar Ajustes
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.orange.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isProcessing ? null : _showAdjustmentsDialog,
                            child: Text(
                              'Solicitar Ajustes',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón Aprobar y Liberar con Biometría
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isProcessing ? null : _handleApproveWithBiometrics,
                            icon: const Icon(Icons.fingerprint_rounded, size: 20, color: Colors.white),
                            label: Text(
                              _isProcessing ? 'Procesando...' : 'Aprobar y Liberar',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'COMPLETADO':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Completado';
        break;
      case 'EN_CORRECCION':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'En Corrección';
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'En Revisión (Escrow)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
