import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_gif.dart';

class GifApiService {
  static final GifApiService _instance = GifApiService._internal();
  factory GifApiService() => _instance;
  GifApiService._internal();

  /// Llave pública oficial de desarrollo para Giphy API (v1)
  /// Puedes reemplazarla por tu propia clave desde https://developers.giphy.com/
  static const String _defaultApiKey = 'sXpGFDGZs0Dv1mmNFvYaGUvYwKX0P4Ey';
  static const String _gifsBaseUrl = 'https://api.giphy.com/v1/gifs';
  static const String _stickersBaseUrl = 'https://api.giphy.com/v1/stickers';

  final http.Client _client = http.Client();
  final Map<String, List<ChatGif>> _cache = {};

  /// Obtiene los GIFs en tendencia (Trending) a nivel global estilo WhatsApp
  Future<List<ChatGif>> getTrendingGifs({int limit = 24}) async {
    const cacheKey = 'trending_gifs';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final uri = Uri.parse('$_gifsBaseUrl/trending?api_key=$_defaultApiKey&limit=$limit&rating=g');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = _parseGiphyResponse(body, defaultCategory: 'Tendencias');
        if (list.isNotEmpty) {
          _cache[cacheKey] = list;
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error consultando trending GIFs en Giphy API: $e. Usando catálogo de respaldo.');
      }
    }

    // Fallback: Catálogo local si no hay conexión o falla la API
    return ChatGif.catalog;
  }

  /// Busca GIFs en tiempo real por término de búsqueda (ej. "Homero", "trato", "risa")
  Future<List<ChatGif>> searchGifs(String query, {int limit = 24}) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return getTrendingGifs(limit: limit);
    }

    final cacheKey = 'search_gifs_${clean.toLowerCase()}';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final encoded = Uri.encodeQueryComponent(clean);
    final uri = Uri.parse('$_gifsBaseUrl/search?api_key=$_defaultApiKey&q=$encoded&limit=$limit&rating=g&lang=es');

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = _parseGiphyResponse(body, defaultCategory: clean);
        if (list.isNotEmpty) {
          _cache[cacheKey] = list;
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error buscando GIFs en Giphy API: $e. Usando catálogo de respaldo.');
      }
    }

    // Fallback: Catálogo local filtrado
    return ChatGif.search(clean);
  }

  /// Obtiene Stickers animados con fondo transparente en tendencia desde GIPHY Stickers API
  Future<List<ChatGif>> getTrendingStickers({int limit = 30}) async {
    const cacheKey = 'trending_stickers';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final uri = Uri.parse('$_stickersBaseUrl/trending?api_key=$_defaultApiKey&limit=$limit&rating=g');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = _parseGiphyResponse(body, defaultCategory: 'Stickers');
        if (list.isNotEmpty) {
          _cache[cacheKey] = list;
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error consultando trending Stickers en Giphy API: $e. Usando catálogo de respaldo.');
      }
    }

    // Fallback con el catálogo de stickers animados para que nunca quede vacío
    return ChatGif.stickerCatalog;
  }

  /// Busca Stickers animados con fondo transparente en tiempo real desde GIPHY Stickers API (estilo WhatsApp)
  Future<List<ChatGif>> searchStickers(String query, {int limit = 30}) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return getTrendingStickers(limit: limit);
    }

    final cacheKey = 'search_stickers_${clean.toLowerCase()}';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final encoded = Uri.encodeQueryComponent(clean);
    final uri = Uri.parse('$_stickersBaseUrl/search?api_key=$_defaultApiKey&q=$encoded&limit=$limit&rating=g&lang=es');

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = _parseGiphyResponse(body, defaultCategory: clean);
        if (list.isNotEmpty) {
          _cache[cacheKey] = list;
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error buscando Stickers en Giphy API: $e. Usando catálogo de respaldo.');
      }
    }

    // Fallback filtrando el catálogo local si la red falla
    final localMatches = ChatGif.stickerCatalog.where((s) {
      final q = clean.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    return localMatches.isNotEmpty ? localMatches : ChatGif.stickerCatalog;
  }

  /// Transforma la respuesta JSON oficial de Giphy a modelos ChatGif
  List<ChatGif> _parseGiphyResponse(dynamic json, {String defaultCategory = 'General'}) {
    if (json is! Map<String, dynamic>) return [];
    final data = json['data'];
    if (data is! List) return [];

    final List<ChatGif> results = [];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString() ?? '';
      final title = item['title']?.toString().replaceAll('GIF', '').replaceAll('Sticker', '').trim() ?? 'Sticker';
      final images = item['images'] as Map<String, dynamic>?;

      // Buscar URL en los formatos soportados por Giphy (fixed_height, fixed_width, downsized, etc.)
      String? gifUrl = images?['fixed_height']?['url']?.toString() ??
          images?['fixed_width']?['url']?.toString() ??
          images?['downsized_medium']?['url']?.toString() ??
          images?['downsized']?['url']?.toString() ??
          images?['fixed_height_small']?['url']?.toString() ??
          images?['original']?['url']?.toString();

      if (id.isNotEmpty && gifUrl != null && gifUrl.isNotEmpty) {
        // Asegurar protocolo HTTPS
        if (gifUrl.startsWith('http://')) {
          gifUrl = gifUrl.replaceFirst('http://', 'https://');
        }

        results.add(ChatGif(
          id: id,
          title: title.isEmpty ? 'Sticker Animado' : title,
          url: gifUrl,
          category: defaultCategory,
          tags: [defaultCategory.toLowerCase()],
        ));
      }
    }

    return results;
  }
}
