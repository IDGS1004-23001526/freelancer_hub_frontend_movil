import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_hub_movil/models/delivery_file.dart';
import 'package:freelance_hub_movil/models/milestone.dart';
import 'package:freelance_hub_movil/services/delivery_service.dart';

void main() {
  group('Pruebas de HU-06 (FLH-MOB-DELIVERY)', () {
    test('Milestone toMap and fromMap deserializan correctamente', () {
      const milestone = Milestone(
        id: 'milestone-01',
        contractId: 'CT-2026-0418',
        label: 'H1',
        title: 'Arquitectura y Telemetría',
        order: 1,
        amount: '\$1,200 USD',
        isFunded: true,
        status: 'funded',
        clientName: 'Carlos Mendoza',
      );

      final map = milestone.toMap();
      final fromMap = Milestone.fromMap(map);

      expect(fromMap.id, 'milestone-01');
      expect(fromMap.contractId, 'CT-2026-0418');
      expect(fromMap.isFunded, true);
      expect(fromMap.label, 'H1');
      expect(fromMap.clientName, 'Carlos Mendoza');
    });

    test('DeliveryFile detecta extensiones y formatea pesos correctamente', () {
      const pdf = DeliveryFile(
        name: 'ADR_arquitectura.pdf',
        sizeInBytes: 2500000,
      );
      const image = DeliveryFile(
        name: 'diagrama_C4.png',
        sizeInBytes: 850000,
      );
      const zip = DeliveryFile(
        name: 'codigo_fuente.zip',
        sizeInBytes: 15000000,
      );

      expect(pdf.isPdf, true);
      expect(pdf.isImage, false);
      expect(image.isImage, true);
      expect(zip.isZip, true);
      expect(zip.sizeInMb, closeTo(14.3, 0.5));
    });

    test('DeliveryService valida límite de tamaño de archivo (máx 25 MB)', () async {
      final service = DeliveryService();
      const oversizedFile = DeliveryFile(
        name: 'archivo_pesado.zip',
        sizeInBytes: 26 * 1024 * 1024, // 26 MB (> 25MB)
      );

      final result = await service.submitDelivery(
        milestoneId: 'milestone-01',
        repositoryUrl: 'github.com/usuario/repo',
        technicalNotes: 'Notas técnicas',
        files: [oversizedFile],
      );

      expect(result.success, false);
      expect(result.message, contains('supera el límite máximo de 25 MB'));
    });
  });
}
