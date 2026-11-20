import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_hub_movil/models/convocatoria.dart';
import 'package:freelance_hub_movil/models/proposal.dart';
import 'package:freelance_hub_movil/screens/proposals/project_detail_screen.dart';
import 'package:freelance_hub_movil/screens/proposals/proposal_submission_screen.dart';
import 'package:freelance_hub_movil/screens/proposals/proposal_submitted_screen.dart';
import 'package:freelance_hub_movil/services/proposal_service.dart';

class _FakeProposalService extends ProposalService {
  final ProposalSubmissionResult resultToReturn;
  ProposalRequest? lastRequest;

  _FakeProposalService(this.resultToReturn);

  @override
  Future<ProposalSubmissionResult> submitProposal(
    ProposalRequest request,
  ) async {
    lastRequest = request;
    return resultToReturn;
  }
}

void main() {
  final sampleConvocatoria = Convocatoria(
    id: 'proj-123',
    title: 'E-commerce móvil con pasarela de pagos',
    company: 'Nexo Commerce',
    timeAgo: 'Hace 2 h · Convocatoria activa',
    category: 'Desarrollo móvil',
    tags: const ['Flutter', '.NET Core', 'SQL Server'],
    budget: 2400,
    remainingDays: 30,
    paymentType: 'Precio fijo',
    remoteType: 'Remoto',
  );

  testWidgets(
    'Valida suma de hitos en tiempo real, agrega/quita hitos y bloquea envío si hay discrepancia',
    (WidgetTester tester) async {
      final fakeService = _FakeProposalService(
        const ProposalSubmissionResult(
          success: true,
          message: 'Propuesta enviada',
          proposalId: 'prop-1',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProposalSubmissionScreen(
            convocatoria: sampleConvocatoria,
            proposalService: fakeService,
          ),
        ),
      );

      // Estado inicial válido ($2,400 == $2,400)
      expect(find.text('Prepara tu propuesta'), findsOneWidget);
      expect(find.text('Cotización validada'), findsOneWidget);
      expect(find.text('\$0 USD'), findsOneWidget);

      // Añadir un segundo hito
      await tester.ensureVisible(find.text('+ Añadir hito'));
      await tester.tap(find.text('+ Añadir hito'));
      await tester.pumpAndSettle();

      expect(find.text('2 hitos · 37 días'), findsOneWidget);

      // Cambiar el monto del primer hito a 1000 para generar discrepancia ($1,000 vs $2,400)
      final amountFields = find.widgetWithText(TextFormField, '2400');
      expect(amountFields, findsWidgets); // Total + Hito 1
      await tester.enterText(amountFields.last, '1000');
      await tester.pumpAndSettle();

      expect(find.text('Los montos no coinciden'), findsOneWidget);
      expect(find.text('Diferencia faltante'), findsOneWidget);

      // Botón Enviar Propuesta deshabilitado
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar Propuesta'),
      );
      expect(submitButton.onPressed, isNull);

      // Completar el segundo hito con 1400 -> vuelve a coincidir ($1,000 + $1,400 = $2,400)
      final secondAmountField = find.widgetWithText(TextFormField, '600');
      await tester.enterText(secondAmountField.last, '1400');
      await tester.pumpAndSettle();

      expect(find.text('Cotización validada'), findsOneWidget);

      // Eliminar el segundo hito
      final removeButtons = find.byTooltip('Eliminar hito');
      await tester.ensureVisible(removeButtons.last);
      await tester.tap(removeButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('1 hito · 30 días'), findsOneWidget);
    },
  );

  testWidgets(
    'Envía propuesta válida y navega a ProposalSubmittedScreen',
    (WidgetTester tester) async {
      final fakeService = _FakeProposalService(
        const ProposalSubmissionResult(
          success: true,
          message: 'Propuesta enviada correctamente.',
          proposalId: 'prop-999',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProposalSubmissionScreen(
            convocatoria: sampleConvocatoria,
            proposalService: fakeService,
          ),
        ),
      );

      // Llenar descripción del entregable y carta de presentación
      final deliverableField =
          find.widgetWithText(TextFormField, 'Ej. Prototipo y arquitectura técnica');
      await tester.ensureVisible(deliverableField);
      await tester.enterText(deliverableField, 'App Flutter y API completa');

      final coverLetterField = find.byType(TextFormField).last;
      await tester.ensureVisible(coverLetterField);
      await tester.enterText(
        coverLetterField,
        'Hola equipo, tengo experiencia construyendo apps e-commerce en Flutter.',
      );
      await tester.pumpAndSettle();

      // Enviar propuesta
      final submitFinder = find.widgetWithText(ElevatedButton, 'Enviar Propuesta');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(fakeService.lastRequest, isNotNull);
      expect(fakeService.lastRequest!.projectId, 'proj-123');
      expect(fakeService.lastRequest!.totalAmount, 2400.0);
      expect(fakeService.lastRequest!.milestones.length, 1);
      expect(find.byType(ProposalSubmittedScreen), findsOneWidget);
      expect(find.text('¡Propuesta enviada!'), findsOneWidget);
    },
  );

  testWidgets(
    'ProjectDetailScreen oculta Postularme y muestra aviso informativo si el rol es CLIENT',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            convocatoria: sampleConvocatoria,
            userRoleOverride: 'CLIENT',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solo los freelancers pueden postularse'), findsOneWidget);
      expect(find.text('Postularme'), findsNothing);
    },
  );

  testWidgets(
    'ProjectDetailScreen muestra Postularme si el rol es FREELANCER',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            convocatoria: sampleConvocatoria,
            userRoleOverride: 'FREELANCER',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solo los freelancers pueden postularse'), findsNothing);
      expect(find.text('Postularme'), findsOneWidget);
    },
  );
}
