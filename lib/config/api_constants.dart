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
  static const String googleAuth = '/auth/google';
  static const String refreshToken = '$baseUrl/auth/refresh-token';
  static const String logout = '$baseUrl/auth/logout';
  static const String me = '$baseUrl/auth/me';

  // Google OAuth Client ID para autenticación federada en móvil (freelancer-92fe8)
  static const String googleServerClientId =
      '417210536628-0r94li2h8u466hl7jrk3fc17jvn35mi7.apps.googleusercontent.com';

  // Perfil y Skills (src/routes/profile.routes.ts, skills.routes.ts)
  static const String profile = '/users/me/profile';
  static const String legacyProfile = '/profile';
  static const String uploadAvatar = '/users/me/avatar';
  static const String updateAvatar = '/users/me/avatar';
  static const String userSkills = '/users/me/skills';
  static String deleteUserSkill(String identifier) =>
      '/users/me/skills/${Uri.encodeComponent(identifier)}';

  // Endpoints de convocatorias
  static const String projects = '/projects';
  static String projectById(String id) => '/projects/$id';

  // Postulaciones (src/presentation/routes/proposal.routes.ts)
  static const String proposals = '/proposals';

  // Contratos, Hitos y Entregas (src/presentation/routes/contract.routes.ts)
  static const String contracts = '/contracts';
  static String fundContract(String contractId) => '/contracts/$contractId/fund';
  static String deliverMilestone(String milestoneId) => '/milestones/$milestoneId/deliver';
  static String approveMilestone(String milestoneId) => '/milestones/$milestoneId/approve';

  // Billetera (src/presentation/routes/wallet.routes.ts)
  static const String wallet = '/wallet';
  static const String withdrawWallet = '/wallet/withdraw';

  // Obtiene la URL del servidor WebSocket/Socket.io eliminando el prefijo de API REST
  static String getSocketUrl([String? explicitBaseUrl]) {
    final base = explicitBaseUrl ?? baseUrl;
    return base.replaceAll('/api/v1', '');
  }
}
