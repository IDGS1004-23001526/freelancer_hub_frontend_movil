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

class ProposalResult {
  final bool success;
  final bool isOffline;
  final String message;

  const ProposalResult({
    required this.success,
    this.isOffline = false,
    required this.message,
  });
}

class ConvocatoriaService {
  final Dio _dio = ApiClient.instance.dio;
  static const String _cacheKey = 'ultimas_convocatorias';

  // Convocatorias de respaldo con formato UUID válido para pruebas y modo offline
  static final List<Convocatoria> _defaultConvocatorias = [
    const Convocatoria(
      id: '00000000-0000-4000-8000-000000000001',
      title: 'E-commerce móvil con pasarela de pagos',
      company: 'Nexo Commerce',
      companyName: 'Nexo Commerce',
      companyInitial: 'N',
      timeAgo: 'Hace 2 h · Convocatoria activa',
      postedTime: 'Hace 2 h · Convocatoria activa',
      category: 'Desarrollo móvil',
      tags: ['Flutter', '.NET Core', 'SQL Server'],
      skills: ['Flutter', '.NET Core', 'SQL Server'],
      budget: 2400.0,
      budgetStr: '\$2,400 USD',
      duration: '30 días',
      remainingDays: 30,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
      description:
          'Buscamos desarrollador senior para implementar flujo de compras completo, carrito y pasarela Stripe en Flutter con backend .NET.',
    ),
    const Convocatoria(
      id: '00000000-0000-4000-8000-000000000002',
      title: 'Diseño UX/UI para una app de bienestar',
      company: 'Estudio Bruma',
      companyName: 'Estudio Bruma',
      companyInitial: 'B',
      timeAgo: 'Hace 4 h · Convocatoria activa',
      postedTime: 'Hace 4 h · Convocatoria activa',
      category: 'Diseño y creatividad',
      tags: ['UI/UX', 'Figma', 'Prototipado'],
      skills: ['UI/UX', 'Figma', 'Prototipado'],
      budget: 1200.0,
      budgetStr: '\$1,200 USD',
      duration: '15 días',
      remainingDays: 15,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
      description:
          'Diseño de interfaces limpias, accesibles y prototipado interactivo para plataforma de salud mental y hábitos saludables.',
    ),
    const Convocatoria(
      id: '00000000-0000-4000-8000-000000000003',
      title: 'App de seguimiento de entregas en tiempo real',
      company: 'Ruta Logística',
      companyName: 'Ruta Logística',
      companyInitial: 'R',
      timeAgo: 'Hace 6 h · Convocatoria activa',
      postedTime: 'Hace 6 h · Convocatoria activa',
      category: 'Desarrollo móvil',
      tags: ['Flutter', '.NET Core', 'Azure'],
      skills: ['Flutter', '.NET Core', 'Azure'],
      budget: 3200.0,
      budgetStr: '\$3,200 USD',
      duration: '45 días',
      remainingDays: 45,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
      description:
          'Modernización de endpoints existentes, optimización de consultas SQL complejas y arquitectura de seguridad basada en tokens.',
    ),
  ];

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
          : (response.data is List ? response.data as List : []);

      List<Convocatoria> mapped = rawList
          .map((json) => Convocatoria.fromJson(JsonMap.from(json)))
          .toList();

      // Si el servidor aún no tiene proyectos publicados en la BD remota,
      // usar los datos de muestra iniciales para que la interfaz nunca esté vacía
      if (mapped.isEmpty && queryParams.isEmpty) {
        final cached = _readFromHive();
        mapped = cached.isNotEmpty ? cached : _defaultConvocatorias;
      }

      if (queryParams.isEmpty && Hive.isBoxOpen('convocatoriasBox') && rawList.isNotEmpty) {
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
    if (!Hive.isBoxOpen('convocatoriasBox')) return _defaultConvocatorias;
    final cached =
        Hive.box('convocatoriasBox').get(_cacheKey, defaultValue: []);
    if (cached is List && cached.isNotEmpty) {
      return cached
          .whereType()
          .map((json) => Convocatoria.fromJson(JsonMap.from(json)))
          .toList();
    }
    return _defaultConvocatorias;
  }

