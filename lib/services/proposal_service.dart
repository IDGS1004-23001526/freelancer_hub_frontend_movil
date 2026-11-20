import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/proposal.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ProposalService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  ProposalService({
    ApiClient? apiClient,
    FlutterSecureStorage? storage,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _storage = storage ?? const FlutterSecureStorage();

  /// Envía una propuesta con cotización por hitos (`POST /api/v1/proposals`).
  /// Incluye automáticamente el token JWT en el header `Authorization: Bearer`.
  Future<ProposalSubmissionResult> submitProposal(
    ProposalRequest request,
  ) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null || token.isEmpty) {
      return const ProposalSubmissionResult(
        success: false,
        message: 'Debes iniciar sesión para enviar una propuesta.',
        statusCode: 401,
      );
    }

    final baseUrls = AuthService.getOrderedBaseUrls();
    String? lastNetworkError;

    for (final base in baseUrls) {
      try {
        final response = await _apiClient.dio.post(
          '$base/proposals',
          data: request.toJson(),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          AuthService.activeBaseUrl = base;
          final data = response.data;
          String? proposalId;
          String message = 'Propuesta enviada correctamente.';

          if (data is Map<String, dynamic>) {
            final payload = data['data'];
            if (payload is Map<String, dynamic>) {
              proposalId = (payload['id'] ?? payload['_id'])?.toString();
            } else {
              proposalId = (data['id'] ?? data['_id'])?.toString();
            }
            if (data['message'] != null &&
                data['message'].toString().trim().isNotEmpty) {
              message = data['message'].toString();
            }
          }

          return ProposalSubmissionResult(
            success: true,
            message: message,
            proposalId: proposalId,
            statusCode: response.statusCode,
          );
        }

        return ProposalSubmissionResult(
          success: false,
          message: _extractErrorMessage(
            response.data,
            'No se pudo enviar la propuesta (código ${response.statusCode}).',
          ),
          statusCode: response.statusCode,
        );
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        // Si el servidor respondió con un código HTTP (4xx/5xx), no reintentar otras URLs
        if (statusCode != null) {
          debugPrint(
            '[ProposalService] HTTP $statusCode en $base/proposals: ${e.response?.data}',
          );
          return ProposalSubmissionResult(
            success: false,
            message: _extractErrorMessage(
              e.response?.data,
              _defaultMessageForStatus(statusCode),
            ),
            statusCode: statusCode,
          );
        }

        // Error de red / timeout: probar siguiente URL candidata
        lastNetworkError = e.message ?? 'Error de conexión con el servidor.';
        debugPrint('[ProposalService] Red fallida en $base: $lastNetworkError');
      } catch (e) {
        lastNetworkError = e.toString();
        debugPrint('[ProposalService] Error inesperado: $e');
      }
    }

    return ProposalSubmissionResult(
      success: false,
      message:
          'No se pudo conectar con el servidor. Verifica tu conexión e intenta de nuevo.',
      statusCode: null,
    );
  }

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data is Map<String, dynamic>) {
      final rawMessage = data['message'] ?? data['error'] ?? data['detail'];
      if (rawMessage is List && rawMessage.isNotEmpty) {
        return rawMessage.map((e) => e.toString()).join('\n');
      }
      if (rawMessage != null && rawMessage.toString().trim().isNotEmpty) {
        return rawMessage.toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback;
  }

  String _defaultMessageForStatus(int statusCode) {
    switch (statusCode) {
      case 400:
      case 422:
        return 'Los datos de la propuesta no son válidos. Revisa los campos e hitos.';
      case 401:
        return 'Tu sesión ha expirado. Inicia sesión nuevamente.';
      case 403:
        return 'Solo los freelancers verificados pueden postularse a esta convocatoria.';
      case 404:
        return 'La convocatoria no existe o ya no está disponible.';
      case 409:
        return 'Ya enviaste una propuesta para esta convocatoria.';
      default:
        return 'Ocurrió un error en el servidor (código $statusCode).';
    }
  }
}
