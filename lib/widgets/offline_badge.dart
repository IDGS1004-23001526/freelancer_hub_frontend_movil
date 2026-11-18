import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class OfflineBadge extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onRetry;

  const OfflineBadge({
    super.key,
    required this.isOffline,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final queueService = OfflineQueueService();
    final connectivityService = ConnectivityService();

    return StreamBuilder<int>(
      stream: queueService.pendingCountStream,
      initialData: queueService.getPendingCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        // Si no está offline y no hay acciones pendientes, no mostramos banner persistente
        if (!isOffline && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOffline ? const Color(0xFFFFF4E5) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOffline
                  ? const Color(0xFFFFB74D).withValues(alpha: 0.6)
                  : const Color(0xFF81C784).withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                    color: isOffline
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOffline ? 'Modo Offline Activo' : 'Conexión Restablecida',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isOffline
                            ? const Color(0xFFE65100)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  if (connectivityService.isSimulatingOffline)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Simulación',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  if (onRetry != null && isOffline)
                    InkWell(
                      onTap: onRetry,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, size: 14, color: Color(0xFFE65100)),
                            const SizedBox(width: 2),
                            Text(
                              'Reintentar',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isOffline
                    ? 'Estás navegando con la última lista de convocatorias guardada en caché local.'
                    : 'Tus datos están actualizados con el servidor.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: isOffline
                      ? const Color(0xFF795548)
                      : const Color(0xFF388E3C),
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_rounded,
                          size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text(
                        '$pendingCount acción(es) en cola para sincronizar al volver online.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
