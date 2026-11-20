import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freelance_hub_movil/models/wallet_data.dart';
import 'package:freelance_hub_movil/services/milestone_service.dart';
import 'package:freelance_hub_movil/services/wallet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  group('Pruebas de HU-07: Aprobación de Hitos (FLH-MOB-APPROVE)', () {
    test('MilestoneService aprueba hito y retorna estado COMPLETADO', () async {
      final service = MilestoneService();
      final result = await service.approveAndReleaseFunds(milestoneId: 'milestone-01');

      expect(result.success, true);
      expect(result.newStatus, 'COMPLETADO');
      expect(result.message, contains('liberados exitosamente'));
    });

    test('MilestoneService solicita ajustes y cambia estado a EN_CORRECCION', () async {
      final service = MilestoneService();
      final result = await service.requestAdjustments(
        milestoneId: 'milestone-01',
        justification: 'Faltan pruebas unitarias y cobertura de código.',
      );

      expect(result.success, true);
      expect(result.newStatus, 'EN_CORRECCION');
      expect(result.message, contains('corrección'));
    });
  });

  group('Pruebas de HU-14: Billetera Digital y Retiros (FLH-MOB-WALLET)', () {
    test('WalletData y WalletTransaction serializan y calculan desglose correctamente', () {
      final tx = WalletTransaction(
        id: 'tx-test',
        title: 'Entrega de Hito 1',
        milestoneLabel: 'H1',
        grossAmount: 1000.0,
        platformFee: 50.0,
        netAmount: 950.0,
        date: DateTime.now(),
        status: 'completed',
      );

      final map = tx.toMap();
      final fromMap = WalletTransaction.fromMap(map);

      expect(fromMap.id, 'tx-test');
      expect(fromMap.grossAmount, 1000.0);
      expect(fromMap.platformFee, 50.0);
      expect(fromMap.netAmount, 950.0);
    });

    test('WalletService rechaza retiro que excede el saldo disponible', () async {
      final service = WalletService();
      final wallet = await service.getWalletData();

      final excessiveAmount = wallet.availableBalance + 5000.0;
      final result = await service.requestWithdraw(
        amount: excessiveAmount,
        clabe: '012180015678901234',
        securityPin: '1234',
      );

      expect(result.success, false);
      expect(result.message, contains('Saldo insuficiente'));
    });

    test('WalletService rechaza CLABE inválida con menos de 18 dígitos', () async {
      final service = WalletService();

      final result = await service.requestWithdraw(
        amount: 100.0,
        clabe: '12345678', // Inválida
        securityPin: '1234',
      );

      expect(result.success, false);
      expect(result.message, contains('18 dígitos'));
    });

    test('WalletService procesa retiro válido y actualiza saldo', () async {
      final service = WalletService();
      final initialWallet = await service.getWalletData();
      const withdrawAmount = 200.0;

      final result = await service.requestWithdraw(
        amount: withdrawAmount,
        clabe: '012180015678901234',
        securityPin: '1234',
      );

      expect(result.success, true);
      expect(result.newAvailableBalance, initialWallet.availableBalance - withdrawAmount);
    });
  });
}
