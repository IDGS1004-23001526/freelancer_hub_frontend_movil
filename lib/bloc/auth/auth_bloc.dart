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

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authService.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
