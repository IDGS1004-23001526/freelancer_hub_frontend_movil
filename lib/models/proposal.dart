class ProposalMilestone {
  final String title;
  final String description;
  final double amount;
  final int estimatedDays;

  const ProposalMilestone({
    required this.title,
    required this.description,
    required this.amount,
    required this.estimatedDays,
  });

  Map<String, dynamic> toJson({required int order}) {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'amount': amount,
      'deliveryDays': estimatedDays, // Backend Zod expects 'deliveryDays'
      'order': order,
    };
  }
}

class ProposalRequest {
  final String projectId;
  final String? projectTitle;
  final String? companyName;
  final String coverLetter;
  final double totalAmount;
  final int estimatedDays;
  final List<ProposalMilestone> milestones;

  const ProposalRequest({
    required this.projectId,
    this.projectTitle,
    this.companyName,
    required this.coverLetter,
    required this.totalAmount,
    required this.estimatedDays,
    required this.milestones,
  });

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'coverLetter': coverLetter.trim(),
      'totalPrice': totalAmount, // Backend Zod expects 'totalPrice'
      'estimatedDays': estimatedDays,
      'milestones': [
        for (int i = 0; i < milestones.length; i++)
          milestones[i].toJson(order: i + 1),
      ],
    };
  }
}

class ProposalSubmissionResult {
  final bool success;
  final String message;
  final String? proposalId;
  final int? statusCode;

  const ProposalSubmissionResult({
    required this.success,
    required this.message,
    this.proposalId,
    this.statusCode,
  });
}

/// Modelo ligero solo para listar las postulaciones en "Mis Postulaciones"
class SubmittedProposal {
  final String id;
  final String projectId;
  final String projectTitle;
  final String companyName;
  final String coverLetter;
  final double totalAmount;
  final int estimatedDays;
  final String status; // 'PENDIENTE', 'ADJUDICADA', 'RECHAZADA', 'EN_COLA_OFFLINE'
  final DateTime createdAt;
  final List<ProposalMilestone> milestones;

  const SubmittedProposal({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.companyName,
    required this.coverLetter,
    required this.totalAmount,
    required this.estimatedDays,
    required this.status,
    required this.createdAt,
    required this.milestones,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'projectTitle': projectTitle,
    'companyName': companyName,
    'coverLetter': coverLetter,
    'totalAmount': totalAmount,
    'estimatedDays': estimatedDays,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'milestones': [
      for (int i = 0; i < milestones.length; i++)
        milestones[i].toJson(order: i + 1),
    ],
  };

  factory SubmittedProposal.fromJson(Map<String, dynamic> json) {
    final rawMs = json['milestones'];
    final ms = rawMs is List
        ? rawMs
        .whereType()
        .map((m) => ProposalMilestone(
      title: m['title']?.toString() ?? 'Hito',
      description: m['description']?.toString() ?? '',
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      estimatedDays: (m['deliveryDays'] ?? m['estimatedDays'] as num?)?.toInt() ?? 15,
    ))
        .toList()
        : <ProposalMilestone>[];

    return SubmittedProposal(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      projectTitle: (json['projectTitle'] ?? 'Convocatoria').toString(),
      companyName: (json['companyName'] ?? 'Cliente').toString(),
      coverLetter: (json['coverLetter'] ?? '').toString(),
      totalAmount: ((json['totalPrice'] ?? json['totalAmount']) as num?)?.toDouble() ?? 0.0,
      estimatedDays: (json['estimatedDays'] as num?)?.toInt() ?? 15,
      status: (json['status'] ?? 'PENDIENTE').toString().toUpperCase(),
      createdAt:
      DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      milestones: ms,
    );
  }
}