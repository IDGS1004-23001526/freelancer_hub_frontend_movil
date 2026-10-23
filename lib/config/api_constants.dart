class ApiConstants {
  // Ajusta el puerto y protocolo según la configuración de freelancer_hub_backend
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  // Endpoints de autenticación
  static const String login = '$baseUrl/auth/login';
  static const String register = '$baseUrl/auth/register';

  // Endpoints de usuario / perfil
  static const String profile = '$baseUrl/users/profile';
  static const String updateAvatar = '$baseUrl/users/avatar';
}
