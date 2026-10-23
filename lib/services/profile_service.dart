import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_constants.dart';
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

  Future<UserProfile?> fetchProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.profile),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(
            data is Map<String, dynamic> ? (data['user'] ?? data) : {});
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProfile(UserProfile user) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(ApiConstants.profile),
        headers: headers,
        body: jsonEncode(user.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final token = await _authService.getToken();
      final uri = Uri.parse(ApiConstants.updateAvatar);
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath('avatar', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['avatarUrl'] ?? data['url'] ?? data['avatar'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
