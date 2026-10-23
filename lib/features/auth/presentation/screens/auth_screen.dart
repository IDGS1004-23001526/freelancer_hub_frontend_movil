import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true; // Controla si estamos en Login o Registro

  String _name = '';
  String _email = '';
  String _password = '';
  String _selectedRole = 'Freelancer';

  final List<String> _roles = ['Freelancer', 'Cliente'];

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      FocusScope.of(context).unfocus();

      if (_isLogin) {
        // TODO: Implementar lógica de Login en el AuthNotifier
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulando Login...')),
        );
      } else {
        // Lógica de Registro (HU-15)
        final success = await ref.read(authProvider.notifier)
            .register(_name, _email, _password, _selectedRole);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro exitoso. Bienvenido.'),
              backgroundColor: AppTheme.raspberry,
            ),
          );
        } else if (mounted) {
          final error = ref.read(authProvider).errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error ?? 'Error en el registro'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.creamWhite,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER INCLINADO CON LOGO
            ClipPath(
              clipper: HeaderClipper(),
              child: Container(
                height: 280,
                width: double.infinity,
                color: AppTheme.darkBurgundy,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ESPACIO PARA EL LOGO
                      Container(
                        height: 90,
                        width: 90,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'LOGO',
                            style: TextStyle(
                              color: AppTheme.darkBurgundy,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SELECTOR LOGIN / SIGN UP
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isLogin = true),
                          child: Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: _isLogin ? FontWeight.bold : FontWeight.normal,
                              color: _isLogin ? AppTheme.darkBurgundy : AppTheme.beige,
                            ),
                          ),
                        ),
                        const Text('  /  ', style: TextStyle(fontSize: 18, color: AppTheme.beige)),
                        GestureDetector(
                          onTap: () => setState(() => _isLogin = false),
                          child: Text(
                            'REGISTRARSE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: !_isLogin ? FontWeight.bold : FontWeight.normal,
                              color: !_isLogin ? AppTheme.darkBurgundy : AppTheme.beige,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // CAMPO NOMBRE (Solo en Registro)
                    if (!_isLogin) ...[
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline, color: AppTheme.dustyRose),
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'El nombre es obligatorio' : null,
                        onSaved: (value) => _name = value!.trim(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // CAMPO CORREO
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined, color: AppTheme.dustyRose),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'El correo es obligatorio';
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value)) return 'Ingresa un correo válido';
                        return null;
                      },
                      onSaved: (value) => _email = value!.trim(),
                    ),
                    const SizedBox(height: 16),

                    // CAMPO CONTRASEÑA
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.dustyRose),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
                        if (!_isLogin) {
                          if (value.length < 8) return 'Mínimo 8 caracteres';
                          if (!RegExp(r'(?=.*[a-zA-Z])(?=.*[0-9])').hasMatch(value)) {
                            return 'Debe contener letra y número';
                          }
                        }
                        return null;
                      },
                      onSaved: (value) => _password = value!,
                    ),
                    const SizedBox(height: 16),

                    // SELECTOR DE ROL (Solo en Registro)
                    if (!_isLogin) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: '¿Cómo usarás la plataforma?',
                          prefixIcon: Icon(Icons.work_outline, color: AppTheme.dustyRose),
                        ),
                        items: _roles.map((String role) {
                          return DropdownMenuItem(value: role, child: Text(role));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedRole = value);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // FORGOT PASSWORD (Solo en Login)
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(color: AppTheme.raspberry),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // BOTÓN PRINCIPAL
                    authState.isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.raspberry))
                        : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // Botón más redondeado
                        ),
                      ),
                      child: Text(
                        _isLogin ? 'INICIAR SESIÓN' : 'REGISTRARSE',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// CUSTOM CLIPPER PARA EL EFECTO INCLINADO DEL HEADER
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40); // Punto inferior izquierdo
    path.lineTo(size.width, size.height); // Punto inferior derecho
    path.lineTo(size.width, 0); // Punto superior derecho
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}