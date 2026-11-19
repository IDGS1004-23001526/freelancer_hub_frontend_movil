import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_constants.dart';
import '../main.dart';
import '../screens/auth/login_screen.dart';
import 'auth_service.dart';

/// Cliente HTTP centralizado basado en Dio con soporte para:
/// 1. Inyección automática del accessToken (Bearer JWT).
/// 2. Silent Refresh Token mediante QueuedInterceptorsWrapper (sin colisiones en peticiones concurrentes).
/// 3. Reintento automático de la petición fallida con el nuevo token.
/// 4. Cierre de sesión y redirección a login si el refreshToken expira.
class ApiClient {
  ApiClient._internal() {
    _initDio();
  }

  static final ApiClient instance = ApiClient._internal();
  factory ApiClient() => instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  void _initDio() {
    final activeBase = AuthService.activeBaseUrl ?? ApiConstants.baseUrl;
    dio = Dio(
      BaseOptions(
        baseUrl: activeBase,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // QueuedInterceptorsWrapper pone en pausa las peticiones concurrentes
    // mientras una renueva el token, evitando múltiples llamadas a /refresh-token.
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          // Asegurar que la URL base coincida con la activa
          if (AuthService.activeBaseUrl != null &&
              !options.path.startsWith('http')) {
            options.baseUrl = AuthService.activeBaseUrl!;
          }

          // Inyectar accessToken guardado si la petición no trae Authorization
          if (!options.headers.containsKey('Authorization')) {
            final token = await _storage.read(key: 'jwt_token');
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;
          final isAlreadyRetried = requestOptions.extra['_retry'] == true;
          final isAuthEndpoint = requestOptions.path.contains('/auth/login') ||
              requestOptions.path.contains('/auth/register') ||
              requestOptions.path.contains('/auth/refresh-token');

          // Si es 401 y no es una ruta de auth ni se ha reintentado previamente
          if (statusCode == 401 && !isAuthEndpoint && !isAlreadyRetried) {
            requestOptions.extra['_retry'] = true;

            try {
              final newAccessToken = await _performRefreshToken();

              if (newAccessToken != null && newAccessToken.isNotEmpty) {
                // Actualizar la cabecera con el nuevo token y reintentar
                requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';

                final retryResponse = await dio.fetch(requestOptions);
                return handler.resolve(retryResponse);
              } else {
                await _handleSessionExpired();
                return handler.next(error);
              }
            } catch (_) {
              await _handleSessionExpired();
              return handler.next(error);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Expone el método de refresco explícito por si algún servicio o BLoC lo necesita.
  Future<String?> refreshToken() => _performRefreshToken();

  /// Ejecuta la renovación del token de forma aislada sin interceptores para evitar bucles.
  Future<String?> _performRefreshToken() async {
    final storedRefreshToken = await _storage.read(key: 'refresh_token');
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      return null;
    }

    final isolatedDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final candidateUrls = AuthService.getOrderedBaseUrls();

    for (final base in candidateUrls) {
      try {
        final response = await isolatedDio.post(
          '$base/auth/refresh-token',
          data: {'refreshToken': storedRefreshToken},
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data;
          final payload = (data is Map<String, dynamic> && data['data'] != null)
              ? data['data']
              : data;

          if (payload is Map<String, dynamic>) {
            final newAccessToken = (payload['accessToken'] ??
                    payload['token'] ??
                    payload['jwt'])
                ?.toString();
            final newRefreshToken = payload['refreshToken']?.toString();

            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              await _storage.write(key: 'jwt_token', value: newAccessToken);
              if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
                await _storage.write(
                    key: 'refresh_token', value: newRefreshToken);
              }
              AuthService.activeBaseUrl = base;
              dio.options.baseUrl = base;
              return newAccessToken;
            }
          }
        }
      } catch (_) {
        // Intentar siguiente URL candidata si falla la conexión
        continue;
      }
    }

    return null;
  }

  /// Limpia credenciales y redirige suavemente al usuario al Login
  Future<void> _handleSessionExpired() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_profile');

    // Redirigir al Login si el contexto de navegación global está montado
    final nav = appNavigatorKey.currentState;
    if (nav != null && nav.mounted) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
