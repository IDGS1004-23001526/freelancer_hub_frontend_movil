import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/api_constants.dart';
import '../models/convocatoria.dart';
import '../models/offline_action.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';

typedef JsonMap = Map<String, dynamic>;

class ConvocatoriaResult {
  final List<Convocatoria> convocatorias;
  final bool isOffline;

  const ConvocatoriaResult({
    required this.convocatorias,
    this.isOffline = false,
  });
}

class ConvocatoriaService {
  final Dio _dio = ApiClient.instance.dio;
  static const String _cacheKey = 'ultimas_convocatorias';

  /// Consulta GET /api/v1/projects con respaldo automático en Hive para Modo Offline
  Future<ConvocatoriaResult> getConvocatorias({
    String? search,
    String? category,
    List<String>? skills,
    double? minBudget,
    double? maxBudget,
  }) async {
    final connectivity = ConnectivityService();
    final forceOffline = connectivity.isSimulatingOffline ||
        connectivity.lastKnownStatus == false;

    if (forceOffline) {
      return ConvocatoriaResult(
        convocatorias: _readFromHive(),
        isOffline: true,
      );
    }

    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (skills != null && skills.isNotEmpty) 'skills': skills.join(','),
      if (minBudget != null) 'minBudget': minBudget,
      if (maxBudget != null) 'maxBudget': maxBudget,
    };

    try {
      final response = await _dio.get(
        ApiConstants.projects,
        queryParameters: queryParams,
      );

      final rawList = response.data is Map && response.data['data'] != null
          ? response.data['data'] as List
          : response.data as List;

      final mapped = rawList
          .map((json) => Convocatoria.fromJson(JsonMap.from(json)))
          .toList();

      if (queryParams.isEmpty && Hive.isBoxOpen('convocatoriasBox')) {
        await Hive.box('convocatoriasBox').put(
          _cacheKey,
          rawList.map((e) => JsonMap.from(e)).toList(),
        );
      }

      return ConvocatoriaResult(
        convocatorias: mapped,
        isOffline: false,
      );
    } catch (e) {
      debugPrint('ConvocatoriaService cargando caché local: $e');
      return ConvocatoriaResult(
        convocatorias: _readFromHive(),
        isOffline: true,
      );
    }
  }

  List<Convocatoria> _readFromHive() {
    if (!Hive.isBoxOpen('convocatoriasBox')) return [];
    final cached =
    Hive.box('convocatoriasBox').get(_cacheKey, defaultValue: []);
    if (cached is List) {
      return cached
          .whereType()
          .map((json) => Convocatoria.fromJson(JsonMap.from(json)))
          .toList();
    }
    return [];
  }

  /// Envía postulación a POST /api/v1/proposals o la encola si no hay internet (HU-03)
  Future<bool> postularAConvocatoria({
    required String convocatoriaId,
    required String propuestaMonto,
    required String mensaje,
  }) async {
    final numericAmount = double.tryParse(
      propuestaMonto.replaceAll(RegExp(r'[^0-9.]'), ''),
    ) ??
        0.0;

    final payload = <String, dynamic>{
      'projectId': convocatoriaId,
      'coverLetter': mensaje.trim().isNotEmpty
          ? mensaje.trim()
          : 'Propuesta enviada desde aplicación móvil',
      'totalAmount': numericAmount,
      'estimatedDays': 15,
      'milestones': [
        {
          'title': 'Entrega del Proyecto',
          'description': mensaje.trim().isNotEmpty
              ? mensaje.trim()
              : 'Entregable completo del proyecto',
          'amount': numericAmount,
        },
      ],
    };

    final connectivity = ConnectivityService();
    final isOffline = connectivity.isSimulatingOffline ||
        connectivity.lastKnownStatus == false;

    if (isOffline) {
      await _enqueueOfflineProposal(payload);
      return false;
    }

    try {
      final response = await _dio.post(
        ApiConstants.proposals,
        data: payload,
      );
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (e) {
      debugPrint('Sin conexión al postular, guardando en cola offline: $e');
      await _enqueueOfflineProposal(payload);
      return false;
    }
  }

  Future<void> _enqueueOfflineProposal(JsonMap payload) async {
    if (!Hive.isBoxOpen('offlineActionsBox')) return;
    final action = OfflineAction.fromMap({
      'id': 'prop-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'postulacion',
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'payload': payload,
    });
    await OfflineQueueService().enqueueAction(action);
  }
}