class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String role;
  final String location;
  final String bio;
  final String phone;
  final String? avatarUrl;
  final List<String> skills;

  UserProfile({
    required this.id,
    String? firstName,
    String? lastName,
    String? fullName,
    required this.email,
    required this.role,
    required this.location,
    required this.bio,
    String? phone,
    this.avatarUrl,
    required this.skills,
  })  : firstName = firstName ?? (fullName != null ? _extractFirstName(fullName) : ''),
        lastName = lastName ?? (fullName != null ? _extractLastName(fullName) : ''),
        fullName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : ('${firstName ?? ''} ${lastName ?? ''}').trim(),
        phone = phone ?? '';

  static String _extractFirstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  static String _extractLastName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawFirst = json['firstName'] ?? json['first_name'] ?? '';
    final rawLast = json['lastName'] ?? json['last_name'] ?? '';
    final rawFull = json['fullName'] ?? json['name'] ?? '';

    String first = rawFirst.toString().trim();
    String last = rawLast.toString().trim();
    String full = rawFull.toString().trim();

    if (first.isEmpty && full.isNotEmpty) {
      first = _extractFirstName(full);
      last = _extractLastName(full);
    }
    if (full.isEmpty) {
      full = ('$first $last').trim();
    }

    return UserProfile(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      firstName: first,
      lastName: last,
      fullName: full,
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['telephone']?.toString() ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar'] ?? json['avatar_url'],
      skills: json['skills'] != null
          ? (json['skills'] as List)
              .map((s) => s is Map ? (s['name'] ?? s['title'] ?? '').toString() : s.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName.isNotEmpty ? firstName : _extractFirstName(fullName),
      'last_name': lastName.isNotEmpty ? lastName : _extractLastName(fullName),
      'firstName': firstName.isNotEmpty ? firstName : _extractFirstName(fullName),
      'lastName': lastName.isNotEmpty ? lastName : _extractLastName(fullName),
      'fullName': fullName.isNotEmpty ? fullName : ('$firstName $lastName').trim(),
      'name': fullName.isNotEmpty ? fullName : ('$firstName $lastName').trim(),
      'email': email,
      'role': role,
      'location': location,
      'bio': bio,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'skills': skills.map((s) => {'name': s}).toList(),
      'skillNames': skills,
    };
  }

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? fullName,
    String? email,
    String? role,
    String? location,
    String? bio,
    String? phone,
    String? avatarUrl,
    List<String>? skills,
  }) {
    final nextFirst = firstName ?? this.firstName;
    final nextLast = lastName ?? this.lastName;
    final nextFull = fullName ??
        ((firstName != null || lastName != null)
            ? ('$nextFirst $nextLast').trim()
            : this.fullName);

    return UserProfile(
      id: id ?? this.id,
      firstName: nextFirst,
      lastName: nextLast,
      fullName: nextFull,
      email: email ?? this.email,
      role: role ?? this.role,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      skills: skills ?? List.from(this.skills),
    );
  }
}
