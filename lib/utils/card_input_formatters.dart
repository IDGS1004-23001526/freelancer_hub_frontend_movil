import 'package:flutter/services.dart';

/// Formateador reactivo que agrupa los dígitos de la tarjeta bancaria en bloques de 4 (XXXX XXXX XXXX XXXX).
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '').replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formateador reactivo para fecha de expiración con inserción automática de pleca (MM/AA).
class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '').replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Detecta la marca de la tarjeta (Visa, Mastercard, Amex, Discover) basada en el BIN inicial.
enum CardBrand { visa, mastercard, amex, discover, generic }

class CardBrandDetector {
  static CardBrand detect(String number) {
    final clean = number.replaceAll(' ', '');
    if (clean.isEmpty) return CardBrand.generic;

    if (clean.startsWith('4')) {
      return CardBrand.visa;
    }

    if (clean.length >= 2) {
      final prefix2 = int.tryParse(clean.substring(0, 2)) ?? 0;
      if (prefix2 == 34 || prefix2 == 37) {
        return CardBrand.amex;
      }
      if (prefix2 >= 51 && prefix2 <= 55) {
        return CardBrand.mastercard;
      }
    }

    if (clean.length >= 4) {
      final prefix4 = int.tryParse(clean.substring(0, 4)) ?? 0;
      if (prefix4 >= 2221 && prefix4 <= 2720) {
        return CardBrand.mastercard;
      }
      if (clean.startsWith('6011') || clean.startsWith('65')) {
        return CardBrand.discover;
      }
    }

    return CardBrand.generic;
  }

  static String getBrandName(CardBrand brand) {
    switch (brand) {
      case CardBrand.visa:
        return 'VISA';
      case CardBrand.mastercard:
        return 'Mastercard';
      case CardBrand.amex:
        return 'American Express';
      case CardBrand.discover:
        return 'Discover';
      case CardBrand.generic:
        return 'Tarjeta Bancaria';
    }
  }
}

