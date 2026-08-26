import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Supabase-native data access for the shared Flutter application.
///
/// This client uses only the publishable key and the signed-in user's session.
/// Authorization, pricing, stock, checkout splitting, and status transitions
/// remain enforced by Supabase RLS and PostgreSQL functions.
class SupabaseMarketplaceClient {
  SupabaseMarketplaceClient({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  bool get isConfigured => SupabaseConfig.isConfigured;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithMagicLink(String email) async {
    const configuredRedirect = String.fromEnvironment(
      'SUPABASE_AUTH_REDIRECT_URL',
    );
    await _client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: configuredRedirect.isNotEmpty
          ? configuredRedirect
          : (kIsWeb ? Uri.base.origin : null),
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<SupabaseMarket?> activeMarket() async {
    final row = await _client
        .from('markets')
        .select(
          'id,governorate,city,district,service_area,status,currency,is_pilot',
        )
        .eq('status', 'active')
        .order('is_pilot', ascending: false)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : SupabaseMarket.fromJson(row);
  }

  Future<List<Map<String, dynamic>>> serviceAreas(String marketId) async {
    final rows = await _client
        .from('market_service_areas')
        .select(
          'id,market_id,name_ar,name_en,area_code,status,delivery_enabled,pickup_enabled',
        )
        .eq('market_id', marketId)
        .eq('status', 'active')
        .order('name_ar');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> pickupPoints(String marketId) async {
    final rows = await _client
        .from('pickup_points')
        .select(
          'id,market_id,service_area_id,name_ar,name_en,address_details,contact_phone,operating_hours',
        )
        .eq('market_id', marketId)
        .eq('status', 'active')
        .order('name_ar');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> merchantDeliveryZones(
    String shopId,
  ) async {
    final rows = await _client
        .from('merchant_delivery_zones')
        .select(
          'id,shop_id,service_area_id,name,fee_minor,currency,eta_min_minutes,eta_max_minutes,instructions,is_active',
        )
        .eq('shop_id', shopId)
        .eq('is_active', true)
        .order('name');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> customerAddresses(String marketId) async {
    final user = currentAuthUser;
    if (user == null) throw const SupabaseMarketplaceException('AUTH_REQUIRED');
    final rows = await _client
        .from('customer_addresses')
        .select(
          'id,customer_user_id,market_id,service_area_id,label,recipient_name,phone,address_line,landmark,city,district,is_default,is_active',
        )
        .eq('customer_user_id', user.id)
        .eq('market_id', marketId)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> saveCustomerAddress({
    String? id,
    required String marketId,
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
    final result = await _client.rpc(
      'save_customer_address',
      params: {
        'p_id': id,
        'p_market_id': marketId,
        'p_service_area_id': serviceAreaId,
        'p_label': label,
        'p_recipient_name': recipientName,
        'p_phone': phone,
        'p_address_line': addressLine,
        'p_landmark': landmark,
        'p_city': city,
        'p_district': district,
        'p_is_default': isDefault,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<SupabaseProduct>> products({
    String? query,
    String? marketId,
  }) async {
    var request = _client
        .from('products')
        .select(
          'id,name,description,price_minor,currency,stock_quantity,shop_id,shops!inner(id,name,slug,merchant_id,market_id,status)',
        )
        .eq('status', 'active')
        .eq('shops.status', 'approved');
    if (marketId != null) request = request.eq('shops.market_id', marketId);
    if (query != null && query.trim().isNotEmpty) {
      request = request.ilike('name', '%${query.trim()}%');
    }
    final rows = await request.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => SupabaseProduct.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<SupabaseProfile?> currentProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;
    final row = await _client
        .from('profiles')
        .select('id,display_name,email,phone')
        .eq('id', user.id)
        .maybeSingle();
    return row == null ? null : SupabaseProfile.fromJson(row);
  }

  Future<List<String>> currentRoles() async {
    final user = currentAuthUser;
    if (user == null) return const [];
    final rows = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id);
    return (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['role'] as String)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> myOrders() async {
    final user = currentAuthUser;
    if (user == null) throw const SupabaseMarketplaceException('AUTH_REQUIRED');
    final rows = await _client
        .from('merchant_orders')
        .select(
          'id,total_minor,currency,payment_status,fulfilment_status,account_holder_name,receiving_identifier,payment_instructions,payment_provider_code',
        )
        .eq('customer_user_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> submitPaymentClaim({
    required String merchantOrderId,
    required String transactionReference,
  }) async {
    final result = await _client.rpc(
      'submit_payment_claim',
      params: {
        'p_merchant_order_id': merchantOrderId,
        'p_transaction_reference': transactionReference,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> productReviews(String productId) async {
    final rows = await _client
        .from('product_reviews')
        .select('id,product_id,rating,comment,status')
        .eq('product_id', productId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> submitProductReview({
    required String productId,
    required String merchantOrderId,
    required int rating,
    String? comment,
  }) async {
    final result = await _client.rpc(
      'submit_product_review',
      params: {
        'p_product_id': productId,
        'p_merchant_order_id': merchantOrderId,
        'p_rating': rating,
        'p_comment': comment,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> merchantPromotions(String shopId) async {
    final rows = await _client
        .from('merchant_promotions')
        .select('id,merchant_id,shop_id,code,kind,value_minor,status')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> saveMerchantPromotion({
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
    final result = await _client.rpc(
      'save_merchant_promotion',
      params: {
        'p_id': id,
        'p_shop_id': shopId,
        'p_code': code,
        'p_kind': kind,
        'p_value_minor': valueMinor,
        'p_starts_at': startsAt?.toUtc().toIso8601String(),
        'p_ends_at': endsAt?.toUtc().toIso8601String(),
        'p_max_redemptions': maxRedemptions,
        'p_status': status,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> notifications({
    bool unreadOnly = false,
  }) async {
    final user = currentAuthUser;
    if (user == null) throw const SupabaseMarketplaceException('AUTH_REQUIRED');
    var request = _client
        .from('notification_events')
        .select('id,kind,payload,read_at,created_at')
        .eq('recipient_user_id', user.id);
    if (unreadOnly) request = request.isFilter('read_at', null);
    final rows = await request.order('created_at', ascending: false).limit(50);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> markNotificationRead(
    String notificationId,
  ) async {
    final result = await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> orderCases() async {
    final user = currentAuthUser;
    if (user == null) throw const SupabaseMarketplaceException('AUTH_REQUIRED');
    final rows = await _client
        .from('order_cases')
        .select('id,merchant_order_id,case_type,status,reason,resolution_note')
        .eq('opened_by_user_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> openOrderCase({
    required String merchantOrderId,
    required String caseType,
    required String reason,
    int? requestedQuantity,
  }) async {
    final result = await _client.rpc(
      'open_order_case',
      params: {
        'p_merchant_order_id': merchantOrderId,
        'p_case_type': caseType,
        'p_reason': reason,
        'p_requested_quantity': requestedQuantity,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> reviewOrderCase({
    required String caseId,
    required String decision,
    required String resolutionNote,
    String? merchantNote,
  }) async {
    final result = await _client.rpc(
      'review_order_case',
      params: {
        'p_case_id': caseId,
        'p_decision': decision,
        'p_resolution_note': resolutionNote,
        'p_merchant_note': merchantNote,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> ensureCart(String marketId) async {
    final user = currentAuthUser;
    if (user == null) throw const SupabaseMarketplaceException('AUTH_REQUIRED');
    final row = await _client
        .from('carts')
        .upsert({
          'customer_user_id': user.id,
          'market_id': marketId,
        }, onConflict: 'customer_user_id,market_id')
        .select('id,customer_user_id,market_id')
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> cartItems(String marketId) async {
    final cart = await ensureCart(marketId);
    final rows = await _client
        .from('cart_items')
        .select(
          'id,quantity,product_id,products!inner(id,name,description,price_minor,currency,stock_quantity,shop_id,shops!inner(id,name,slug,merchant_id,market_id,status))',
        )
        .eq('cart_id', cart['id']);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> cartSummary(String marketId) async {
    final rows = await cartItems(marketId);
    final groups = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final product = Map<String, dynamic>.from(row['products'] as Map);
      final shop = Map<String, dynamic>.from(product['shops'] as Map);
      final shopId = shop['id'] as String;
      final quantity = (row['quantity'] as num).toInt();
      final unitPrice = (product['price_minor'] as num).toInt();
      final group = groups.putIfAbsent(
        shopId,
        () => {
          'shop': <String, dynamic>{
            'id': shopId,
            'name': shop['name'],
            'slug': shop['slug'],
          },
          'merchant_id': shop['merchant_id'],
          'total_minor': 0,
          'items': <Map<String, dynamic>>[],
        },
      );
      (group['items'] as List<Map<String, dynamic>>).add({
        'product_id': product['id'],
        'name': product['name'],
        'quantity': quantity,
        'unit_price_minor': unitPrice,
        'line_total_minor': unitPrice * quantity,
        'stock_quantity': product['stock_quantity'],
        'status': product['status'],
        'currency': product['currency'],
      });
      group['total_minor'] =
          (group['total_minor'] as int) + unitPrice * quantity;
    }
    for (final group in groups.values) {
      final shop = group['shop'] as Map<String, dynamic>;
      final fulfilment = await _client
          .from('shop_fulfilment_methods')
          .select('method,instructions')
          .eq('shop_id', shop['id'])
          .eq('is_active', true);
      final payments = await _client
          .from('payment_methods')
          .select('id,name,provider_code')
          .eq('merchant_id', group['merchant_id'])
          .eq('is_active', true)
          .eq('mode', 'manual');
      group['fulfilment_methods'] = fulfilment;
      group['payment_methods'] = payments;
    }
    return groups.values.toList(growable: false);
  }

  Future<void> addCartItem({
    required String marketId,
    required String productId,
    int quantity = 1,
  }) async {
    final cart = await ensureCart(marketId);
    final existing = await _client
        .from('cart_items')
        .select('id,quantity')
        .eq('cart_id', cart['id'])
        .eq('product_id', productId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('cart_items').insert({
        'cart_id': cart['id'],
        'product_id': productId,
        'quantity': quantity,
      });
    } else {
      await _client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity})
          .eq('id', existing['id']);
    }
  }

  Future<Map<String, dynamic>?> merchantContext() async {
    final user = currentAuthUser;
    if (user == null) return null;
    final row = await _client
        .from('merchants')
        .select(
          'id,owner_user_id,market_id,phone,owner_name,verification_status',
        )
        .eq('owner_user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> providerCatalog() async {
    final rows = await _client
        .from('provider_catalog')
        .select(
          'provider_code,category,display_name_ar,display_name_en,integration_mode,readiness_state,supports_webhooks,notes_ar',
        )
        .eq('active', true)
        .order('category')
        .order('display_name_ar');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> saveBusinessProfile({
    required String businessName,
    required String contactPhone,
    String? taxIdentifier,
  }) async {
    final result = await _client.rpc(
      'save_business_profile',
      params: {
        'p_business_name': businessName,
        'p_contact_phone': contactPhone,
        'p_tax_identifier': taxIdentifier,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> openWholesaleRequest({
    required String shopId,
    required String note,
    int estimatedMonthlyMinor = 0,
  }) async {
    final result = await _client.rpc(
      'open_wholesale_request',
      params: {
        'p_shop_id': shopId,
        'p_note': note,
        'p_estimated_monthly_minor': estimatedMonthlyMinor,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> openPosSession({
    required String shopId,
    String? openingNote,
  }) async {
    final result = await _client.rpc(
      'open_pos_session',
      params: {'p_shop_id': shopId, 'p_opening_note': openingNote},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> recordPosSale({
    required String posSessionId,
    required int totalMinor,
    required String paymentMode,
    List<Map<String, dynamic>> lineItems = const [],
    String? note,
  }) async {
    final result = await _client.rpc(
      'record_pos_sale',
      params: {
        'p_pos_session_id': posSessionId,
        'p_total_minor': totalMinor,
        'p_payment_mode': paymentMode,
        'p_line_items': lineItems,
        'p_note': note,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> saveMerchantIntegration({
    required String shopId,
    required String providerCode,
    required String status,
    Map<String, dynamic> configuration = const {},
    String? credentialReference,
    String? webhookEndpointReference,
  }) async {
    final result = await _client.rpc(
      'save_merchant_integration',
      params: {
        'p_shop_id': shopId,
        'p_provider_code': providerCode,
        'p_status': status,
        'p_configuration': configuration,
        'p_credential_reference': credentialReference,
        'p_webhook_endpoint_reference': webhookEndpointReference,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> merchantQualitySummary(String shopId) async {
    final result = await _client.rpc(
      'merchant_quality_summary',
      params: {'p_shop_id': shopId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> openSupportTicket({
    required String category,
    required String subject,
    required String description,
    String priority = 'normal',
    String? merchantOrderId,
  }) async {
    final result = await _client.rpc(
      'open_support_ticket',
      params: {
        'p_category': category,
        'p_subject': subject,
        'p_description': description,
        'p_priority': priority,
        'p_merchant_order_id': merchantOrderId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> merchantAnalytics(String shopId) async {
    final result = await _client.rpc(
      'merchant_dashboard_metrics',
      params: {'p_shop_id': shopId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>?> storefrontSettings(String shopId) async {
    final row = await _client
        .from('storefront_settings')
        .select(
          'shop_id,display_name,tagline,theme_key,primary_color,logo_storage_key,custom_slug,custom_domain,is_published',
        )
        .eq('shop_id', shopId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> saveStorefrontSettings({
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
    final result = await _client.rpc(
      'save_storefront_settings',
      params: {
        'p_shop_id': shopId,
        'p_display_name': displayName,
        'p_tagline': tagline,
        'p_theme_key': themeKey,
        'p_primary_color': primaryColor,
        'p_logo_storage_key': logoStorageKey,
        'p_custom_slug': customSlug,
        'p_custom_domain': customDomain,
        'p_is_published': isPublished,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> inventoryLocations(String shopId) async {
    final rows = await _client
        .from('inventory_locations')
        .select('id,shop_id,name,area_label,status,is_default')
        .eq('shop_id', shopId)
        .order('is_default', ascending: false)
        .order('name');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> merchantProducts() async {
    final merchant = await merchantContext();
    if (merchant == null) return const [];
    final rows = await _client
        .from('products')
        .select(
          'id,shop_id,name,description,price_minor,currency,stock_quantity,status,shops!inner(name,merchant_id)',
        )
        .eq('shops.merchant_id', merchant['id'])
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> merchantWorkspace() async {
    final merchant = await merchantContext();
    if (merchant == null) {
      return {
        'merchant': null,
        'shops': [],
        'payment_methods': [],
        'orders': [],
      };
    }
    final merchantId = merchant['id'];
    final shops = await _client
        .from('shops')
        .select('id,name,status,area_label')
        .eq('merchant_id', merchantId)
        .order('created_at');
    final paymentMethods = await _client
        .from('payment_methods')
        .select(
          'id,name,account_holder_name,receiving_identifier,customer_instructions,proof_requirement,is_active,provider_code,provider_metadata',
        )
        .eq('merchant_id', merchantId)
        .order('created_at');
    final orders = await _client
        .from('merchant_orders')
        .select(
          'id,total_minor,payment_status,fulfilment_status,payment_provider_code,delivery_fee_minor,cod_expected_minor,cod_collected_minor,cod_status',
        )
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return {
      'merchant': merchant,
      'shops': shops,
      'payment_methods': paymentMethods,
      'orders': orders,
    };
  }

  Future<Map<String, dynamic>> submitMerchantApplication({
    required String phone,
    required String ownerName,
    required String marketId,
  }) async {
    final result = await _client.rpc(
      'submit_merchant_application',
      params: {
        'p_phone': phone,
        'p_owner_name': ownerName,
        'p_market_id': marketId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> createShop({
    required String name,
    required String slug,
    required String areaLabel,
    required String marketId,
  }) async {
    final result = await _client.rpc(
      'create_shop',
      params: {
        'p_name': name,
        'p_slug': slug,
        'p_area_label': areaLabel,
        'p_market_id': marketId,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> saveProduct({
    String? id,
    required String shopId,
    String? categoryId,
    required String name,
    required String description,
    required int priceMinor,
    required int stockQuantity,
    required String status,
  }) async {
    final result = await _client.rpc(
      'save_product',
      params: {
        'p_id': id,
        'p_shop_id': shopId,
        'p_category_id': categoryId,
        'p_name': name,
        'p_description': description,
        'p_price_minor': priceMinor,
        'p_stock_quantity': stockQuantity,
        'p_status': status,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> productVariants(String productId) async {
    final rows = await _client
        .from('product_variants')
        .select('id,product_id,name,sku,price_minor,stock_quantity,status')
        .eq('product_id', productId)
        .order('created_at');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> saveProductVariant({
    String? id,
    required String productId,
    required String name,
    String? sku,
    required int priceMinor,
    required int stockQuantity,
    required String status,
  }) async {
    final result = await _client.rpc(
      'save_product_variant',
      params: {
        'p_id': id,
        'p_product_id': productId,
        'p_name': name,
        'p_sku': sku,
        'p_price_minor': priceMinor,
        'p_stock_quantity': stockQuantity,
        'p_status': status,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> saveMerchantPaymentMethod({
    String? id,
    required String name,
    required String accountHolderName,
    required String receivingIdentifier,
    required String instructions,
    required String proofRequirement,
    String providerCode = 'manual',
    Map<String, dynamic> providerMetadata = const {},
  }) async {
    final result = await _client.rpc(
      'save_merchant_payment_method',
      params: {
        'p_id': id,
        'p_name': name,
        'p_account_holder_name': accountHolderName,
        'p_receiving_identifier': receivingIdentifier,
        'p_instructions': instructions,
        'p_proof_requirement': proofRequirement,
        'p_provider_code': providerCode,
        'p_provider_metadata': providerMetadata,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> setMerchantFulfilment({
    required String shopId,
    required String method,
    required String instructions,
    required bool isActive,
  }) async {
    final result = await _client.rpc(
      'set_merchant_fulfilment',
      params: {
        'p_shop_id': shopId,
        'p_method': method,
        'p_instructions': instructions,
        'p_is_active': isActive,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> reviewPaymentClaim({
    required String merchantOrderId,
    required bool approve,
    String? reason,
  }) async {
    final result = await _client.rpc(
      'review_payment_claim',
      params: {
        'p_merchant_order_id': merchantOrderId,
        'p_decision': approve ? 'paid' : 'rejected',
        'p_reason': reason,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> updateMerchantFulfilment({
    required String merchantOrderId,
    required String fulfilmentStatus,
  }) async {
    final result = await _client.rpc(
      'transition_fulfilment',
      params: {
        'p_merchant_order_id': merchantOrderId,
        'p_next_status': fulfilmentStatus,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> identityMine() async {
    final merchant = await merchantContext();
    if (merchant == null) {
      return {'identityCase': null, 'evidenceKinds': <String>[]};
    }
    final row = await _client
        .from('identity_verification_cases')
        .select('id,status,decision_note,identity_evidence(kind)')
        .eq('merchant_id', merchant['id'])
        .maybeSingle();
    final evidence = row == null
        ? const <dynamic>[]
        : (row['identity_evidence'] as List<dynamic>? ?? const []);
    return {
      'identityCase': row,
      'evidenceKinds': evidence
          .map((item) => (item as Map<String, dynamic>)['kind'])
          .toList(),
    };
  }

  Future<Map<String, dynamic>> submitIdentityEvidenceFromBase64({
    required String passportBase64,
    required String passportName,
    required String passportMimeType,
    required String selfieBase64,
    required String selfieName,
    required String selfieMimeType,
  }) async {
    final user = currentAuthUser;
    if (user == null) throw const SupabaseMarketplaceException('AUTH_REQUIRED');
    final batch = DateTime.now().microsecondsSinceEpoch.toString();
    final passportPath = '${user.id}/$batch/passport';
    final selfiePath = '${user.id}/$batch/selfie';
    await _client.storage
        .from('identity-evidence')
        .uploadBinary(
          passportPath,
          base64Decode(passportBase64),
          fileOptions: FileOptions(contentType: passportMimeType, upsert: true),
        );
    await _client.storage
        .from('identity-evidence')
        .uploadBinary(
          selfiePath,
          base64Decode(selfieBase64),
          fileOptions: FileOptions(contentType: selfieMimeType, upsert: true),
        );
    return submitIdentityCase(
      passportStorageKey: passportPath,
      passportMimeType: passportMimeType,
      passportOriginalName: passportName,
      selfieStorageKey: selfiePath,
      selfieMimeType: selfieMimeType,
      selfieOriginalName: selfieName,
    );
  }

  Future<Map<String, dynamic>> submitIdentityCase({
    required String passportStorageKey,
    required String passportMimeType,
    required String passportOriginalName,
    required String selfieStorageKey,
    required String selfieMimeType,
    required String selfieOriginalName,
  }) async {
    final result = await _client.rpc(
      'submit_identity_case',
      params: {
        'p_passport_storage_key': passportStorageKey,
        'p_passport_mime_type': passportMimeType,
        'p_passport_original_name': passportOriginalName,
        'p_selfie_storage_key': selfieStorageKey,
        'p_selfie_mime_type': selfieMimeType,
        'p_selfie_original_name': selfieOriginalName,
        'p_consent': true,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> adminIdentityQueue() async {
    final rows = await _client
        .from('identity_verification_cases')
        .select('id,merchant_id,status')
        .inFilter('status', ['submitted', 'under_review'])
        .order('created_at');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> adminIdentityEvidence(
    String identityCaseId,
  ) async {
    final rows = await _client
        .from('identity_evidence')
        .select('kind,storage_key')
        .eq('identity_case_id', identityCaseId);
    final result = <Map<String, dynamic>>[];
    for (final row in rows as List<dynamic>) {
      final map = Map<String, dynamic>.from(row as Map);
      final signedUrl = await _client.storage
          .from('identity-evidence')
          .createSignedUrl(map['storage_key'] as String, 300);
      result.add({'kind': map['kind'], 'signed_url': signedUrl});
    }
    return result;
  }

  Future<Map<String, dynamic>> reviewIdentityCase({
    required String identityCaseId,
    required bool approve,
    required String note,
  }) async {
    final result = await _client.rpc(
      'review_identity_case',
      params: {
        'p_identity_case_id': identityCaseId,
        'p_decision': approve ? 'verified' : 'rejected',
        'p_note': note,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> checkoutCreateOrders({
    required String marketId,
    required List<Map<String, dynamic>> fulfilmentByShop,
    required List<Map<String, dynamic>> paymentByMerchant,
    List<Map<String, dynamic>> deliveryByShop = const [],
  }) async {
    final result = await _client.rpc(
      'checkout_create_orders',
      params: {
        'p_market_id': marketId,
        'p_fulfilment_by_shop': fulfilmentByShop,
        'p_payment_by_merchant': paymentByMerchant,
        'p_delivery_by_shop': deliveryByShop,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> recordCodCollection({
    required String merchantOrderId,
    required int collectedMinor,
    String? note,
  }) async {
    final result = await _client.rpc(
      'record_cod_collection',
      params: {
        'p_merchant_order_id': merchantOrderId,
        'p_collected_minor': collectedMinor,
        'p_note': note,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }
}

class SupabaseMarketplaceException implements Exception {
  const SupabaseMarketplaceException(this.code);
  final String code;

  @override
  String toString() => code;
}

class SupabaseMarket {
  const SupabaseMarket({
    required this.id,
    required this.governorate,
    required this.city,
    required this.status,
    required this.currency,
    required this.isPilot,
    this.district,
    this.serviceArea,
  });

  final String id;
  final String governorate;
  final String city;
  final String status;
  final String currency;
  final bool isPilot;
  final String? district;
  final String? serviceArea;

  factory SupabaseMarket.fromJson(Map<String, dynamic> json) => SupabaseMarket(
    id: json['id'] as String,
    governorate: json['governorate'] as String,
    city: json['city'] as String,
    status: json['status'] as String,
    currency: json['currency'] as String,
    isPilot: json['is_pilot'] as bool,
    district: json['district'] as String?,
    serviceArea: json['service_area'] as String?,
  );
}

class SupabaseProfile {
  const SupabaseProfile({
    required this.id,
    this.displayName,
    this.email,
    this.phone,
  });
  final String id;
  final String? displayName;
  final String? email;
  final String? phone;

  factory SupabaseProfile.fromJson(Map<String, dynamic> json) =>
      SupabaseProfile(
        id: json['id'] as String,
        displayName: json['display_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}

class SupabaseProduct {
  const SupabaseProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.currency,
    required this.stockQuantity,
    required this.shopId,
    required this.shopName,
    required this.shopSlug,
    required this.merchantId,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final int priceMinor;
  final String currency;
  final int stockQuantity;
  final String shopId;
  final String shopName;
  final String shopSlug;
  final String merchantId;

  factory SupabaseProduct.fromJson(Map<String, dynamic> json) {
    final shop = Map<String, dynamic>.from(json['shops'] as Map);
    return SupabaseProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      priceMinor: (json['price_minor'] as num).toInt(),
      currency: json['currency'] as String,
      stockQuantity: (json['stock_quantity'] as num).toInt(),
      shopId: json['shop_id'] as String,
      shopName: shop['name'] as String,
      shopSlug: shop['slug'] as String,
      merchantId: shop['merchant_id'] as String,
    );
  }
}
