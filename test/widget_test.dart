import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_hub_movil/main.dart';

void main() {
  testWidgets('App onboarding screen smoke test', (WidgetTester tester) async {
    // Build our app with no active session and trigger a frame.
    await tester.pumpWidget(const MyApp(hasActiveSession: false));

    // Verify that onboarding screen widgets are present.
    expect(find.text('Freelance'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
