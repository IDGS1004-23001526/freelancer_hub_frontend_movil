import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/convocatoria.dart';
import 'auth_service.dart';

class ProjectService {
  final AuthService _authService = AuthService();
  final http.Client _httpClient;

  ProjectService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Consulta el feed de convocatorias del backend (`GET /api/v1/projects`)
  Future<List<Convocatoria>> getProjects({
    String? search,
    String? category,
    double? minBudget,
    double? maxBudget,
    List<String>? skills,
  }) async {
    final token = await _authService.getToken();

    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      queryParams['category'] = category.trim();
    }
    if (minBudget != null) {
      queryParams['minBudget'] = minBudget.toInt().toString();
    }
    if (maxBudget != null) {
      queryParams['maxBudget'] = maxBudget.toInt().toString();
    }
    if (skills != null && skills.isNotEmpty) {
      queryParams['skills'] = skills.join(',');
    }

    final baseUrls = AuthService.getOrderedBaseUrls();

    for (final base in baseUrls) {
      try {
        final parsed = Uri.parse('$base/projects');
        final uri = parsed.replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );

        final response = await _httpClient.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'];
          if (data is List) {
            return data
                .map((item) =>
                    Convocatoria.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          }
        }
      } catch (_) {
        // Intenta la siguiente URL candidata si falla la red
      }
    }

    return [];
  }
}
