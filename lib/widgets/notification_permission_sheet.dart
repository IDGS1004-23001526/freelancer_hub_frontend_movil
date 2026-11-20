import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_notification_service.dart';
import '../theme/app_colors.dart';

/// Modal BottomSheet y Tarjeta visual interactiva para solicitar y gestionar
/// los permisos de notificaciones push (Android 13+ y iOS) de forma amigable.
class NotificationPermissionSheet extends StatefulWidget {
  final VoidCallback? onGranted;
  final VoidCallback? onDismissed;
  final bool isInlineCard;

  const NotificationPermissionSheet({
    super.key,
    this.onGranted,
    this.onDismissed,
    this.isInlineCard = false,
  });

  /// Bandera en memoria para no spamear al usuario si ya descartó la card en esta sesión
  static bool hasDismissedThisSession = false;

  /// Abre la card como un Modal Bottom Sheet si el usuario aún no tiene los permisos otorgados
  static Future<bool?> showIfNeeded(BuildContext context) async {
    if (hasDismissedThisSession) return false;

    final isGranted =
        await FirebaseNotificationService.instance.isPermissionGranted();
    if (isGranted) return true;

    if (!context.mounted) return false;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationPermissionSheet(),
    );
  }

  /// Muestra explícitamente el modal (e.g. desde Ajustes o Perfil)
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationPermissionSheet(),
    );
  }

  @override
  State<NotificationPermissionSheet> createState() =>
      _NotificationPermissionSheetState();
}

class _NotificationPermissionSheetState
    extends State<NotificationPermissionSheet> {
  bool _isLoading = false;

  Future<void> _handleAccept() async {
    setState(() => _isLoading = true);

    try {
      final granted = await FirebaseNotificationService.instance
          .requestNotificationPermission();

      if (mounted) {
        setState(() => _isLoading = false);

        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Notificaciones activadas! Recibirás alertas de nuevos mensajes.',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.accentGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );

          widget.onGranted?.call();
          if (!widget.isInlineCard && Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se otorgaron permisos. Puedes activarlos luego en Ajustes.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              backgroundColor: Colors.grey.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );

          NotificationPermissionSheet.hasDismissedThisSession = true;
          widget.onDismissed?.call();
          if (!widget.isInlineCard && Navigator.canPop(context)) {
            Navigator.pop(context, false);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDismiss() {
    NotificationPermissionSheet.hasDismissedThisSession = true;
    widget.onDismissed?.call();
    if (!widget.isInlineCard && Navigator.canPop(context)) {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: widget.isInlineCard
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: widget.isInlineCard
            ? Border.all(color: AppColors.primaryLight, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isInlineCard ? 0.05 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.isInlineCard) ...[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Cabecera con Icono llamativo
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Activar notificaciones?',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Mantente al día en tiempo real',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isInlineCard)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: _handleDismiss,
                  tooltip: 'Cerrar',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Texto descriptivo
          Text(
            'Recibe alertas importantes incluso cuando la aplicación esté minimizada o completamente cerrada:',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Lista de beneficios
          _buildBenefitItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Mensajes y propuestas de clientes al instante',
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Actualizaciones de hitos y contratos',
          ),
          const SizedBox(height: 8),
          _buildBenefitItem(
            icon: Icons.security_update_good_outlined,
            title: 'Avisos de pagos y estado de tu cuenta',
          ),
          const SizedBox(height: 22),

          // Botón principal "Permitir Notificaciones"
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Permitir notificaciones',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Botón secundario "Ahora no"
          SizedBox(
            height: 42,
            child: TextButton(
              onPressed: _isLoading ? null : _handleDismiss,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Ahora no',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isInlineCard) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: content,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: content,
      ),
    );
  }

  Widget _buildBenefitItem({required IconData icon, required String title}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
