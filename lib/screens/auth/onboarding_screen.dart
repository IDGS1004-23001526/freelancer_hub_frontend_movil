import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../main_navigation_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Freelance',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Conecta con talento independiente o postula a los mejores proyectos y servicios',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),
              PrimaryButton(
                text: 'Crear Cuenta',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'Ingresar',
                backgroundColor: AppColors.primaryLight,
                textColor: AppColors.textPrimary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              // Acceso directo a Modo Offline para pruebas o sin conexión
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainNavigationScreen(initialIndex: 0),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.primary),
                label: Text(
                  'Explorar en Modo Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Al continuar, aceptas nuestros Términos y Política de Privacidad',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
