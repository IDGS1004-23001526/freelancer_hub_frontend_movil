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
  final String? description;

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
    this.description,
  });

  factory Convocatoria.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skills'];
    List<String> tagsList = [];
    if (rawSkills is List) {
      tagsList = rawSkills.map((e) => e.toString()).toList();
    }

    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null;

    final estimatedDate = json['estimatedDate'] != null
        ? DateTime.tryParse(json['estimatedDate'].toString())
        : null;

    int daysRemaining = 30;
    if (estimatedDate != null) {
      final diff = estimatedDate.difference(DateTime.now()).inDays;
      daysRemaining = diff > 0 ? diff : 1;
    }

    String timeAgoStr = 'Convocatoria activa';
    if (createdAt != null) {
      final hours = DateTime.now().difference(createdAt).inHours;
      if (hours < 1) {
        timeAgoStr = 'Hace unos minutos · Convocatoria activa';
      } else if (hours < 24) {
        timeAgoStr = 'Hace $hours h · Convocatoria activa';
      } else {
        final days = (hours / 24).floor();
        timeAgoStr = 'Hace $days d · Convocatoria activa';
      }
    }

    return Convocatoria(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sin título',
      company: json['company']?.toString() ?? 'Cliente verificado',
      timeAgo: timeAgoStr,
      category: json['category']?.toString() ?? 'Desarrollo de software',
      tags: tagsList.isNotEmpty ? tagsList : ['Software', 'Tecnología'],
      budget: (json['budget'] is num)
          ? (json['budget'] as num).toDouble()
          : double.tryParse(json['budget']?.toString() ?? '0') ?? 0.0,
      remainingDays: daysRemaining,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
      description: json['description']?.toString(),
    );
  }
}
