import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'contracts.dart';

/// The server remains the authority. This client transports versioned contracts;
/// it never calculates prices, authorizes roles, or changes payment states locally.
class MarketplaceApiClient {
  MarketplaceApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? Uri.base.origin : '';
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<MarketConfig> activeMarket() async {
    final response = await _client.get(_uri('/api/trpc/market.active'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل إعدادات السوق.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = (data['json'] ?? data) as Map<String, dynamic>;
    return MarketConfig.fromJson(json);
  }

  Future<List<MarketplaceProduct>> products({String? query}) async {
    final input = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) input['query'] = query.trim();
    final uri = _uri('/api/trpc/catalog.products').replace(queryParameters: {'input': jsonEncode({'json': input})});
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل كتالوج المنتجات.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = (data['json'] ?? data) as List<dynamic>;
    return json.map((item) => MarketplaceProduct.fromCatalogJson(item as Map<String, dynamic>)).toList();
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
