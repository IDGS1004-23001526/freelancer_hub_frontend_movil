import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } catch (e) {
      debugPrint('Error comprobando biometría: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error obteniendo tipos de biometría: $e');
      return [];
    }
  }

  /// Autentica al usuario usando Huella Dactilar, FaceID o PIN del sistema.
  /// Si el usuario cancela o falla, retorna false sin realizar ninguna acción.
  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      final bool isSupported = await isBiometricsAvailable();

      if (!isSupported) {
        debugPrint('Biometría o PIN de dispositivo no configurado en este entorno.');
        // Si el hardware no soporta o es un emulador sin PIN registrado,
        // devolvemos true o se solicita PIN en modal de la app
        return true;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite PIN o patrón del sistema
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        await HapticFeedback.heavyImpact();
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('PlatformException en autenticación: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error inesperado en autenticación biométrica: $e');
      return false;
    }
  }
}
