import 'dart:io';
import 'package:dio/dio.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ProfileService {
  final AuthService _authService = AuthService();
  final ApiClient _apiClient;

  ProfileService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  Future<UserProfile?> fetchProfile() async {
    final cached = await _authService.getCachedUserProfile();
    try {
      for (final base in AuthService.getOrderedBaseUrls()) {
        try {
          Response? response;
          try {
            response = await _apiClient.dio.get('$base/users/me/profile');
          } catch (_) {
            response = await _apiClient.dio.get('$base/auth/me');
          }

          if (response.statusCode == 200) {
            AuthService.activeBaseUrl = base;
            final dynamic data = response.data;
            final payload = data is Map<String, dynamic>
                ? (data['data'] ?? data['user'] ?? data['profile'] ?? data)
                : <String, dynamic>{};

            if (payload is Map<String, dynamic>) {
              final remoteProfile = UserProfile.fromJson(payload);
              final effectiveAvatar = (remoteProfile.avatarUrl != null &&
                      remoteProfile.avatarUrl!.isNotEmpty)
                  ? remoteProfile.avatarUrl
                  : cached?.avatarUrl;

              final merged = cached != null
                  ? remoteProfile.copyWith(
                      firstName: remoteProfile.firstName.isNotEmpty
                          ? remoteProfile.firstName
                          : cached.firstName,
                      lastName: remoteProfile.lastName.isNotEmpty
                          ? remoteProfile.lastName
                          : cached.lastName,
                      fullName: remoteProfile.fullName.isNotEmpty
                          ? remoteProfile.fullName
                          : cached.fullName,
                      role: cached.role.isNotEmpty
                          ? cached.role
                          : remoteProfile.role,
                      location: remoteProfile.location.isNotEmpty
                          ? remoteProfile.location
                          : cached.location,
                      bio: remoteProfile.bio.isNotEmpty
                          ? remoteProfile.bio
                          : cached.bio,
                      phone: remoteProfile.phone.isNotEmpty
                          ? remoteProfile.phone
                          : cached.phone,
                      avatarUrl: effectiveAvatar,
                      skills: remoteProfile.skills.isNotEmpty
                          ? remoteProfile.skills
                          : cached.skills,
                    )
                  : remoteProfile.copyWith(avatarUrl: effectiveAvatar);

              await _authService.saveUserProfile(merged);
              return merged;
            }
          }
        } catch (_) {
          continue;
        }
      }
      return cached;
    } catch (_) {
      return cached;
    }
  }

  Future<bool> updateProfile(UserProfile user) async {
    await _authService.saveUserProfile(user);
    try {
      for (final base in AuthService.getOrderedBaseUrls()) {
        try {
          Response? response;
          try {
            response = await _apiClient.dio.put(
              '$base/users/me/profile',
              data: user.toJson(),
            );
          } on DioException catch (dioErr) {
            if (dioErr.response?.statusCode == 404) {
              response = await _apiClient.dio.put(
                '$base/profile/professional-info',
                data: user.toJson(),
              );
            } else {
              rethrow;
            }
          }

          AuthService.activeBaseUrl = base;
          return response.statusCode == 200 ||
              response.statusCode == 201 ||
              response.statusCode == 204 ||
              true;
        } catch (_) {
          continue;
        }
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    try {
      for (final base in AuthService.getOrderedBaseUrls()) {
        try {
          final formData = FormData.fromMap({
            'avatar': await MultipartFile.fromFile(
              imageFile.path,
              filename: imageFile.path.split(Platform.pathSeparator).last,
            ),
          });

          final response = await _apiClient.dio.post(
            '$base/users/me/avatar',
            data: formData,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            AuthService.activeBaseUrl = base;
            final dynamic data = response.data;
            final payload =
                data is Map<String, dynamic> ? data['data'] : null;
            final newUrl = (payload is Map<String, dynamic>
                    ? payload['avatarUrl']
                    : null) ??
                (data is Map<String, dynamic>
                    ? (data['avatarUrl'] ?? data['url'] ?? data['avatar'])
                    : null);

            if (newUrl != null && newUrl is String) {
              final cached = await _authService.getCachedUserProfile();
              if (cached != null) {
                await _authService
                    .saveUserProfile(cached.copyWith(avatarUrl: newUrl));
              }
              return newUrl;
            }
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
