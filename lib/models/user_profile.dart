class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String location;
  final String bio;
  final String? avatarUrl;
  final List<String> skills;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.location,
    required this.bio,
    this.avatarUrl,
    required this.skills,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      fullName: json['name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      location: json['location'] ?? '',
      bio: json['bio'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
      skills: json['skills'] != null ? List<String>.from(json['skills']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': fullName,
      'role': role,
      'location': location,
      'bio': bio,
      'skills': skills,
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? location,
    String? bio,
    String? avatarUrl,
    List<String>? skills,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      skills: skills ?? List.from(this.skills),
    );
  }
}
