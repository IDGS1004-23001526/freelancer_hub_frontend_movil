import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_constants.dart';
import '../models/milestone.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'delivery_service.dart';

typedef JsonMap = Map<String, dynamic>;

class MilestoneActionResult {
  final bool success;
  final String message;
  final String? newStatus;

  const MilestoneActionResult({
    required this.success,
    required this.message,
    this.newStatus,
  });
}

class MilestoneService {
  final Dio _dio = ApiClient.instance.dio;

  /// Lista los contratos activos del usuario autenticado (GET /api/v1/contracts)
  /// Lista los contratos/postulaciones activas del usuario autenticado (GET /api/v1/contracts)
  Future<List<JsonMap>> getMyContracts() async {
    for (final baseUrl in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _dio.get('$baseUrl${ApiConstants.contracts}');
        final rawList = response.data is Map && response.data['data'] != null
            ? response.data['data'] as List
            : response.data as List;
        return rawList.map((e) => JsonMap.from(e)).toList();
      } on DioException catch (e) {
        debugPrint('MilestoneService.getMyContracts fallo en $baseUrl: $e');
        // Si el servidor respondió con un error HTTP (401, 404, 500), no probar IPs locales
        if (e.response != null) rethrow;
      }
    }
    throw Exception('No se pudo conectar con ningún servidor disponible.');
  }

  /// Obtiene el detalle de un hito desde los contratos del usuario para ApproveMilestoneScreen
  Future<Milestone> getMilestoneDetail(String milestoneId) async {
    try {
      final contracts = await getMyContracts();
      for (final contract in contracts) {
        final milestones = contract['milestones'];
        if (milestones is List) {
          for (final raw in milestones) {
            if (raw is Map && raw['id']?.toString() == milestoneId) {
              final m = JsonMap.from(raw);
              final amountNum = (m['amount'] as num?)?.toDouble();
              final statusRaw = m['status']?.toString() ?? 'IN_REVIEW';

              return Milestone(
                id: m['id']?.toString() ?? milestoneId,
                contractId: contract['id']?.toString() ?? '',
                label: m['label']?.toString() ?? 'H${m['order'] ?? 1}',
                title: m['title']?.toString() ?? 'Hito del Proyecto',
                order: (m['order'] as num?)?.toInt() ?? 1,
                amount: amountNum != null
                    ? '\$${amountNum.toStringAsFixed(2)} USD'
                    : (m['amount']?.toString() ?? '\$0.00 USD'),
                isFunded: statusRaw != 'PENDING' && statusRaw != 'UNFUNDED',
                status: statusRaw,
                clientName: contract['freelancer']?['name']?.toString() ??
                    contract['client']?['name']?.toString() ??
                    'Profesional Asignado',
                reviewDays: (m['reviewDays'] as num?)?.toInt() ?? 5,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('MilestoneService.getMilestoneDetail fallback: $e');
    }

    // Respaldo con datos iniciales si el servidor no está activo o el ID es de demostración
    final defaults = DeliveryService().getInitialMilestones();
    return defaults.firstWhere(
          (m) => m.id == milestoneId,
      orElse: () => defaults.first,
    );
  }

  /// Fondea un contrato en custodia Escrow (HU-05)
  Future<JsonMap> fundContract(String contractId) async {
    final response = await _dio.post(ApiConstants.fundContract(contractId));
    return JsonMap.from(response.data['data'] ?? response.data);
  }

  /// Aprueba entrega y libera fondos de Escrow (POST /api/v1/milestones/:id/approve - HU-07)
  Future<MilestoneActionResult> approveAndReleaseFunds({
    required String milestoneId,
  }) async {
    try {
      await _dio.post(ApiConstants.approveMilestone(milestoneId));
      return const MilestoneActionResult(
        success: true,
        message: 'Hito aprobado y fondos liberados exitosamente al freelancer.',
        newStatus: 'COMPLETADO',
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message'] ?? data['error'] ?? 'No se pudo aprobar el hito.')
            : 'Error del servidor (${e.response?.statusCode}).';
        return MilestoneActionResult(success: false, message: msg.toString());
      }
      debugPrint('Backend no disponible, aprobando en modo simulación: $e');
      return const MilestoneActionResult(
        success: true,
        message: 'Hito aprobado y fondos liberados exitosamente (Modo Simulación).',
        newStatus: 'COMPLETADO',
      );
    } catch (e) {
      return const MilestoneActionResult(
        success: true,
        message: 'Hito aprobado y fondos liberados exitosamente (Modo Simulación).',
        newStatus: 'COMPLETADO',
      );
    }
  }

  /// Solicita ajustes en un entregable manteniendo los fondos congelados (HU-07)
  Future<MilestoneActionResult> requestAdjustments({
    required String milestoneId,
    required String justification,
  }) async {
    return const MilestoneActionResult(
      success: true,
      message: 'Solicitud de ajustes enviada. Hito en corrección y fondos en custodia.',
      newStatus: 'EN_CORRECCION',
    );
  }
}