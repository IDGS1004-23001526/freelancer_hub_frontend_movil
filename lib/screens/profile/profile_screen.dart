import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/profile_menu_item.dart';
import '../auth/onboarding_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  int _currentNavIndex = 3;
  bool _isLoading = true;

  UserProfile _user = UserProfile(
    id: '',
    fullName: 'Laura Mendoza',
    email: '',
    role: 'Cliente Contratante & Diseñadora de Producto',
    location: 'Ciudad de México, MX',
    bio: 'Especialista en interfaces de usuario y liderazgo de proyectos.',
    skills: ['Flutter', 'UI/UX', 'Dart'],
  );

  @override
  void initState() {
    super.initState();
    final blocUser = context.read<AuthBloc?>()?.state.user;
    if (blocUser != null) {
      _user = blocUser;
      _isLoading = false;
    } else {
      _loadProfileData();
    }
  }

  Future<void> _loadProfileData() async {
    final fetched = await _profileService.fetchProfile();
    if (fetched != null && mounted) {
      setState(() {
        _user = fetched;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      color: AppColors.primaryLight,
      child: const Icon(Icons.person, size: 50, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perfil',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              // Tarjeta Cabecera de Perfil
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ClipOval(
                          child: _user.avatarUrl != null && _user.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  _user.avatarUrl!,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                                )
                              : _buildAvatarPlaceholder(),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _user.fullName,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _user.role,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _user.location.isNotEmpty ? _user.location : 'Sin ubicación especificada',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.push<UserProfile>(
                            context,
                            MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
                          );
                          if (updated != null) {
                            setState(() => _user = updated);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                        label: Text(
                          'Editar Perfil',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Pagos protegidos mediante custodia Escrow SSL 256-bit',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Configuración y Cuenta',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    ProfileMenuItem(
                      icon: Icons.person_outline,
                      title: 'Editar información personal',
                      subtitle: 'Nombre, correo, teléfono y biografía',
                    ),
                    Divider(height: 1),
                    ProfileMenuItem(
                      icon: Icons.credit_card,
                      title: 'Métodos de pago y tarjetas',
                      subtitle: 'Tarjetas bancarias y fondos en custodia',
                    ),
                    Divider(height: 1),
                    ProfileMenuItem(
                      icon: Icons.receipt_long_outlined,
                      title: 'Historial de facturación y recibos',
                      subtitle: 'Descarga tus facturas fiscales CFDI',
                    ),
                    Divider(height: 1),
                    ProfileMenuItem(
                      icon: Icons.tune,
                      title: 'Preferencias de notificaciones',
                      subtitle: 'Alertas de postulaciones y mensajes',
                    ),
                    Divider(height: 1),
                    ProfileMenuItem(
                      icon: Icons.lock_outline,
                      title: 'Seguridad y contraseña',
                      subtitle: 'Autenticación en 2 pasos activa',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    context.read<AuthBloc?>()?.add(const AuthLogoutRequested());
                    await _authService.logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  label: Text(
                    'Cerrar sesión',
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Versión 2.4.1 (Build 184) • Plataforma Freelance',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explorar'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Postulaciones'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
