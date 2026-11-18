import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _connectivity = ConnectivityService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _enterOfflineMode() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu correo y contraseña')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final isOnline = await _connectivity.checkConnection();
    final success = await _authService.login(email, pass);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(initialIndex: 0),
        ),
        (route) => false,
      );
    } else {
      if (!isOnline) {
        // Dispositivo sin conexión
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Sin conexión al servidor. Puedes navegar en Modo Offline.'),
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Entrar Offline',
              textColor: Colors.white,
              onPressed: _enterOfflineMode,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Credenciales incorrectas o backend no disponible.'),
            action: SnackBarAction(
              label: 'Modo Offline',
              textColor: Colors.amberAccent,
              onPressed: _enterOfflineMode,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Iniciar Sesión',
          style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Estás a un paso de tu próximo gran proyecto',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Vuelve a conectar con clientes de alto impacto o impulsa tus servicios freelance hacia el siguiente nivel.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _emailController,
                labelText: 'Correo electrónico',
                hintText: 'ej. sofia@estudio.com',
                prefixIcon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Contraseña',
                hintText: 'Introduce tu contraseña',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Iniciar sesión',
                icon: Icons.arrow_forward,
                isLoading: _isLoading,
                onPressed: _submitLogin,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _enterOfflineMode,
                  icon: const Icon(Icons.cloud_off_rounded,
                      size: 16, color: AppColors.primary),
                  label: Text(
                    '¿Sin conexión? Entrar en Modo Offline',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
