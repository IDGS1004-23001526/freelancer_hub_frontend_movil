import 'package:dio/dio.dart';
import '../config/api_constants.dart';
import 'api_client.dart';

typedef JsonMap = Map<String, dynamic>;

class ProposalMilestoneInput {
  final String title;
  final String description;
  final double amount;
  final String? dueDate;

  const ProposalMilestoneInput({
    required this.title,
    required this.description,
    required this.amount,
    this.dueDate,
  });

  JsonMap toJson() => {
    'title': title,
    'description': description,
    'amount': amount,
    if (dueDate != null && dueDate!.isNotEmpty) 'dueDate': dueDate,
  };
}

class ProposalService {
  final Dio _dio = ApiClient.instance.dio;

  /// Envía una postulación formal desglosada por hitos a POST /api/v1/proposals (HU-03)
  Future<JsonMap> submitProposal({
    required String projectId,
    required String coverLetter,
    required double totalAmount,
    required int estimatedDays,
    required List<ProposalMilestoneInput> milestones,
  }) async {
    if (milestones.isEmpty) {
      throw ArgumentError('Debes incluir al menos un hito en la propuesta.');
    }

    final sumMilestones = milestones.fold<double>(0, (acc, m) => acc + m.amount);
    if ((sumMilestones - totalAmount).abs() > 0.01) {
      throw ArgumentError(
        'La suma de los hitos (\$${sumMilestones.toStringAsFixed(2)}) debe coincidir con el monto total (\$${totalAmount.toStringAsFixed(2)}).',
      );
    }

    final response = await _dio.post(
      ApiConstants.proposals,
      data: {
        'projectId': projectId,
        'coverLetter': coverLetter.trim(),
        'totalAmount': totalAmount,
        'estimatedDays': estimatedDays,
        'milestones': milestones.map((m) => m.toJson()).toList(),
      },
    );

    if (response.data is Map) {
      return JsonMap.from(response.data);
    }
    return {'data': response.data};
  }
}