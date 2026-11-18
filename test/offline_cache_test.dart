import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_hub_movil/models/convocatoria.dart';
import 'package:freelance_hub_movil/models/offline_action.dart';

void main() {
  group('Pruebas unitarias de Modelos Offline', () {
    test('Convocatoria toMap and fromMap serializan correctamente', () {
      const conv = Convocatoria(
        id: 'conv-test-1',
        title: 'App Móvil Flutter',
        companyName: 'Nexo Commerce',
        companyInitial: 'N',
        postedTime: 'Hace 2 h',
        budget: '\$2,400 USD',
        duration: '30 días',
        skills: ['Flutter', '.NET Core'],
        category: 'Móvil',
        description: 'Descripción de prueba',
        isApplied: false,
      );

      final map = conv.toMap();
      final fromMap = Convocatoria.fromMap(map);

      expect(fromMap.id, 'conv-test-1');
      expect(fromMap.title, 'App Móvil Flutter');
      expect(fromMap.companyName, 'Nexo Commerce');
      expect(fromMap.skills, contains('Flutter'));
      expect(fromMap.isApplied, false);
    });

    test('Convocatoria copyWith actualiza isApplied', () {
      const conv = Convocatoria(
        id: 'conv-1',
        title: 'Prueba',
        companyName: 'Empresa',
        companyInitial: 'E',
        postedTime: 'Hoy',
        budget: '\$100',
        duration: '5 días',
        skills: ['Dart'],
        category: 'Desarrollo',
      );

      final updated = conv.copyWith(isApplied: true);
      expect(updated.isApplied, true);
      expect(conv.isApplied, false);
    });

    test('OfflineAction encola y parsea payload correctamente', () {
      final action = OfflineAction(
        id: 'act-101',
        type: 'postulacion',
        convocatoriaId: 'conv-test-1',
        payload: {
          'convocatoriaId': 'conv-test-1',
          'monto': '\$2,000 USD',
          'mensaje': 'Cuento con experiencia en Flutter',
        },
        createdAt: DateTime.now(),
      );

      final map = action.toMap();
      final fromMap = OfflineAction.fromMap(map);

      expect(fromMap.id, 'act-101');
      expect(fromMap.type, 'postulacion');
      expect(fromMap.convocatoriaId, 'conv-test-1');
      expect(fromMap.payload['monto'], '\$2,000 USD');
      expect(fromMap.status, 'pending');
    });
  });
}
