class ApiConstants {
  // IP real de tu tarjeta Wi-Fi actual (usada para dispositivos físicos en la misma red)
  static const String wifiBaseUrl = 'http://192.168.100.9:4000/api/v1';

  // IP secundaria / Ethernet
  static const String ethernetBaseUrl = 'http://10.174.71.174:4000/api/v1';

  // IP del adaptador virtual / Ethernet (VirtualBox / Host-Only)
  static const String virtualBaseUrl = 'http://192.168.56.1:4000/api/v1';

  // Base URL para emulador Android de Android Studio (10.0.2.2 apunta al localhost del PC)
  static const String emulatorBaseUrl = 'http://10.0.2.2:4000/api/v1';

  // URL para dispositivos con adb reverse / navegador web / escritorio
  static const String localBaseUrl = 'http://127.0.0.1:4000/api/v1';

  // URL principal activa
  static const String baseUrl = wifiBaseUrl;

  // Lista ordenada de URLs base candidatas para fallback automático:
  static const List<String> candidateBaseUrls = [
    wifiBaseUrl,
    ethernetBaseUrl,
    virtualBaseUrl,
    emulatorBaseUrl,
    localBaseUrl,
  ];

  // Endpoints de autenticación (API v1)
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String refreshToken = '$baseUrl/auth/refresh-token';
  static const String logout = '$baseUrl/auth/logout';
  static const String me = '$baseUrl/auth/me';

  // Endpoints de usuario / perfil
  static const String profile = '$baseUrl/users/me/profile';
  static const String updateAvatar = '$baseUrl/users/me/avatar';

  // Obtiene la URL del servidor WebSocket/Socket.io eliminando el prefijo de API REST
  static String getSocketUrl([String? explicitBaseUrl]) {
    final base = explicitBaseUrl ?? baseUrl;
    return base.replaceAll('/api/v1', '');
  }
}
