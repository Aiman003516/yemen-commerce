import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<List<MerchantDeliveryZone>> merchantDeliveryZones(
    String shopId,
  ) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مناطق توصيل المتجر اتصال Supabase.');
    }
    final rows = await supabase.merchantDeliveryZones(shopId);
    return rows
        .map((row) => MerchantDeliveryZone.fromJson(row))
        .toList(growable: false);
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

  Future<List<ProviderCatalogEntry>> providerCatalog() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب قائمة المزودين اتصال Supabase.');
    }
    final rows = await supabase.providerCatalog();
    return rows
        .map((row) => ProviderCatalogEntry.fromJson(row))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> merchantWholesaleRequests(
    String shopId,
  ) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب طلبات الجملة اتصال Supabase.');
    }
    return supabase.listMerchantWholesaleRequests(shopId);
  }

  Future<void> saveWholesalePriceList({
    String? id,
    required String shopId,
    required String nameAr,
    required String currency,
    required String status,
    required String reason,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب قائمة الأسعار اتصال Supabase.');
    }
    await supabase.saveWholesalePriceList(
      id: id,
      shopId: shopId,
      nameAr: nameAr,
      currency: currency,
      status: status,
      reason: reason,
    );
  }

  Future<void> saveWholesalePriceListItem({
    String? id,
    required String priceListId,
    required String productId,
    String? variantId,
    required int unitPriceMinor,
    required int minQuantity,
    required String status,
    required String reason,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب أسعار الجملة اتصال Supabase.');
    }
    await supabase.saveWholesalePriceListItem(
      id: id,
      priceListId: priceListId,
      productId: productId,
      variantId: variantId,
      unitPriceMinor: unitPriceMinor,
      minQuantity: minQuantity,
      status: status,
      reason: reason,
    );
  }

  Future<void> reviewWholesaleRequestWithPriceList({
    required String requestId,
    required String status,
    required String reviewNote,
    String? priceListId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مراجعة طلبات الجملة اتصال Supabase.');
    }
    await supabase.reviewWholesaleRequestWithPriceList(
      requestId: requestId,
      status: status,
      reviewNote: reviewNote,
      priceListId: priceListId,
    );
  }

  Future<void> saveBusinessProfile({
    required String businessName,
    required String contactPhone,
    String? taxIdentifier,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب بيانات النشاط اتصال Supabase.');
    }
    await supabase.saveBusinessProfile(
      businessName: businessName,
      contactPhone: contactPhone,
      taxIdentifier: taxIdentifier,
    );
  }

  Future<void> openWholesaleRequest({
    required String shopId,
    required String note,
    int estimatedMonthlyMinor = 0,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب طلبات الجملة اتصال Supabase.');
    }
    await supabase.openWholesaleRequest(
      shopId: shopId,
      note: note,
      estimatedMonthlyMinor: estimatedMonthlyMinor,
    );
  }

  Future<String> openPosSession({
    required String shopId,
    String? openingNote,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب نقطة البيع اتصال Supabase.');
    }
    final result = await supabase.openPosSession(
      shopId: shopId,
      openingNote: openingNote,
    );
    return result['pos_session_id'].toString();
  }

  Future<void> closePosSession({
    required String posSessionId,
    required int countedTotalMinor,
    String? closingNote,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مطابقة وإغلاق نقطة البيع اتصال Supabase.');
    }
    await supabase.closePosSession(
      posSessionId: posSessionId,
      countedTotalMinor: countedTotalMinor,
      closingNote: closingNote,
    );
  }

  Future<void> recordPosSale({
    required String posSessionId,
    required int totalMinor,
    required String paymentMode,
    List<Map<String, dynamic>> lineItems = const [],
    String? note,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مبيعات نقطة البيع اتصال Supabase.');
    }
    await supabase.recordPosSale(
      posSessionId: posSessionId,
      totalMinor: totalMinor,
      paymentMode: paymentMode,
      lineItems: lineItems,
      note: note,
    );
  }

  Future<List<WholesalePriceListSummary>> merchantPriceLists(
    String shopId,
  ) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب قوائم أسعار الجملة اتصال Supabase.');
    }
    final rows = await supabase.listMerchantPriceLists(shopId);
    return rows
        .map((row) => WholesalePriceListSummary.fromJson(row))
        .toList(growable: false);
  }

  Future<List<WholesaleQuoteSummary>> merchantWholesaleQuotes(
    String shopId,
  ) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب عروض أسعار الجملة اتصال Supabase.');
    }
    final rows = await supabase.listMerchantWholesaleQuotes(shopId);
    return rows
        .map((row) => WholesaleQuoteSummary.fromJson(row))
        .toList(growable: false);
  }

  Future<List<WholesaleQuoteSummary>> customerWholesaleQuotes() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب عروض الأسعار الخاصة بك اتصال Supabase.');
    }
    final rows = await supabase.listCustomerWholesaleQuotes();
    return rows
        .map((row) => WholesaleQuoteSummary.fromJson(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createWholesaleQuoteVersion({
    String? quoteId,
    String? wholesaleRequestId,
    required String shopId,
    required String buyerUserId,
    required String currency,
    DateTime? validUntil,
    String? note,
    required List<Map<String, dynamic>> items,
    required String reason,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إنشاء عرض سعر جملة اتصال Supabase.');
    }
    if (items.isEmpty || reason.trim().length < 3) {
      throw ApiException('أضف بنداً واحداً وسبباً واضحاً قبل إرسال العرض.');
    }
    return supabase.createWholesaleQuoteVersion(
      quoteId: quoteId,
      wholesaleRequestId: wholesaleRequestId,
      shopId: shopId,
      buyerUserId: buyerUserId,
      currency: currency,
      validUntil: validUntil,
      note: note,
      items: items,
      reason: reason,
    );
  }

  Future<void> acceptWholesaleQuoteVersion(String quoteVersionId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب الموافقة على عرض السعر اتصال Supabase.');
    }
    await supabase.acceptWholesaleQuoteVersion(quoteVersionId);
  }

  Future<Map<String, dynamic>> applyAcceptedWholesaleQuote({
    required String merchantOrderId,
    required String quoteVersionId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب تطبيق السعر المتفاوض عليه اتصال Supabase.');
    }
    return supabase.applyAcceptedWholesaleQuote(
      merchantOrderId: merchantOrderId,
      quoteVersionId: quoteVersionId,
    );
  }

  Future<MerchantDailyRollup> refreshMerchantDailyRollup({
    required String shopId,
    required DateTime businessDate,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مؤشرات اليوم اتصال Supabase.');
    }
    final row = await supabase.refreshMerchantDailyRollup(
      shopId: shopId,
      businessDate: businessDate,
    );
    return MerchantDailyRollup.fromJson(row);
  }

  Future<List<MerchantDailyRollup>> merchantDailyRollups({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب السلسلة الزمنية للتحليلات اتصال Supabase.');
    }
    final rows = await supabase.merchantDailyRollups(
      shopId: shopId,
      from: from,
      to: to,
    );
    return rows
        .map((row) => MerchantDailyRollup.fromJson(row))
        .toList(growable: false);
  }

  Future<List<ProviderAdapterOperation>> providerAdapterOperations() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب بوابة المزودين اتصال Supabase.');
    }
    final rows = await supabase.providerAdapterOperations();
    return rows
        .map((row) => ProviderAdapterOperation.fromJson(row))
        .toList(growable: false);
  }

  Future<ProductAssetVariantSummary> uploadOptimizedProductImage({
    required String productId,
    required Uint8List source,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب معالجة صور المنتج اتصال Supabase.');
    }
    final row = await supabase.uploadOptimizedProductImage(
      productId: productId,
      source: source,
    );
    return ProductAssetVariantSummary.fromJson(row);
  }

  Future<ProductAssetVariantSummary> registerProductAssetVariant({
    required String productId,
    required String sourceStorageKey,
    required String format,
    required int width,
    required int height,
    required int byteSize,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب فهرسة صورة المنتج اتصال Supabase.');
    }
    final row = await supabase.registerProductAssetVariant(
      productId: productId,
      sourceStorageKey: sourceStorageKey,
      format: format,
      width: width,
      height: height,
      byteSize: byteSize,
    );
    return ProductAssetVariantSummary.fromJson(row);
  }

  Future<Map<String, dynamic>> merchantB2bAnalytics(String shopId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مؤشرات B2B اتصال Supabase.');
    }
    return supabase.merchantB2bAnalytics(shopId);
  }

  Future<List<Map<String, dynamic>>> exportMerchantB2b(
    String shopId, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (offset < 0 || offset > 10000) {
      throw ArgumentError.value(
        offset,
        'offset',
        'must be between 0 and 10000',
      );
    }
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('يتطلب تصدير B2B اتصال Supabase.');
    }
    return supabase.exportMerchantB2b(
      shopId,
      limit: limit.clamp(1, 500),
      offset: offset,
    );
  }

  Future<Map<String, dynamic>> merchantPosAnalytics(
    String shopId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مؤشرات POS اتصال Supabase.');
    }
    return supabase.merchantPosAnalytics(shopId, from: from, to: to);
  }

  Future<List<Map<String, dynamic>>> exportMerchantPos(
    String shopId, {
    required DateTime from,
    required DateTime to,
    int limit = 100,
    int offset = 0,
  }) async {
    if (offset < 0 || offset > 10000) {
      throw ArgumentError.value(
        offset,
        'offset',
        'must be between 0 and 10000',
      );
    }
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('يتطلب تصدير POS اتصال Supabase.');
    }
    return supabase.exportMerchantPos(
      shopId,
      from: from,
      to: to,
      limit: limit.clamp(1, 500),
      offset: offset,
    );
  }

  Future<void> saveMerchantIntegration({
    required String shopId,
    required String providerCode,
    required String status,
    Map<String, dynamic> configuration = const {},
    String? credentialReference,
    String? webhookEndpointReference,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إعدادات المزود اتصال Supabase.');
    }
    await supabase.saveMerchantIntegration(
      shopId: shopId,
      providerCode: providerCode,
      status: status,
      configuration: configuration,
      credentialReference: credentialReference,
      webhookEndpointReference: webhookEndpointReference,
    );
  }

  Future<MerchantQualitySummary> merchantQualitySummary(String shopId) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مؤشرات جودة المتجر اتصال Supabase.');
    }
    final row = await supabase.merchantQualitySummary(shopId);
    return MerchantQualitySummary.fromJson(row);
  }

  Future<void> openSupportTicket({
    required String category,
    required String subject,
    required String description,
    String priority = 'normal',
    String? merchantOrderId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('فتح تذكرة الدعم يتطلب اتصال Supabase.');
    }
    await supabase.openSupportTicket(
      category: category,
      subject: subject,
      description: description,
      priority: priority,
      merchantOrderId: merchantOrderId,
    );
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

  Future<void> saveInventoryLocation({
    required String shopId,
    required String name,
    String? areaLabel,
    String status = 'active',
    bool isDefault = false,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إدارة مواقع المخزون اتصال Supabase.');
    }
    await supabase.saveInventoryLocation(
      shopId: shopId,
      name: name,
      areaLabel: areaLabel,
      status: status,
      isDefault: isDefault,
    );
  }

  Future<InventoryAdjustmentResult> recordInventoryAdjustment({
    required String shopId,
    required String productId,
    required String locationId,
    required int quantityDelta,
    required String reason,
    required String idempotencyKey,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب تعديلات المخزون اتصال Supabase.');
    }
    final row = await supabase.recordInventoryAdjustment(
      shopId: shopId,
      productId: productId,
      locationId: locationId,
      quantityDelta: quantityDelta,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
    return InventoryAdjustmentResult.fromJson(row);
  }

  Future<InventoryCommandResult> completeInventoryTransfer({
    required String shopId,
    required String fromLocationId,
    required String toLocationId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required String idempotencyKey,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب عمليات نقل المخزون اتصال Supabase.');
    }
    final row = await supabase.completeInventoryTransfer(
      shopId: shopId,
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      items: items,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
    return InventoryCommandResult.fromJson(row);
  }

  Future<InventoryCommandResult> applyInventoryCount({
    required String shopId,
    required String locationId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required String idempotencyKey,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب جرد المخزون اتصال Supabase.');
    }
    final row = await supabase.applyInventoryCount(
      shopId: shopId,
      locationId: locationId,
      items: items,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
    return InventoryCommandResult.fromJson(row);
  }

  Future<List<MerchantOrderWorkbenchEntry>> merchantOrderWorkbench({
    required String shopId,
    String? fulfilmentStatus,
    String? paymentStatus,
    String? codStatus,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب لوحة الطلبات اتصال Supabase.');
    }
    try {
      final rows = await supabase.merchantOrderWorkbench(
        shopId: shopId,
        fulfilmentStatus: fulfilmentStatus,
        paymentStatus: paymentStatus,
        codStatus: codStatus,
        query: query,
        limit: limit,
        offset: offset,
      );
      return rows
          .map((row) => MerchantOrderWorkbenchEntry.fromJson(row))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw ApiException(
        _localizedSupabaseError(error, 'تعذر تحميل لوحة الطلبات.'),
      );
    }
  }

  Future<CodReconciliationBatch> openCodReconciliationBatch({
    required String shopId,
    required String businessDate,
    String? note,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مطابقة التحصيل النقدي اتصال Supabase.');
    }
    try {
      final row = await supabase.openCodReconciliationBatch(
        shopId: shopId,
        businessDate: businessDate,
        note: note,
      );
      return CodReconciliationBatch.fromJson(row);
    } on PostgrestException catch (error) {
      throw ApiException(
        _localizedSupabaseError(error, 'تعذر فتح دفعة المطابقة.'),
      );
    }
  }

  Future<void> recordCodCollectionInBatch({
    required String merchantOrderId,
    required int collectedMinor,
    required String reconciliationBatchId,
    String? note,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مطابقة التحصيل النقدي اتصال Supabase.');
    }
    try {
      await supabase.recordCodCollectionInBatch(
        merchantOrderId: merchantOrderId,
        collectedMinor: collectedMinor,
        reconciliationBatchId: reconciliationBatchId,
        note: note,
      );
    } on PostgrestException catch (error) {
      throw ApiException(
        _localizedSupabaseError(error, 'تعذر تسجيل التحصيل في الدفعة.'),
      );
    }
  }

  Future<CodReconciliationCloseResult> closeCodReconciliationBatch({
    required String batchId,
    String? note,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مطابقة التحصيل النقدي اتصال Supabase.');
    }
    try {
      final row = await supabase.closeCodReconciliationBatch(
        batchId: batchId,
        note: note,
      );
      return CodReconciliationCloseResult.fromJson(row);
    } on PostgrestException catch (error) {
      throw ApiException(
        _localizedSupabaseError(error, 'تعذر إغلاق دفعة المطابقة.'),
      );
    }
  }

  Future<CodReconciliationSnapshot> merchantCodReconciliation({
    required String shopId,
    required String businessDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب مطابقة التحصيل النقدي اتصال Supabase.');
    }
    try {
      final row = await supabase.merchantCodReconciliation(
        shopId: shopId,
        businessDate: businessDate,
        limit: limit,
        offset: offset,
      );
      return CodReconciliationSnapshot.fromJson(row);
    } on PostgrestException catch (error) {
      throw ApiException(
        _localizedSupabaseError(error, 'تعذر تحميل مطابقة التحصيل النقدي.'),
      );
    }
  }

  Future<CatalogImportResult> bulkSaveProducts({
    required String shopId,
    required List<Map<String, dynamic>> rows,
    required String idempotencyKey,
    String sourceFormat = 'csv',
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب الاستيراد الجماعي اتصال Supabase.');
    }
    final row = await supabase.bulkSaveProducts(
      shopId: shopId,
      rows: rows,
      idempotencyKey: idempotencyKey,
      sourceFormat: sourceFormat,
    );
    return CatalogImportResult.fromJson(row);
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

  Future<String?> saveProduct({
    String? id,
    required String shopId,
    String? categoryId,
    required String name,
    required String description,
    required int priceMinor,
    required int stockQuantity,
    required String status,
    String? barcode,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      if (barcode != null && barcode.trim().isNotEmpty) {
        final result = await supabase.saveProductWithBarcode(
          id: id,
          shopId: shopId,
          categoryId: categoryId,
          name: name,
          description: description,
          priceMinor: priceMinor,
          stockQuantity: stockQuantity,
          status: status,
          barcode: barcode.trim(),
        );
        return result['product_id']?.toString();
      }
      final result = await supabase.saveProduct(
        id: id,
        shopId: shopId,
        categoryId: categoryId,
        name: name,
        description: description,
        priceMinor: priceMinor,
        stockQuantity: stockQuantity,
        status: status,
      );
      return result['product_id']?.toString();
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
    return null;
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
    String? reason,
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      await supabase.updateMerchantFulfilment(
        merchantOrderId: merchantOrderId,
        fulfilmentStatus: fulfilmentStatus,
        reason: reason,
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
          'reason': reason,
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
    List<Map<String, dynamic>> deliveryByShop = const [],
  }) async {
    final supabase = _supabase;
    if (supabase != null) {
      final market = await supabase.activeMarket();
      if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
      await supabase.checkoutCreateOrders(
        marketId: market.id,
        fulfilmentByShop: fulfilmentByShop,
        paymentByMerchant: paymentMethodByMerchant,
        deliveryByShop: deliveryByShop,
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
          'deliveryByShop': deliveryByShop,
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'تعذر إتمام الطلبات المنفصلة. تحقق من خيارات كل متجر ثم حاول مرة أخرى.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> courierAssignments() async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب عمليات التوصيل اتصال Supabase.');
    }
    return supabase.courierAssignments();
  }

  Future<void> assignOrderCourier({
    required String merchantOrderId,
    required String courierUserId,
    String? deliveryNote,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب إسنادات التوصيل اتصال Supabase.');
    }
    await supabase.assignOrderCourier(
      merchantOrderId: merchantOrderId,
      courierUserId: courierUserId,
      deliveryNote: deliveryNote,
    );
  }

  Future<void> recordCourierHandoff({
    required String assignmentId,
    required String status,
    String? deliveryNote,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب تحديثات التسليم اتصال Supabase.');
    }
    await supabase.recordCourierHandoff(
      assignmentId: assignmentId,
      status: status,
      deliveryNote: deliveryNote,
    );
  }

  Future<void> recordCourierDispatchEvent({
    required String assignmentId,
    required String eventType,
    String? note,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تتطلب أحداث التوصيل اتصال Supabase.');
    }
    await supabase.recordCourierDispatchEvent(
      assignmentId: assignmentId,
      eventType: eventType,
      note: note,
    );
  }

  Future<void> checkoutCartIdempotent({
    required List<Map<String, dynamic>> fulfilmentByShop,
    required List<Map<String, dynamic>> paymentMethodByMerchant,
    required List<Map<String, dynamic>> deliveryByShop,
    required String commandKey,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('إتمام الطلبات المتكررة يتطلب اتصال Supabase.');
    }
    final market = await supabase.activeMarket();
    if (market == null) throw ApiException('لا يوجد سوق نشط حالياً.');
    await supabase.checkoutCreateOrdersIdempotent(
      marketId: market.id,
      fulfilmentByShop: fulfilmentByShop,
      paymentByMerchant: paymentMethodByMerchant,
      deliveryByShop: deliveryByShop,
      commandKey: commandKey,
    );
  }

  Future<void> applyOrderPromotion({
    required String merchantOrderId,
    required String code,
    String? commandKey,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تطبيق العرض يتطلب اتصال Supabase.');
    }
    await supabase.applyOrderPromotion(
      merchantOrderId: merchantOrderId,
      code: code,
      commandKey: commandKey,
    );
  }

  Future<void> recordCodCollection({
    required String merchantOrderId,
    required int collectedMinor,
    String? note,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw ApiException('تسجيل التحصيل النقدي يتطلب اتصال Supabase.');
    }
    await supabase.recordCodCollection(
      merchantOrderId: merchantOrderId,
      collectedMinor: collectedMinor,
      note: note,
    );
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

@visibleForTesting
String localizedSupabaseErrorForTest(
  PostgrestException error,
  String fallback,
) => _localizedSupabaseError(error, fallback);

String _localizedSupabaseError(PostgrestException error, String fallback) {
  final signal = '${error.code} ${error.message}'.toUpperCase();
  if (signal.contains('AUTH_REQUIRED')) {
    return 'انتهت الجلسة أو لم يتم تسجيل الدخول. سجّل الدخول مجدداً.';
  }
  if (signal.contains('SHOP_NOT_OWNED') || signal.contains('ORDER_NOT_FOUND')) {
    return 'لا يمكن الوصول إلى هذا الطلب أو المتجر بهذه الجلسة.';
  }
  if (signal.contains('INVALID_ORDER_WORKBENCH_PAGINATION') ||
      signal.contains('INVALID_COD_PAGINATION')) {
    return 'نطاق البحث غير صالح. استخدم صفحة لا تتجاوز 500 سجلاً.';
  }
  if (signal.contains('INVALID_FULFILMENT_FILTER') ||
      signal.contains('INVALID_PAYMENT_FILTER') ||
      signal.contains('INVALID_COD_FILTER')) {
    return 'مرشح الطلبات غير صالح. حدّث الشاشة ثم حاول مجدداً.';
  }
  if (signal.contains('QUOTE_REASON_REQUIRED')) {
    return 'اكتب سبباً واضحاً قبل إرسال إصدار العرض.';
  }
  if (signal.contains('INVALID_QUOTE_ITEMS') ||
      signal.contains('INVALID_QUOTE_ITEM')) {
    return 'بنود العرض غير صالحة. تحقق من المنتجات والكميات والأسعار.';
  }
  if (signal.contains('QUOTE_NOT_AVAILABLE')) {
    return 'هذا العرض غير متاح أو انتهت صلاحيته.';
  }
  if (signal.contains('QUOTE_NOT_FOUND')) {
    return 'عرض السعر غير موجود أو لا تملك صلاحية الوصول إليه.';
  }
  if (signal.contains('QUOTE_ITEMS_MISMATCH')) {
    return 'بنود العرض لا تطابق بنود الطلب. راجع السلة ثم حاول مجدداً.';
  }
  if (signal.contains('QUOTE_ORDER_ALREADY_PRICED') ||
      signal.contains('QUOTE_ORDER_NOT_EDITABLE')) {
    return 'لا يمكن تغيير سعر هذا الطلب بعد بدء إجراء التسعير أو الدفع.';
  }
  if (signal.contains('INVALID_ROLLUP_DATE')) {
    return 'تاريخ الملخص اليومي غير صالح أو يقع في المستقبل.';
  }
  if (signal.contains('INVALID_ROLLUP_RANGE')) {
    return 'نطاق الملخصات اليومية غير صالح. اختر فترة لا تتجاوز سنة.';
  }
  if (signal.contains('INVALID_ASSET_VARIANT')) {
    return 'بيانات صورة المنتج غير صالحة. اختر صورة كتالوج أخرى.';
  }
  if (signal.contains('INVALID_ASSET_PATH')) {
    return 'مسار صورة المنتج غير صالح لهذه الجلسة.';
  }
  if (signal.contains('ASSET_VARIANT_NOT_FOUND')) {
    return 'سجل تحسين صورة المنتج غير موجود أو لا تملك صلاحية الوصول إليه.';
  }
  if (signal.contains('PROVIDER_UNAVAILABLE')) {
    return 'هذا المزود غير متاح حالياً؛ لم يتم تنفيذ أي اتصال خارجي.';
  }
  if (signal.contains('COD_BATCH_NOT_FOUND')) {
    return 'دفعة المطابقة غير موجودة أو لم تعد متاحة. حدّث الشاشة.';
  }
  if (signal.contains('COD_BATCH_ALREADY_CLOSED')) {
    return 'أُغلقت دفعة المطابقة ولا يمكن تعديلها.';
  }
  if (signal.contains('COD_BATCH_NOT_OPEN')) {
    return 'دفعة المطابقة ليست مفتوحة لتسجيل تحصيل جديد.';
  }
  if (signal.contains('COD_ORDER_BATCH_DATE_MISMATCH')) {
    return 'لا يمكن تسجيل الطلب في دفعة بتاريخ مختلف عن تاريخ الطلب.';
  }
  if (signal.contains('COD_NOT_APPLICABLE')) {
    return 'هذا الطلب ليس طلب تحصيل نقدي.';
  }
  if (signal.contains('COD_ALREADY_FINAL')) {
    return 'تم اعتماد تحصيل هذا الطلب ولا يمكن تعديله.';
  }
  if (signal.contains('INVALID_COD_AMOUNT')) {
    return 'مبلغ التحصيل غير صالح.';
  }
  return fallback;
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
