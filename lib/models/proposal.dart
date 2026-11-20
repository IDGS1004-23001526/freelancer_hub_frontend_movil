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
      'estimatedDays': estimatedDays,
      'order': order,
    };
  }
}

class ProposalRequest {
  final String projectId;
  final String coverLetter;
  final double totalAmount;
  final int estimatedDays;
  final List<ProposalMilestone> milestones;

  const ProposalRequest({
    required this.projectId,
    required this.coverLetter,
    required this.totalAmount,
    required this.estimatedDays,
    required this.milestones,
  });

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'coverLetter': coverLetter.trim(),
      'totalAmount': totalAmount,
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
