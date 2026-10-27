import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../models/user_profile.dart';

/// Resultado detallado de una operación de autenticación (Login / Registro).
class AuthResult {
  final bool success;
  final String? message;
  final UserProfile? user;
  final String? token;

  const AuthResult({
    required this.success,
    this.message,
    this.user,
    this.token,
  });
}

class AuthService {
  final FlutterSecureStorage _storage;
  final http.Client _httpClient;

  /// Recuerda en memoria la última URL base que respondió con éxito para evitar timeouts repetidos.
  static String? activeBaseUrl;

  AuthService({
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client();

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> saveUserProfile(UserProfile user) async {
    await _storage.write(
      key: 'user_profile',
      value: jsonEncode({
        'id': user.id,
        'fullName': user.fullName,
        'name': user.fullName,
        'email': user.email,
        'role': user.role,
        'location': user.location,
        'bio': user.bio,
        'avatarUrl': user.avatarUrl,
        'skills': user.skills,
      }),
    );
  }

  Future<UserProfile?> getCachedUserProfile() async {
    final raw = await _storage.read(key: 'user_profile');
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _postToEndpoint(
          endpointPath: '/auth/logout',
          body: {'refreshToken': refreshToken},
        );
      } catch (_) {
        // Ignorar errores de red al cerrar sesión localmente
      }
    }
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_profile');
  }

  /// Obtiene la lista de URLs base priorizando la última que funcionó.
  static List<String> getOrderedBaseUrls() {
    final urls = <String>[
      if (activeBaseUrl != null) activeBaseUrl!,
      ...ApiConstants.candidateBaseUrls,
    ];
    return urls.toSet().toList();
  }

