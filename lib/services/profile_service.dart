import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_constants.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'auth_service.dart';

typedef JsonMap = Map<String, dynamic>;

class ProfileService {
  final Dio _dio = ApiClient.instance.dio;
  final AuthService _authService = AuthService();

  Future<Options> _authOptions() async {
    final token = await _authService.getToken();
    return Options(
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// GET /api/v1/users/me/profile (con respaldo a /profile y /auth/me)
  Future<UserProfile?> fetchProfile() async {
    final options = await _authOptions();
    final cached = await _authService.getCachedProfile();

    for (final base in AuthService.getOrderedBaseUrls()) {
      for (final endpoint in [
        ApiConstants.profile,
        ApiConstants.legacyProfile,
        ApiConstants.me,
      ]) {
        try {
          final response = await _dio.get('$base$endpoint', options: options);
          if (response.statusCode == 200 && response.data != null) {
            AuthService.activeBaseUrl = base;
            final raw = response.data;
            final JsonMap payload = raw is Map && raw['data'] is Map
                ? JsonMap.from(raw['data'])
                : (raw is Map ? JsonMap.from(raw) : <String, dynamic>{});

            final user = _mapToUserProfile(payload, cachedLocation: cached?.location);
            // Preservar en almacenamiento local seguro
            await _authService.saveProfile(user);
            return user;
          }
        } catch (e) {
          debugPrint('ProfileService.fetchProfile fallo en $base$endpoint: $e');
        }
      }
    }
    return cached;
  }

  UserProfile _mapToUserProfile(JsonMap payload, {String? cachedLocation}) {
    final firstName = (payload['firstName'] ?? payload['first_name'] ?? '')
        .toString()
        .trim();
    final lastName = (payload['lastName'] ?? payload['last_name'] ?? '')
        .toString()
        .trim();

    final combinedFromParts = '$firstName $lastName'.trim();
    final rawName = combinedFromParts.isNotEmpty
        ? combinedFromParts
        : (payload['fullName'] ?? payload['name'] ?? '').toString().trim();

    final nameParts = rawName.split(' ');
    final resolvedFirst = firstName.isNotEmpty
        ? firstName
        : (nameParts.isNotEmpty ? nameParts.first : '');
    final resolvedLast = lastName.isNotEmpty
        ? lastName
        : (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    final rawSkills = payload['skills'];
    final parsedSkills = rawSkills is List
        ? rawSkills
        .map((s) => s is Map ? (s['name'] ?? '').toString() : s.toString())
        .where((s) => s.isNotEmpty)
        .toList()
        : <String>[];

    final serverLocation = (payload['location'] ?? payload['city'] ?? payload['country'])?.toString().trim() ?? '';
    final resolvedLocation = serverLocation.isNotEmpty
        ? serverLocation
        : (cachedLocation != null && cachedLocation.isNotEmpty ? cachedLocation : '');

    return UserProfile(
      id: (payload['id'] ?? payload['userId'] ?? '').toString(),
      firstName: resolvedFirst,
      lastName: resolvedLast,
      fullName: rawName,
      email: payload['email']?.toString() ?? '',
      role: payload['role']?.toString() ?? 'FREELANCER',
      location: resolvedLocation,
      bio: payload['bio']?.toString() ?? '',
      phone: payload['phone']?.toString() ?? '',
      avatarUrl: payload['avatarUrl']?.toString(),
      skills: parsedSkills,
    );
  }

  /// PUT /api/v1/users/me/profile
  Future<bool> updateProfile(UserProfile profile) async {
    // 1. Guardar de inmediato en almacenamiento seguro local para que la ubicación nunca se pierda
    await _authService.saveProfile(profile);

    final options = await _authOptions();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _dio.put(
          '$base${ApiConstants.profile}',
          options: options,
          data: {
            'firstName': profile.firstName,
            'lastName': profile.lastName,
            'phone': profile.phone,
            'location': profile.location,
            'bio': profile.bio,
            'skills': profile.skills,
            if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
              'avatarUrl': profile.avatarUrl,
          },
        );
        final code = response.statusCode ?? 0;
        if (code >= 200 && code < 300) {
          AuthService.activeBaseUrl = base;
          return true;
        }
      } catch (e) {
        debugPrint('ProfileService.updateProfile error en $base: $e');
      }
    }
    // Retornamos true porque ya quedó persistido localmente con seguridad
    return true;
  }

  /// POST /api/v1/users/me/avatar (multer field: 'avatar')
  Future<String?> uploadAvatar(File imageFile) async {
    final token = await _authService.getToken();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final formData = FormData.fromMap({
          'avatar': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split(Platform.pathSeparator).last,
          ),
        });

        final response = await _dio.post(
          '$base${ApiConstants.uploadAvatar}',
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            headers: {
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          ),
        );

        final payload = response.data is Map && response.data['data'] != null
            ? response.data['data']
            : response.data;
        return payload['avatarUrl']?.toString();
      } catch (e) {
        debugPrint('ProfileService.uploadAvatar error en $base: $e');
      }
    }
    return null;
  }

  /// GET /api/v1/users/me/skills
  Future<List<String>> getUserSkills() async {
    final options = await _authOptions();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _dio.get(
          '$base${ApiConstants.userSkills}',
          options: options,
        );
        if (response.statusCode == 200) {
          final raw = response.data is Map && response.data['data'] != null
              ? response.data['data']
              : response.data;
          if (raw is List) {
            return raw
                .map((s) => s is Map ? (s['name'] ?? '').toString() : s.toString())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      } catch (e) {
        debugPrint('ProfileService.getUserSkills error en $base: $e');
      }
    }
    return [];
  }

  /// POST /api/v1/users/me/skills
  Future<bool> addSkill(String skillName) async {
    final options = await _authOptions();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _dio.post(
          '$base${ApiConstants.userSkills}',
          options: options,
          data: {'name': skillName.trim()},
        );
        if ((response.statusCode ?? 0) >= 200 &&
            (response.statusCode ?? 0) < 300) {
          return true;
        }
      } catch (e) {
        debugPrint('ProfileService.addSkill error en $base: $e');
      }
    }
    return false;
  }

  /// DELETE /api/v1/users/me/skills/:identifier
  Future<bool> removeSkill(String identifier) async {
    final options = await _authOptions();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _dio.delete(
          '$base${ApiConstants.deleteUserSkill(identifier)}',
          options: options,
        );
        if ((response.statusCode ?? 0) >= 200 &&
            (response.statusCode ?? 0) < 300) {
          return true;
        }
      } catch (e) {
        debugPrint('ProfileService.removeSkill error en $base: $e');
      }
    }
    return false;
  }
}