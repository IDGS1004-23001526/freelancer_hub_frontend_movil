class WalletTransaction {
  final String id;
  final String title;
  final String milestoneLabel;
  final double grossAmount;
  final double platformFee;
  final double netAmount;
  final DateTime date;
  final String status; // 'completed', 'pending', 'withdrawn'
  final String? clabeAccount;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.milestoneLabel,
    required this.grossAmount,
    required this.platformFee,
    required this.netAmount,
    required this.date,
    required this.status,
    this.clabeAccount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'milestoneLabel': milestoneLabel,
      'grossAmount': grossAmount,
      'platformFee': platformFee,
      'netAmount': netAmount,
      'date': date.toIso8601String(),
      'status': status,
      'clabeAccount': clabeAccount,
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Pago de Hito',
      milestoneLabel: map['milestoneLabel']?.toString() ?? 'Hito',
      grossAmount: (map['grossAmount'] as num?)?.toDouble() ?? 0.0,
      platformFee: (map['platformFee'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      status: map['status']?.toString() ?? 'completed',
      clabeAccount: map['clabeAccount']?.toString(),
    );
  }
}

class WalletData {
  final double availableBalance;
  final double escrowBalance;
  final String currency;
  final List<WalletTransaction> transactions;

  const WalletData({
    required this.availableBalance,
    required this.escrowBalance,
    this.currency = 'USD',
    required this.transactions,
  });

  WalletData copyWith({
    double? availableBalance,
    double? escrowBalance,
    String? currency,
    List<WalletTransaction>? transactions,
  }) {
    return WalletData(
      availableBalance: availableBalance ?? this.availableBalance,
      escrowBalance: escrowBalance ?? this.escrowBalance,
      currency: currency ?? this.currency,
      transactions: transactions ?? this.transactions,
    );
  }

  factory WalletData.fromMap(Map<String, dynamic> map) {
    return WalletData(
      availableBalance: (map['availableBalance'] as num?)?.toDouble() ?? 0.0,
      escrowBalance: (map['escrowBalance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'USD',
      transactions: (map['transactions'] as List<dynamic>?)
              ?.map((t) => WalletTransaction.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
