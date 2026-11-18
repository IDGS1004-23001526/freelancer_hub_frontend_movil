import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../models/convocatoria.dart';
import '../models/offline_action.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';

class ConvocatoriasResult {
  final List<Convocatoria> convocatorias;
  final bool isOffline;
  final String? message;

  const ConvocatoriasResult({
    required this.convocatorias,
    required this.isOffline,
    this.message,
  });
}

class ConvocatoriaService {
  static final ConvocatoriaService _instance = ConvocatoriaService._internal();
  factory ConvocatoriaService() => _instance;
  ConvocatoriaService._internal();

  final Box _box = Hive.box('convocatoriasBox');
  final ConnectivityService _connectivity = ConnectivityService();
  final OfflineQueueService _queue = OfflineQueueService();

  static const String _cacheKey = 'cached_convocatorias_list';

  // Convocatorias iniciales basadas en el diseño de Figma para garantizar
  // que jamás haya pantalla en blanco ni crash al abrir por primera vez sin internet
  final List<Convocatoria> _defaultConvocatorias = const [
    Convocatoria(
      id: 'conv-01',
      title: 'E-commerce móvil con pasarela de pagos',
      companyName: 'Nexo Commerce',
      companyInitial: 'N',
      postedTime: 'Hace 2 h · Convocatoria activa',
      budget: '\$2,400 USD',
      duration: '30 días',
      skills: ['Flutter', '.NET Core', 'SQL Server'],
      category: 'Desarrollo móvil · Remoto · Precio fijo',
      description:
          'Buscamos desarrollador senior para implementar flujo de compras completo, carrito y pasarela Stripe en Flutter con backend .NET.',
    ),
    Convocatoria(
      id: 'conv-02',
      title: 'Diseño UX/UI para una app de bienestar',
      companyName: 'Estudio Bruma',
      companyInitial: 'B',
      postedTime: 'Hace 4 h · Convocatoria activa',
      budget: '\$1,200 USD',
      duration: '15 días',
      skills: ['UI/UX', 'Figma', 'Design System'],
      category: 'Diseño de producto · Remoto · Hito',
      description:
          'Diseño de interfaces limpias, accesibles y prototipado interactivo para plataforma de salud mental y hábitos saludables.',
    ),
    Convocatoria(
      id: 'conv-03',
      title: 'Integración de microservicios y autenticación JWT',
      companyName: 'FinTech Nova',
      companyInitial: 'F',
      postedTime: 'Hace 1 d · Convocatoria activa',
      budget: '\$3,100 USD',
      duration: '45 días',
      skills: ['.NET Core', 'SQL Server', 'Docker'],
      category: 'Backend · Remoto · Tiempo completo',
      description:
          'Modernización de endpoints existentes, optimización de consultas SQL complejas y arquitectura de seguridad basada en tokens.',
    ),
    Convocatoria(
      id: 'conv-04',
      title: 'Desarrollo de aplicación multiplataforma con Flutter',
      companyName: 'CodeCrafters Lab',
      companyInitial: 'C',
      postedTime: 'Hace 1 d · Convocatoria activa',
      budget: '\$1,800 USD',
      duration: '20 días',
      skills: ['Flutter', 'Dart', 'Firebase'],
      category: 'Desarrollo móvil · Remoto · Precio fijo',
      description:
          'Construcción de módulos interactivos de catálogo, sistema de notificaciones push y persistencia local con Hive.',
    ),
  ];

  Future<void> initCacheIfNeeded() async {
    final cached = _box.get(_cacheKey);
    if (cached == null) {
      final initialData = _defaultConvocatorias.map((c) => c.toMap()).toList();
      await _box.put(_cacheKey, initialData);
    }
  }

  Future<ConvocatoriasResult> getConvocatorias({bool forceRefresh = false}) async {
    await initCacheIfNeeded();

    final isOnline = await _connectivity.checkConnection();

    // Si no hay conexión a internet, cargar directamente desde caché Hive
    if (!isOnline) {
      final cachedList = _getCachedList();
      return ConvocatoriasResult(
        convocatorias: cachedList,
        isOffline: true,
        message: 'Modo Offline: Mostrando convocatorias guardadas localmente.',
      );
    }

    // Si hay conexión, intentar consultar el backend
    try {
      final uri = Uri.parse(ApiConstants.convocatorias);
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> items = [];
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          items = decoded['data'];
        }

        final list = items.map((m) => Convocatoria.fromMap(m)).toList();
        if (list.isNotEmpty) {
          await _saveToCache(list);
          return ConvocatoriasResult(
            convocatorias: list,
            isOffline: false,
          );
        }
      }
    } catch (e) {
      debugPrint('No se pudo conectar al endpoint remoto, usando caché: $e');
    }

    // Si falló el backend pero hay conexión o timeout, usar la caché local sin romper la app
    final cachedList = _getCachedList();
    return ConvocatoriasResult(
      convocatorias: cachedList,
      isOffline: !isOnline,
      message: isOnline
          ? 'Servidor no disponible. Usando datos guardados en caché.'
          : 'Modo Offline activo.',
    );
  }

  List<Convocatoria> _getCachedList() {
    final raw = _box.get(_cacheKey);
    if (raw is List && raw.isNotEmpty) {
      return raw.map((item) {
        if (item is Map) {
          return Convocatoria.fromMap(item);
        }
        return Convocatoria.fromMap({});
      }).toList();
    }
    return _defaultConvocatorias;
  }

  Future<void> _saveToCache(List<Convocatoria> list) async {
    final mapped = list.map((c) => c.toMap()).toList();
    await _box.put(_cacheKey, mapped);
  }

  Future<bool> postularAConvocatoria({
    required String convocatoriaId,
    required String propuestaMonto,
    required String mensaje,
  }) async {
    final isOnline = await _connectivity.checkConnection();

    final action = OfflineAction(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      type: 'postulacion',
      convocatoriaId: convocatoriaId,
      payload: {
        'convocatoriaId': convocatoriaId,
        'monto': propuestaMonto,
        'mensaje': mensaje,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
    );

    // Actualizar estado local en la lista en caché para reflejar que ya postuló
    final currentList = _getCachedList();
    final updatedList = currentList.map((c) {
      if (c.id == convocatoriaId) {
        return c.copyWith(isApplied: true);
      }
      return c;
    }).toList();
    await _saveToCache(updatedList);

    if (!isOnline) {
      // Encolar acción para cuando regrese la conexión
      await _queue.enqueueAction(action);
      return false; // Indica que se guardó offline
    } else {
      // Enviar directamente
      try {
        final uri = Uri.parse(ApiConstants.postulaciones);
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: action.toJson(),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        debugPrint('Fallo al enviar online, encolando en offline actions: $e');
      }
      // Si la llamada falló por error de red en el servidor, encolamos también
      await _queue.enqueueAction(action);
      return false;
    }
  }
}
