import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/bloc/auth/auth_bloc.dart';
import 'package:freelance_hub_movil/bloc/auth/auth_state.dart';
import 'package:freelance_hub_movil/models/user_profile.dart';
import 'package:freelance_hub_movil/screens/auth/register_screen.dart';
import 'package:freelance_hub_movil/services/auth_service.dart';
import 'package:freelance_hub_movil/utils/form_validators.dart';

class FakeAuthService extends AuthService {
  String? lastRegisteredName;
  String? lastRegisteredEmail;
  String? lastRegisteredRole;

  @override
  Future<AuthResult> registerWithResult({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    lastRegisteredName = name;
    lastRegisteredEmail = email;
    lastRegisteredRole = role;

    return AuthResult(
      success: true,
      token: 'fake_jwt_token',
      user: UserProfile(
        id: 'uuid-1234',
        fullName: name,
        email: email,
        role: role,
        location: 'Ciudad de México, MX',
        bio: 'Perfil creado desde pruebas',
        skills: const ['Flutter', 'Dart'],
      ),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FormValidators - Validadores de TextFormField', () {
    test('validateName rechaza vacío o menos de 2 caracteres y acepta nombres válidos', () {
      expect(FormValidators.validateName(''), isNotNull);
      expect(FormValidators.validateName('A'), isNotNull);
      expect(FormValidators.validateName('Sofía Morales'), isNull);
    });

    test('validateEmail rechaza formatos inválidos y acepta correos válidos', () {
      expect(FormValidators.validateEmail(''), isNotNull);
      expect(FormValidators.validateEmail('correo-invalido'), isNotNull);
      expect(FormValidators.validateEmail('sofia@empresa.com'), isNull);
    });

    test('validatePassword exige mínimo 8 caracteres, al menos 1 letra y 1 número', () {
      expect(FormValidators.validatePassword(''), isNotNull);
      expect(FormValidators.validatePassword('Ab1'), isNotNull);
      expect(FormValidators.validatePassword('SoloLetrasPassword'), isNotNull);
      expect(FormValidators.validatePassword('123456789'), isNotNull);
      expect(FormValidators.validatePassword('Password123'), isNull);
    });
  });

  group('RegisterScreen - Selector interactivo de rol, validadores y AuthBloc', () {
    testWidgets('Permite alternar interactivamente entre CLIENT y FREELANCER y valida el formulario', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeAuthService();
      final authBloc = AuthBloc(authService: fakeService);

      await tester.pumpWidget(
        BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      // Por defecto el rol seleccionado es CLIENT
      expect(authBloc.state.selectedRole, equals('CLIENT'));

      // Seleccionar interactivamente la tarjeta de FREELANCER
      await tester.tap(find.byKey(const Key('role_card_freelancer')));
      await tester.pumpAndSettle();
      expect(authBloc.state.selectedRole, equals('FREELANCER'));

      // Intentar enviar formulario vacío -> debe mostrar errores de validación en TextFormField
      await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pump();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(find.text('El correo electrónico es obligatorio'), findsOneWidget);
      expect(find.text('La contraseña es obligatoria'), findsOneWidget);

      // Llenar el formulario con datos válidos y enviar
      await tester.enterText(
        find.byKey(const Key('register_name_field')),
        'Sofía Morales',
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'sofia@freelancerhub.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'ClaveSegura2026',
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeService.lastRegisteredName, equals('Sofía Morales'));
      expect(fakeService.lastRegisteredEmail, equals('sofia@freelancerhub.com'));
      expect(fakeService.lastRegisteredRole, equals('FREELANCER'));
      expect(authBloc.state.status, equals(AuthStatus.authenticated));
    });
  });
}
