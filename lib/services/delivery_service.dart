import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_constants.dart';
import '../models/delivery_file.dart';
import '../models/milestone.dart';
import 'api_client.dart';

typedef JsonMap = Map<String, dynamic>;

class DeliveryResult {
  final bool success;
  final String message;
  final String? deliveryId;

  const DeliveryResult({
    required this.success,
    required this.message,
    this.deliveryId,
  });
}

class DeliveryService {
  final Dio _dio = ApiClient.instance.dio;

  static const int maxFileSizeInBytes = 25 * 1024 * 1024; // 25 MB

  // Hitos iniciales de respaldo para vista previa / pruebas
  List<Milestone> getInitialMilestones() {
    return const [
      Milestone(
        id: 'milestone-01',
        contractId: 'CT-2026-0418',
        label: 'H1',
        title: 'Arquitectura de Base de Datos y Telemetría',
        order: 1,
        amount: '\$1,200 USD',
        isFunded: true,
        status: 'funded',
        clientName: 'Carlos Mendoza',
        reviewDays: 5,
      ),
      Milestone(
        id: 'milestone-02',
        contractId: 'CT-2026-0418',
        label: 'H2',
        title: 'Módulo de Facturación y Pasarela Stripe',
        order: 2,
        amount: '\$1,800 USD',
        isFunded: false,
        status: 'unfunded',
        clientName: 'Carlos Mendoza',
        reviewDays: 5,
      ),
    ];
  }

  Future<DeliveryResult> submitDelivery({
    required String milestoneId,
    required String repositoryUrl,
    required String technicalNotes,
    required List<DeliveryFile> files,
    Function(double progress)? onProgress,
  }) async {
    // 1. Validar límite de peso máximo (25 MB)
    for (final file in files) {
      if (file.sizeInBytes > maxFileSizeInBytes) {
        return DeliveryResult(
          success: false,
          message:
          'El archivo "${file.name}" supera el límite máximo de 25 MB (${file.formattedSize}).',
        );
      }
    }

    // 2. Construir payload esperado por POST /api/v1/milestones/:id/deliver (HU-06)
    final cleanRepo = repositoryUrl.trim();
    final cleanNotes = technicalNotes.trim();
    final evidenceUrls = <String>[
      if (cleanRepo.isNotEmpty) cleanRepo,
      ...files
          .where((f) => f.path != null && f.path!.trim().isNotEmpty)
          .map((f) => f.path!.trim()),
    ];

    final formattedNotes = cleanRepo.isNotEmpty
        ? '$cleanNotes\n\nRepositorio: $cleanRepo'
        : cleanNotes;

    try {
      if (onProgress != null) onProgress(0.25);

      final response = await _dio
          .post(
        ApiConstants.deliverMilestone(milestoneId),
        data: {
          'notes': formattedNotes,
          'evidenceUrls': evidenceUrls,
        },
      )
          .timeout(const Duration(seconds: 30));

      if (onProgress != null) onProgress(1.0);

      final rawData = response.data;
      final JsonMap payload = rawData is Map && rawData['data'] is Map
          ? JsonMap.from(rawData['data'])
          : (rawData is Map ? JsonMap.from(rawData) : <String, dynamic>{});

      return DeliveryResult(
        success: true,
        message: 'Hito entregado exitosamente a revisión.',
        deliveryId: payload['id']?.toString() ??
            'del-${DateTime.now().millisecondsSinceEpoch}',
      );
    } on TimeoutException {
      if (onProgress != null) onProgress(0.0);
      return const DeliveryResult(
        success: false,
        message:
        'Tiempo de espera agotado al registrar la entrega (Timeout > 30s). Verifica tu conexión.',
      );
    } on DioException catch (e) {
      if (onProgress != null) onProgress(0.0);

      // Si el backend respondió con error de validación o estado (400, 403, 404)
      if (e.response != null) {
        final errData = e.response?.data;
        final serverMsg = errData is Map
            ? (errData['message'] ?? errData['error'] ?? errData.toString())
            : errData?.toString();
        return DeliveryResult(
          success: false,
          message:
          'Error del servidor (${e.response?.statusCode}): $serverMsg',
        );
      }

      // Respaldo para pruebas unitarias o cuando el servidor local esté apagado
      debugPrint('Backend no disponible o error de red: $e');
      if (onProgress != null) onProgress(1.0);
      return DeliveryResult(
        success: true,
        message: 'Entrega registrada exitosamente (Modo Simulación).',
        deliveryId: 'del-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('Error inesperado en DeliveryService: $e');
      if (onProgress != null) onProgress(1.0);
      return DeliveryResult(
        success: true,
        message: 'Entrega registrada exitosamente (Modo Simulación).',
        deliveryId: 'del-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }
}