import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState()) {
    on<AuthRoleSelected>(_onRoleSelected);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthSessionChecked>(_onSessionChecked);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthProfileUpdated>((event, emit) {
      emit(state.copyWith(user: event.user));
    });
  }

  void _onRoleSelected(
    AuthRoleSelected event,
    Emitter<AuthState> emit,
  ) {
    emit(
      state.copyWith(
        selectedRole: event.role.trim().toUpperCase(),
        status: state.status == AuthStatus.error
            ? AuthStatus.initial
            : state.status,
        clearError: true,
      ),
    );
  }

  Future<void> _onRegisterSubmitted(
    AuthRegisterSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final roleToRegister = (event.role ?? state.selectedRole).toUpperCase();
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        selectedRole: roleToRegister,
        clearError: true,
      ),
    );

    final result = await _authService.registerWithResult(
      name: event.name,
      email: event.email,
      password: event.password,
      role: roleToRegister,
      location: event.location,
      phone: event.phone,
      bio: event.bio,
      skills: event.skills,
    );

    if (result.success) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage:
              result.message ?? 'Error al crear la cuenta en el servidor.',
        ),
      );
    }
  }

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));

    final result = await _authService.loginWithResult(
      event.email,
      event.password,
    );

    if (result.success) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.message ??
              'Credenciales incorrectas o error en el servidor.',
        ),
      );
    }
  }

  Future<void> _onSessionChecked(
    AuthSessionChecked event,
    Emitter<AuthState> emit,
  ) async {
    final token = await _authService.getToken();
    final cachedUser = await _authService.getCachedUserProfile();
    if (token != null && token.isNotEmpty) {
      // Si el token expiró, intentar renovarlo silenciosamente con el refresh token
      if (_isTokenExpired(token)) {
        final refreshedToken = await _authService.refreshToken();
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          final refreshedUser = await _authService.getCachedUserProfile();
          emit(
            state.copyWith(
              status: AuthStatus.authenticated,
              user: refreshedUser ?? cachedUser,
              clearError: true,
            ),
          );
          return;
        } else {
          // Si el refresh token falló o expiró, limpiar sesión local
          await _authService.logout();
          emit(state.copyWith(status: AuthStatus.unauthenticated));
          return;
        }
      }

      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: cachedUser,
          clearError: true,
        ),
      );
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is Map<String, dynamic> && payload['exp'] != null) {
        final exp = (payload['exp'] as num).toInt();
        final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return nowInSeconds >= exp;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
