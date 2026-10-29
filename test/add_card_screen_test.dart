import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:freelance_hub_movil/screens/payment/add_card_screen.dart';
import 'package:freelance_hub_movil/utils/card_input_formatters.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AddCardScreen - Diseño, Formateo Reactivo y Validación PCI-DSS', () {
    test('CardBrandDetector reconoce marcas principales Visa, Mastercard y Amex', () {
      expect(CardBrandDetector.detect('4123 4567 8901 2345'), equals(CardBrand.visa));
      expect(CardBrandDetector.detect('5200 1234 5678 9010'), equals(CardBrand.mastercard));
      expect(CardBrandDetector.detect('3782 822463 10005'), equals(CardBrand.amex));
      expect(CardBrandDetector.detect(''), equals(CardBrand.generic));
    });

    test('CardNumberInputFormatter formatea automáticamente en bloques de 4 dígitos', () {
      final formatter = CardNumberInputFormatter();
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: '4000123456789010');

      final formatted = formatter.formatEditUpdate(oldValue, newValue);
      expect(formatted.text, equals('4000 1234 5678 9010'));
    });

    test('CardExpiryInputFormatter inserta automáticamente la pleca en MM/AA', () {
      final formatter = CardExpiryInputFormatter();
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(text: '1228');

      final formatted = formatter.formatEditUpdate(oldValue, newValue);
      expect(formatted.text, equals('12/28'));
    });

    testWidgets('Renderiza la tarjeta visual, campos con teclado numérico y banner PCI-DSS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddCardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Título y sello de seguridad
      expect(find.text('Registrar Tarjeta'), findsOneWidget);
      expect(find.text('PCI-DSS'), findsOneWidget);

      // 2. Elementos de la tarjeta visual
      expect(find.text('FREELANCER HUB'), findsOneWidget);
      expect(find.text('TITULAR'), findsOneWidget);
      expect(find.text('EXPIRA'), findsOneWidget);

      // 3. Campos del formulario
      expect(find.byKey(const Key('card_number_field')), findsOneWidget);
      expect(find.byKey(const Key('cardholder_name_field')), findsOneWidget);
      expect(find.byKey(const Key('card_expiry_field')), findsOneWidget);
      expect(find.byKey(const Key('card_cvv_field')), findsOneWidget);

      // 4. Banner informativo de seguridad
      expect(find.text('Cifrado Bancario de Nivel 1 (PCI-DSS)'), findsOneWidget);
    });

    testWidgets('Formatea reactivamente los campos e interactúa con la tarjeta visual', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddCardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Ingresar número de tarjeta Visa
      await tester.enterText(
        find.byKey(const Key('card_number_field')),
        '4000123456789010',
      );
      await tester.pump();

      // Ingresar titular
      await tester.enterText(
        find.byKey(const Key('cardholder_name_field')),
        'DIEGO HERNANDEZ',
      );
      await tester.pump();

      // Ingresar fecha de expiración
      await tester.enterText(
        find.byKey(const Key('card_expiry_field')),
        '1129',
      );
      await tester.pump();

      // Ingresar CVV
      await tester.enterText(
        find.byKey(const Key('card_cvv_field')),
        '789',
      );
      await tester.pump();

      // La tarjeta visual debe reflejar los datos reactivos
      expect(find.text('DIEGO HERNANDEZ'), findsWidgets);
      expect(find.text('11/29'), findsWidgets);
      expect(find.text('VISA'), findsWidgets);

      // Guardar tarjeta
      await tester.ensureVisible(find.byKey(const Key('save_card_button')));
      await tester.tap(find.byKey(const Key('save_card_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
    });
  });
}
