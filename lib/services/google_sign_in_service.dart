import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_constants.dart';

/// Servicio encargado de la comunicación con el SDK nativo de Google Sign-In.
class GoogleSignInService {
  static GoogleSignInService _instance = GoogleSignInService._internal();
  static GoogleSignInService get instance => _instance;

  GoogleSignInService._internal();

  /// Permite inyectar una instancia simulada para pruebas unitarias y de widgets.
  @visibleForTesting
  static set testInstance(GoogleSignInService service) {
    _instance = service;
  }

  bool _initialized = false;

  /// Inicializa la configuración de Google Sign-In con el Client ID de servidor.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: ApiConstants.googleServerClientId,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[GoogleSignInService] Nota sobre inicialización: $e');
      _initialized = true;
    }
  }

  /// Inicia el flujo interactivo de Google Sign-In y obtiene el `idToken` para el backend.
  /// Retorna `null` si el usuario canceló deliberadamente el diálogo.
  Future<String?> getIdToken() async {
    await ensureInitialized();

    try {
      // Limpia cualquier sesión previa en caché local para garantizar la selección de cuenta
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();
      final String? idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'No se pudo obtener el idToken de Google. Asegúrate de que las credenciales OAuth estén registradas.',
        );
      }

      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[GoogleSignInService] Inicio de sesión cancelado por el usuario.');
        return null;
      }
      debugPrint('[GoogleSignInService] Excepción de Google Sign In: ${e.code} - ${e.description}');
      rethrow;
    } catch (e) {
      debugPrint('[GoogleSignInService] Error general en Google Sign-In: $e');
      rethrow;
    }
  }

  /// Cierra la sesión de Google en el dispositivo.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
