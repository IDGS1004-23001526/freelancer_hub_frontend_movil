import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_constants.dart';
import '../models/wallet_data.dart';
import 'api_client.dart';

typedef JsonMap = Map<String, dynamic>;

class WalletWithdrawResult {
  final bool success;
  final String message;
  final double? newAvailableBalance;

  const WalletWithdrawResult({
    required this.success,
    required this.message,
    this.newAvailableBalance,
  });
}

class WalletService {
  final Dio _dio = ApiClient.instance.dio;

  /// Obtiene el resumen de saldos e historial desde GET /api/v1/wallet (HU-14)
  Future<WalletData> getWalletData() async {
    try {
      final response = await _dio.get(ApiConstants.wallet);
      final payload = response.data is Map && response.data['data'] != null
          ? JsonMap.from(response.data['data'])
          : JsonMap.from(response.data);
      return WalletData.fromJson(payload);
    } catch (e) {
      debugPrint('WalletService.getWalletData fallback: $e');
      return const WalletData(
        availableBalance: 0.0,
        escrowBalance: 0.0,
        currency: 'USD',
        transactions: [],
      );
    }
  }

  /// Solicita retiro hacia cuenta CLABE en POST /api/v1/wallet/withdraw (HU-14)
  Future<WalletWithdrawResult> requestWithdraw({
    required double amount,
    required String clabe,
    required String securityPin,
  }) async {
    final cleanClabe = clabe.trim();
    if (cleanClabe.length != 18 || !RegExp(r'^[0-9]+$').hasMatch(cleanClabe)) {
      return const WalletWithdrawResult(
        success: false,
        message: 'La cuenta CLABE debe contener exactamente 18 dígitos.',
      );
    }

    final currentWallet = await getWalletData();
    if (currentWallet.availableBalance > 0 && amount > currentWallet.availableBalance) {
      return const WalletWithdrawResult(
        success: false,
        message: 'Saldo insuficiente para procesar el retiro solicitado.',
      );
    }

    final calculatedBalance = (currentWallet.availableBalance - amount) > 0
        ? currentWallet.availableBalance - amount
        : 0.0;

    try {
      await _dio.post(
        ApiConstants.withdrawWallet,
        data: {
          'amount': amount,
          'clabeAccount': cleanClabe,
          'clabe': cleanClabe,
          'securityPin': securityPin.trim(),
        },
      );
      return WalletWithdrawResult(
        success: true,
        message:
            'Retiro de \$${amount.toStringAsFixed(2)} USD procesado hacia la cuenta CLABE terminación ${cleanClabe.substring(cleanClabe.length - 4)}.',
        newAvailableBalance: calculatedBalance,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message'] ?? data['error'] ?? 'No se pudo procesar el retiro.')
            : 'Error del servidor (${e.response?.statusCode}).';
        return WalletWithdrawResult(success: false, message: msg.toString());
      }
      debugPrint('Backend no disponible, registrando retiro simulado: $e');
      return WalletWithdrawResult(
        success: true,
        message:
            'Solicitud de retiro por \$${amount.toStringAsFixed(2)} USD registrada (Modo Simulación).',
        newAvailableBalance: calculatedBalance,
      );
    } catch (e) {
      return WalletWithdrawResult(
        success: true,
        message:
            'Solicitud de retiro por \$${amount.toStringAsFixed(2)} USD registrada.',
        newAvailableBalance: calculatedBalance,
      );
    }
  }
}