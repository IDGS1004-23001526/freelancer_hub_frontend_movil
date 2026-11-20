import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/form_validators.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/role_selection_card.dart';
import '../profile/profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKeyStep0 = GlobalKey<FormState>();
  final _formKeyStep1 = GlobalKey<FormState>();

  // Paso 0: Nombres, Apellidos y Credenciales
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Paso 1: Ubicación & Contacto
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  // Paso 2: Perfil Profesional
  final _titleController = TextEditingController();
  final _bioController = TextEditingController();
  final List<String> _selectedSkills = [];

  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();

  int _currentStep = 0;
  bool _isSavingProfile = false;

  final List<String> _freelancerAvailableSkills = [
    'Flutter',
    'Dart',
    'UI/UX',
    'Figma',
    'Node.js',
    'PostgreSQL',
    'TypeScript',
    'REST APIs',
    'Git',
    'Docker',
    'Firebase',
    'Clean Architecture',
  ];

  final List<String> _clientAvailableInterests = [
    'Desarrollo Móvil',
    'Diseño UI/UX',
    'Desarrollo Web Fullstack',
    'Bases de Datos & Cloud',
    'Consultoría Tecnológica',
    'Mantenimiento & Soporte',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _submitStep0(BuildContext blocContext, String selectedRole) {
    FocusScope.of(blocContext).unfocus();
    if (!_formKeyStep0.currentState!.validate()) return;

    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final fullName = (last.isNotEmpty ? '$first $last' : first).trim();

    blocContext.read<AuthBloc>().add(
          AuthRegisterSubmitted(
            name: fullName,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: selectedRole,
            location: '',
            phone: '',
            bio: '',
            skills: const [],
          ),
        );
  }

  void _continueToStep2() {
    FocusScope.of(context).unfocus();
    if (!_formKeyStep1.currentState!.validate()) return;
    setState(() {
      _currentStep = 2;
    });
  }

  Future<void> _saveProfileAndFinish() async {
    setState(() => _isSavingProfile = true);
    try {
      final cached = await _authService.getCachedUserProfile();
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final fullName = (last.isNotEmpty ? '$first $last' : first).trim();
      final title = _titleController.text.trim();
      final bio = _bioController.text.trim();
      final combinedBio = title.isNotEmpty
          ? (bio.isNotEmpty ? '$title. $bio' : title)
          : bio;
      final location = _locationController.text.trim();
      final phone = _phoneController.text.trim();

      final baseProfile = cached ?? UserProfile(
        id: '',
        email: _emailController.text.trim(),
        role: 'FREELANCER',
        location: location,
        bio: combinedBio,
        skills: _selectedSkills,
      );

      final updated = baseProfile.copyWith(
        firstName: first.isNotEmpty ? first : baseProfile.firstName,
        lastName: last.isNotEmpty ? last : baseProfile.lastName,
        fullName: fullName.isNotEmpty ? fullName : baseProfile.fullName,
        location: location,
        phone: phone,
        bio: combinedBio,
        skills: _selectedSkills,
      );

      await _authService.saveUserProfile(updated);
      await _profileService.updateProfile(updated);
      if (mounted) {
        context.read<AuthBloc?>()?.add(AuthProfileUpdated(updated));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil configurado exitosamente!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(initialUser: updated)),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _skipAndFinish() async {
    final cached = await _authService.getCachedUserProfile();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(initialUser: cached)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingBloc = context.read<AuthBloc?>();
    if (existingBloc != null) {
      return _buildRegisterView(context);
    }
    return BlocProvider(
      create: (_) => AuthBloc(),
      child: Builder(
        builder: (innerContext) => _buildRegisterView(innerContext),
      ),
    );
  }

  Widget _buildRegisterView(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated && _currentStep == 0) {
          setState(() {
            _currentStep = 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Cuenta creada! Personalicemos tu perfil.'),
              backgroundColor: AppColors.accentGreen,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.redAccent.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
        final isClient = state.selectedRole.toUpperCase() == 'CLIENT';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _currentStep == 0
                  ? 'Crear Cuenta'
                  : (_currentStep == 1 ? 'Ubicación y Contacto' : 'Perfil Profesional'),
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressIndicator(),
                  const SizedBox(height: 16),
                  if (_currentStep == 0)
                    _buildStep0(context, state, isClient)
                  else if (_currentStep == 1)
                    _buildStep1()
                  else
                    _buildStep2(isClient),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    final double progress = (_currentStep + 1) / 3.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paso ${_currentStep + 1} de 3',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}% completado',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// PASO 1: Credenciales de acceso, Nombres, Apellidos y Rol
  Widget _buildStep0(BuildContext context, AuthState state, bool isClient) {
    return Form(
      key: _formKeyStep0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comencemos con tu cuenta',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '¿Cómo deseas utilizar la plataforma? Selecciona tu rol principal para configurar tu cuenta.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          RoleSelectionCard(
            key: const Key('role_card_client'),
            title: 'Quiero contratar talento',
            subtitle:
                'Publica vacantes, descubre especialistas verificados y gestiona entregas con contratos protegidos.',
            badgeText: 'CLIENT',
            icon: Icons.work_outline,
            isSelected: isClient,
            onTap: () => context.read<AuthBloc>().add(const AuthRoleSelected('CLIENT')),
          ),
          RoleSelectionCard(
            key: const Key('role_card_freelancer'),
            title: 'Quiero ofrecer mis servicios',
            subtitle:
                'Postula a proyectos internacionales, construye reputación y cobra puntualmente en tu moneda local.',
            badgeText: 'FREELANCER',
            icon: Icons.laptop_chromebook,
            isSelected: !isClient,
            onTap: () => context.read<AuthBloc>().add(const AuthRoleSelected('FREELANCER')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  key: const Key('register_name_field'),
                  controller: _firstNameController,
                  labelText: 'Nombre(s)',
                  hintText: 'Ej. Sofía',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.validateName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  key: const Key('register_lastname_field'),
                  controller: _lastNameController,
                  labelText: 'Apellidos',
                  hintText: 'Ej. Morales',
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            key: const Key('register_email_field'),
            controller: _emailController,
            labelText: 'Correo electrónico profesional',
            hintText: 'sofia@empresa.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: FormValidators.validateEmail,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            key: const Key('register_password_field'),
            controller: _passwordController,
            labelText: 'Contraseña (mín. 8 caracteres, letra y número)',
            hintText: 'Crea una clave segura (ej. Clave2026)',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            validator: FormValidators.validatePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            key: const Key('register_submit_button'),
            text: 'Crear cuenta y continuar',
            icon: Icons.arrow_forward,
            isLoading: state.isLoading,
            onPressed: () => _submitStep0(context, state.selectedRole),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// PASO 2: Ubicación y Contacto
  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ubicación y contacto',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Indica tu ciudad/país y un teléfono de contacto real para coordinar proyectos y recibir notificaciones.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _locationController,
            labelText: 'Ciudad y País',
            hintText: 'Ej. Guadalajara, México o Remoto',
            prefixIcon: Icons.location_on_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _phoneController,
            labelText: 'Teléfono de contacto (con lada)',
            hintText: 'Ej. +52 33 1234 5678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: FormValidators.validatePhone,
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            text: 'Continuar al perfil profesional',
            icon: Icons.arrow_forward,
            onPressed: _continueToStep2,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: Text(
                'Omitir este paso por ahora',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// PASO 3: Perfil Profesional y Habilidades / Intereses
  Widget _buildStep2(bool isClient) {
    final availableList = isClient ? _clientAvailableInterests : _freelancerAvailableSkills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isClient ? 'Perfil de Empresa o Proyecto' : 'Tu Especialidad Profesional',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isClient
              ? 'Cuéntanos sobre tu organización y qué tipo de servicios planeas contratar.'
              : 'Destaca tu experiencia y las tecnologías que dominas para recibir proyectos adecuados.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        CustomTextField(
          controller: _titleController,
          labelText: isClient ? 'Nombre de empresa o proyecto' : 'Título o especialidad profesional',
          hintText: isClient ? 'Ej. Nexo Tech o Emprendimiento' : 'Ej. Desarrollador Flutter Móvil',
          prefixIcon: isClient ? Icons.business_outlined : Icons.badge_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _bioController,
          labelText: isClient ? 'Descripción de proyectos' : 'Sobre ti / Biografía breve',
          hintText: isClient
              ? 'Detalla qué soluciones necesitas desarrollar...'
              : 'Cuéntanos brevemente sobre tu trayectoria...',
          prefixIcon: isClient ? Icons.description_outlined : Icons.edit_note_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        Text(
          isClient ? 'Áreas de talento que buscas:' : 'Selecciona tus habilidades principales:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableList.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(
                skill,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSkills.add(skill);
                  } else {
                    _selectedSkills.remove(skill);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          text: 'Finalizar y Comenzar',
          icon: Icons.check,
          isLoading: _isSavingProfile,
          onPressed: _saveProfileAndFinish,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _skipAndFinish,
            child: Text(
              'Omitir y completar después en mi perfil',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
