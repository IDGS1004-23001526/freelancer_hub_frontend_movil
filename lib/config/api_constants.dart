class ApiConstants {
  // Base URL en red local (LAN Wi-Fi) para dispositivos físicos
  static const String lanBaseUrl = 'http://192.168.1.146:4000/api/v1';

  // Base URL para emulador Android (10.0.2.2 apunta al localhost de la máquina host)
  static const String emulatorBaseUrl = 'http://10.0.2.2:4000/api/v1';

  // URL alternativa para dispositivos con adb reverse / entorno local / Web / Desktop
  static const String localBaseUrl = 'http://localhost:4000/api/v1';

  // Base URL principal por defecto
  static const String baseUrl = lanBaseUrl;

  // Lista ordenada de URLs base candidatas para fallback automático
  static const List<String> candidateBaseUrls = [
    emulatorBaseUrl,
    lanBaseUrl,
    localBaseUrl,
  ];

  // Endpoints de autenticación (API v1)
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';
  static const String refreshToken = '$baseUrl/auth/refresh-token';
  static const String logout = '$baseUrl/auth/logout';
  static const String me = '$baseUrl/auth/me';

  // Endpoints de emulador Android
  static const String emulatorLogin = '$emulatorBaseUrl/auth/login';
  static const String emulatorRegister = '$emulatorBaseUrl/auth/register';
  static const String emulatorMe = '$emulatorBaseUrl/auth/me';

  // Endpoints locales de respaldo
  static const String localLogin = '$localBaseUrl/auth/login';
  static const String localRegister = '$localBaseUrl/auth/register';
  static const String localMe = '$localBaseUrl/auth/me';

  // Endpoints de usuario / perfil
  static const String profile = '$baseUrl/auth/me';
  static const String updateAvatar = '$baseUrl/users/avatar';
}
