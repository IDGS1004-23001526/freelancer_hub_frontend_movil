/// Validadores reutilizables para los campos [TextFormField] del flujo de autenticación y perfil.
/// Alineados con las reglas de dominio del backend (FreelancerHub API).
class FormValidators {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _letterRegex = RegExp(r'[a-zA-Z]');
  static final RegExp _numberRegex = RegExp(r'[0-9]');

  /// Valida el nombre completo del usuario (mínimo 2 caracteres, máximo 100).
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es obligatorio';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    if (trimmed.length > 100) {
      return 'El nombre no puede superar los 100 caracteres';
    }
    return null;
  }

  /// Valida el formato de correo electrónico profesional.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo electrónico es obligatorio';
    }
    final trimmed = value.trim();
    if (trimmed.length > 255) {
      return 'El correo no puede superar los 255 caracteres';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Ingresa un correo electrónico válido (ej. nombre@dominio.com)';
    }
    return null;
  }

  /// Valida las reglas de seguridad de la contraseña para registro:
  /// - Mínimo 8 caracteres
  /// - Al menos 1 letra
  /// - Al menos 1 número
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (value.length > 100) {
      return 'La contraseña no puede superar los 100 caracteres';
    }
    if (!_letterRegex.hasMatch(value)) {
      return 'La contraseña debe incluir al menos una letra';
    }
    if (!_numberRegex.hasMatch(value)) {
      return 'La contraseña debe incluir al menos un número';
    }
    return null;
  }

  /// Valida la contraseña en el formulario de inicio de sesión.
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    return null;
  }
}
