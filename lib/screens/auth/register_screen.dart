import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitRegister(BuildContext blocContext, String selectedRole) {
    FocusScope.of(blocContext).unfocus();
    if (!_formKey.currentState!.validate()) return;

    blocContext.read<AuthBloc>().add(
          AuthRegisterSubmitted(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: selectedRole,
          ),
        );
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
        if (state.status == AuthStatus.authenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Registro completado exitosamente!'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
            (route) => false,
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
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Crear Cuenta',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crea tu cuenta',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '¿Cómo deseas utilizar la plataforma hoy? Selecciona tu rol principal para configurar tu cuenta.',
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
                      onTap: () => context
                          .read<AuthBloc>()
                          .add(const AuthRoleSelected('CLIENT')),
                    ),
                    RoleSelectionCard(
                      key: const Key('role_card_freelancer'),
                      title: 'Quiero ofrecer mis servicios',
                      subtitle:
                          'Postula a proyectos internacionales, construye reputación y cobra puntualmente en tu moneda local.',
                      badgeText: 'FREELANCER',
                      icon: Icons.laptop_chromebook,
                      isSelected: !isClient,
                      onTap: () => context
                          .read<AuthBloc>()
                          .add(const AuthRoleSelected('FREELANCER')),
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      key: const Key('register_name_field'),
                      controller: _nameController,
                      labelText: 'Nombre y apellido',
                      hintText: 'Ej. Sofía Morales',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: FormValidators.validateName,
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
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      key: const Key('register_submit_button'),
                      text: 'Crear cuenta y continuar',
                      icon: Icons.arrow_forward,
                      isLoading: state.isLoading,
                      onPressed: () =>
                          _submitRegister(context, state.selectedRole),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
