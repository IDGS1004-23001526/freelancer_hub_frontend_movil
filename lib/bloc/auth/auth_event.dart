import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Evento para seleccionar interactivamente el rol en RegisterScreen ('CLIENT' o 'FREELANCER').
class AuthRoleSelected extends AuthEvent {
  final String role;

  const AuthRoleSelected(this.role);

  @override
  List<Object?> get props => [role];
}

/// Evento para enviar el formulario de registro de usuario.
class AuthRegisterSubmitted extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String? role;

  const AuthRegisterSubmitted({
    required this.name,
    required this.email,
    required this.password,
    this.role,
  });

  @override
  List<Object?> get props => [name, email, password, role];
}

/// Evento para enviar el formulario de inicio de sesión.
class AuthLoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginSubmitted({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Evento para verificar el estado de la sesión actual.
class AuthSessionChecked extends AuthEvent {
  const AuthSessionChecked();
}

/// Evento para cerrar la sesión activa.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
