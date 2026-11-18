import 'dart:convert';

class OfflineAction {
  final String id;
  final String type; // e.g. 'postulacion', 'favorito'
  final String convocatoriaId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String status; // 'pending', 'synced', 'failed'

  const OfflineAction({
    required this.id,
    required this.type,
    required this.convocatoriaId,
    required this.payload,
    required this.createdAt,
    this.status = 'pending',
  });

  OfflineAction copyWith({
    String? id,
    String? type,
    String? convocatoriaId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    String? status,
  }) {
    return OfflineAction(
      id: id ?? this.id,
      type: type ?? this.type,
      convocatoriaId: convocatoriaId ?? this.convocatoriaId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'convocatoriaId': convocatoriaId,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory OfflineAction.fromMap(Map<dynamic, dynamic> map) {
    return OfflineAction(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      convocatoriaId: map['convocatoriaId']?.toString() ?? '',
      payload: (map['payload'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
    );
  }

  String toJson() => json.encode(toMap());

  factory OfflineAction.fromJson(String source) =>
      OfflineAction.fromMap(json.decode(source) as Map<String, dynamic>);
}
