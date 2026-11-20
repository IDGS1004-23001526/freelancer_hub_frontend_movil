import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/bloc/auth/auth_bloc.dart';
import 'package:freelance_hub_movil/bloc/auth/auth_state.dart';
import 'package:freelance_hub_movil/models/user_profile.dart';
import 'package:freelance_hub_movil/screens/auth/register_screen.dart';
import 'package:freelance_hub_movil/screens/profile/profile_screen.dart';
import 'package:freelance_hub_movil/services/auth_service.dart';

class MockWizardAuthService extends AuthService {
  String? registeredName;
  String? registeredEmail;
  String? registeredRole;

  @override
  Future<AuthResult> registerWithResult({
    required String name,
    required String email,
    required String password,
    required String role,
    String? location,
    String? phone,
    String? bio,
    List<String>? skills,
  }) async {
    registeredName = name;
    registeredEmail = email;
    registeredRole = role;

    return AuthResult(
      success: true,
      token: 'jwt_wizard_test',
      user: UserProfile(
        id: 'user_wizard_1',
        fullName: name,
        email: email,
        role: role,
        location: location ?? '',
        bio: bio ?? '',
        phone: phone ?? '',
        skills: skills ?? const [],
      ),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Flujo Multi-paso de Registro y Completitud de Perfil', () {
    testWidgets('Wizard de 3 pasos avanza tras credenciales y permite configurar ubicación y habilidades', (
      WidgetTester tester,
    ) async {
      final mockAuth = MockWizardAuthService();
      final authBloc = AuthBloc(authService: mockAuth);

      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PASO 1: Verificar que estamos en Paso 1 de 3 (Cuenta y Credenciales)
      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Comencemos con tu cuenta'), findsOneWidget);

      // Seleccionar rol Freelancer
      await tester.tap(find.byKey(const Key('role_card_freelancer')));
      await tester.pumpAndSettle();

      // Llenar datos de cuenta
      await tester.enterText(find.byKey(const Key('register_name_field')), 'Carlos Developer');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'carlos@empresa.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'Password2026!');
      await tester.pump();

      // Pulsar crear cuenta y avanzar
      await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      // Verificar que se registró la cuenta en backend
      expect(mockAuth.registeredName, equals('Carlos Developer'));
      expect(mockAuth.registeredEmail, equals('carlos@empresa.com'));

      // PASO 2: Debe avanzar automáticamente al Paso 2 de 3 (Ubicación y Contacto)
      expect(find.text('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Ubicación y contacto'), findsOneWidget);

      // Ingresar ubicación y teléfono
      await tester.enterText(find.widgetWithText(TextField, 'Ej. Guadalajara, México o Remoto'), 'Guadalajara, Jalisco');
      await tester.enterText(find.widgetWithText(TextField, 'Ej. +52 33 1234 5678'), '+52 33 9999 8888');
      await tester.pump();

      // Continuar al paso 3
      await tester.ensureVisible(find.text('Continuar al perfil profesional'));
      await tester.tap(find.text('Continuar al perfil profesional'));
      await tester.pumpAndSettle();

      // PASO 3: Debe estar en Paso 3 de 3 (Perfil Profesional)
      expect(find.text('Paso 3 de 3'), findsOneWidget);
      expect(find.text('Selecciona tus habilidades principales:'), findsOneWidget);

      // Seleccionar una habilidad interactiva (Flutter)
      expect(find.text('Flutter'), findsOneWidget);
      await tester.ensureVisible(find.text('Flutter'));
      await tester.tap(find.text('Flutter'));
      await tester.pumpAndSettle();

      // Verificar botón de finalizar
      expect(find.text('Finalizar y Comenzar'), findsOneWidget);
    });

    testWidgets('Perfil incompleto muestra banner de alerta y porcentaje real sin datos inventados', (
      WidgetTester tester,
    ) async {
      final incompleteUser = UserProfile(
        id: 'user_inc_1',
        fullName: 'Ana Martínez',
        email: 'ana@ejemplo.com',
        role: 'FREELANCER',
        location: '', // Vacío a propósito
        bio: '',      // Vacío a propósito
        phone: '',    // Vacío a propósito
        skills: const [], // Vacío a propósito
      );

      final authBloc = AuthBloc();
      authBloc.emit(AuthState(
        status: AuthStatus.authenticated,
        user: incompleteUser,
      ));

      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el banner de perfil incompleto (solo 25% completado: nombre)
      expect(find.text('Tu perfil está al 25% completado'), findsOneWidget);
      expect(find.text('Completar perfil ahora'), findsOneWidget);

      // No debe contener 'Ciudad de México, MX' hardcodeado
      expect(find.text('Ciudad de México, MX'), findsNothing);

      // Debe mostrar el estado vacío elegante
      expect(find.text('Sin ubicación especificada'), findsOneWidget);
      expect(find.text('Sin biografía añadida todavía.'), findsOneWidget);
      expect(find.text('Añadir habilidades profesionales'), findsOneWidget);
    });
  });
}
