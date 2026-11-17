class Convocatoria {
  final String id;
  final String title;
  final String company;
  final String timeAgo;
  final String category;
  final List<String> tags;
  final double budget;
  final int remainingDays;
  final String paymentType; // 'Precio fijo', 'Por hitos'
  final String remoteType; // 'Remoto', 'Presencial'

  Convocatoria({
    required this.id,
    required this.title,
    required this.company,
    required this.timeAgo,
    required this.category,
    required this.tags,
    required this.budget,
    required this.remainingDays,
    required this.paymentType,
    required this.remoteType,
  });
}
