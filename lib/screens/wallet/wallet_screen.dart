import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/wallet_data.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_colors.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  WalletData? _walletData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    final data = await _walletService.getWalletData();
    if (mounted) {
      setState(() {
        _walletData = data;
        _isLoading = false;
      });
    }
  }

  void _showWithdrawModal() {
    final available = _walletData?.availableBalance ?? 0.0;
    final TextEditingController amountController = TextEditingController();
    final TextEditingController clabeController = TextEditingController();
    final TextEditingController pinController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Solicitar Retiro de Fondos',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saldo disponible para transferir: \$${available.toStringAsFixed(2)} USD',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Campo de Importe
                    Text(
                      'Importe a retirar (USD)',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money, color: AppColors.primary),
                        hintText: '0.00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de Cuenta CLABE (18 dígitos)
                    Text(
                      'Cuenta Bancaria (CLABE interbancaria - 18 dígitos)',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: clabeController,
                      keyboardType: TextInputType.number,
                      maxLength: 18,
                      decoration: InputDecoration(
                        counterText: '',
                        prefixIcon: const Icon(Icons.account_balance, color: AppColors.primary),
                        hintText: 'Ej. 012180015678901234',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de PIN de seguridad
                    Text(
                      'PIN de Seguridad (4 dígitos)',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: InputDecoration(
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                        hintText: '****',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón confirmar retiro
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final textAmount = amountController.text.trim();
                                final double? amount = double.tryParse(textAmount);
                                final clabe = clabeController.text.trim();
                                final pin = pinController.text.trim();

                                if (amount == null || amount <= 0) {
                                  setModalState(() {
                                    errorText = 'Ingresa un importe válido mayor a 0.';
                                  });
                                  return;
                                }

                                if (amount > available) {
                                  setModalState(() {
                                    errorText =
                                        'El importe no puede superar el saldo disponible (\$${available.toStringAsFixed(2)}).';
                                  });
                                  return;
                                }

                                if (clabe.length != 18 || !RegExp(r'^[0-9]+$').hasMatch(clabe)) {
                                  setModalState(() {
                                    errorText = 'La cuenta CLABE debe contener exactamente 18 dígitos.';
                                  });
                                  return;
                                }

                                if (pin.length < 4) {
                                  setModalState(() {
                                    errorText = 'El PIN de seguridad debe contener al menos 4 dígitos.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  errorText = null;
                                });

                                final res = await _walletService.requestWithdraw(
                                  amount: amount,
                                  clabe: clabe,
                                  securityPin: pin,
                                );

                                if (res.success) {
                                  Navigator.pop(modalContext);
                                  await _fetchWallet();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message),
                                      backgroundColor: Colors.green.shade800,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorText = res.message;
                                  });
                                }
                              },
                        child: Text(
                          isSubmitting ? 'Procesando...' : 'Confirmar Retiro',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final wallet = _walletData!;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Billetera y Finanzas (HU-14)',
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchWallet,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tarjetas de saldos destacados
            Row(
              children: [
                // Saldo Disponible
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B1B29), Color(0xFF86273A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Saldo Disponible',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${wallet.availableBalance.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Listo para transferir',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Saldo en Garantía (Escrow)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5D9CB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_rounded, color: AppColors.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'En Garantía',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${wallet.escrowBalance.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Retenido en hitos',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Botón Solicitar Retiro
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showWithdrawModal,
                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Solicitar Retiro a Cuenta Bancaria',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Encabezado de últimos cobros
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Últimos Cobros y Movimientos',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Desglose neto',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Listado de transacciones con desglose de comisión
            if (wallet.transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No hay movimientos registrados.',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...wallet.transactions.map((tx) => _buildTransactionCard(tx)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(WalletTransaction tx) {
    final bool isWithdraw = tx.status == 'withdrawn';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isWithdraw ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      isWithdraw ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                      size: 18,
                      color: isWithdraw ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        tx.milestoneLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                isWithdraw
                    ? '-\$${tx.netAmount.toStringAsFixed(2)}'
                    : '+\$${tx.netAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isWithdraw ? Colors.red.shade700 : Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Desglose de comisión
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monto Bruto: \$${tx.grossAmount.toStringAsFixed(2)} · Comisión (5%): \$${tx.platformFee.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isWithdraw ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isWithdraw ? 'Retirado' : 'Completado',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isWithdraw ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
