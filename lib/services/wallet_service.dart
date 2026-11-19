import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
import '../models/wallet_data.dart';
import 'auth_service.dart';

class WithdrawResult {
  final bool success;
  final String message;
  final String? transactionId;
  final double? newAvailableBalance;

  const WithdrawResult({
    required this.success,
    required this.message,
    this.transactionId,
    this.newAvailableBalance,
  });
}

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final AuthService _authService = AuthService();

  // Estado en memoria para simulación persistente
  WalletData _currentWallet = WalletData(
    availableBalance: 2400.0,
    escrowBalance: 1800.0,
    currency: 'USD',
    transactions: [
      WalletTransaction(
        id: 'tx-01',
        title: 'Arquitectura de Base de Datos y Telemetría',
        milestoneLabel: 'Hito 1 · Contrato CT-2026-0418',
        grossAmount: 1200.0,
        platformFee: 60.0, // 5% de comisión
        netAmount: 1140.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'completed',
      ),
      WalletTransaction(
        id: 'tx-02',
        title: 'Diseño UX/UI Sistema de Pagos',
        milestoneLabel: 'Hito 2 · Contrato CT-2026-0391',
        grossAmount: 1300.0,
        platformFee: 65.0,
        netAmount: 1235.0,
        date: DateTime.now().subtract(const Duration(days: 9)),
        status: 'completed',
      ),
    ],
  );

  /// Obtiene los datos de la billetera (GET /api/v1/wallet)
  Future<WalletData> getWalletData() async {
    final token = await _authService.getToken();
    try {
      final uri = Uri.parse(ApiConstants.wallet);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentWallet = WalletData.fromMap(data);
        return _currentWallet;
      }
    } catch (e) {
      debugPrint('Usando billetera en modo simulación/caché: $e');
    }
    return _currentWallet;
  }

  /// Solicita un retiro a cuenta bancaria CLABE (POST /api/v1/wallet/withdraw)
  Future<WithdrawResult> requestWithdraw({
    required double amount,
    required String clabe,
    required String securityPin,
  }) async {
    // 1. Criterio de Aceptación: Validar que el monto no supere el saldo disponible
    if (amount <= 0) {
      return const WithdrawResult(
        success: false,
        message: 'El importe a retirar debe ser mayor a 0.',
      );
    }

    if (amount > _currentWallet.availableBalance) {
      return WithdrawResult(
        success: false,
        message:
            'Saldo insuficiente. El monto solicitado (\$${amount.toStringAsFixed(2)}) excede tu saldo disponible (\$${_currentWallet.availableBalance.toStringAsFixed(2)}).',
      );
    }

    // 2. Validación de cuenta CLABE (18 dígitos numéricos)
    final cleanClabe = clabe.replaceAll(RegExp(r'\s+'), '');
    if (cleanClabe.length != 18 || !RegExp(r'^[0-9]+$').hasMatch(cleanClabe)) {
      return const WithdrawResult(
        success: false,
        message: 'La cuenta CLABE debe contener exactamente 18 dígitos numéricos.',
      );
    }

    // 3. Validación de PIN de seguridad
    if (securityPin.length < 4) {
      return const WithdrawResult(
        success: false,
        message: 'El PIN de seguridad debe contener al menos 4 dígitos.',
      );
    }

    final token = await _authService.getToken();
    try {
      final uri = Uri.parse(ApiConstants.walletWithdraw);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'clabe': cleanClabe,
          'pin': securityPin,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final newBalance = (data['newBalance'] as num?)?.toDouble() ??
            (_currentWallet.availableBalance - amount);
        _applyLocalWithdraw(amount, cleanClabe);
        return WithdrawResult(
          success: true,
          message: 'Retiro procesado exitosamente. Fondos en tránsito a tu cuenta.',
          transactionId: data['transactionId']?.toString(),
          newAvailableBalance: newBalance,
        );
      }
    } catch (e) {
      debugPrint('Retiro procesado en simulación local: $e');
    }

    // Descontar en el estado local simulado
    _applyLocalWithdraw(amount, cleanClabe);

    return WithdrawResult(
      success: true,
      message: 'Solicitud de retiro registrada (EN_PROCESO_DE_PAGO a CLABE ****${cleanClabe.substring(14)}).',
      transactionId: 'wd-${DateTime.now().millisecondsSinceEpoch}',
      newAvailableBalance: _currentWallet.availableBalance,
    );
  }

  void _applyLocalWithdraw(double amount, String clabe) {
    final updatedBalance = _currentWallet.availableBalance - amount;
    final newTx = WalletTransaction(
      id: 'tx-wd-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Retiro a Cuenta Bancaria (SPEI / CLABE)',
      milestoneLabel: 'Transferencia a ****${clabe.substring(14)}',
      grossAmount: amount,
      platformFee: 0.0,
      netAmount: amount,
      date: DateTime.now(),
      status: 'withdrawn',
      clabeAccount: clabe,
    );

    _currentWallet = _currentWallet.copyWith(
      availableBalance: updatedBalance,
      transactions: [newTx, ..._currentWallet.transactions],
    );
  }
}
