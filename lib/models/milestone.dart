class Milestone {
  final String id;
  final String contractId;
  final String label; // e.g. 'H1'
  final String title;
  final int order;
  final String amount;
  final bool isFunded;
  final String status; // 'funded', 'unfunded', 'in_review', 'completed'
  final String clientName;
  final int reviewDays;
  final String? repositoryUrl;
  final String? technicalNotes;
  final List<String> attachments;

  const Milestone({
    required this.id,
    required this.contractId,
    required this.label,
    required this.title,
    required this.order,
    required this.amount,
    required this.isFunded,
    required this.status,
    required this.clientName,
    this.reviewDays = 5,
    this.repositoryUrl,
    this.technicalNotes,
    this.attachments = const [],
  });

  Milestone copyWith({
    String? id,
    String? contractId,
    String? label,
    String? title,
    int? order,
    String? amount,
    bool? isFunded,
    String? status,
    String? clientName,
    int? reviewDays,
    String? repositoryUrl,
    String? technicalNotes,
    List<String>? attachments,
  }) {
    return Milestone(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      label: label ?? this.label,
      title: title ?? this.title,
      order: order ?? this.order,
      amount: amount ?? this.amount,
      isFunded: isFunded ?? this.isFunded,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      reviewDays: reviewDays ?? this.reviewDays,
      repositoryUrl: repositoryUrl ?? this.repositoryUrl,
      technicalNotes: technicalNotes ?? this.technicalNotes,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contractId': contractId,
      'label': label,
      'title': title,
      'order': order,
      'amount': amount,
      'isFunded': isFunded,
      'status': status,
      'clientName': clientName,
      'reviewDays': reviewDays,
      'repositoryUrl': repositoryUrl,
      'technicalNotes': technicalNotes,
      'attachments': attachments,
    };
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id']?.toString() ?? '',
      contractId: map['contractId']?.toString() ?? 'CT-2026-0418',
      label: map['label']?.toString() ?? 'H1',
      title: map['title']?.toString() ?? 'Hito de entrega',
      order: int.tryParse(map['order']?.toString() ?? '') ?? 1,
      amount: map['amount']?.toString() ?? '\$0 USD',
      isFunded: map['isFunded'] == true,
      status: map['status']?.toString() ?? 'funded',
      clientName: map['clientName']?.toString() ?? 'Carlos Mendoza',
      reviewDays: int.tryParse(map['reviewDays']?.toString() ?? '') ?? 5,
      repositoryUrl: map['repositoryUrl']?.toString(),
      technicalNotes: map['technicalNotes']?.toString(),
      attachments: (map['attachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
