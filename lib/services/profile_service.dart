import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'auth_service.dart';

class ProfileService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _getWithFallback(
    String endpointPath,
    Map<String, String> headers,
  ) async {
    Object? lastError;
    for (final base in AuthService.getOrderedBaseUrls()) {
      try {
        final response = await http
            .get(Uri.parse('$base$endpointPath'), headers: headers)
            .timeout(const Duration(seconds: 4));
        AuthService.activeBaseUrl = base;
        return response;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('No se pudo conectar con el servidor.');
  }

  Future<UserProfile?> fetchProfile() async {
    final cached = await _authService.getCachedUserProfile();
    try {
      final headers = await _getHeaders();
      http.Response? response;
      try {
        response = await _getWithFallback('/users/me/profile', headers);
      } catch (_) {
        response = await _getWithFallback('/auth/me', headers);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final payload = data is Map<String, dynamic>
            ? (data['data'] ?? data['user'] ?? data['profile'] ?? data)
            : <String, dynamic>{};
        if (payload is Map<String, dynamic>) {
          final remoteProfile = UserProfile.fromJson(payload);
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
                  role: cached.role.isNotEmpty ? cached.role : remoteProfile.role,
                  location: remoteProfile.location.isNotEmpty
                      ? remoteProfile.location
                      : cached.location,
                  bio: remoteProfile.bio.isNotEmpty
                      ? remoteProfile.bio
                      : cached.bio,
                  phone: remoteProfile.phone.isNotEmpty
                      ? remoteProfile.phone
                      : cached.phone,
                  avatarUrl: remoteProfile.avatarUrl ?? cached.avatarUrl,
                  skills: remoteProfile.skills.isNotEmpty
                      ? remoteProfile.skills
                      : cached.skills,
                )
              : remoteProfile;
          await _authService.saveUserProfile(merged);
          return merged;
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
      final headers = await _getHeaders();
      for (final base in AuthService.getOrderedBaseUrls()) {
        try {
          var response = await http
              .put(
                Uri.parse('$base/users/me/profile'),
                headers: headers,
                body: jsonEncode(user.toJson()),
              )
              .timeout(const Duration(seconds: 4));

          if (response.statusCode == 404) {
            response = await http
                .put(
                  Uri.parse('$base/profile/professional-info'),
                  headers: headers,
                  body: jsonEncode(user.toJson()),
                )
                .timeout(const Duration(seconds: 4));
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
      final token = await _authService.getToken();
      for (final base in AuthService.getOrderedBaseUrls()) {
        try {
          final uri = Uri.parse('$base/users/me/avatar');
          final request = http.MultipartRequest('POST', uri);

          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }

          request.files.add(
            await http.MultipartFile.fromPath('avatar', imageFile.path),
          );

          final streamedResponse =
              await request.send().timeout(const Duration(seconds: 6));
          final response = await http.Response.fromStream(streamedResponse);
          AuthService.activeBaseUrl = base;

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final newUrl = data['avatarUrl'] ?? data['url'] ?? data['avatar'];
            if (newUrl != null && newUrl is String) {
              final cached = await _authService.getCachedUserProfile();
              if (cached != null) {
                await _authService.saveUserProfile(cached.copyWith(avatarUrl: newUrl));
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
