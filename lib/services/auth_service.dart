import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'firebase_notification_service.dart';
import 'google_sign_in_service.dart';
import 'notification_socket_service.dart';

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

  /// Normaliza cualquier variante de rol a 'CLIENT' o 'FREELANCER'.
  static String normalizeRole(String? rawRole) {
    final upper = (rawRole ?? '').trim().toUpperCase();
    if (upper == 'CLIENT' || upper.contains('CLIENT')) {
      return 'CLIENT';
    }
    return 'FREELANCER';
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
    unawaited(NotificationSocketService.instance.connectIfAuthenticated());
    unawaited(FirebaseNotificationService.instance.syncFcmTokenWithBackend());
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'jwt_token');
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: 'refresh_token');
    } catch (_) {
      return null;
    }
  }

  /// Devuelve el rol guardado en sesión ('CLIENT' o 'FREELANCER') si existe.
  Future<String?> getSavedRole() async {
    final cached = await getCachedUserProfile();
    if (cached != null && cached.role.isNotEmpty) {
      return normalizeRole(cached.role);
    }
    return null;
  }

  /// Renueva el token de acceso invocando el flujo de refresh token
  Future<String?> refreshToken() async {
    return await ApiClient.instance.refreshToken();
  }

  Future<void> saveProfile(UserProfile user) => saveUserProfile(user);

  Future<void> saveUserProfile(UserProfile user) async {
    final cached = await getCachedUserProfile();
    final effectiveAvatar =
    (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
        ? user.avatarUrl
        : cached?.avatarUrl;

    final normalizedRole = normalizeRole(
      user.role.isNotEmpty ? user.role : cached?.role,
    );

    if (effectiveAvatar != null &&
        effectiveAvatar.isNotEmpty &&
        user.email.isNotEmpty) {
      await _storage.write(
        key: 'saved_avatar_${user.email.trim().toLowerCase()}',
        value: effectiveAvatar,
      );
    }

    if (user.location.isNotEmpty && user.email.isNotEmpty) {
      await _storage.write(
        key: 'saved_location_${user.email.trim().toLowerCase()}',
        value: user.location.trim(),
      );
    }

    await _storage.write(
      key: 'user_profile',
      value: jsonEncode({
        'id': user.id,
        'firstName': user.firstName,
        'lastName': user.lastName,
        'fullName': user.fullName,
        'name': user.fullName,
        'email': user.email,
        'role': normalizedRole,
        'phone': user.phone.isNotEmpty ? user.phone : (cached?.phone ?? ''),
        'location':
        user.location.isNotEmpty ? user.location : (cached?.location ?? ''),
        'bio': user.bio.isNotEmpty ? user.bio : (cached?.bio ?? ''),
        'avatarUrl': effectiveAvatar,
        'avatar': effectiveAvatar,
        'skills': user.skills.isNotEmpty ? user.skills : (cached?.skills ?? []),
      }),
    );
  }

  Future<UserProfile?> getCachedProfile() => getCachedUserProfile();

  Future<UserProfile?> getCachedUserProfile() async {
    final raw = await _storage.read(key: 'user_profile');
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed =
      UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return parsed.copyWith(role: normalizeRole(parsed.role));
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
    NotificationSocketService.instance.disconnect();
    try {
      final base = activeBaseUrl ?? ApiConstants.baseUrl;
      await ApiClient.instance.dio.delete('$base/users/fcm-token');
    } catch (_) {}
    try {
      await GoogleSignInService.instance.signOut();
    } catch (_) {}
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

        // Asegurar rol puro ('CLIENT' o 'FREELANCER') desde la respuesta real del backend
        final serverRole = normalizeRole(
          userMap['role']?.toString() ?? rawProfile.role,
        );

        final normalizedEmail =
        (rawProfile.email.isNotEmpty ? rawProfile.email : email)
            .trim()
            .toLowerCase();
        final persistedAvatar =
        await _storage.read(key: 'saved_avatar_$normalizedEmail');
        final persistedLocation =
        await _storage.read(key: 'saved_location_$normalizedEmail');

        final effectiveAvatar =
        (rawProfile.avatarUrl != null && rawProfile.avatarUrl!.isNotEmpty)
            ? rawProfile.avatarUrl
            : (cached?.email.trim().toLowerCase() == normalizedEmail
            ? (cached?.avatarUrl ?? persistedAvatar)
            : persistedAvatar);

        final isSameUserCache =
            cached?.email.trim().toLowerCase() == normalizedEmail;

        final effectiveLocation = rawProfile.location.isNotEmpty
            ? rawProfile.location
            : ((persistedLocation != null && persistedLocation.isNotEmpty)
                ? persistedLocation
                : (isSameUserCache && cached!.location.isNotEmpty
                    ? cached.location
                    : ''));

        final userProfile = rawProfile.copyWith(
          role: serverRole,
          location: effectiveLocation,
          bio: rawProfile.bio.isNotEmpty
              ? rawProfile.bio
              : (isSameUserCache && cached!.bio.isNotEmpty
              ? cached.bio
              : (serverRole == 'CLIENT'
              ? 'Cliente contratante verificado en Freelancer Hub.'
              : 'Especialista verificado en Freelancer Hub.')),
          avatarUrl: effectiveAvatar,
          skills: rawProfile.skills.isNotEmpty
              ? rawProfile.skills
              : (isSameUserCache && cached!.skills.isNotEmpty
              ? cached.skills
              : (serverRole == 'CLIENT'
              ? const ['Gestión de Proyectos', 'Producto']
              : const ['Flutter', 'Dart', 'UI/UX'])),
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

  /// Autentica o registra al usuario mediante Google ID Token en el endpoint `/auth/google`.
  /// Si se especifica [role], se asocia al usuario si es una cuenta nueva (default: FREELANCER).
  Future<AuthResult> googleAuthWithResult({
    String? role,
    String? explicitIdToken,
  }) async {
    try {
      final String? idToken;
      if (explicitIdToken != null && explicitIdToken.isNotEmpty) {
        idToken = explicitIdToken;
      } else {
        idToken = await GoogleSignInService.instance.getIdToken();
      }

      if (idToken == null) {
        return const AuthResult(
          success: false,
          message: 'Inicio de sesión con Google cancelado.',
        );
      }

      final normalizedRole = (role != null && role.isNotEmpty)
          ? role.trim().toUpperCase()
          : 'FREELANCER';

      final response = await _postToEndpoint(
        endpointPath: '/auth/google',
        body: {
          'idToken': idToken,
          'role': normalizedRole,
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

        final normalizedEmail = rawProfile.email.trim().toLowerCase();
        final persistedAvatar =
            await _storage.read(key: 'saved_avatar_$normalizedEmail');

        final effectiveAvatar = (rawProfile.avatarUrl != null &&
                rawProfile.avatarUrl!.isNotEmpty)
            ? rawProfile.avatarUrl
            : (cached?.avatarUrl ?? persistedAvatar);

        String _formatRoleLabel(String rawRole) {
          return normalizeRole(rawRole);
        }

        final persistedLocation =
        await _storage.read(key: 'saved_location_${rawProfile.email.trim().toLowerCase()}');

        final userProfile = rawProfile.copyWith(
          role: _formatRoleLabel(rawProfile.role),
          location: rawProfile.location.isNotEmpty
              ? rawProfile.location
              : ((persistedLocation != null && persistedLocation.isNotEmpty)
                  ? persistedLocation
                  : (cached?.location ?? '')),
          bio: rawProfile.bio.isNotEmpty ? rawProfile.bio : (cached?.bio ?? ''),
          avatarUrl: effectiveAvatar,
          skills: rawProfile.skills.isNotEmpty
              ? rawProfile.skills
              : (cached?.skills ?? const []),
        );

        await saveUserProfile(userProfile);

        return AuthResult(
          success: true,
          user: userProfile,
          token: token?.toString(),
          message: 'Autenticación con Google exitosa.',
        );
      }

      final errorMsg = _extractErrorMessage(
        decoded,
        'Error al autenticar con la cuenta de Google.',
      );
      return AuthResult(success: false, message: errorMsg);
    } catch (e) {
      return AuthResult(
        success: false,
        message: e is Exception
            ? 'Error al conectar con Google: ${e.toString().replaceAll('Exception: ', '')}'
            : 'No se pudo completar la autenticación con Google.',
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
    String? location,
    String? phone,
    String? bio,
    List<String>? skills,
  }) async {
    try {
      final normalizedRole = normalizeRole(role);
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

        final resolvedRole = normalizeRole(
          userMap['role']?.toString() ?? normalizedRole,
        );

        UserProfile userProfile = UserProfile(
          id: userMap['id']?.toString() ?? '',
          fullName: (userMap['fullName'] ?? userMap['name'])?.toString() ??
              name.trim(),
          email: userMap['email']?.toString() ?? email.trim(),
          role: resolvedRole,
          location: 'Ciudad de México, MX',
          bio: resolvedRole == 'CLIENT'
              ? 'Cliente verificado en búsqueda de talento especializado.'
              : 'Especialista independiente disponible para proyectos.',
          skills: resolvedRole == 'CLIENT'
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
            if (loginResult.user != null) {
              userProfile = loginResult.user!;
            }
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
