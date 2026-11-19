import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/models/user_profile.dart';
import 'package:freelance_hub_movil/screens/profile/edit_profile_screen.dart';
import 'package:freelance_hub_movil/services/profile_service.dart';
import 'package:freelance_hub_movil/utils/form_validators.dart';

class FakeProfileService extends ProfileService {
  UserProfile? lastUpdatedUser;

  @override
  Future<bool> updateProfile(UserProfile user) async {
    lastUpdatedUser = user;
    return true;
  }

  @override
  Future<String?> uploadAvatar(File imageFile) async {
    return 'https://freelancerhub.com/avatars/test.jpg';
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Historia de Usuario: Completar y Editar Perfil (Criterios Gherkin)', () {
    final testUserFreelancer = UserProfile(
      id: 'uuid-test-1',
      firstName: 'Diego',
      lastName: 'García',
      fullName: 'Diego García',
      email: 'diego@freelancerhub.com',
      role: 'FREELANCER',
      location: 'León, Guanajuato',
      bio: 'Desarrollador backend y móvil con experiencia en Flutter.',
      phone: '+52 477 123 4567',
      skills: ['Flutter', 'Node.js', 'PostgreSQL'],
    );

    final testUserClient = UserProfile(
      id: 'uuid-test-2',
      firstName: 'María',
      lastName: 'Fernández',
      fullName: 'María Fernández',
      email: 'maria@empresa.com',
      role: 'CLIENT',
      location: 'Monterrey, NL',
      bio: 'Líder de proyectos buscando desarrolladores móviles.',
      phone: '+52 81 9876 5432',
      skills: ['Desarrollo Móvil', 'Diseño UI/UX'],
    );

    test('Validadores de formulario de perfil: Nombre, Apellidos y Teléfono', () {
      // Validador de nombre
      expect(FormValidators.validateName(''), isNotNull);
      expect(FormValidators.validateName('A'), isNotNull);
      expect(FormValidators.validateName('Diego'), isNull);

      // Validador de apellidos
      expect(FormValidators.validateLastName(''), isNotNull);
      expect(FormValidators.validateLastName('G'), isNotNull);
      expect(FormValidators.validateLastName('García'), isNull);

      // Validador de teléfono
      expect(FormValidators.validatePhone(''), isNull); // opcional si está vacío
      expect(FormValidators.validatePhone('telefono-invalido'), isNotNull);
      expect(FormValidators.validatePhone('+52 477 123 4567'), isNull);
    });

    testWidgets('Escenario 1: Pre-llenado de datos (correo, rol) y campos según rol FREELANCER', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            user: testUserFreelancer,
            profileService: FakeProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el correo registrado previamente
      expect(find.text('diego@freelancerhub.com'), findsOneWidget);

      // Debe mostrar badge de rol FREELANCER
      expect(find.byWidgetPredicate((w) => w is Text && w.data == 'FREELANCER'), findsWidgets);

      // Debe mostrar prellenados nombre, apellidos, teléfono y biografía
      expect(find.text('Diego'), findsOneWidget);
      expect(find.text('García'), findsOneWidget);
      expect(find.text('+52 477 123 4567'), findsOneWidget);

      // Sección de habilidades para Freelancer
      expect(find.text('Habilidades Técnicas'), findsOneWidget);
    });

    testWidgets('Escenario 1 (Variante CLIENTE): Pre-llenado y campos según rol CLIENT', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            user: testUserClient,
            profileService: FakeProfileService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Correo y badge de cliente
      expect(find.text('maria@empresa.com'), findsOneWidget);
      expect(find.text('CLIENTE'), findsOneWidget);

      // Preferencias para cliente
      expect(find.text('Preferencias de Contratación'), findsOneWidget);
    });

    testWidgets('Escenario 2: Edición y guardado exitoso con mensaje de éxito', (
      WidgetTester tester,
    ) async {
      final fakeService = FakeProfileService();
      UserProfile? returnedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_edit_btn'),
                onPressed: () async {
                  returnedUser = await Navigator.push<UserProfile>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        user: testUserFreelancer,
                        profileService: fakeService,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      // Abrir pantalla de edición
      await tester.tap(find.byKey(const Key('open_edit_btn')));
      await tester.pumpAndSettle();

      // Actualizar biografía y teléfono
      await tester.enterText(
        find.byKey(const Key('edit_bio_field')),
        'Nueva biografía profesional actualizada con éxito.',
      );
      await tester.enterText(
        find.byKey(const Key('edit_phone_field')),
        '+52 477 999 8888',
      );
      await tester.pump();

      // Hacer clic en Guardar Cambios
      await tester.ensureVisible(find.byKey(const Key('edit_profile_submit_button')));
      await tester.tap(find.byKey(const Key('edit_profile_submit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe mostrar el mensaje de éxito requerido
      expect(find.text('¡Perfil actualizado con éxito!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(returnedUser, isNotNull);
      expect(returnedUser!.phone, equals('+52 477 999 8888'));
      expect(returnedUser!.bio, equals('Nueva biografía profesional actualizada con éxito.'));
      expect(fakeService.lastUpdatedUser, isNotNull);
    });
  });
}
