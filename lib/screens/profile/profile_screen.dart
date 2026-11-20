import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_image.dart';
import '../../widgets/profile_menu_item.dart';
import '../auth/onboarding_screen.dart';
import '../main_navigation_screen.dart';
import '../notifications/notifications_screen.dart';
import '../payment/add_card_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBottomNav;
  final UserProfile? initialUser;

  const ProfileScreen({
    super.key,
    this.showBottomNav = false,
    this.initialUser,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  int _standaloneNavIndex = 4;
  bool _isLoading = true;

  UserProfile _user = UserProfile(
    id: '',
    fullName: '',
    email: '',
    role: 'FREELANCER',
    location: '',
    bio: '',
    phone: '',
    skills: const [],
  );

  int get _completionPercentage {
    int total = 4;
    int filled = 0;
    if (_user.fullName.trim().isNotEmpty) filled++;
    if (_user.location.trim().isNotEmpty) filled++;
    if (_user.bio.trim().isNotEmpty) filled++;
    if (_user.skills.isNotEmpty) filled++;
    return ((filled / total) * 100).round();
  }

  bool get _isProfileIncomplete => _completionPercentage < 100;

  Widget _buildIncompleteProfileBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tu perfil está al $_completionPercentage% completado',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _completionPercentage / 100.0,
              backgroundColor: const Color(0xFFFEF3C7),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu ubicación, biografía y habilidades para generar confianza y recibir propuestas.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
              label: Text(
                'Completar perfil ahora',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _user = widget.initialUser!;
      _isLoading = false;
    }
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final cached = await _authService.getCachedUserProfile();
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    final fetched = await _profileService.fetchProfile();
    if (fetched != null && mounted) {
      setState(() {
        _user = fetched;
        _isLoading = false;
      });
    } else if (cached == null && mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToEditProfile() async {
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
    );
    if (updated != null && mounted) {
      setState(() => _user = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isClient = _user.role.toUpperCase() == 'CLIENT';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mi Perfil',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.primary),
                    tooltip: 'Recargar datos',
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadProfileData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isProfileIncomplete) _buildIncompleteProfileBanner(),
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
                          child: AvatarImage(
                            avatarUrl: _user.avatarUrl,
                            size: 90,
                          ),
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
                      _user.fullName.isNotEmpty ? _user.fullName : 'Usuario FreelancerHub',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isClient ? 'CLIENTE CONTRATANTE' : 'PROFESIONAL FREELANCER',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (_user.email.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.email_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _user.email,
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (_user.displayPhone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _user.displayPhone,
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
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
                    const SizedBox(height: 10),
                    Text(
                      _user.bio.isNotEmpty
                          ? _user.bio
                          : 'Sin biografía añadida todavía.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _user.bio.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (_user.skills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: _user.skills.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textPrimary),
                          ),
                        )).toList(),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _navigateToEditProfile,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Añadir habilidades profesionales',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        key: const Key('profile_edit_button'),
                        onPressed: _navigateToEditProfile,
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
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ProfileMenuItem(
                      icon: Icons.person_outline,
                      title: 'Editar información personal',
                      subtitle: 'Nombre, correo, teléfono y biografía',
                      onTap: _navigateToEditProfile,
                    ),
                    const Divider(height: 1),
                    ProfileMenuItem(
                      icon: Icons.credit_card,
                      title: 'Métodos de pago y tarjetas',
                      subtitle: 'Tarjetas bancarias y fondos en custodia',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddCardScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    const ProfileMenuItem(
                      icon: Icons.receipt_long_outlined,
                      title: 'Historial de facturación y recibos',
                      subtitle: 'Descarga tus facturas fiscales CFDI',
                    ),
                    const Divider(height: 1),
                    ProfileMenuItem(
                      icon: Icons.notifications_outlined,
                      title: 'Sección de notificaciones',
                      subtitle: 'Alertas de postulaciones, contratos y mensajes',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    const ProfileMenuItem(
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
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: _standaloneNavIndex,
              onTap: (index) {
                if (index != _standaloneNavIndex) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainNavigationScreen(initialIndex: index),
                    ),
                  );
                }
              },
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              backgroundColor: AppColors.surface,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10.5),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Explorar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.description_outlined),
                  activeIcon: Icon(Icons.description),
                  label: 'Contratos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet),
                  label: 'Billetera',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            )
          : null,
    );
  }
}
