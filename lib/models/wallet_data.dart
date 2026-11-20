typedef JsonMap = Map<String, dynamic>;

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

  JsonMap toMap() {
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

  factory WalletTransaction.fromJson(JsonMap json) {
    final gross = (json['grossAmount'] ?? json['amount'] ?? 0) as num;
    final fee = (json['platformFee'] ?? json['fee'] ?? 0) as num;
    final net = (json['netAmount'] ?? (gross - fee)) as num;

    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ??
          json['description']?.toString() ??
          'Pago de Hito',
      milestoneLabel: json['milestoneLabel']?.toString() ??
          json['type']?.toString() ??
          'Hito',
      grossAmount: gross.toDouble(),
      platformFee: fee.toDouble(),
      netAmount: net.toDouble(),
      date: DateTime.tryParse(
          (json['date'] ?? json['createdAt'])?.toString() ?? '') ??
          DateTime.now(),
      status: json['status']?.toString().toLowerCase() ?? 'completed',
      clabeAccount:
      json['clabeAccount']?.toString() ?? json['clabe']?.toString(),
    );
  }

  factory WalletTransaction.fromMap(JsonMap map) {
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

  factory WalletData.fromJson(JsonMap json) {
    final rawTransactions = json['transactions'] ?? json['movements'] ?? [];

    return WalletData(
      availableBalance:
      ((json['availableBalance'] ?? json['balance'] ?? 0) as num)
          .toDouble(),
      escrowBalance: ((json['escrowBalance'] ??
          json['pendingBalance'] ??
          json['heldBalance'] ??
          0) as num)
          .toDouble(),
      currency: json['currency']?.toString() ?? 'USD',
      transactions: (rawTransactions as List)
          .map((item) => WalletTransaction.fromJson(JsonMap.from(item)))
          .toList(),
    );
  }

  factory WalletData.fromMap(JsonMap map) {
    return WalletData(
      availableBalance: (map['availableBalance'] as num?)?.toDouble() ?? 0.0,
      escrowBalance: (map['escrowBalance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'USD',
      transactions: (map['transactions'] as List<dynamic>?)
          ?.map((t) => WalletTransaction.fromMap(t as JsonMap))
          .toList() ??
          [],
    );
  }
}