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

  /// GET /api/v1/users/me/profile (conservando el rol real de la sesión)
  Future<UserProfile?> fetchProfile({String? fallbackRole}) async {
    final options = await _authOptions();
    final cachedProfile = await _authService.getCachedUserProfile();
    final sessionRole = fallbackRole ?? cachedProfile?.role;

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

            final mapped = _mapToUserProfile(
              payload,
              fallbackRole: sessionRole,
              cachedProfile: cachedProfile,
            );
            await _authService.saveUserProfile(mapped);
            return mapped;
          }
        } catch (e) {
          debugPrint('ProfileService.fetchProfile fallo en $base$endpoint: $e');
        }
      }
    }
    return cachedProfile;
  }

  UserProfile _mapToUserProfile(
      JsonMap payload, {
        String? fallbackRole,
        UserProfile? cachedProfile,
      }) {
    final firstName = (payload['firstName'] ?? payload['first_name'] ?? '')
        .toString()
        .trim();
    final lastName = (payload['lastName'] ?? payload['last_name'] ?? '')
        .toString()
        .trim();

    final combinedFromParts = '$firstName $lastName'.trim();
    final rawName = combinedFromParts.isNotEmpty
        ? combinedFromParts
        : (payload['fullName'] ?? payload['name'] ?? cachedProfile?.fullName ?? '')
        .toString()
        .trim();

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
        : (cachedProfile?.skills ?? <String>[]);

    final rawRole = payload['role']?.toString().trim();
    final resolvedRole = (rawRole != null && rawRole.isNotEmpty)
        ? AuthService.normalizeRole(rawRole)
        : AuthService.normalizeRole(fallbackRole);

    return UserProfile(
      id: (payload['id'] ?? payload['userId'] ?? cachedProfile?.id ?? '').toString(),
      firstName: resolvedFirst,
      lastName: resolvedLast,
      fullName: rawName,
      email: (payload['email']?.toString().isNotEmpty == true)
          ? payload['email'].toString()
          : (cachedProfile?.email ?? ''),
      role: resolvedRole,
      location: (payload['location']?.toString().isNotEmpty == true)
          ? payload['location'].toString()
          : (cachedProfile?.location ?? ''),
      bio: (payload['bio']?.toString().isNotEmpty == true)
          ? payload['bio'].toString()
          : (cachedProfile?.bio ?? ''),
      phone: (payload['phone']?.toString().isNotEmpty == true)
          ? payload['phone'].toString()
          : (cachedProfile?.phone ?? ''),
      avatarUrl: payload['avatarUrl']?.toString() ?? cachedProfile?.avatarUrl,
      skills: parsedSkills,
    );
  }

  /// PUT /api/v1/users/me/profile
  Future<bool> updateProfile(UserProfile profile) async {
    final safeProfile = profile.copyWith(
      role: AuthService.normalizeRole(profile.role),
    );
    await _authService.saveUserProfile(safeProfile);

    final options = await _authOptions();
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await _dio.put(
          '$base${ApiConstants.profile}',
          options: options,
          data: {
            'firstName': safeProfile.firstName,
            'lastName': safeProfile.lastName,
            'phone': safeProfile.phone,
            'location': safeProfile.location,
            'bio': safeProfile.bio,
            'skills': safeProfile.skills,
            if (safeProfile.avatarUrl != null &&
                safeProfile.avatarUrl!.isNotEmpty)
              'avatarUrl': safeProfile.avatarUrl,
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
    return imageFile.path;
  }
}