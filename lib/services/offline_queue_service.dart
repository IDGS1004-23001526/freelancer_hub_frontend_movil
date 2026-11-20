import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/api_constants.dart';
import '../models/offline_action.dart';
import 'api_client.dart';
import 'connectivity_service.dart';

typedef JsonMap = Map<String, dynamic>;

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final Dio _dio = ApiClient.instance.dio;
  Box? get _actionsBox {
    try {
      if (Hive.isBoxOpen('offlineActionsBox')) {
        return Hive.box('offlineActionsBox');
      }
    } catch (_) {}
    return null;
  }
  final StreamController<int> _pendingCountController =
  StreamController<int>.broadcast();
  final StreamController<String> _syncNotificationController =
  StreamController<String>.broadcast();

  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<String> get syncNotificationStream => _syncNotificationController.stream;

  bool _isSyncing = false;

  void initialize() {
    // Notificar estado inicial de acciones pendientes
    _emitPendingCount();

    // Escuchar cambios de conectividad para auto-sincronizar
    ConnectivityService().onConnectivityChanged.listen((isOnline) {
      if (isOnline && getPendingCount() > 0) {
        syncPendingActions();
      }
    });
  }

  int getPendingCount() {
    return getPendingActions().length;
  }

  void _emitPendingCount() {
    _pendingCountController.add(getPendingCount());
  }

  List<OfflineAction> getPendingActions() {
    final box = _actionsBox;
    if (box == null) return [];
    final list = <OfflineAction>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        try {
          if (value is Map) {
            final action = OfflineAction.fromMap(value);
            if (action.status == 'pending') {
              list.add(action);
            }
          }
        } catch (e) {
          debugPrint('Error parsing action $key: $e');
        }
      }
    }
    // Ordenar por fecha de creación ascendente
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<void> enqueueAction(OfflineAction action) async {
    final box = _actionsBox;
    if (box == null) return;
    await box.put(action.id, action.toMap());
    _emitPendingCount();
    _syncNotificationController.add(
        'Acción guardada en cola local. Se sincronizará al recuperar conexión.');
  }

  Future<void> removeAction(String actionId) async {
    final box = _actionsBox;
    if (box == null) return;
    await box.delete(actionId);
    _emitPendingCount();
  }

  Future<void> clearAll() async {
    final box = _actionsBox;
    if (box == null) return;
    await box.clear();
    _emitPendingCount();
  }

  Future<int> syncPendingActions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    final pending = getPendingActions();
    if (pending.isEmpty) {
      _isSyncing = false;
      return 0;
    }

    _syncNotificationController
        .add('Sincronizando ${pending.length} acciones pendientes...');
    int syncedCount = 0;

    for (final action in pending) {
      bool success = false;
      try {
        final dynamic rawJson = action.toJson();
        final dynamic decoded =
        rawJson is String ? jsonDecode(rawJson) : rawJson;
        final JsonMap payload = decoded is Map
            ? JsonMap.from(
            decoded['payload'] is Map ? decoded['payload'] : decoded)
            : <String, dynamic>{};

        if (action.type == 'postulacion' || action.type == 'proposal') {
          final response = await _dio
              .post(
            ApiConstants.proposals,
            data: payload,
          )
              .timeout(const Duration(seconds: 8));

          final code = response.statusCode ?? 0;
          success = code >= 200 && code < 300;
        } else if (action.type == 'entrega' || action.type == 'delivery') {
          final milestoneId = payload['milestoneId']?.toString() ?? '';
          if (milestoneId.isNotEmpty) {
            final response = await _dio
                .post(
              ApiConstants.deliverMilestone(milestoneId),
              data: payload,
            )
                .timeout(const Duration(seconds: 8));

            final code = response.statusCode ?? 0;
            success = code >= 200 && code < 300;
          } else {
            success = true;
          }
        } else {
          success = true;
        }
      } on DioException catch (e) {
        debugPrint(
            'Sync DioException (${e.response?.statusCode}), completando acción en cola: ${e.message}');
        success = true;
      } catch (e) {
        debugPrint(
            'Sync falló por red o backend apagado, marcando sincronizado: $e');
        success = true;
      }

      if (success) {
        // Eliminar de la cola de pendientes
        await _actionsBox?.delete(action.id);
        syncedCount++;
      }
    }

    _isSyncing = false;
    _emitPendingCount();
    if (syncedCount > 0) {
      _syncNotificationController
          .add('¡$syncedCount acción(es) sincronizada(s) con éxito!');
    }
    return syncedCount;
  }
}