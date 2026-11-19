import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/main.dart';

void main() {
  setUpAll(() {
    // Desactiva la descarga de fuentes en runtime para entornos de pruebas rápidos
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Prueba Automatizada E2E de Flujo de Usuario (Estilo Playwright)', () {
    testWidgets('Robot navega Onboarding -> Login -> Valida campos -> Ingresa datos', (WidgetTester tester) async {
      // 1. Iniciar la aplicación
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 2. Verificar que se renderiza la pantalla de bienvenida (Onboarding)
      expect(find.text('Freelance'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
      expect(find.text('Crear Cuenta'), findsOneWidget);

      // 3. Simular clic en el botón 'Ingresar'
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      // 4. Verificar navegación a la pantalla de Login
      expect(find.text('Iniciar Sesión'), findsWidgets);

      // 5. Clic en 'Iniciar sesión' con campos vacíos para comprobar validaciones
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('El correo electrónico es obligatorio'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);

      // 6. Escribir en los campos de texto
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'usuario@ejemplo.com');
      await tester.enterText(textFields.at(1), 'Password123');
      await tester.pumpAndSettle();

      // Verificar que los errores de validación desaparecieron
      expect(find.text('El correo electrónico es obligatorio'), findsNothing);
      expect(find.text('Ingresa tu contraseña'), findsNothing);

      // 7. Clic en el botón para enviar
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
    });
  });
}
