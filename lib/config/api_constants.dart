class ApiConstants {
  // URL de Cloudflare (Producción / Remoto - No requiere túneles ni backend local encendido)
  static const String cloudBaseUrl = 'https://api.freelancerhub.org/api/v1';

  // Base URL para emulador Android de Android Studio (10.0.2.2 apunta al localhost del PC)
  static const String emulatorBaseUrl = 'http://10.0.2.2:4000/api/v1';

  // URL para dispositivos con adb reverse / navegador web / escritorio
  static const String localBaseUrl = 'http://127.0.0.1:4000/api/v1';

  // IP real de tu tarjeta Wi-Fi actual (usada para dispositivos físicos en la misma red)
  static const String wifiBaseUrl = 'http://192.168.100.9:4000/api/v1';
  static const String wifiHotspotBaseUrl = 'http://192.168.137.50:4000/api/v1';

  // IP secundaria / Ethernet
  static const String ethernetBaseUrl = 'http://10.174.71.174:4000/api/v1';

  // IP del adaptador virtual / Ethernet (VirtualBox / Host-Only)
  static const String virtualBaseUrl = 'http://192.168.56.1:4000/api/v1';

  // URL principal activa (Apuntando a Cloudflare)
  static const String baseUrl = cloudBaseUrl;

  // Lista ordenada de URLs base candidatas para fallback automático:
  static const List<String> candidateBaseUrls = [
    cloudBaseUrl,
    wifiBaseUrl,
    emulatorBaseUrl,
    localBaseUrl,
    wifiHotspotBaseUrl,
    ethernetBaseUrl,
    virtualBaseUrl,
  ];

  // Endpoints de autenticación (API v1)
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String googleAuth = '$baseUrl/auth/google';
  static const String refreshToken = '$baseUrl/auth/refresh-token';
  static const String logout = '$baseUrl/auth/logout';
  static const String me = '$baseUrl/auth/me';

  // Google OAuth Client ID para autenticación federada en móvil (freelancer-92fe8)
  static const String googleServerClientId =
      '417210536628-0r94li2h8u466hl7jrk3fc17jvn35mi7.apps.googleusercontent.com';

  // Endpoints de usuario / perfil
  static const String profile = '$baseUrl/users/me/profile';
  static const String updateAvatar = '$baseUrl/users/me/avatar';

  // Endpoints de convocatorias
  static const String convocatorias = '$emulatorBaseUrl/convocatorias';
  static const String postulaciones = '$emulatorBaseUrl/postulaciones';

  // Endpoints HU-06: Entrega de hitos
  static String milestoneDeliveries(String milestoneId) =>
      '$emulatorBaseUrl/milestones/$milestoneId/deliveries';

  // Endpoints HU-07: Aprobación de hitos
  static String milestoneDetail(String milestoneId) =>
      '$emulatorBaseUrl/milestones/$milestoneId';
  static String approveMilestone(String milestoneId) =>
      '$emulatorBaseUrl/milestones/$milestoneId/approve';
  static String requestCorrections(String milestoneId) =>
      '$emulatorBaseUrl/milestones/$milestoneId/adjustments';

  // Endpoints HU-14: Billetera
  static const String wallet = '$emulatorBaseUrl/wallet';
  static const String walletWithdraw = '$emulatorBaseUrl/wallet/withdraw';

  // Obtiene la URL del servidor WebSocket/Socket.io eliminando el prefijo de API REST
  static String getSocketUrl([String? explicitBaseUrl]) {
    final base = explicitBaseUrl ?? baseUrl;
    return base.replaceAll('/api/v1', '');
  }
}
