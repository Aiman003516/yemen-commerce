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

  Future<SessionUser?> currentUser() async {
    final response = await _client.get(_uri('/api/trpc/auth.me'));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = data['json'] ?? data;
    return json == null ? null : SessionUser.fromJson(json as Map<String, dynamic>);
  }

  Future<void> submitMerchantApplication({required String phone, required String ownerName}) async {
    final response = await _client.post(
      _uri('/api/trpc/merchant.submitApplication'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'json': {'phone': phone, 'ownerName': ownerName}}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر إرسال طلب التاجر. تحقق من تسجيل الدخول والبيانات.');
    }
  }

  Future<List<MerchantOrderSummary>> myOrders() async {
    final response = await _client.get(_uri('/api/trpc/orders.mine'));
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException('تعذر تحميل الطلبات.');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = (data['json'] ?? data) as List<dynamic>;
    return json.map((item) => MerchantOrderSummary.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> addToCart(int productId) async {
    final response = await _client.post(_uri('/api/trpc/cart.addItem'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'json': {'productId': productId, 'quantity': 1}}));
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException('تعذر إضافة المنتج إلى السلة.');
  }

  Future<List<CartGroup>> cartGroups() async {
    final uri = _uri('/api/trpc/cart.get').replace(queryParameters: {'input': jsonEncode({'json': {}})});
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) throw ApiException('تعذر تحميل السلة.');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['result'] as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final json = (data['json'] ?? data) as Map<String, dynamic>;
    return (json['groups'] as List<dynamic>).map((group) => CartGroup.fromJson(group as Map<String, dynamic>)).toList();
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
