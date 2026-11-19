import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:freelance_hub_movil/main.dart' as app;

void main() {
  // Inicializa el binding de pruebas de integración (equivalente a inicializar el navegador en Playwright)
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas E2E de Flujo de Autenticación', () {
    testWidgets('Automatización completa: Onboarding -> Login -> Validación de campos', (WidgetTester tester) async {
      // 1. Iniciar la aplicación
      app.main();
      await tester.pumpAndSettle();

      // 2. Verificar que se cargó la pantalla de Onboarding
      expect(find.text('Freelance'), findsOneWidget);
      expect(find.text('Crear Cuenta'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);

      // 3. Simular clic en el botón 'Ingresar' (como page.click('text=Ingresar') en Playwright)
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      // 4. Verificar que navegamos a la pantalla de Inicio de Sesión
      expect(find.text('Iniciar Sesión'), findsWidgets);
      expect(find.text('Estás a un paso de tu próximo gran proyecto'), findsOneWidget);

      // 5. Intentar enviar el formulario vacío para validar que saltan los errores
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      // Deben aparecer los mensajes de validación
      expect(find.text('El correo electrónico es obligatorio'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);

      // 6. Encontrar los campos de texto y escribir credenciales (como page.fill() en Playwright)
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      // Campo de correo electrónico
      await tester.enterText(textFields.at(0), 'usuario.prueba@dominio.com');
      // Campo de contraseña
      await tester.enterText(textFields.at(1), 'Password123');
      await tester.pumpAndSettle();

      // 7. Simular clic en 'Iniciar sesión' con datos ingresados
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
    });
  });
}
