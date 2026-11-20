import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/proposal.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'offline_queue_service.dart';

typedef JsonMap = Map<String, dynamic>;

class ProposalService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  static final StreamController<void> _proposalsStreamController =
      StreamController<void>.broadcast();

  /// Stream global para notificar a la UI cuando se envía o sincroniza una propuesta
  static Stream<void> get onProposalsChanged =>
      _proposalsStreamController.stream;

  static void notifyProposalChanged() {
    if (!_proposalsStreamController.isClosed) {
      _proposalsStreamController.add(null);
    }
  }

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

          if (data is JsonMap) {
            final payload = data['data'];
            if (payload is JsonMap) {
              proposalId = (payload['id'] ?? payload['_id'])?.toString();
            } else {
              proposalId = (data['id'] ?? data['_id'])?.toString();
            }
            if (data['message'] != null &&
                data['message'].toString().trim().isNotEmpty) {
              message = data['message'].toString();
            }
          }

          await _saveLocalProposal(request, proposalId);

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

    return const ProposalSubmissionResult(
      success: false,
      message:
      'No se pudo conectar con el servidor. Verifica tu conexión e intenta de nuevo.',
      statusCode: null,
    );
  }

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data is JsonMap) {
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

  Future<void> _saveLocalProposal(
      ProposalRequest request, String? proposalId) async {
    if (!Hive.isBoxOpen('convocatoriasBox')) return;
    final box = Hive.box('convocatoriasBox');

    // Intentar resolver título y empresa reales
    String resolvedTitle = request.projectTitle ?? '';
    String resolvedCompany = request.companyName ?? '';

    if (resolvedTitle.isEmpty || resolvedCompany.isEmpty) {
      final cachedRaw = box.get('ultimas_convocatorias', defaultValue: []);
      if (cachedRaw is List) {
        for (final item in cachedRaw.whereType<Map>()) {
          if (item['id']?.toString() == request.projectId) {
            if (resolvedTitle.isEmpty) {
              resolvedTitle = (item['title'] ?? '').toString();
            }
            if (resolvedCompany.isEmpty) {
              resolvedCompany = (item['company'] ?? item['companyName'] ?? '').toString();
            }
            break;
          }
        }
      }
    }

    if (resolvedTitle.isEmpty) {
      resolvedTitle = 'Convocatoria #${request.projectId}';
    }
    if (resolvedCompany.isEmpty) {
      resolvedCompany = 'Cliente Contratante';
    }

    final raw = box.get('mis_postulaciones', defaultValue: []);
    final List<JsonMap> list = raw is List
        ? raw.whereType().map((e) => JsonMap.from(e)).toList()
        : <JsonMap>[];

    list.removeWhere((e) => e['projectId']?.toString() == request.projectId);
    list.insert(
      0,
      SubmittedProposal(
        id: proposalId ?? 'prop-${DateTime.now().millisecondsSinceEpoch}',
        projectId: request.projectId,
        projectTitle: resolvedTitle,
        companyName: resolvedCompany,
        coverLetter: request.coverLetter,
        totalAmount: request.totalAmount,
        estimatedDays: request.estimatedDays,
        status: 'PENDIENTE',
        createdAt: DateTime.now(),
        milestones: request.milestones,
      ).toJson(),
    );
    await box.put('mis_postulaciones', list);
    notifyProposalChanged();
  }

  Future<List<SubmittedProposal>> getMyProposals() async {
    final Map<String, SubmittedProposal> map = {};

    // 1. Guardadas localmente al postular
    if (Hive.isBoxOpen('convocatoriasBox')) {
      final box = Hive.box('convocatoriasBox');
      final raw = box.get('mis_postulaciones', defaultValue: []);
      final cachedRaw = box.get('ultimas_convocatorias', defaultValue: []);
      final Map<String, Map> convocatoriasDict = {};

      if (cachedRaw is List) {
        for (final item in cachedRaw.whereType<Map>()) {
          final cid = item['id']?.toString();
          if (cid != null && cid.isNotEmpty) {
            convocatoriasDict[cid] = item;
          }
        }
      }

      if (raw is List) {
        for (final item in raw.whereType()) {
          final p = SubmittedProposal.fromJson(JsonMap.from(item));
          var title = p.projectTitle;
          var company = p.companyName;

          // Si tenía título genérico "Convocatoria #...", enriquecerlo con el caché real
          if ((title.startsWith('Convocatoria #') || company == 'Cliente Contratante') &&
              convocatoriasDict.containsKey(p.projectId)) {
            final match = convocatoriasDict[p.projectId]!;
            final realTitle = match['title']?.toString();
            final realComp = (match['company'] ?? match['companyName'])?.toString();
            if (realTitle != null && realTitle.isNotEmpty) title = realTitle;
            if (realComp != null && realComp.isNotEmpty) company = realComp;
          }

          map[p.projectId] = SubmittedProposal(
            id: p.id,
            projectId: p.projectId,
            projectTitle: title,
            companyName: company,
            coverLetter: p.coverLetter,
            totalAmount: p.totalAmount,
            estimatedDays: p.estimatedDays,
            status: p.status,
            createdAt: p.createdAt,
            milestones: p.milestones,
          );
        }
      }
    }

    // 2. Cola offline pendiente
    if (Hive.isBoxOpen('offlineActionsBox')) {
      for (final a in OfflineQueueService().getPendingActions()) {
        if (a.type == 'postulacion') {
          final p = a.payload;
          final pId = p['projectId']?.toString() ?? a.id;
          map[pId] = SubmittedProposal(
            id: a.id,
            projectId: pId,
            projectTitle:
            p['projectTitle']?.toString() ?? 'Convocatoria #$pId',
            companyName:
            p['companyName']?.toString() ?? 'Cliente Contratante',
            coverLetter: p['coverLetter']?.toString() ?? '',
            totalAmount: ((p['totalPrice'] ?? p['totalAmount']) as num?)
                ?.toDouble() ??
                0.0,
            estimatedDays: (p['estimatedDays'] as num?)?.toInt() ?? 15,
            status: 'EN_COLA_OFFLINE',
            createdAt: a.createdAt,
            milestones: const [],
          );
        }
      }
    }

    // 3. Contratos adjudicados en backend (GET /api/v1/contracts)
    final token = await _storage.read(key: 'jwt_token');
    if (token != null && token.isNotEmpty) {
      for (final base in AuthService.getOrderedBaseUrls()) {
        try {
          final res = await _apiClient.dio.get(
            '$base/contracts',
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          if (res.statusCode == 200) {
            final list = res.data is Map && res.data['data'] is List
                ? res.data['data'] as List
                : (res.data is List ? res.data as List : []);
            for (final raw in list.whereType()) {
              final proj = raw['project'] is Map ? raw['project'] as Map : {};
              final cli = raw['client'] is Map ? raw['client'] as Map : {};
              final pId =
              (proj['id'] ?? raw['projectId'] ?? raw['id']).toString();
              final prev = map[pId];
              map[pId] = SubmittedProposal(
                id: raw['id']?.toString() ?? pId,
                projectId: pId,
                projectTitle: proj['title']?.toString() ??
                    prev?.projectTitle ??
                    'Proyecto Adjudicado',
                companyName:
                cli['name']?.toString() ?? prev?.companyName ?? 'Cliente',
                coverLetter:
                prev?.coverLetter ?? 'Propuesta adjudicada en contrato.',
                totalAmount: prev?.totalAmount ?? 0.0,
                estimatedDays: prev?.estimatedDays ?? 15,
                status: 'ADJUDICADA',
                createdAt: prev?.createdAt ?? DateTime.now(),
                milestones: prev?.milestones ?? const [],
              );
            }
            break;
          }
        } catch (_) {}
      }
    }

    return map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Obtiene las propuestas/candidatos de un proyecto (vista CLIENT).
  /// GET /api/v1/proposals/project/:projectId
  Future<List<JsonMap>> getProposalsForProject(String projectId) async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null || token.isEmpty) return [];

    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final res = await _apiClient.dio.get(
          '$base/proposals/project/$projectId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (res.statusCode == 200) {
          final raw = res.data;
          final list = raw is Map && raw['data'] is List
              ? raw['data'] as List
              : (raw is List ? raw : []);
          return list.whereType<Map>().map((e) => JsonMap.from(e)).toList();
        }
      } on DioException catch (e) {
        debugPrint('[ProposalService] getProposalsForProject error: ${e.message}');
        if (e.response != null) break; // Error HTTP → no reintentar
      } catch (e) {
        debugPrint('[ProposalService] getProposalsForProject unexpected: $e');
      }
    }
    return [];
  }
}