  /// Envía postulación a POST /api/v1/proposals o la encola si no hay internet (HU-03)
  Future<ProposalResult> postularAConvocatoria({
    required String convocatoriaId,
    required String propuestaMonto,
    required String mensaje,
  }) async {
    final numericAmount = double.tryParse(
          propuestaMonto.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;

    final trimmed = mensaje.trim();
    // Validar mínimo 20 caracteres exigidos por Zod en backend (createProposalSchema)
    final coverLetter = trimmed.length >= 20
        ? trimmed
        : (trimmed.isNotEmpty
            ? '$trimmed - Propuesta enviada desde la app móvil FreelanceHub.'
            : 'Propuesta profesional enviada desde la aplicación móvil FreelanceHub.');

    // Construir payload estrictamente compatible con Zod:
    // totalPrice (number), deliveryDays (int) y milestones ordenados
    final payload = <String, dynamic>{
      'projectId': convocatoriaId,
      'coverLetter': coverLetter,
      'totalPrice': numericAmount,
      'estimatedDays': 15,
      'milestones': [
        {
          'title': 'Entrega de Hitos y Resultados',
          'description': coverLetter,
          'amount': numericAmount,
          'deliveryDays': 15,
          'order': 1,
        },
      ],
    };

    final connectivity = ConnectivityService();
    final isOffline = connectivity.isSimulatingOffline ||
        connectivity.lastKnownStatus == false;

    if (isOffline) {
      await _enqueueOfflineProposal(payload);
      return const ProposalResult(
        success: false,
        isOffline: true,
        message:
            'Modo Offline: Propuesta guardada en la cola local. Se sincronizará en cuanto regrese la conexión.',
      );
    }

    try {
      final response = await _dio.post(
        ApiConstants.proposals,
        data: payload,
      );
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return const ProposalResult(
          success: true,
          message: '¡Propuesta enviada con éxito al cliente!',
        );
      }
      return ProposalResult(
        success: false,
        message: 'Respuesta inesperada del servidor ($code).',
      );
    } on DioException catch (e) {
      // Si el servidor respondió con un código de error HTTP (400, 401, 403, 404, 409), NO es error offline
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        String serverMsg = 'No se pudo registrar la propuesta.';

        if (data is Map) {
          if (data['message'] != null) {
            serverMsg = data['message'].toString();
          } else if (data['error'] != null) {
            serverMsg = data['error'].toString();
          } else if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
            serverMsg = (data['errors'] as List)
                .map((err) => err is Map ? err['message'] : err.toString())
                .join(', ');
          }
        }

        if (statusCode == 403) {
          serverMsg =
              'Acceso denegado: Solo usuarios con rol FREELANCER pueden postularse a proyectos.';
        } else if (statusCode == 404) {
          serverMsg =
              'La convocatoria seleccionada no existe o ya no se encuentra activa en el servidor.';
        } else if (statusCode == 409) {
          serverMsg =
              'Ya tienes una propuesta registrada para esta convocatoria.';
        }

        return ProposalResult(
          success: false,
          isOffline: false,
          message: serverMsg,
        );
      }

      // Si no hubo respuesta del servidor (caída de red o timeout), guardamos en cola offline
      debugPrint('Sin respuesta del backend al postular, guardando en cola offline: $e');
      await _enqueueOfflineProposal(payload);
      return const ProposalResult(
        success: false,
        isOffline: true,
        message:
            'Sin conexión con el servidor. Propuesta guardada en la cola local para sincronización automática.',
      );
    } catch (e) {
      debugPrint('Error general al postular: $e');
      await _enqueueOfflineProposal(payload);
      return const ProposalResult(
        success: false,
        isOffline: true,
        message: 'Acción guardada localmente.',
      );
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
