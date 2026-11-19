/// Modelo unificado de Convocatoria.
/// Mantiene compatibilidad con el branch RV (fromJson, campos company/timeAgo/tags/budget double)
/// y agrega los campos/getters que necesita el branch Axel (companyName, companyInitial,
/// postedTime, skills, duration, budget como String getter, isApplied) + toMap/fromMap/copyWith.
class Convocatoria {
  // ── Campos principales ──────────────────────────────────────────────
  final String id;
  final String title;
  final String category;
  final String? description;
  final bool isApplied;

  // ── Campos RV (se conservan igual que antes) ─────────────────────────
  final String company;        // nombre de empresa (RV)
  final String timeAgo;        // texto relativo de tiempo (RV)
  final List<String> tags;     // habilidades como lista (RV)
  final double budget;         // presupuesto numérico (RV) ← double, como RV lo declaró
  final int remainingDays;     // días restantes (RV)
  final String paymentType;    // 'Precio fijo', 'Por hitos' (RV)
  final String remoteType;     // 'Remoto', 'Presencial' (RV)

  // ── Campos extra Axel (privados, con fallback a campos RV) ───────────
  final String? _companyName;
  final String? _companyInitial;
  final String? _postedTime;
  final List<String>? _skills;
  final String? _duration;
  final String? _budgetStr; // presupuesto formateado como String (Axel)

  // ── Getters de compatibilidad Axel ──────────────────────────────────
  String get companyName    => _companyName    ?? company;
  String get companyInitial => _companyInitial ?? (company.isNotEmpty ? company[0].toUpperCase() : '?');
  String get postedTime     => _postedTime     ?? timeAgo;
  List<String> get skills   => _skills         ?? tags;
  String get duration       => _duration       ?? '$remainingDays días';

  /// Presupuesto como String (usado por ConvocatoriaCard y ExplorarScreen de Axel).
  /// Si se pasó un String explícito (Axel), lo usa; si no, formatea el double de RV.
  String get budgetFormatted => _budgetStr ?? '\$${budget.toStringAsFixed(0)} USD';

  // ── Constructor unificado ─────────────────────────────────────────────
  const Convocatoria({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.isApplied = false,
    // RV params (mismo nombre que antes)
    this.company = '',
    this.timeAgo = '',
    this.tags = const [],
    this.budget = 0.0,
    this.remainingDays = 30,
    this.paymentType = 'Precio fijo',
    this.remoteType = 'Remoto',
    // Axel optional overrides
    String? companyName,
    String? companyInitial,
    String? postedTime,
    List<String>? skills,
    String? duration,
    String? budgetStr,
  })  : _companyName    = companyName,
        _companyInitial = companyInitial,
        _postedTime     = postedTime,
        _skills         = skills,
        _duration       = duration,
        _budgetStr      = budgetStr;

  // ── fromJson (RV) ────────────────────────────────────────────────────
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

    final companyStr = json['company']?.toString() ?? 'Cliente verificado';
    final double budgetDouble = (json['budget'] is num)
        ? (json['budget'] as num).toDouble()
        : double.tryParse(json['budget']?.toString() ?? '0') ?? 0.0;

    return Convocatoria(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sin título',
      company: companyStr,
      timeAgo: timeAgoStr,
      category: json['category']?.toString() ?? 'Desarrollo de software',
      tags: tagsList.isNotEmpty ? tagsList : ['Software', 'Tecnología'],
      budget: budgetDouble,
      remainingDays: daysRemaining,
      paymentType: 'Precio fijo',
      remoteType: 'Remoto',
      description: json['description']?.toString(),
    );
  }

  // ── fromMap (Axel / caché Hive) ───────────────────────────────────────
  factory Convocatoria.fromMap(Map<dynamic, dynamic> map) {
    final rawSkills = map['skills'] ?? map['tags'];
    List<String> skillsList = [];
    if (rawSkills is List) {
      skillsList = rawSkills.map((e) => e.toString()).toList();
    }

    final double budgetDouble =
        (map['budget'] is num)
            ? (map['budget'] as num).toDouble()
            : double.tryParse(map['budget']?.toString() ?? '0') ?? 0.0;

    return Convocatoria(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Sin título',
      company: map['company']?.toString() ?? '',
      companyName: map['companyName']?.toString(),
      companyInitial: map['companyInitial']?.toString(),
      timeAgo: map['timeAgo']?.toString() ?? '',
      postedTime: map['postedTime']?.toString(),
      category: map['category']?.toString() ?? '',
      tags: skillsList,
      skills: skillsList.isNotEmpty ? skillsList : null,
      budget: budgetDouble,
      budgetStr: map['budgetStr']?.toString(),
      remainingDays: int.tryParse(map['remainingDays']?.toString() ?? '30') ?? 30,
      duration: map['duration']?.toString(),
      paymentType: map['paymentType']?.toString() ?? 'Precio fijo',
      remoteType: map['remoteType']?.toString() ?? 'Remoto',
      description: map['description']?.toString(),
      isApplied: map['isApplied'] == true,
    );
  }

  // ── toMap (Axel / caché Hive) ─────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'companyName': companyName,
      'companyInitial': companyInitial,
      'timeAgo': timeAgo,
      'postedTime': postedTime,
      'category': category,
      'tags': tags,
      'skills': skills,
      'budget': budget,
      'budgetStr': budgetFormatted,
      'remainingDays': remainingDays,
      'duration': duration,
      'paymentType': paymentType,
      'remoteType': remoteType,
      'description': description,
      'isApplied': isApplied,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────
  Convocatoria copyWith({
    String? id,
    String? title,
    String? company,
    String? companyName,
    String? companyInitial,
    String? timeAgo,
    String? postedTime,
    String? category,
    List<String>? tags,
    List<String>? skills,
    double? budget,
    String? budgetStr,
    int? remainingDays,
    String? duration,
    String? paymentType,
    String? remoteType,
    String? description,
    bool? isApplied,
  }) {
    return Convocatoria(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      companyName: companyName ?? _companyName,
      companyInitial: companyInitial ?? _companyInitial,
      timeAgo: timeAgo ?? this.timeAgo,
      postedTime: postedTime ?? _postedTime,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      skills: skills ?? _skills,
      budget: budget ?? this.budget,
      budgetStr: budgetStr ?? _budgetStr,
      remainingDays: remainingDays ?? this.remainingDays,
      duration: duration ?? _duration,
      paymentType: paymentType ?? this.paymentType,
      remoteType: remoteType ?? this.remoteType,
      description: description ?? this.description,
      isApplied: isApplied ?? this.isApplied,
    );
  }
}
