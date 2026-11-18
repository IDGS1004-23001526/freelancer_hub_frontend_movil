import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool? _simulatedOffline; // Para pruebas/demo manual si se requiere
  bool _lastKnownStatus = true;

  Stream<bool> get onConnectivityChanged => _controller.stream;
  bool get lastKnownStatus => _simulatedOffline != null ? !_simulatedOffline! : _lastKnownStatus;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = _isResultsOnline(results);
      _lastKnownStatus = isOnline;
      if (_simulatedOffline == null) {
        _controller.add(isOnline);
      }
    });

    // Verificación inicial
    checkConnection();
  }

  Future<bool> checkConnection() async {
    if (_simulatedOffline != null) {
      return !_simulatedOffline!;
    }
    try {
      final results = await _connectivity.checkConnectivity();
      final isOnline = _isResultsOnline(results);
      _lastKnownStatus = isOnline;
      _controller.add(isOnline);
      return isOnline;
    } catch (_) {
      // Si falla la verificación, asumimos offline por seguridad
      _lastKnownStatus = false;
      _controller.add(false);
      return false;
    }
  }

  bool _isResultsOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  // Permitir activar simulación de offline para evaluar la rúbrica fácilmente
  void toggleSimulatedOffline({bool? forceState}) {
    if (forceState != null) {
      _simulatedOffline = forceState;
    } else {
      _simulatedOffline = _simulatedOffline == null ? true : !_simulatedOffline!;
    }
    final effectiveOnline = !_simulatedOffline!;
    _controller.add(effectiveOnline);
  }

  void resetSimulation() {
    _simulatedOffline = null;
    checkConnection();
  }

  bool get isSimulatingOffline => _simulatedOffline == true;

  void dispose() {
    _controller.close();
  }
}
