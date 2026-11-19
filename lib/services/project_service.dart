import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../models/convocatoria.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ProjectService {
  final ApiClient _apiClient;

  ProjectService({ApiClient? apiClient, http.Client? httpClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Consulta el feed de convocatorias del backend (`GET /api/v1/projects`)
  /// El token de autorización y la renovación transparente (401 refresh token)
  /// son manejados automáticamente por [ApiClient].
  Future<List<Convocatoria>> getProjects({
    String? search,
    String? category,
    double? minBudget,
    double? maxBudget,
    List<String>? skills,
  }) async {
    final queryParams = <String, dynamic>{};
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
        final response = await _apiClient.dio.get(
          '$base/projects',
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          AuthService.activeBaseUrl = base;
          final dynamic body = response.data;
          final dynamic data =
              (body is Map<String, dynamic>) ? body['data'] : body;
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
