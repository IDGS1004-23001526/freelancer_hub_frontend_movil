import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../utils/card_input_formatters.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _cardNumberController;
  late TextEditingController _cardHolderController;
  late TextEditingController _expiryController;
  late TextEditingController _cvvController;

  bool _isDefault = true;
  bool _obscureCvv = true;
  bool _isLoading = false;
  CardBrand _detectedBrand = CardBrand.generic;

  @override
  void initState() {
    super.initState();
    _cardNumberController = TextEditingController();
    _cardHolderController = TextEditingController();
    _expiryController = TextEditingController();
    _cvvController = TextEditingController();

    _cardNumberController.addListener(_onCardNumberChanged);
    _cardHolderController.addListener(_onFieldChanged);
    _expiryController.addListener(_onFieldChanged);
    _cvvController.addListener(_onFieldChanged);
  }

  void _onCardNumberChanged() {
    if (!mounted) return;
    final brand = CardBrandDetector.detect(_cardNumberController.text);
    if (brand != _detectedBrand) {
      setState(() => _detectedBrand = brand);
    } else {
      setState(() {});
    }
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_onCardNumberChanged);
    _cardHolderController.removeListener(_onFieldChanged);
    _expiryController.removeListener(_onFieldChanged);
    _cvvController.removeListener(_onFieldChanged);

    _cvvController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el número de tarjeta';
    }
    final clean = value.replaceAll(' ', '');
    if (clean.length < 15 || clean.length > 16) {
      return 'Debe contener 15 o 16 dígitos';
    }
    return null;
  }

  String? _validateCardHolder(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre del titular es obligatorio';
    }
    if (value.trim().length < 3) {
      return 'Ingresa el nombre completo del titular';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa MM/AA';
    }
    final clean = value.trim();
    if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(clean)) {
      return 'Formato inválido (MM/AA)';
    }
    final parts = clean.split('/');
    final month = int.tryParse(parts[0]) ?? 0;
    final year = (int.tryParse(parts[1]) ?? 0) + 2000;
    final now = DateTime.now();
    final cardDate = DateTime(year, month + 1, 0);

    if (cardDate.isBefore(now)) {
      return 'Tarjeta vencida';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa el CVV';
    }
    final clean = value.trim();
    if (clean.length < 3 || clean.length > 4) {
      return '3 o 4 dígitos';
    }
    return null;
  }

  Future<void> _handleSaveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulación de tokenización segura PCI-DSS y registro de método de pago
    await Future.delayed(const Duration(milliseconds: 900));

    // PCI-DSS: Eliminación inmediata del CVV en memoria tras verificación
    _cvvController.clear();

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.accentGreen,
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Tarjeta ${_detectedBrand == CardBrand.visa ? "Visa" : _detectedBrand == CardBrand.mastercard ? "Mastercard" : "bancaria"} registrada con éxito!',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
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
          'Registrar Tarjeta',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'PCI-DSS',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tarjeta Bancaria Visual e Interactiva
                _buildVisualCreditCard(),
                const SizedBox(height: 24),

                // 2. Encabezado de Datos
                Text(
                  'Datos de la Tarjeta',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Información bancaria protegida para custodia Escrow de contratos',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Campo: Número de Tarjeta con teclado numérico y formateo reactivo
                CustomTextField(
                  key: const Key('card_number_field'),
                  controller: _cardNumberController,
                  labelText: 'Número de Tarjeta',
                  hintText: '4000 1234 5678 9010',
                  prefixIcon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    CardNumberInputFormatter(),
                  ],
                  validator: _validateCardNumber,
                  suffixIcon: _buildBrandBadge(),
                ),
                const SizedBox(height: 14),

                // Campo: Nombre del Titular
                CustomTextField(
                  key: const Key('cardholder_name_field'),
                  controller: _cardHolderController,
                  labelText: 'Nombre del Titular',
                  hintText: 'NOMBRE COMO APARECE EN EL PLÁSTICO',
                  prefixIcon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.characters,
                  validator: _validateCardHolder,
                ),
                const SizedBox(height: 14),

                // Fila: Fecha de Expiración y Código CVV
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: CustomTextField(
                        key: const Key('card_expiry_field'),
                        controller: _expiryController,
                        labelText: 'Expiración',
                        hintText: 'MM/AA',
                        prefixIcon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          CardExpiryInputFormatter(),
                        ],
                        validator: _validateExpiry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: CustomTextField(
                        key: const Key('card_cvv_field'),
                        controller: _cvvController,
                        labelText: 'CVV / CVC',
                        hintText: '123',
                        prefixIcon: Icons.shield_outlined,
                        obscureText: _obscureCvv,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: _validateCvv,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCvv ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Switch: Método predeterminado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.star_outline, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Método Predeterminado',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Usar para fondeo de contratos Escrow',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isDefault,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isDefault = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Banner de Cumplimiento PCI-DSS & Escrow
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cifrado Bancario de Nivel 1 (PCI-DSS)',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tus datos viajan con encriptación SSL de 256 bits. El código de seguridad CVV se verifica al instante y se destruye en memoria sin almacenarse.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Botón Principal
                PrimaryButton(
                  key: const Key('save_card_button'),
                  text: 'Guardar Tarjeta Bancaria',
                  isLoading: _isLoading,
                  onPressed: _handleSaveCard,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de Crédito Visual con gradiente borgoña y elementos reactivos en tiempo real
  Widget _buildVisualCreditCard() {
    final rawNumber = _cardNumberController.text.replaceAll(' ', '');
    final displayHolder = _cardHolderController.text.trim().isEmpty
        ? 'NOMBRE DEL TITULAR'
        : _cardHolderController.text.trim().toUpperCase();
    final displayExpiry = _expiryController.text.trim().isEmpty
        ? 'MM/AA'
        : _expiryController.text.trim();

    return Container(
      width: double.infinity,
      height: 215,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6B1D2F), // Color borgoña característico de la plataforma
            Color(0xFF4A101E),
            Color(0xFF2E0711),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1D2F).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cabecera de la tarjeta: Título de plataforma y Badge de Marca
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FREELANCER HUB',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              _buildBrandLogoWhite(),
            ],
          ),

          // Chip EMV Dorado y Símbolo Contactless
          Row(
            children: [
              Container(
                width: 42,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFE6BE8A),
                      Color(0xFFD4AF37),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black.withOpacity(0.3), width: 0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.wifi,
                color: Colors.white.withOpacity(0.7),
                size: 22,
              ),
            ],
          ),

          // Número de tarjeta reactivo con formato de 4 bloques
          Text(
            _formatCardNumberDisplay(rawNumber),
            style: GoogleFonts.spaceMono(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),

          // Pie de la tarjeta: Titular y Expiración
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TITULAR',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayHolder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EXPIRA',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayExpiry,
                    style: GoogleFonts.spaceMono(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCardNumberDisplay(String raw) {
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      if (i < raw.length) {
        buffer.write(raw[i]);
      } else {
        buffer.write('•');
      }
    }
    return buffer.toString();
  }

  Widget _buildBrandLogoWhite() {
    switch (_detectedBrand) {
      case CardBrand.visa:
        return Text(
          'VISA',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        );
      case CardBrand.mastercard:
        return Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      case CardBrand.amex:
        return Text(
          'AMEX',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        );
      default:
        return Icon(
          Icons.credit_card,
          color: Colors.white.withOpacity(0.8),
          size: 24,
        );
    }
  }

  Widget _buildBrandBadge() {
    if (_detectedBrand == CardBrand.generic) {
      return const SizedBox(width: 0);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              CardBrandDetector.getBrandName(_detectedBrand),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
