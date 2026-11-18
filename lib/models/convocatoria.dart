import 'dart:convert';

class Convocatoria {
  final String id;
  final String title;
  final String companyName;
  final String companyInitial;
  final String postedTime;
  final String budget;
  final String duration;
  final List<String> skills;
  final String category;
  final String description;
  final bool isApplied;

  const Convocatoria({
    required this.id,
    required this.title,
    required this.companyName,
    required this.companyInitial,
    required this.postedTime,
    required this.budget,
    required this.duration,
    required this.skills,
    required this.category,
    this.description = '',
    this.isApplied = false,
  });

  Convocatoria copyWith({
    String? id,
    String? title,
    String? companyName,
    String? companyInitial,
    String? postedTime,
    String? budget,
    String? duration,
    List<String>? skills,
    String? category,
    String? description,
    bool? isApplied,
  }) {
    return Convocatoria(
      id: id ?? this.id,
      title: title ?? this.title,
      companyName: companyName ?? this.companyName,
      companyInitial: companyInitial ?? this.companyInitial,
      postedTime: postedTime ?? this.postedTime,
      budget: budget ?? this.budget,
      duration: duration ?? this.duration,
      skills: skills ?? this.skills,
      category: category ?? this.category,
      description: description ?? this.description,
      isApplied: isApplied ?? this.isApplied,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'companyName': companyName,
      'companyInitial': companyInitial,
      'postedTime': postedTime,
      'budget': budget,
      'duration': duration,
      'skills': skills,
      'category': category,
      'description': description,
      'isApplied': isApplied,
    };
  }

  factory Convocatoria.fromMap(Map<dynamic, dynamic> map) {
    return Convocatoria(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      companyInitial: (map['companyInitial']?.toString().isNotEmpty == true)
          ? map['companyInitial'].toString()
          : (map['companyName'] != null && map['companyName'].toString().trim().isNotEmpty
              ? map['companyName'].toString().trim().substring(0, 1).toUpperCase()
              : 'C'),
      postedTime: map['postedTime']?.toString() ?? 'Reciente',
      budget: map['budget']?.toString() ?? '\$0 USD',
      duration: map['duration']?.toString() ?? 'Por definir',
      skills: (map['skills'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      category: map['category']?.toString() ?? 'General',
      description: map['description']?.toString() ?? '',
      isApplied: map['isApplied'] == true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Convocatoria.fromJson(String source) =>
      Convocatoria.fromMap(json.decode(source) as Map<String, dynamic>);
}
