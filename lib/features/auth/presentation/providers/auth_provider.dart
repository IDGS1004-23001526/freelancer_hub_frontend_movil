import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;

  AuthState({this.isLoading = false, this.errorMessage});
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<bool> register(String name, String email, String password, String role) async {
    state = AuthState(isLoading: true);

    try {
      // Simulación de petición HTTP al backend
      await Future.delayed(const Duration(seconds: 2));

      // Si el correo ya existe, se lanzaría una excepción aquí
      // throw Exception('El correo ya está registrado');

      state = AuthState(isLoading: false);
      return true; // Registro exitoso
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: e.toString());
      return false; // Fallo en el registro
    }
  }
}