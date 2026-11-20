import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../models/convocatoria.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import 'proposal_submission_screen.dart';
import 'proposals_received_screen.dart';

/// HU-03 · Convocatoria abierta (Detalle de convocatoria antes de postularse)
class ProjectDetailScreen extends StatefulWidget {
  final Convocatoria convocatoria;
  final String? userRoleOverride;

  const ProjectDetailScreen({
    super.key,
    required this.convocatoria,
    this.userRoleOverride,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  String _resolvedRole = '';
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    if (widget.userRoleOverride != null &&
        widget.userRoleOverride!.trim().isNotEmpty) {
      setState(() {
        _resolvedRole = widget.userRoleOverride!.trim().toUpperCase();
        _isCheckingRole = false;
      });
      return;
    }

    // 1. Intentar obtener el rol desde AuthBloc
    try {
      final authBloc = context.read<AuthBloc?>();
      final blocRole = authBloc?.state.user?.role.trim() ?? '';
      if (blocRole.isNotEmpty) {
        setState(() {
          _resolvedRole = blocRole.toUpperCase();
          _isCheckingRole = false;
        });
        return;
      }
    } catch (_) {
      // AuthBloc no disponible en el árbol (ej. pruebas aisladas)
    }

    // 2. Fallback: consultar el perfil actual en el servidor
    try {
      final profile = await ProfileService().fetchProfile();
      if (!mounted) return;
      setState(() {
        _resolvedRole = (profile?.role ?? '').trim().toUpperCase();
        _isCheckingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvedRole = '';
        _isCheckingRole = false;
      });
    }
  }

  bool get _isClient =>
      _resolvedRole == 'CLIENT' || _resolvedRole == 'CLIENTE';

  String _formatUsd(double value) {
    final isWhole = value == value.roundToDouble();
    final raw = isWhole ? value.round().toString() : value.toStringAsFixed(2);
    final parts = raw.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return parts.length > 1 ? '\$$intPart.${parts[1]}' : '\$$intPart';
  }

  @override
  Widget build(BuildContext context) {
    final convocatoria = widget.convocatoria;
    final descriptionText = (convocatoria.description != null &&
            convocatoria.description!.trim().isNotEmpty)
        ? convocatoria.description!.trim()
        : 'Buscamos un especialista para llevar a cabo este proyecto cumpliendo con los estándares de calidad, entregas por hitos y comunicación constante.';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Volver
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 20, color: AppColors.textDark),
                      SizedBox(width: 8),
                      Text(
                        'Convocatoria',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.wine,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Detalle de convocatoria',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isClient
                    ? 'Vista de consulta de la convocatoria.'
                    : 'Conoce el proyecto y prepara tu propuesta.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),

              // Aviso informativo al inicio si el usuario tiene rol Cliente
              if (!_isCheckingRole && _isClient) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.roseTint.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.dustyRose.withValues(alpha: 0.7),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.wine,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Solo los freelancers pueden postularse',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.wine,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tienes iniciada sesión como Cliente. Para enviar una propuesta y cotizar hitos, ingresa con una cuenta de Freelancer.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Tarjeta principal de convocatoria
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.roseTint,
                          child: Text(
                            convocatoria.company.isNotEmpty
                                ? convocatoria.company[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: AppColors.wine,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                convocatoria.company,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                convocatoria.timeAgo,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      convocatoria.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'ABIERTO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.successText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${convocatoria.remoteType} · ${convocatoria.paymentType}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: AppColors.cardBorder, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Presupuesto',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${_formatUsd(convocatoria.budget)} USD',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.wine,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Plazo del proyecto',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${convocatoria.remainingDays} días',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: convocatoria.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Acerca del proyecto
              const Text(
                'Acerca del proyecto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                descriptionText,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),

              // Solo mostrar verificación y botón Postularme si NO es Cliente
              if (!_isCheckingRole && !_isClient) ...[                const SizedBox(height: 20),

                // Banner de verificación
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.roseTint.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 20,
                        color: AppColors.wine,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu perfil está verificado',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.wine,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Aún no has postulado a esta convocatoria.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Botón Postularme
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProposalSubmissionScreen(
                            convocatoria: convocatoria,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.wine,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    child: const Text(
                      'Postularme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Envía una cotización por hitos y tu carta de presentación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],

              // Botón "Ver candidatos" solo para CLIENT
              if (!_isCheckingRole && _isClient) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProposalsReceivedScreen(
                            projectId: widget.convocatoria.id,
                            projectTitle: widget.convocatoria.title,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_outline),
                    label: const Text(
                      'Ver candidatos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Revisa las propuestas recibidas y adjudica el contrato.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