  /// Realiza una petición POST probando las URLs base candidatas (emulador 10.0.2.2, LAN y localhost).
  Future<http.Response> _postToEndpoint({
    required String endpointPath,
    required Map<String, dynamic> body,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    final encodedBody = jsonEncode(body);
    final baseUrls = getOrderedBaseUrls();

    Object? lastError;
    for (final base in baseUrls) {
      final url = '$base$endpointPath';
      try {
        final response = await _httpClient
            .post(Uri.parse(url), headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 4));
        activeBaseUrl = base;
        return response;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No se pudo conectar con ningún endpoint.');
  }

  /// Extrae el mensaje de error más descriptivo devuelto por el backend.
  String _extractErrorMessage(
    Map<String, dynamic> decoded,
    String defaultMessage,
  ) {
    final detalles = decoded['detalles'];
    if (detalles is List && detalles.isNotEmpty) {
      final first = detalles.first;
      if (first is Map && first['mensaje'] != null) {
        return first['mensaje'].toString();
      }
    }
    return decoded['message']?.toString() ?? defaultMessage;
  }

  /// Autentica al usuario y retorna un [AuthResult] con el perfil y token.
  Future<AuthResult> loginWithResult(String email, String password) async {
    try {
      final response = await _postToEndpoint(
        endpointPath: '/auth/login',
        body: {
          'email': email.trim(),
          'password': password,
        },
      );

      final Map<String, dynamic> decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        final token =
            payload['accessToken'] ?? payload['token'] ?? payload['jwt'];
        final refreshToken = payload['refreshToken'];

        if (token != null) {
          await saveToken(token.toString());
        }
        if (refreshToken != null) {
          await _storage.write(
              key: 'refresh_token', value: refreshToken.toString());
        }

        final userMap = payload['user'] is Map<String, dynamic>
            ? payload['user'] as Map<String, dynamic>
            : payload;
        final rawProfile = UserProfile.fromJson(userMap);
        final cached = await getCachedUserProfile();

        final userProfile = rawProfile.copyWith(
          role: _formatRoleLabel(rawProfile.role),
          location: rawProfile.location.isNotEmpty
              ? rawProfile.location
              : (cached?.location.isNotEmpty == true
                  ? cached!.location
                  : 'Ciudad de México, MX'),
          bio: rawProfile.bio.isNotEmpty
              ? rawProfile.bio
              : (cached?.bio.isNotEmpty == true
                  ? cached!.bio
                  : 'Especialista verificado en Freelancer Hub.'),
          skills: rawProfile.skills.isNotEmpty
              ? rawProfile.skills
              : (cached?.skills.isNotEmpty == true
                  ? cached!.skills
                  : const ['Flutter', 'Dart', 'UI/UX']),
        );

        await saveUserProfile(userProfile);

        return AuthResult(
          success: true,
          user: userProfile,
          token: token?.toString(),
          message: 'Sesión iniciada correctamente',
        );
      }

      final errorMsg = _extractErrorMessage(
        decoded,
        'Credenciales incorrectas o error en el servidor.',
      );
      return AuthResult(success: false, message: errorMsg);
    } catch (e) {
      return const AuthResult(
        success: false,
        message: 'No se pudo conectar con el servidor de autenticación.',
      );
    }
  }

  /// Registra un nuevo usuario en el backend y autentica su sesión.
  /// Envía `fullName` según el esquema estricto de validación del servidor (`registerSchema`).
  Future<AuthResult> registerWithResult({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final normalizedRole = role.trim().toUpperCase();
      final response = await _postToEndpoint(
        endpointPath: '/auth/register',
        body: {
          'fullName': name.trim(),
          'email': email.trim(),
          'password': password,
          'role': normalizedRole,
        },
      );

      final Map<String, dynamic> decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = decoded['data'] is Map<String, dynamic>
            ? decoded['data'] as Map<String, dynamic>
            : decoded;

        String? token = (payload['accessToken'] ??
                payload['token'] ??
                payload['jwt'])
            ?.toString();
        final refreshToken = payload['refreshToken']?.toString();

        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }

        final userMap = payload['user'] is Map<String, dynamic>
            ? payload['user'] as Map<String, dynamic>
            : payload;

        UserProfile userProfile = UserProfile(
          id: userMap['id']?.toString() ?? '',
          fullName: (userMap['fullName'] ?? userMap['name'])?.toString() ??
              name.trim(),
          email: userMap['email']?.toString() ?? email.trim(),
          role: _formatRoleLabel(
              userMap['role']?.toString() ?? normalizedRole),
          location: 'Ciudad de México, MX',
          bio: normalizedRole == 'CLIENT'
              ? 'Cliente verificado en búsqueda de talento especializado.'
              : 'Especialista independiente disponible para proyectos.',
          skills: normalizedRole == 'CLIENT'
              ? ['Gestión de Proyectos', 'Producto']
              : ['Flutter', 'Dart', 'UI/UX'],
        );

        if (token != null && token.isNotEmpty) {
          await saveToken(token);
        } else {
          // Obtener token JWT iniciando sesión automáticamente si el registro no lo incluyó
          final loginResult = await loginWithResult(email.trim(), password);
          if (loginResult.success && loginResult.token != null) {
            token = loginResult.token;
          }
        }

        await saveUserProfile(userProfile);

        return AuthResult(
          success: true,
          user: userProfile,
          token: token,
          message: 'Cuenta creada exitosamente',
        );
      }

      final errorMsg = _extractErrorMessage(
        decoded,
        'Error al crear la cuenta en el servidor.',
      );
      return AuthResult(success: false, message: errorMsg);
    } catch (_) {
      return const AuthResult(
        success: false,
        message:
            'No se pudo conectar con el servidor para completar el registro.',
      );
    }
  }

  String _formatRoleLabel(String rawRole) {
    final upper = rawRole.toUpperCase();
    if (upper == 'CLIENT') {
      return 'Cliente Contratante (CLIENT)';
    } else if (upper == 'FREELANCER') {
      return 'Especialista Freelancer (FREELANCER)';
    }
    return rawRole;
  }

  Future<bool> login(String email, String password) async {
    final result = await loginWithResult(email, password);
    return result.success;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final result = await registerWithResult(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    return result.success;
  }
}
