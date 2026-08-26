import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'contracts.dart';
import 'supabase_config.dart';
import 'supabase_marketplace_client.dart';

/// The server remains the authority. This client transports versioned contracts;
/// it never calculates prices, authorizes roles, or changes payment states locally.
class MarketplaceApiClient {
  MarketplaceApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  SupabaseMarketplaceClient? get _supabase =>
      SupabaseConfig.isConfigured ? SupabaseMarketplaceClient() : null;

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) return configured;
    return kIsWeb ? Uri.base.origin : '';
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<MarketConfig> activeMarket() async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
      return MarketConfig(
        id: market.id,
        governorate: market.governorate,
        city: market.city,
        currency: market.currency,
        isPilot: market.isPilot,
      );
    }
    final response = await _client.get(_uri('/api/trpc/market.active'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل إعدادات السوق.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    return MarketConfig.fromJson(
      (data['json'] ?? data) as Map<String, dynamic>,
    );
  }

  Future<List<ProductReview>> productReviews(String productId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مراجعات المنتجات اتصال Supabase.');
    }
    final rows = await supabase.productReviews(productId);
    return rows
        .map((row) => ProductReview.fromJson(row))
        .toList(growable: false);
  }

  Future<void> submitProductReview({
    required String productId,
    required String merchantOrderId,
    required int rating,
    String? comment,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مراجعات المنتجات اتصال Supabase.');
    }
    await supabase.submitProductReview(
      productId: productId,
      merchantOrderId: merchantOrderId,
      rating: rating,
      comment: comment,
    );
  }

  Future<List<MerchantPromotion>> merchantPromotions(String shopId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب العروض اتصال Supabase.');
    }
    final rows = await supabase.merchantPromotions(shopId);
    return rows
        .map((row) => MerchantPromotion.fromJson(row))
        .toList(growable: false);
  }

  Future<void> saveMerchantPromotion({
    String? id,
    required String shopId,
    required String code,
    required String kind,
    required int valueMinor,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxRedemptions,
    required String status,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب العروض اتصال Supabase.');
    }
    await supabase.saveMerchantPromotion(
      id: id,
      shopId: shopId,
      code: code,
      kind: kind,
      valueMinor: valueMinor,
      startsAt: startsAt,
      endsAt: endsAt,
      maxRedemptions: maxRedemptions,
      status: status,
    );
  }

  Future<List<NotificationEvent>> notifications({
    bool unreadOnly = false,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب الإشعارات اتصال Supabase.');
    }
    final rows = await supabase.notifications(unreadOnly: unreadOnly);
    return rows
        .map((row) => NotificationEvent.fromJson(row))
        .toList(growable: false);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب الإشعارات اتصال Supabase.');
    }
    await supabase.markNotificationRead(notificationId);
  }

  Future<List<OrderCaseSummary>> orderCases() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إدارة حالات الطلب اتصال Supabase.');
    }
    final rows = await supabase.orderCases();
    return rows
        .map((row) => OrderCaseSummary.fromJson(row))
        .toList(growable: false);
  }

  Future<void> openOrderCase({
    required String merchantOrderId,
    required String caseType,
    required String reason,
    int? requestedQuantity,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إدارة حالات الطلب اتصال Supabase.');
    }
    await supabase.openOrderCase(
      merchantOrderId: merchantOrderId,
      caseType: caseType,
      reason: reason,
      requestedQuantity: requestedQuantity,
    );
  }

  Future<List<MarketServiceArea>> serviceAreas() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مناطق الخدمة اتصال Supabase.');
    }
    final market = await supabase.activeMarket();
    if (market == null) return const [];
    final rows = await supabase.serviceAreas(market.id);
    return rows
        .map((row) => MarketServiceArea.fromJson(row))
        .toList(growable: false);
  }

  Future<List<PickupPoint>> pickupPoints() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب نقاط الاستلام اتصال Supabase.');
    }
    final market = await supabase.activeMarket();
    if (market == null) return const [];
    final rows = await supabase.pickupPoints(market.id);
    return rows.map((row) => PickupPoint.fromJson(row)).toList(growable: false);
  }

  Future<List<CustomerAddress>> customerAddresses() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب عناوين العملاء اتصال Supabase.');
    }
    final market = await supabase.activeMarket();
    if (market == null) return const [];
    final rows = await supabase.customerAddresses(market.id);
    return rows
        .map((row) => CustomerAddress.fromJson(row))
        .toList(growable: false);
  }

  Future<void> saveCustomerAddress({
    String? id,
    String? serviceAreaId,
    required String label,
    required String recipientName,
    required String phone,
    required String addressLine,
    String? landmark,
    required String city,
    String? district,
    required bool isDefault,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب عناوين العملاء اتصال Supabase.');
    }
    final market = await supabase.activeMarket();
    if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
    await supabase.saveCustomerAddress(
      id: id,
      marketId: market.id,
      serviceAreaId: serviceAreaId,
      label: label,
      recipientName: recipientName,
      phone: phone,
      addressLine: addressLine,
      landmark: landmark,
      city: city,
      district: district,
      isDefault: isDefault,
    );
  }

  Future<List<MarketplaceProduct>> products({String? query}) async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) return const [];
      final products = await supabase.products(
        query: query,
        marketId: market.id,
      );
      return products
          .map(
            (product) => MarketplaceProduct(
              id: product.id,
              name: product.name,
              priceMinor: product.priceMinor,
              currency: product.currency,
              stockQuantity: product.stockQuantity,
              shopName: product.shopName,
              shopSlug: product.shopSlug,
            ),
          )
          .toList(growable: false);
    }
    final input = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) input['query'] = query.trim();
    final uri = _uri('/api/trpc/catalog.products').replace(
      queryParameters: {
        'input': jsonEncode({'json': input}),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل كتالوج المنتجات.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = (data['json'] ?? data) as List<dynamic>;
    return json
        .map(
          (item) => MarketplaceProduct.fromCatalogJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<SessionUser?> currentUser() async {
    final supabase = _supabase;
    if (supabase != null) {
      final user = supabase.currentAuthUser;
      if (user == null) return null;
      final profile = await supabase.currentProfile();
      final roles = await supabase.currentRoles();
      return SessionUser(
        id: user.id,
        name: profile?.displayName ?? user.email,
        role: roles.contains('admin')
            ? 'admin'
            : roles.contains('merchant')
            ? 'merchant'
            : 'customer',
      );
    }
    final response = await _client.get(_uri('/api/trpc/auth.me'));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = data['json'] ?? data;
    return json == null
        ? null
        : SessionUser.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<void> submitMerchantApplication({
    required String phone,
    required String ownerName,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
      await supabase.submitMerchantApplication(
        phone: phone,
        ownerName: ownerName,
        marketId: market.id,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/merchant.submitApplication'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {'phone': phone, 'ownerName': ownerName},
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'تعذر إرسال طلب التاجر. تحقق من تسجيل الدخول والبيانات.',
      );
    }
  }

  Future<bool> hasMerchantContext() async {
    final supabase = _supabase;
    if (supabase != null) return (await supabase.merchantContext()) != null;
    final response = await _client.get(_uri('/api/trpc/merchant.mine'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر التحقق من حالة حساب التاجر.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data =
        (decoded['result'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final json = (data['json'] ?? data) as Map<String, dynamic>;
    return json['merchant'] != null;
  }

  Future<MerchantWorkspace> merchantWorkspace() async {
    final supabase = _supabase;
    if (supabase != null) {
      return MerchantWorkspace.fromJson(await supabase.merchantWorkspace());
    }
    final response = await _client.get(_uri('/api/trpc/merchant.mine'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل مساحة التاجر.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data =
        (decoded['result'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return MerchantWorkspace.fromJson(
      Map<String, dynamic>.from((data['json'] ?? data) as Map),
    );
  }

  Future<void> createShop({
    required String name,
    required String slug,
    required String areaLabel,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
      await supabase.createShop(
        name: name,
        slug: slug,
        areaLabel: areaLabel,
        marketId: market.id,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/merchant.createShop'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {'name': name, 'slug': slug, 'areaLabel': areaLabel},
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'تعذر إرسال المتجر للمراجعة. تحقق من الاسم والرابط المختصر.',
      );
    }
  }

  Future<MerchantAnalytics> merchantAnalytics(String shopId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب تقارير المتجر اتصال Supabase.');
    }
    final row = await supabase.merchantAnalytics(shopId);
    return MerchantAnalytics.fromJson(row);
  }

  Future<StorefrontSettings?> storefrontSettings(String shopId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إعدادات المتجر اتصال Supabase.');
    }
    final row = await supabase.storefrontSettings(shopId);
    return row == null ? null : StorefrontSettings.fromJson(row);
  }

  Future<void> saveStorefrontSettings({
    required String shopId,
    String? displayName,
    String? tagline,
    required String themeKey,
    required String primaryColor,
    String? logoStorageKey,
    String? customSlug,
    String? customDomain,
    required bool isPublished,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إعدادات المتجر اتصال Supabase.');
    }
    await supabase.saveStorefrontSettings(
      shopId: shopId,
      displayName: displayName,
      tagline: tagline,
      themeKey: themeKey,
      primaryColor: primaryColor,
      logoStorageKey: logoStorageKey,
      customSlug: customSlug,
      customDomain: customDomain,
      isPublished: isPublished,
    );
  }

  Future<List<InventoryLocation>> inventoryLocations(String shopId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مواقع المخزون اتصال Supabase.');
    }
    final rows = await supabase.inventoryLocations(shopId);
    return rows
        .map((row) => InventoryLocation.fromJson(row))
        .toList(growable: false);
  }

  Future<List<MerchantProductSummary>> merchantProducts() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إدارة الكتالوج اتصال Supabase.');
    }
    final rows = await supabase.merchantProducts();
    return rows
        .map((row) => MerchantProductSummary.fromJson(row))
        .toList(growable: false);
  }

  Future<List<ProductVariant>> productVariants(String productId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب متغيرات المنتجات اتصال Supabase.');
    }
    final rows = await supabase.productVariants(productId);
    return rows
        .map((row) => ProductVariant.fromJson(row))
        .toList(growable: false);
  }

  Future<void> saveProductVariant({
    String? id,
    required String productId,
    required String name,
    String? sku,
    required int priceMinor,
    required int stockQuantity,
    required String status,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب متغيرات المنتجات اتصال Supabase.');
    }
    await supabase.saveProductVariant(
      id: id,
      productId: productId,
      name: name,
      sku: sku,
      priceMinor: priceMinor,
      stockQuantity: stockQuantity,
      status: status,
    );
  }

  Future<void> saveProduct({
    String? id,
    required String shopId,
    String? categoryId,
    required String name,
    required String description,
    required int priceMinor,
    required int stockQuantity,
    required String status,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.saveProduct(
        id: id,
        shopId: shopId,
        categoryId: categoryId,
        name: name,
        description: description,
        priceMinor: priceMinor,
        stockQuantity: stockQuantity,
        status: status,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/merchant.saveProduct'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'id': id,
          'shopId': shopId,
          'categoryId': categoryId,
          'name': name,
          'description': description,
          'priceMinor': priceMinor,
          'stockQuantity': stockQuantity,
          'status': status,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر حفظ المنتج.');
    }
  }

  Future<void> saveMerchantPaymentMethod({
    String? id,
    required String name,
    required String accountHolderName,
    required String receivingIdentifier,
    required String instructions,
    required String proofRequirement,
    String providerCode = 'manual',
    Map<String, dynamic> providerMetadata = const {},
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.saveMerchantPaymentMethod(
        id: id,
        name: name,
        accountHolderName: accountHolderName,
        receivingIdentifier: receivingIdentifier,
        instructions: instructions,
        proofRequirement: proofRequirement,
        providerCode: providerCode,
        providerMetadata: providerMetadata,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/merchant.savePaymentMethod'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'id': id,
          'name': name,
          'accountHolderName': accountHolderName,
          'receivingIdentifier': receivingIdentifier,
          'customerInstructions': instructions,
          'proofRequirement': proofRequirement,
          'providerCode': providerCode,
          'providerMetadata': providerMetadata,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر حفظ طريقة الدفع اليدوية.');
    }
  }

  Future<void> setMerchantFulfilment({
    required String shopId,
    required String method,
    required String instructions,
    required bool isActive,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.setMerchantFulfilment(
        shopId: shopId,
        method: method,
        instructions: instructions,
        isActive: isActive,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/merchant.setFulfilment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'shopId': shopId,
          'method': method,
          'instructions': instructions,
          'isActive': isActive,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر حفظ إعداد التنفيذ.');
    }
  }

  Future<void> reviewPaymentClaim({
    required String merchantOrderId,
    required bool approve,
    String? reason,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.reviewPaymentClaim(
        merchantOrderId: merchantOrderId,
        approve: approve,
        reason: reason,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/payment.reviewClaim'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'merchantOrderId': merchantOrderId,
          'decision': approve ? 'paid' : 'rejected',
          'reason': reason,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر حفظ قرار مراجعة الدفع.');
    }
  }

  Future<void> updateMerchantFulfilment({
    required String merchantOrderId,
    required String fulfilmentStatus,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.updateMerchantFulfilment(
        merchantOrderId: merchantOrderId,
        fulfilmentStatus: fulfilmentStatus,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/merchant.updateFulfilment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'merchantOrderId': merchantOrderId,
          'fulfilmentStatus': fulfilmentStatus,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'تعذر تحديث حالة تنفيذ الطلب. تأكد من تأكيد الدفع أولاً.',
      );
    }
  }

  Future<IdentityVerificationSummary> identityMine() async {
    final supabase = _supabase;
    if (supabase != null) {
      return IdentityVerificationSummary.fromJson(
        await supabase.identityMine(),
      );
    }
    final response = await _client.get(_uri('/api/trpc/identity.mine'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل حالة التحقق.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data =
        (decoded['result'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return IdentityVerificationSummary.fromJson(
      Map<String, dynamic>.from((data['json'] ?? data) as Map),
    );
  }

  Future<void> submitIdentityEvidence({
    required String passportBase64,
    required String passportName,
    required String passportMimeType,
    required String selfieBase64,
    required String selfieName,
    required String selfieMimeType,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.submitIdentityEvidenceFromBase64(
        passportBase64: passportBase64,
        passportName: passportName,
        passportMimeType: passportMimeType,
        selfieBase64: selfieBase64,
        selfieName: selfieName,
        selfieMimeType: selfieMimeType,
      );
      return;
    }
    final body = {
      'consent': true,
      'passport': {
        'base64': passportBase64,
        'originalName': passportName,
        'mimeType': passportMimeType,
      },
      'selfie': {
        'base64': selfieBase64,
        'originalName': selfieName,
        'mimeType': selfieMimeType,
      },
    };
    final response = await _client.post(
      _uri('/api/trpc/identity.submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'json': body}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'تعذر إرسال صور التحقق. استخدم صورة JPEG أو PNG أو WebP أصغر من الحد المسموح.',
      );
    }
  }

  Future<List<AdminIdentityCase>> adminIdentityQueue() async {
    final supabase = _supabase;
    if (supabase != null) {
      final rows = await supabase.adminIdentityQueue();
      return rows
          .map((row) => AdminIdentityCase.fromJson(row))
          .toList(growable: false);
    }
    final response = await _client.get(_uri('/api/trpc/identity.adminQueue'));
    if (response.statusCode == 403) {
      throw ApiException('هذه الشاشة متاحة للإدارة المخوّلة فقط.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل قائمة المراجعة.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data =
        (decoded['result'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final json = (data['json'] ?? data) as List<dynamic>;
    return json
        .map(
          (item) => AdminIdentityCase.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<AdminIdentityEvidence>> adminIdentityEvidence(
    String identityCaseId,
  ) async {
    final supabase = _supabase;
    if (supabase != null) {
      final rows = await supabase.adminIdentityEvidence(identityCaseId);
      return rows
          .map((row) => AdminIdentityEvidence.fromJson(row))
          .toList(growable: false);
    }
    final uri = _uri('/api/trpc/identity.adminEvidenceAccess').replace(
      queryParameters: {
        'input': jsonEncode({
          'json': {'identityCaseId': identityCaseId},
        }),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر فتح الوثائق المصرح بها.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data =
        (decoded['result'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final json = (data['json'] ?? data) as List<dynamic>;
    return json
        .map(
          (item) => AdminIdentityEvidence.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> reviewIdentityCase({
    required String identityCaseId,
    required bool approve,
    required String note,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.reviewIdentityCase(
        identityCaseId: identityCaseId,
        approve: approve,
        note: note,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/identity.review'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'identityCaseId': identityCaseId,
          'decision': approve ? 'verified' : 'rejected',
          'note': note,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر حفظ قرار المراجعة. اكتب ملاحظة توضح القرار.');
    }
  }

  Future<List<MerchantOrderSummary>> myOrders() async {
    final supabase = _supabase;
    if (supabase != null) {
      final rows = await supabase.myOrders();
      return rows
          .map((row) => MerchantOrderSummary.fromJson(row))
          .toList(growable: false);
    }
    final response = await _client.get(_uri('/api/trpc/orders.mine'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل الطلبات.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>;
    final data = result['data'] as Map<String, dynamic>;
    final json = (data['json'] ?? data) as List<dynamic>;
    return json
        .map(
          (item) => MerchantOrderSummary.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> addToCart(String productId) async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
      await supabase.addCartItem(marketId: market.id, productId: productId);
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/cart.addItem'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {'productId': productId, 'quantity': 1},
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر إضافة المنتج إلى السلة.');
    }
  }

  Future<List<CartGroup>> cartGroups() async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) return const [];
      final groups = await supabase.cartSummary(market.id);
      return groups
          .map((group) => CartGroup.fromJson(group))
          .toList(growable: false);
    }
    final uri = _uri('/api/trpc/cart.get').replace(
      queryParameters: {
        'input': jsonEncode({'json': {}}),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر تحميل السلة.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data =
        (decoded['result'] as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final json = (data['json'] ?? data) as Map<String, dynamic>;
    return (json['groups'] as List<dynamic>)
        .map(
          (group) =>
              CartGroup.fromJson(Map<String, dynamic>.from(group as Map)),
        )
        .toList();
  }

  Future<void> checkoutCart({
    required List<Map<String, dynamic>> fulfilmentByShop,
    required List<Map<String, dynamic>> paymentMethodByMerchant,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
      await supabase.checkoutCreateOrders(
        marketId: market.id,
        fulfilmentByShop: fulfilmentByShop,
        paymentByMerchant: paymentMethodByMerchant,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/cart.checkout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'fulfilmentByShop': fulfilmentByShop,
          'paymentMethodByMerchant': paymentMethodByMerchant,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'تعذر إتمام الطلبات المنفصلة. تحقق من خيارات كل متجر ثم حاول مرة أخرى.',
      );
    }
  }

  Future<void> submitPaymentReference({
    required String merchantOrderId,
    required String reference,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.submitPaymentClaim(
        merchantOrderId: merchantOrderId,
        transactionReference: reference,
      );
      return;
    }
    final response = await _client.post(
      _uri('/api/trpc/payment.submitClaim'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'json': {
          'merchantOrderId': merchantOrderId,
          'transactionReference': reference,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('تعذر إرسال مرجع التحويل.');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
