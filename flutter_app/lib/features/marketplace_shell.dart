import 'dart:convert';

import 'package:commerce_core/commerce_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/contracts.dart';
import '../core/supabase_config.dart';
import '../core/supabase_marketplace_client.dart';
import '../core/outbox_replay_worker.dart';
import '../core/secure_command_outbox.dart';

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({
    super.key,
    this.market,
    this.marketLoading = false,
    this.user,
  });

  final MarketConfig? market;
  final bool marketLoading;
  final SessionUser? user;

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  int _selectedIndex = 0;

  static const _destinations = <_Destination>[
    _Destination('الرئيسية', Icons.storefront_outlined, Icons.storefront),
    _Destination('السلة', Icons.shopping_bag_outlined, Icons.shopping_bag),
    _Destination('طلباتي', Icons.receipt_long_outlined, Icons.receipt_long),
    _Destination(
      'للتجار',
      Icons.store_mall_directory_outlined,
      Icons.store_mall_directory,
    ),
    _Destination('الخدمات', Icons.auto_awesome_outlined, Icons.auto_awesome),
    _Destination('المزامنة', Icons.sync_outlined, Icons.sync),
    _Destination(
      'الإدارة',
      Icons.admin_panel_settings_outlined,
      Icons.admin_panel_settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        final page = _pageFor(_selectedIndex);
        if (!desktop) {
          return Scaffold(
            appBar: _topBar(compact: true),
            body: page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: _destinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: Icon(destination.outlined),
                      selectedIcon: Icon(destination.filled),
                      label: destination.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                minWidth: 94,
                extended: constraints.maxWidth >= 1180,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                leading: const Padding(
                  padding: EdgeInsets.only(top: 28, bottom: 26),
                  child: _BrandMark(),
                ),
                destinations: _destinations
                    .map(
                      (destination) => NavigationRailDestination(
                        icon: Icon(destination.outlined),
                        selectedIcon: Icon(destination.filled),
                        label: Text(destination.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _topBar(),
                    Expanded(child: page),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _topBar({bool compact = false}) => AppBar(
    titleSpacing: compact ? 20 : 36,
    title: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        children: [
          if (compact) const _BrandMark(compact: true),
          if (compact) const SizedBox(width: 10),
          const Text('يمن كومرس'),
        ],
      ),
    ),
    actions: [
      if (widget.user == null)
        TextButton.icon(
          onPressed: _startLogin,
          icon: const Icon(Icons.login_rounded),
          label: const Text('تسجيل الدخول'),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('مرحباً ${widget.user!.name ?? 'بك'}'),
        ),
        IconButton(
          onPressed: _signOut,
          tooltip: 'تسجيل الخروج',
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      const SizedBox(width: 14),
    ],
  );

  Widget _pageFor(int index) => switch (index) {
    0 => _HomePage(
      market: widget.market,
      marketLoading: widget.marketLoading,
      user: widget.user,
      onNavigate: (index) => setState(() => _selectedIndex = index),
    ),
    1 => _CartPage(user: widget.user),
    2 => _OrdersPage(user: widget.user),
    3 => _MerchantPage(user: widget.user),
    4 => const _ServicesPage(),
    5 => const _SyncCenterPage(),
    _ => _AdminPage(user: widget.user),
  };

  Future<void> _startLogin() async {
    if (!SupabaseConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SupabaseConfig.missingConfigurationMessage)),
      );
      return;
    }
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الدخول'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, emailController.text.trim()),
            child: const Text('إرسال الرابط'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await SupabaseMarketplaceClient().signInWithMagicLink(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط تسجيل الدخول إلى بريدك الإلكتروني.'),
          ),
        );
      }
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إرسال رابط تسجيل الدخول. تحقق من البريد وإعدادات المصادقة.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    if (SupabaseConfig.isConfigured) {
      await SupabaseMarketplaceClient().signOut();
    }
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 34 : 48,
    height: compact ? 34 : 48,
    decoration: BoxDecoration(
      color: const Color(0xFF006A63),
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
    ),
    child: const Icon(Icons.storefront_rounded, color: Colors.white),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.onNavigate,
    this.market,
    required this.marketLoading,
    this.user,
  });
  final ValueChanged<int> onNavigate;
  final MarketConfig? market;
  final bool marketLoading;
  final SessionUser? user;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(city: market?.city ?? 'إب', onBrowse: () => onNavigate(1)),
              if (marketLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 30),
              const _SectionHeader(
                title: 'كيف يعمل السوق؟',
                subtitle: 'تجربة محلية واضحة تحفظ استقلال كل متجر ومدفوعاته.',
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _PrincipleCard(
                    icon: Icons.travel_explore_rounded,
                    title: 'اكتشف متاجر إب',
                    detail: 'تظهر المتاجر بعد اعتماد الإدارة فقط.',
                  ),
                  _PrincipleCard(
                    icon: Icons.shopping_bag_rounded,
                    title: 'سلة واحدة، طلبات منفصلة',
                    detail: 'تُجمع المنتجات حسب التاجر قبل إتمام الطلب.',
                  ),
                  _PrincipleCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'دفع لصاحب المتجر',
                    detail: 'تُراجع إثباتات الدفع يدوياً وبشكل آمن.',
                  ),
                ],
              ),
              const SizedBox(height: 34),
              const _SectionHeader(
                title: 'المتاجر والمنتجات المعتمدة',
                subtitle: 'ستظهر هنا بعد اكتمال الاعتماد ونشر الكتالوج.',
              ),
              const SizedBox(height: 14),
              _CatalogSection(user: user),
              const SizedBox(height: 20),
              _AddressBookSection(user: user),
              const SizedBox(height: 20),
              _NotificationSection(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationSection extends StatefulWidget {
  const _NotificationSection({required this.user});

  final SessionUser? user;

  @override
  State<_NotificationSection> createState() => _NotificationSectionState();
}

class _NotificationSectionState extends State<_NotificationSection> {
  late Future<List<NotificationEvent>> _notifications = MarketplaceApiClient()
      .notifications();

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<List<NotificationEvent>>(
          future: _notifications,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            if (snapshot.hasError) {
              return const Text('تعذر تحميل الإشعارات حالياً.');
            }
            final notifications = snapshot.data ?? const <NotificationEvent>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionHeader(
                  title: 'التنبيهات',
                  subtitle: 'تحديثات الطلبات والدفع والتنفيذ في مكان واحد.',
                ),
                const SizedBox(height: 10),
                if (notifications.isEmpty)
                  const Text('لا توجد تنبيهات جديدة.')
                else
                  ...notifications
                      .take(5)
                      .map(
                        (notification) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active_outlined,
                          ),
                          title: Text(_notificationTitle(notification)),
                          subtitle: Text(
                            notification.payload['next_value']?.toString() ??
                                notification.payload['event_type']
                                    ?.toString() ??
                                'تحديث جديد',
                          ),
                          onTap: notification.isRead
                              ? null
                              : () async {
                                  await MarketplaceApiClient()
                                      .markNotificationRead(notification.id);
                                  if (mounted) {
                                    setState(
                                      () => _notifications =
                                          MarketplaceApiClient()
                                              .notifications(),
                                    );
                                  }
                                },
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _notificationTitle(NotificationEvent notification) {
    switch (notification.kind) {
      case 'payment_review':
        return 'تحديث مراجعة الدفع';
      case 'delivery_update':
        return 'تحديث التنفيذ والتوصيل';
      case 'case_update':
        return 'تحديث حالة الطلب';
      case 'system':
        return 'تنبيه من المنصة';
      default:
        return 'تحديث طلب';
    }
  }
}

class _AddressBookSection extends StatefulWidget {
  const _AddressBookSection({required this.user});

  final SessionUser? user;

  @override
  State<_AddressBookSection> createState() => _AddressBookSectionState();
}

class _AddressBookSectionState extends State<_AddressBookSection> {
  Future<List<CustomerAddress>>? _addresses;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    if (widget.user != null) {
      _addresses = MarketplaceApiClient().customerAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<List<CustomerAddress>>(
          future: _addresses,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final addresses = snapshot.data ?? const <CustomerAddress>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: _SectionHeader(
                        title: 'عناوين التوصيل',
                        subtitle: 'احفظ العناوين والملامح التي يحتاجها التاجر أو مندوب التوصيل.',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('إضافة'),
                    ),
                  ],
                ),
                if (snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('تعذر تحميل العناوين. يمكنك المحاولة لاحقاً.'),
                  )
                else if (addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('لم تحفظ عنواناً بعد.'),
                  )
                else
                  ...addresses.map(
                    (address) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        address.isDefault
                            ? Icons.home_rounded
                            : Icons.location_on_outlined,
                      ),
                      title: Text(
                        '${address.label}${address.isDefault ? ' · افتراضي' : ''}',
                      ),
                      subtitle: Text(
                        '${address.recipientName} · ${address.addressLine} · ${address.city}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _addAddress() async {
    final label = TextEditingController(text: 'المنزل');
    final recipient = TextEditingController();
    final phone = TextEditingController();
    final addressLine = TextEditingController();
    final landmark = TextEditingController();
    final city = TextEditingController(text: 'إب');
    final district = TextEditingController();
    var isDefault = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة عنوان توصيل'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'اسم العنوان'),
                ),
                TextField(
                  controller: recipient,
                  decoration: const InputDecoration(labelText: 'اسم المستلم'),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                ),
                TextField(
                  controller: addressLine,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'العنوان والوصف',
                  ),
                ),
                TextField(
                  controller: landmark,
                  decoration: const InputDecoration(
                    labelText: 'أقرب معلم أو نقطة دالة',
                  ),
                ),
                TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'المدينة'),
                ),
                TextField(
                  controller: district,
                  decoration: const InputDecoration(labelText: 'المديرية'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isDefault,
                  title: const Text('اجعل هذا العنوان افتراضياً'),
                  onChanged: (value) =>
                      setDialogState(() => isDefault = value ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (recipient.text.trim().length < 2 ||
                    phone.text.trim().length < 5 ||
                    addressLine.text.trim().length < 4 ||
                    city.text.trim().length < 2) {
                  return;
                }
                try {
                  await MarketplaceApiClient().saveCustomerAddress(
                    label: label.text.trim(),
                    recipientName: recipient.text.trim(),
                    phone: phone.text.trim(),
                    addressLine: addressLine.text.trim(),
                    landmark: landmark.text.trim(),
                    city: city.text.trim(),
                    district: district.text.trim(),
                    isDefault: isDefault,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  setState(_refresh);
                } on ApiException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ العنوان'),
            ),
          ],
        ),
      ),
    );
    label.dispose();
    recipient.dispose();
    phone.dispose();
    addressLine.dispose();
    landmark.dispose();
    city.dispose();
    district.dispose();
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onBrowse, required this.city});
  final VoidCallback onBrowse;
  final String city;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(
        colors: [Color(0xFF006A63), Color(0xFF024B4B)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 26,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Pill(label: '$city · السوق التجريبي الأول'),
              const SizedBox(height: 18),
              const Text(
                'تسوّق محلياً، بثقة ووضوح.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'منصة متعددة المتاجر، مصممة للعربية أولاً. كل متجر يستقبل مدفوعاته بنفسه وكل طلب يُتابع بشكل مستقل.',
                style: TextStyle(
                  color: Color(0xFFD7F0E9),
                  fontSize: 16,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD39A2C),
            foregroundColor: const Color(0xFF1F1605),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          ),
          onPressed: onBrowse,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('ابدأ التسوق'),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: .2)),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: const Color(0xFF68655F)),
      ),
    ],
  );
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 310,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE2F2EC),
              foregroundColor: const Color(0xFF006A63),
              child: Icon(icon),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFF68655F), height: 1.55),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CatalogSection extends StatefulWidget {
  const _CatalogSection({this.user});
  final SessionUser? user;

  @override
  State<_CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<_CatalogSection> {
  final _search = TextEditingController();
  late Future<List<MarketplaceProduct>> _products = MarketplaceApiClient()
      .products();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() => setState(
    () => _products = MarketplaceApiClient().products(query: _search.text),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _runSearch(),
              decoration: const InputDecoration(
                hintText: 'ابحث في المنتجات المعتمدة',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(onPressed: _runSearch, child: const Text('بحث')),
        ],
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<MarketplaceProduct>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return _CatalogNotice(
              icon: Icons.cloud_off_outlined,
              title: 'تعذر تحميل الكتالوج',
              detail: 'تحقق من الاتصال ثم حاول البحث مرة أخرى.',
            );
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const _CatalogNotice(
              icon: Icons.storefront_outlined,
              title: 'نستعد لاستقبال المتاجر المعتمدة في إب',
              detail: 'لا نعرض متاجر أو منتجات تجريبية. يظهر الكتالوج فقط بعد إدخاله واعتماده من التاجر والإدارة.',
            );
          }
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: products
                .map(
                  (product) => _ProductCard(
                    product: product,
                    canAdd: widget.user != null,
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF5ECD8),
            foregroundColor: const Color(0xFFD39A2C),
            child: Icon(icon, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF68655F), height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.canAdd});
  final MarketplaceProduct product;
  final bool canAdd;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.shopName,
              style: const TextStyle(
                color: Color(0xFF006A63),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${product.priceMinor} ${product.currency}',
              style: const TextStyle(color: Color(0xFF68655F)),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: () async {
                if (!canAdd) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'سجّل الدخول أولاً لإضافة المنتجات إلى السلة.',
                      ),
                    ),
                  );
                  return;
                }
                try {
                  await MarketplaceApiClient().addToCart(product.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة المنتج إلى السلة.'),
                      ),
                    );
                  }
                } on ApiException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('أضف إلى السلة'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CartPage extends StatefulWidget {
  const _CartPage({this.user});
  final SessionUser? user;
  @override
  State<_CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<_CartPage> {
  late Future<List<CartGroup>> _cart = MarketplaceApiClient().cartGroups();
  final Map<String, String> _fulfilmentByShop = {};
  final Map<String, String> _paymentByMerchant = {};
  final Map<String, String?> _addressByShop = {};
  final Map<String, String?> _pickupByShop = {};
  final Map<String, String?> _zoneByShop = {};
  final Map<String, Future<List<MerchantDeliveryZone>>> _zonesByShop = {};
  Future<List<CustomerAddress>>? _addresses;
  Future<List<PickupPoint>>? _pickupPoints;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _addresses = MarketplaceApiClient().customerAddresses();
      _pickupPoints = MarketplaceApiClient().pickupPoints();
    }
  }

  Future<List<MerchantDeliveryZone>> _zonesFor(String shopId) =>
      _zonesByShop.putIfAbsent(
        shopId,
        () => MarketplaceApiClient().merchantDeliveryZones(shopId),
      );
  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const _CenteredPage(
        icon: Icons.lock_outline,
        title: 'سجّل الدخول لاستخدام السلة',
        detail:
            'ستُحفظ منتجاتك في سلة واحدة وتُقسم بوضوح حسب المتجر قبل الدفع.',
      );
    }
    return FutureBuilder<List<CartGroup>>(
      future: _cart,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _CenteredPage(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل السلة',
            detail: 'تحقق من الاتصال ثم حاول مرة أخرى.',
          );
        }
        final groups = snapshot.data ?? [];
        if (groups.isEmpty) {
          return const _CenteredPage(
            icon: Icons.shopping_bag_outlined,
            title: 'سلتك فارغة',
            detail: 'تُعرض المنتجات في مجموعات منفصلة لكل متجر عند إضافتها.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'سلة واحدة، طلبات ودفع منفصلان',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'اختر طريقة التنفيذ وطريقة الدفع يدوياً لكل متجر. سيُنشأ طلب مستقل لكل مجموعة.',
            ),
            const SizedBox(height: 14),
            ...groups.map((group) {
              final fulfilment =
                  _fulfilmentByShop[group.shopId] ??
                  (group.fulfilmentMethods.isEmpty
                      ? null
                      : group.fulfilmentMethods.first);
              final payment =
                  _paymentByMerchant[group.merchantId] ??
                  (group.paymentMethods.isEmpty
                      ? null
                      : group.paymentMethods.first.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.shopName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ...group.items.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          trailing: Text('${item.priceMinor} ${item.currency}'),
                        ),
                      ),
                      const Divider(),
                      Text(
                        'إجمالي هذا المتجر: ${group.totalMinor} YER',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (group.fulfilmentMethods.isEmpty)
                        const _InlineWarning(
                          'لا توجد طريقة تنفيذ مفعلة لهذا المتجر حالياً.',
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'fulfilment-${group.shopId}-$fulfilment',
                          ),
                          initialValue: fulfilment,
                          decoration: const InputDecoration(
                            labelText: 'طريقة التنفيذ',
                          ),
                          items: group.fulfilmentMethods
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(_fulfilmentLabel(method)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _fulfilmentByShop[group.shopId] =
                                value ?? group.fulfilmentMethods.first,
                          ),
                        ),
                      if (fulfilment != null &&
                          (fulfilment == 'seller_arranged' ||
                              fulfilment == 'collection'))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _CheckoutDeliverySelection(
                            fulfilment: fulfilment,
                            addresses: _addresses ?? Future.value(const []),
                            pickupPoints:
                                _pickupPoints ?? Future.value(const []),
                            zones: _zonesFor(group.shopId),
                            selectedAddressId: _addressByShop[group.shopId],
                            selectedPickupPointId: _pickupByShop[group.shopId],
                            selectedZoneId: _zoneByShop[group.shopId],
                            onAddressChanged: (value) => setState(
                              () => _addressByShop[group.shopId] = value,
                            ),
                            onPickupPointChanged: (value) => setState(
                              () => _pickupByShop[group.shopId] = value,
                            ),
                            onZoneChanged: (value) => setState(
                              () => _zoneByShop[group.shopId] = value,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (group.paymentMethods.isEmpty)
                        const _InlineWarning(
                          'لا توجد طريقة دفع يدوية مفعلة لهذا التاجر حالياً.',
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey('payment-${group.merchantId}-$payment'),
                          initialValue: payment,
                          decoration: const InputDecoration(
                            labelText: 'طريقة الدفع لهذا المتجر',
                          ),
                          items: group.paymentMethods
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method.id,
                                  child: Text(method.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _paymentByMerchant[group.merchantId] =
                                value ?? group.paymentMethods.first.id,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _checkingOut ? null : () => _checkout(groups),
              icon: _checkingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.call_split_outlined),
              label: Text(
                _checkingOut ? 'جارٍ إنشاء الطلبات' : 'إنشاء الطلبات المنفصلة',
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fulfilmentLabel(String value) => switch (value) {
    'collection' => 'استلام من المتجر',
    'digital' => 'تسليم رقمي',
    _ => 'تسليم يرتبه التاجر',
  };

  Future<void> _checkout(List<CartGroup> groups) async {
    final fulfilment = <Map<String, dynamic>>[];
    final payments = <Map<String, dynamic>>[];
    final delivery = <Map<String, dynamic>>[];
    for (final group in groups) {
      final selectedFulfilment =
          _fulfilmentByShop[group.shopId] ??
          (group.fulfilmentMethods.isEmpty
              ? null
              : group.fulfilmentMethods.first);
      final selectedPayment =
          _paymentByMerchant[group.merchantId] ??
          (group.paymentMethods.isEmpty ? null : group.paymentMethods.first.id);
      if (selectedFulfilment == null || selectedPayment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('اختر التنفيذ والدفع لمتجر ${group.shopName}.'),
          ),
        );
        return;
      }
      final deliverySelection = <String, dynamic>{'shopId': group.shopId};
      if (selectedFulfilment == 'seller_arranged') {
        final addressId = _addressByShop[group.shopId];
        final zoneId = _zoneByShop[group.shopId];
        if (addressId == null || zoneId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'اختر العنوان ومنطقة التوصيل لمتجر ${group.shopName}.',
              ),
            ),
          );
          return;
        }
        deliverySelection['addressId'] = addressId;
        deliverySelection['deliveryZoneId'] = zoneId;
      } else if (selectedFulfilment == 'collection' &&
          _pickupByShop[group.shopId] != null) {
        deliverySelection['pickupPointId'] = _pickupByShop[group.shopId];
      }
      fulfilment.add({'shopId': group.shopId, 'method': selectedFulfilment});
      delivery.add(deliverySelection);
      payments.add({
        'merchantId': group.merchantId,
        'paymentMethodId': selectedPayment,
      });
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('تأكيد الطلبات المنفصلة'),
        content: Text(
          'سيُنشأ ${groups.length} طلب/طلبات منفصلة، مع تعليمات دفع مستقلة لكل متجر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _checkingOut = true);
    final commandKey = 'checkout-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await MarketplaceApiClient().checkoutCartIdempotent(
        fulfilmentByShop: fulfilment,
        paymentMethodByMerchant: payments,
        deliveryByShop: delivery,
        commandKey: commandKey,
      );
      if (mounted) setState(() => _cart = MarketplaceApiClient().cartGroups());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إنشاء طلبات منفصلة لكل متجر. راجع صفحة طلباتي لإتمام الدفع.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      await SecureCommandOutbox().enqueue(
        QueuedCommand(
          idempotencyKey: commandKey,
          kind: 'checkout_create_orders',
          payload: {
            'fulfilmentByShop': fulfilment,
            'paymentByMerchant': payments,
            'deliveryByShop': delivery,
          },
          createdAt: DateTime.now(),
          lastError: error.message,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر الاتصال. حُفظ الطلب في مركز المزامنة لإعادة المحاولة.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }
}

class _CheckoutDeliverySelection extends StatelessWidget {
  const _CheckoutDeliverySelection({
    required this.fulfilment,
    required this.addresses,
    required this.pickupPoints,
    required this.zones,
    required this.selectedAddressId,
    required this.selectedPickupPointId,
    required this.selectedZoneId,
    required this.onAddressChanged,
    required this.onPickupPointChanged,
    required this.onZoneChanged,
  });

  final String fulfilment;
  final Future<List<CustomerAddress>> addresses;
  final Future<List<PickupPoint>> pickupPoints;
  final Future<List<MerchantDeliveryZone>> zones;
  final String? selectedAddressId;
  final String? selectedPickupPointId;
  final String? selectedZoneId;
  final ValueChanged<String?> onAddressChanged;
  final ValueChanged<String?> onPickupPointChanged;
  final ValueChanged<String?> onZoneChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait<dynamic>([addresses, pickupPoints, zones]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator(minHeight: 2);
      }
      if (snapshot.hasError) {
        return const _InlineWarning(
          'تعذر تحميل خيارات العنوان والتوصيل حالياً.',
        );
      }
      final addressRows =
          snapshot.data?[0] as List<CustomerAddress>? ?? const [];
      final pickupRows = snapshot.data?[1] as List<PickupPoint>? ?? const [];
      final zoneRows =
          snapshot.data?[2] as List<MerchantDeliveryZone>? ?? const [];
      if (fulfilment == 'collection') {
        if (pickupRows.isEmpty) {
          return const _InlineWarning(
            'يمكن متابعة الاستلام من المتجر؛ لا توجد نقطة استلام محددة لهذا السوق.',
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedPickupPointId,
          decoration: const InputDecoration(
            labelText: 'نقطة الاستلام (اختيارية)',
          ),
          items: pickupRows
              .map(
                (point) => DropdownMenuItem(
                  value: point.id,
                  child: Text('${point.nameAr} · ${point.addressDetails}'),
                ),
              )
              .toList(),
          onChanged: onPickupPointChanged,
        );
      }

      final selectedAddress = addressRows
          .where((address) => address.id == selectedAddressId)
          .firstOrNull;
      final compatibleZones = selectedAddress?.serviceAreaId == null
          ? const <MerchantDeliveryZone>[]
          : zoneRows
                .where(
                  (zone) =>
                      zone.serviceAreaId == selectedAddress!.serviceAreaId,
                )
                .toList(growable: false);
      return Column(
        children: [
          if (addressRows.isEmpty)
            const _InlineWarning(
              'أضف عنواناً مرتبطاً بمنطقة خدمة قبل اختيار التوصيل.',
            )
          else
            DropdownButtonFormField<String>(
              initialValue: selectedAddressId,
              decoration: const InputDecoration(labelText: 'عنوان التوصيل'),
              items: addressRows
                  .map(
                    (address) => DropdownMenuItem(
                      value: address.id,
                      child: Text('${address.label} · ${address.addressLine}'),
                    ),
                  )
                  .toList(),
              onChanged: onAddressChanged,
            ),
          const SizedBox(height: 10),
          if (selectedAddressId != null && compatibleZones.isEmpty)
            const _InlineWarning(
              'لا توجد منطقة توصيل مفعلة لهذا العنوان والمتجر.',
            )
          else if (compatibleZones.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue:
                  compatibleZones.any((zone) => zone.id == selectedZoneId)
                  ? selectedZoneId
                  : null,
              decoration: const InputDecoration(labelText: 'منطقة التوصيل'),
              items: compatibleZones
                  .map(
                    (zone) => DropdownMenuItem(
                      value: zone.id,
                      child: Text('${zone.name} · ${zone.feeMinor} YER'),
                    ),
                  )
                  .toList(),
              onChanged: onZoneChanged,
            ),
        ],
      );
    },
  );
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF9A4E00), height: 1.45),
    ),
  );
}

class _OrdersPage extends StatefulWidget {
  const _OrdersPage({this.user});
  final SessionUser? user;
  @override
  State<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<_OrdersPage> {
  late final Future<List<MerchantOrderSummary>> _orders = MarketplaceApiClient()
      .myOrders();
  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const _CenteredPage(
        icon: Icons.lock_outline,
        title: 'سجّل الدخول لمتابعة طلباتك',
        detail: 'ستظهر كل مجموعة تاجر كطلب مستقل مع حالة الدفع والتنفيذ الخاصة بها.',
      );
    }
    return FutureBuilder<List<MerchantOrderSummary>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _CenteredPage(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل الطلبات',
            detail: 'تحقق من الاتصال ثم حاول مرة أخرى.',
          );
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const _CenteredPage(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد طلبات بعد',
            detail: 'عند إتمام الدفع، سيُنشأ طلب مستقل لكل متجر في السلة.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: orders
              .map(
                (order) => Card(
                  child: ListTile(
                    title: Text('طلب #${order.id}'),
                    subtitle: Text(
                      'الدفع: ${order.paymentStatus} · التنفيذ: ${order.fulfilmentStatus}',
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${order.totalMinor} ${order.currency}'),
                        if (order.paymentStatus == 'awaiting_payment')
                          TextButton(
                            onPressed: () => _showPayment(order),
                            child: const Text('تعليمات الدفع'),
                          ),
                        if (order.fulfilmentStatus != 'cancelled')
                          TextButton(
                            onPressed: () => _openCase(order),
                            child: const Text('طلب إلغاء أو مساعدة'),
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _openCase(MerchantOrderSummary order) async {
    final reason = TextEditingController();
    var caseType = 'dispute';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('طلب إلغاء أو مساعدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: caseType,
                decoration: const InputDecoration(labelText: 'نوع الطلب'),
                items: const [
                  DropdownMenuItem(
                    value: 'cancellation',
                    child: Text('طلب إلغاء'),
                  ),
                  DropdownMenuItem(value: 'return', child: Text('طلب إرجاع')),
                  DropdownMenuItem(
                    value: 'dispute',
                    child: Text('شكوى أو نزاع'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => caseType = value ?? 'dispute'),
              ),
              TextField(
                controller: reason,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'اشرح السبب بالتفصيل',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length < 5) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) {
      reason.dispose();
      return;
    }
    try {
      await MarketplaceApiClient().openOrderCase(
        merchantOrderId: order.id,
        caseType: caseType,
        reason: reason.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الطلب للمراجعة.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      reason.dispose();
    }
  }

  Future<void> _showPayment(MerchantOrderSummary order) async {
    final reference = TextEditingController();
    final provider = PaymentProviderCatalog.byCode(order.providerCode);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('الدفع عبر ${provider.nameAr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.accountHolderName != null)
              Text('اسم المستلم: ${order.accountHolderName}'),
            if (order.receivingIdentifier != null)
              Text('الحساب/المحفظة: ${order.receivingIdentifier}'),
            if (order.paymentInstructions != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(order.paymentInstructions!),
              ),
            if (provider.supportsQrOrPos)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'افتح تطبيق ${provider.nameAr} وادفع باستخدام رقم نقطة البيع أو رمز QR، ثم اكتب مرجع العملية هنا. لا يتم تأكيد الدفع تلقائياً.',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(provider.activationNoteAr),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: reference,
              decoration: const InputDecoration(labelText: 'مرجع التحويل'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final value = reference.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await MarketplaceApiClient().submitPaymentReference(
                  merchantOrderId: order.id,
                  reference: value,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أُرسل مرجع التحويل للمراجعة.'),
                    ),
                  );
                }
              } on ApiException catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
            child: const Text('إرسال للمراجعة'),
          ),
        ],
      ),
    );
    reference.dispose();
  }
}

class _MerchantPage extends StatefulWidget {
  const _MerchantPage({this.user});
  final SessionUser? user;

  @override
  State<_MerchantPage> createState() => _MerchantPageState();
}

class _MerchantPageState extends State<_MerchantPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _ownerName = TextEditingController();
  bool _submitting = false;
  bool _applicationSubmitted = false;
  late final Future<bool> _hasMerchant = MarketplaceApiClient()
      .hasMerchantContext();

  @override
  void dispose() {
    _phone.dispose();
    _ownerName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await MarketplaceApiClient().submitMerchantApplication(
        phone: _phone.text.trim(),
        ownerName: _ownerName.text.trim(),
      );
      if (mounted) setState(() => _applicationSubmitted = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب التاجر للمراجعة.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const _CenteredPage(
        icon: Icons.lock_outline,
        title: 'سجّل الدخول لبدء طلب التاجر',
        detail:
            'يُحفظ حساب التاجر وبيانات متجره بشكل منفصل وآمن بعد تسجيل الدخول.',
      );
    }
    if (_applicationSubmitted) return const _MerchantHub();
    return FutureBuilder<bool>(
      future: _hasMerchant,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _CenteredPage(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل حالة حساب التاجر',
            detail: 'تحقق من الاتصال ثم حاول فتح صفحة التاجر مجدداً.',
          );
        }
        if (snapshot.data == true) return const _MerchantHub();
        return _applicationForm(context);
      },
    );
  }

  Widget _applicationForm(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب الانضمام كتاجر',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيُراجع الطلب قبل ظهور المتجر أو منتجاته في السوق العام.',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _ownerName,
                    decoration: const InputDecoration(
                      labelText: 'اسم صاحب النشاط',
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 3
                        ? 'أدخل اسماً صحيحاً.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    validator: (value) =>
                        value == null || value.trim().length < 7
                        ? 'أدخل رقم هاتف صحيحاً.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيُحفظ الرقم كغير مُتحقق منه خلال المرحلة التجريبية. سيتاح التحقق برسالة عند اعتماد مزود رسائل محلي.',
                    style: TextStyle(color: Color(0xFF68655F), height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_submitting ? 'جارٍ الإرسال' : 'إرسال الطلب'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MerchantHub extends StatelessWidget {
  const _MerchantHub();

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'الهوية والمراجعة'),
            Tab(text: 'إدارة المتجر'),
          ],
        ),
        const Expanded(
          child: TabBarView(
            children: [_IdentityMerchantPanel(), _MerchantOperationsPanel()],
          ),
        ),
      ],
    ),
  );
}

class _IdentityMerchantPanel extends StatefulWidget {
  const _IdentityMerchantPanel();

  @override
  State<_IdentityMerchantPanel> createState() => _IdentityMerchantPanelState();
}

class _IdentityMerchantPanelState extends State<_IdentityMerchantPanel> {
  PlatformFile? _passport;
  PlatformFile? _selfie;
  bool _consent = false;
  bool _submitting = false;
  late Future<IdentityVerificationSummary> _summary = MarketplaceApiClient()
      .identityMine();

  Future<void> _pick(bool passport) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.bytes == null || file.size > 3 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اختر صورة JPEG أو PNG أو WebP أصغر من 3 ميغابايت.'),
          ),
        );
      }
      return;
    }
    setState(() {
      if (passport) {
        _passport = file;
      } else {
        _selfie = file;
      }
    });
  }

  String _mime(PlatformFile file) => file.name.toLowerCase().endsWith('.png')
      ? 'image/png'
      : file.name.toLowerCase().endsWith('.webp')
      ? 'image/webp'
      : 'image/jpeg';

  Future<void> _submit() async {
    if (!_consent || _passport?.bytes == null || _selfie?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أقرّ بالموافقة واختر صورة جواز وصورة سيلفي أولاً.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await MarketplaceApiClient().submitIdentityEvidence(
        passportBase64: base64Encode(_passport!.bytes!),
        passportName: _passport!.name,
        passportMimeType: _mime(_passport!),
        selfieBase64: base64Encode(_selfie!.bytes!),
        selfieName: _selfie!.name,
        selfieMimeType: _mime(_selfie!),
      );
      if (mounted) {
        setState(() => _summary = MarketplaceApiClient().identityMine());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال الوثائق للمراجعة اليدوية. لن يتم اتخاذ قرار تلقائي.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: FutureBuilder<IdentityVerificationSummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return const _CenteredPage(
                icon: Icons.cloud_off_outlined,
                title: 'تعذر تحميل حالة التحقق',
                detail: 'تحقق من الاتصال ثم حاول فتح صفحة التاجر مجدداً.',
              );
            }
            final status = snapshot.data?.status;
            final note = snapshot.data?.decisionNote;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التحقق من هوية التاجر',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ترسل صورة الجواز وصورة السيلفي لموظفي الإدارة المخوّلين للمراجعة اليدوية فقط. لا تُعرض علناً ولا تُستخدم لمطابقة الوجه أو لقرار آلي.',
                      style: TextStyle(height: 1.65),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        status == null
                            ? 'لم تُرسل وثائق تحقق بعد.'
                            : 'حالة المراجعة: $status${note == null ? '' : '\nملاحظة الإدارة: $note'}',
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : () => _pick(true),
                      icon: const Icon(Icons.badge_outlined),
                      label: Text(
                        _passport == null
                            ? 'اختر صورة جواز السفر'
                            : 'تم اختيار: ${_passport!.name}',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : () => _pick(false),
                      icon: const Icon(Icons.face_retouching_natural_outlined),
                      label: Text(
                        _selfie == null
                            ? 'اختر صورة سيلفي للوجه'
                            : 'تم اختيار: ${_selfie!.name}',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consent,
                      onChanged: _submitting
                          ? null
                          : (value) =>
                                setState(() => _consent = value ?? false),
                      title: const Text(
                        'أوافق على إرسال الوثيقتين للمراجعة اليدوية من الإدارة المخوّلة.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: Text(
                        _submitting ? 'جارٍ الإرسال' : 'إرسال للمراجعة اليدوية',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _MerchantInsightsCard extends StatelessWidget {
  const _MerchantInsightsCard({
    required this.shopId,
    required this.onAddPromotion,
  });

  final String shopId;
  final VoidCallback onAddPromotion;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<MerchantAnalytics>(
        future: MarketplaceApiClient().merchantAnalytics(shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Text('تعذر تحميل مؤشرات المتجر حالياً.');
          }
          final metrics = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _SectionHeader(
                      title: 'مؤشرات ونمو المتجر',
                      subtitle: 'أرقام مجمعة للعناية بالتشغيل، مع عروض قابلة للتوسع لاحقاً داخل الدفع.',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onAddPromotion,
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('إضافة عرض'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricChip(
                    label: 'الطلبات',
                    value: '${metrics.ordersCount}',
                  ),
                  _MetricChip(
                    label: 'المدفوعة',
                    value: '${metrics.paidOrdersCount}',
                  ),
                  _MetricChip(
                    label: 'المكتملة',
                    value: '${metrics.completedOrdersCount}',
                  ),
                  _MetricChip(
                    label: 'المنتجات النشطة',
                    value: '${metrics.activeProductsCount}',
                  ),
                  _MetricChip(
                    label: 'مخزون منخفض',
                    value: '${metrics.lowStockProductsCount}',
                  ),
                  _MetricChip(
                    label: 'حالات مفتوحة',
                    value: '${metrics.openCasesCount}',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(
      backgroundColor: const Color(0xFFE5F3EE),
      child: Text(value, style: const TextStyle(fontSize: 11)),
    ),
    label: Text(label),
  );
}

class _MerchantQualityCard extends StatelessWidget {
  const _MerchantQualityCard({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<MerchantQualitySummary>(
        future: MarketplaceApiClient().merchantQualitySummary(shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Text('تعذر تحميل مؤشرات الجودة حالياً.');
          }
          final quality = snapshot.data!;
          final rating = quality.averageRating == null
              ? 'لا توجد تقييمات منشورة'
              : '${quality.averageRating!.toStringAsFixed(1)} / 5';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeader(
                title: 'جودة المتجر والثقة',
                subtitle: 'مؤشرات تفسيرية تساعدك على تحسين الخدمة؛ لا يوجد حظر آلي أو تغيير للمدفوعات.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricChip(label: 'التقييم', value: rating),
                  _MetricChip(
                    label: 'المكتملة',
                    value: '${quality.completedOrdersCount}',
                  ),
                  _MetricChip(
                    label: 'الملغاة',
                    value: '${quality.cancelledOrdersCount}',
                  ),
                  _MetricChip(
                    label: 'النزاعات',
                    value: '${quality.disputedOrdersCount}',
                  ),
                  _MetricChip(
                    label: 'إشارات مفتوحة',
                    value: '${quality.openRiskSignalsCount}',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _MerchantB2BCard extends StatefulWidget {
  const _MerchantB2BCard({required this.shopId});

  final String shopId;

  @override
  State<_MerchantB2BCard> createState() => _MerchantB2BCardState();
}

class _MerchantB2BCardState extends State<_MerchantB2BCard> {
  late Future<List<Map<String, dynamic>>> requests = MarketplaceApiClient()
      .merchantWholesaleRequests(widget.shopId);

  void refresh() {
    setState(
      () => requests = MarketplaceApiClient().merchantWholesaleRequests(
        widget.shopId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  title: 'الجملة وطلبات B2B',
                  subtitle: 'راجع طلبات الشراء التجاري وأنشئ قائمة أسعار تفاوضية دون تحويل الائتمان إلى تمويل تلقائي.',
                ),
              ),
              IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
              OutlinedButton(
                onPressed: _createPriceList,
                child: const Text('قائمة أسعار'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: requests,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snapshot.hasError) {
                return const Text('تعذر تحميل طلبات الجملة.');
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text('لا توجد طلبات جملة مفتوحة.');
              }
              return Column(
                children: rows
                    .take(6)
                    .map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.business_outlined),
                        title: Text(
                          '${row['business_name']} · ${row['status']}',
                        ),
                        subtitle: Text(
                          '${row['contact_phone']} · ${row['note']}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (status) =>
                              _review(row['id'].toString(), status),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'reviewing',
                              child: Text('قيد المراجعة'),
                            ),
                            PopupMenuItem(
                              value: 'approved',
                              child: Text('اعتماد'),
                            ),
                            PopupMenuItem(
                              value: 'rejected',
                              child: Text('رفض'),
                            ),
                            PopupMenuItem(
                              value: 'closed',
                              child: Text('إغلاق'),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _review(String requestId, String status) async {
    try {
      await MarketplaceApiClient().reviewWholesaleRequestWithPriceList(
        requestId: requestId,
        status: status,
        reviewNote: 'قرار التاجر من مساحة B2B',
      );
      if (mounted) {
        refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث طلب الجملة.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createPriceList() async {
    final name = TextEditingController();
    final reason = TextEditingController();
    var currency = 'YER';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إنشاء قائمة أسعار جملة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'اسم القائمة بالعربية',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: const InputDecoration(labelText: 'العملة'),
                items: const [
                  DropdownMenuItem(value: 'YER', child: Text('YER')),
                ],
                onChanged: (value) =>
                    setDialogState(() => currency = value ?? 'YER'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'سبب التغيير'),
              ),
              const SizedBox(height: 8),
              const Text(
                'بعد إنشاء القائمة تُضاف أسعار المنتجات من الكتالوج المعتمد؛ لا يتم تطبيقها تلقائياً على الطلبات.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().length < 2 ||
                    reason.text.trim().length < 3) {
                  return;
                }
                try {
                  await MarketplaceApiClient().saveWholesalePriceList(
                    shopId: widget.shopId,
                    nameAr: name.text,
                    currency: currency,
                    status: 'draft',
                    reason: reason.text,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ قائمة الأسعار كمسودة.'),
                      ),
                    );
                  }
                } on ApiException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ مسودة'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    reason.dispose();
  }
}

class _CourierDispatchCard extends StatefulWidget {
  const _CourierDispatchCard();

  @override
  State<_CourierDispatchCard> createState() => _CourierDispatchCardState();
}

class _CourierDispatchCardState extends State<_CourierDispatchCard> {
  late Future<List<Map<String, dynamic>>> assignments = MarketplaceApiClient()
      .courierAssignments();
  bool busy = false;

  void refresh() {
    setState(() => assignments = MarketplaceApiClient().courierAssignments());
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  title: 'لوحة dispatch والتسليم',
                  subtitle: 'تابع الإسنادات وحدث حالات الاستلام والخروج والتسليم. لا يمكن للكابتن أو التاجر تغيير حالة الدفع.',
                ),
              ),
              IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: assignments,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snapshot.hasError) {
                return const Text('تعذر تحميل قائمة التوصيل.');
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text('لا توجد إسنادات توصيل نشطة.');
              }
              return Column(
                children: rows.take(8).map((row) {
                  final status = row['status'].toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text('طلب #${row['merchant_order_id']}'),
                    subtitle: Text(
                      'الكابتن: ${row['courier_user_id']} · الحالة: $status',
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled:
                          !busy &&
                          !{
                            'delivered',
                            'failed',
                            'cancelled',
                          }.contains(status),
                      onSelected: (next) =>
                          _handoff(row['id'].toString(), next),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'picked_up',
                          child: Text('تم الاستلام'),
                        ),
                        PopupMenuItem(
                          value: 'out_for_delivery',
                          child: Text('خرج للتوصيل'),
                        ),
                        PopupMenuItem(
                          value: 'delivered',
                          child: Text('تم التسليم'),
                        ),
                        PopupMenuItem(
                          value: 'failed',
                          child: Text('تعذر التسليم'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _handoff(String assignmentId, String status) async {
    setState(() => busy = true);
    try {
      await MarketplaceApiClient().recordCourierHandoff(
        assignmentId: assignmentId,
        status: status,
        deliveryNote: status == 'failed' ? 'تعذر التسليم - يحتاج متابعة' : null,
      );
      if (mounted) {
        refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة التوصيل.')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _MerchantPosCard extends StatefulWidget {
  const _MerchantPosCard({required this.shopId});

  final String shopId;

  @override
  State<_MerchantPosCard> createState() => _MerchantPosCardState();
}

class _MerchantPosCardState extends State<_MerchantPosCard> {
  String? sessionId;
  bool busy = false;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'نقطة البيع المحلية',
            subtitle: 'سجل مبيعات المتجر النقدية أو اليدوية داخل جلسة محلية. هذا لا ينشئ تحصيلاً إلكترونياً ولا يتجاوز الطلبات الأساسية.',
          ),
          const SizedBox(height: 12),
          Text(
            sessionId == null
                ? 'لا توجد جلسة مفتوحة.'
                : 'جلسة مفتوحة: $sessionId',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy || sessionId != null ? null : _openSession,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('فتح جلسة'),
              ),
              OutlinedButton.icon(
                onPressed: busy || sessionId == null ? null : _recordSale,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('تسجيل بيع'),
              ),
              OutlinedButton.icon(
                onPressed: busy || sessionId == null ? null : _closeSession,
                icon: const Icon(Icons.lock_clock_outlined),
                label: const Text('إغلاق ومطابقة'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _openSession() async {
    setState(() => busy = true);
    try {
      final id = await MarketplaceApiClient().openPosSession(
        shopId: widget.shopId,
        openingNote: 'جلسة تشغيل محلية',
      );
      if (mounted) setState(() => sessionId = id);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _recordSale() async {
    final productName = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final unitPrice = TextEditingController();
    var paymentMode = 'cash';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('تسجيل بيع محلي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productName,
                decoration: const InputDecoration(labelText: 'اسم الصنف'),
              ),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
              TextField(
                controller: unitPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'سعر الوحدة بالريال',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration: const InputDecoration(labelText: 'طريقة التسجيل'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem(
                    value: 'manual_reference',
                    child: Text('مرجع يدوي'),
                  ),
                  DropdownMenuItem(value: 'mock', child: Text('تجريبي')),
                ],
                onChanged: (value) =>
                    setDialogState(() => paymentMode = value ?? 'cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final count = int.tryParse(quantity.text.trim());
                final price = int.tryParse(unitPrice.text.trim());
                final amount = count != null && price != null
                    ? count * price
                    : null;
                if (productName.text.trim().length < 2 ||
                    count == null ||
                    count <= 0 ||
                    amount == null ||
                    amount <= 0 ||
                    sessionId == null) {
                  return;
                }
                try {
                  await MarketplaceApiClient().recordPosSale(
                    posSessionId: sessionId!,
                    totalMinor: amount,
                    paymentMode: paymentMode,
                    lineItems: [
                      {
                        'name': productName.text.trim(),
                        'quantity': count,
                        'unit_price_minor': price,
                        'total_minor': amount,
                      },
                    ],
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تسجيل البيع بانتظار المطابقة.'),
                      ),
                    );
                  }
                } on ApiException catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
    productName.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }

  Future<void> _closeSession() async {
    final counted = TextEditingController();
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إغلاق ومطابقة الجلسة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: counted,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ النقدي المعدود بالريال',
              ),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'ملاحظة الإغلاق'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = int.tryParse(counted.text.trim());
              if (amount == null || amount < 0 || sessionId == null) return;
              try {
                await MarketplaceApiClient().closePosSession(
                  posSessionId: sessionId!,
                  countedTotalMinor: amount,
                  closingNote: note.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (mounted) {
                  setState(() => sessionId = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إغلاق الجلسة وحفظ نتيجة المطابقة.'),
                    ),
                  );
                }
              } on ApiException catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
            child: const Text('إغلاق الجلسة'),
          ),
        ],
      ),
    );
    counted.dispose();
    note.dispose();
  }
}

class _MerchantProviderOperationsCard extends StatelessWidget {
  const _MerchantProviderOperationsCard({required this.shopId});

  final String shopId;

  static const modules = [
    (
      'الشحن والتتبع',
      '12 شحنة تجريبية · 8 تم التسليم',
      Icons.local_shipping_outlined,
      'Mock',
    ),
    (
      'رسائل العملاء',
      '24 قالباً · 91% تسليم تجريبي',
      Icons.chat_bubble_outline,
      'Mock',
    ),
    (
      'الولاء والإحالات',
      '47 عميلاً في البرنامج',
      Icons.card_giftcard_outlined,
      'تجريبي',
    ),
    (
      'قنوات البيع',
      'كتالوج اجتماعي جاهز للمعاينة',
      Icons.share_outlined,
      'Mock',
    ),
    (
      'تمويل التاجر',
      'غير متاح قبل شريك مرخص',
      Icons.account_balance_outlined,
      'محجوب',
    ),
  ];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'مركز الخدمات المتقدمة',
            subtitle: 'معاينات تشغيلية لمزودي الشحن والرسائل والولاء والقنوات والتمويل. هذه البيانات تجريبية ولا تنفذ أي إجراء خارج التطبيق.',
          ),
          const SizedBox(height: 12),
          ...modules.map(
            (module) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(module.$3, color: const Color(0xFF173B63)),
              title: Text(module.$1),
              subtitle: Text(module.$2),
              trailing: Chip(label: Text(module.$4)),
              onTap: () => _showModuleInfo(context, module.$1, module.$2),
            ),
          ),
          const Divider(height: 24),
          const Text(
            'دليل المزودين المتاح للتهيئة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          FutureBuilder<List<ProviderCatalogEntry>>(
            future: MarketplaceApiClient().providerCatalog(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('تعذر تحميل دليل المزودين حالياً.'),
                );
              }
              return Column(
                children: (snapshot.data ?? const <ProviderCatalogEntry>[])
                    .map(
                      (provider) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(provider.displayNameAr),
                        subtitle: Text(
                          '${provider.category} · ${provider.readinessState}${provider.supportsWebhooks ? ' · Webhook' : ''}',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () =>
                              _savePreviewIntegration(context, provider),
                          child: const Text('تهيئة آمنة'),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _savePreviewIntegration(
    BuildContext context,
    ProviderCatalogEntry provider,
  ) async {
    final status = provider.readinessState == 'blocked'
        ? 'blocked'
        : provider.readinessState;
    try {
      await MarketplaceApiClient().saveMerchantIntegration(
        shopId: shopId,
        providerCode: provider.providerCode,
        status: status,
        configuration: {
          'mode': 'preview',
          'external_calls_enabled': false,
          'provider_readiness': provider.readinessState,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حفظ ${provider.displayNameAr} بوضع المعاينة فقط.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static Future<void> _showModuleInfo(
    BuildContext context,
    String title,
    String detail,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        '$detail\\n\\nهذه معاينة Mock فقط. لن يتم إرسال رسالة أو إنشاء شحنة أو احتساب تمويل أو نشر كتالوج خارجي حتى تتم إضافة مزود معتمد وإكمال إعدادات الأمان والامتثال.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}

class _MerchantOperationsPanel extends StatefulWidget {
  const _MerchantOperationsPanel();

  @override
  State<_MerchantOperationsPanel> createState() =>
      _MerchantOperationsPanelState();
}

class _MerchantOperationsPanelState extends State<_MerchantOperationsPanel> {
  late Future<MerchantWorkspace> _workspace = MarketplaceApiClient()
      .merchantWorkspace();
  late Future<List<MerchantProductSummary>> _products = MarketplaceApiClient()
      .merchantProducts();
  final Set<String> _updatingOrders = <String>{};

  void _reload() {
    setState(() {
      _workspace = MarketplaceApiClient().merchantWorkspace();
      _products = MarketplaceApiClient().merchantProducts();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MerchantWorkspace>(
    future: _workspace,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return const _CenteredPage(
          icon: Icons.cloud_off_outlined,
          title: 'تعذر تحميل مساحة المتجر',
          detail: 'تحقق من الاتصال ثم حاول فتح صفحة التاجر مجدداً.',
        );
      }
      final workspace = snapshot.data ?? const MerchantWorkspace();
      if (!workspace.exists) {
        return const _CenteredPage(
          icon: Icons.store_mall_directory_outlined,
          title: 'يُجهز حساب التاجر',
          detail: 'أرسل طلب الانضمام أولاً، ثم أكمل خطوات التحقق والإعداد من هذه المساحة.',
        );
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'إدارة المتجر',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'حالة حساب التاجر: ${workspace.verificationStatus ?? 'قيد المراجعة'} · لا يصبح المتجر عاماً إلا بعد اعتماد الإدارة.',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OperationsCard(
                  title: 'المتاجر',
                  detail: workspace.shops.isEmpty
                      ? 'لم تُنشئ متجراً بعد.'
                      : '${workspace.shops.length} متجر/متاجر محفوظة',
                  icon: Icons.storefront_outlined,
                  action: 'إضافة متجر',
                  onAction: _createShop,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OperationsCard(
                  title: 'طرق الدفع اليدوية',
                  detail: workspace.paymentMethods.isEmpty
                      ? 'لم تُضف حساب استقبال بعد.'
                      : '${workspace.paymentMethods.length} طريقة دفع مفعلة',
                  icon: Icons.account_balance_wallet_outlined,
                  action: 'إضافة طريقة دفع',
                  onAction: _createPaymentMethod,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<MerchantProductSummary>>(
            future: _products,
            builder: (context, productSnapshot) {
              final products =
                  productSnapshot.data ?? const <MerchantProductSummary>[];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionHeader(
                              title: 'الكتالوج',
                              subtitle: 'أضف منتجاتك الآن، ثم وسّعها لاحقاً بالصور والمتغيرات والمخزون متعدد المواقع.',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: workspace.shops.isEmpty
                                ? null
                                : () => _createProduct(workspace.shops),
                            icon: const Icon(Icons.add_box_outlined),
                            label: const Text('إضافة منتج'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (productSnapshot.connectionState ==
                          ConnectionState.waiting)
                        const LinearProgressIndicator(minHeight: 2)
                      else if (productSnapshot.hasError)
                        const Text('تعذر تحميل منتجاتك حالياً.')
                      else if (products.isEmpty)
                        const Text(
                          'لا توجد منتجات بعد. أضف أول منتج بعد اعتماد المتجر.',
                        )
                      else
                        ...products
                            .take(8)
                            .map(
                              (product) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: Text(product.name),
                                subtitle: Text(
                                  '${product.shopName} · ${product.priceMinor} ${product.currency} · المخزون: ${product.stockQuantity}',
                                ),
                                trailing: Text(product.status),
                              ),
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (workspace.shops.isNotEmpty) ...[
            const SizedBox(height: 20),
            _MerchantInsightsCard(
              shopId: workspace.shops.first.id,
              onAddPromotion: () => _createPromotion(workspace.shops.first.id),
            ),
            const SizedBox(height: 20),
            _MerchantQualityCard(shopId: workspace.shops.first.id),
            const SizedBox(height: 20),
            _MerchantProviderOperationsCard(shopId: workspace.shops.first.id),
            const SizedBox(height: 20),
            _CourierDispatchCard(),
            const SizedBox(height: 20),
            _MerchantB2BCard(shopId: workspace.shops.first.id),
            const SizedBox(height: 20),
            _MerchantPosCard(shopId: workspace.shops.first.id),
          ],
          const SizedBox(height: 20),
          Text(
            'متاجرك',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (workspace.shops.isEmpty)
            const _CatalogNotice(
              icon: Icons.storefront_outlined,
              title: 'لا توجد متاجر بعد',
              detail: 'أنشئ متجراً وأرسله للمراجعة قبل إضافة الكتالوج والظهور للعملاء.',
            )
          else
            ...workspace.shops.map(
              (shop) => Card(
                child: ListTile(
                  title: Text(shop.name),
                  subtitle: Text(
                    'الحالة: ${shop.status}${shop.areaLabel == null ? '' : ' · ${shop.areaLabel}'}',
                  ),
                  trailing: TextButton(
                    onPressed: () => _configureFulfilment(shop),
                    child: const Text('إعداد التنفيذ'),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'طرق الدفع',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (workspace.paymentMethods.isEmpty)
            const _CatalogNotice(
              icon: Icons.account_balance_wallet_outlined,
              title: 'لا توجد طريقة دفع',
              detail: 'أضف حساب الاستقبال وتعليمات واضحة. تظل المدفوعات في المرحلة التجريبية يدوية ويمتلك التاجر حسابه.',
            )
          else
            ...workspace.paymentMethods.map(
              (method) => Card(
                child: ListTile(
                  title: Text(
                    '${method.name} · ${PaymentProviderCatalog.byCode(method.providerCode).nameAr}',
                  ),
                  subtitle: Text(
                    '${method.accountHolderName} · إثبات: ${method.proofRequirement} · ${PaymentProviderCatalog.byCode(method.providerCode).activationNoteAr}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      Icon(
                        method.isActive
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        color: method.isActive ? const Color(0xFF006A63) : null,
                      ),
                      IconButton(
                        onPressed: () => _editPaymentMethod(method),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'تعديل طريقة الدفع',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'طلبات المتجر',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (workspace.orders.isEmpty)
            const _CatalogNotice(
              icon: Icons.receipt_long_outlined,
              title: 'لا توجد طلبات للتاجر بعد',
              detail: 'تظهر هنا فقط الطلبات الخاصة بمتجرك بعد قيام العملاء بإتمام طلباتهم المنفصلة.',
            )
          else
            ...workspace.orders.map(
              (order) => Card(
                child: ListTile(
                  title: Text('طلب #${order.id} · ${order.totalMinor} YER'),
                  subtitle: Text(
                    'الدفع: ${order.paymentStatus} · التنفيذ: ${order.fulfilmentStatus}',
                  ),
                  trailing:
                      (order.paymentStatus == 'paid' ||
                          (order.codExpectedMinor > 0 &&
                              order.codStatus != 'collected'))
                      ? _orderActions(order)
                      : null,
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _createPromotion(String shopId) async {
    final code = TextEditingController();
    final value = TextEditingController();
    var kind = 'percent';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة عرض'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'رمز العرض'),
              ),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'نوع العرض'),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
                  DropdownMenuItem(value: 'fixed', child: Text('قيمة ثابتة')),
                ],
                onChanged: (value) =>
                    setDialogState(() => kind = value ?? 'percent'),
              ),
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'القيمة (نسبة أو ريال)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final parsed = int.tryParse(value.text.trim());
                if (code.text.trim().length < 3 ||
                    parsed == null ||
                    parsed <= 0) {
                  return;
                }
                try {
                  await MarketplaceApiClient().saveMerchantPromotion(
                    shopId: shopId,
                    code: code.text.trim(),
                    kind: kind,
                    valueMinor: parsed,
                    status: 'draft',
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ العرض كمسودة.')),
                  );
                } on ApiException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ كمسودة'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    value.dispose();
  }

  Future<void> _createProduct(List<MerchantShopSummary> shops) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController(text: '0');
    var shopId = shops.first.id;
    var status = 'draft';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة منتج'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: shopId,
                  decoration: const InputDecoration(labelText: 'المتجر'),
                  items: shops
                      .map(
                        (shop) => DropdownMenuItem(
                          value: shop.id,
                          child: Text(shop.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => shopId = value ?? shops.first.id),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                ),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر بالريال اليمني',
                  ),
                ),
                TextField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية المتاحة',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'حالة المنتج'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? 'draft'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final parsedPrice = int.tryParse(price.text.trim());
                final parsedStock = int.tryParse(stock.text.trim());
                if (name.text.trim().length < 2 ||
                    parsedPrice == null ||
                    parsedPrice <= 0 ||
                    parsedStock == null ||
                    parsedStock < 0) {
                  return;
                }
                try {
                  await MarketplaceApiClient().saveProduct(
                    shopId: shopId,
                    name: name.text.trim(),
                    description: description.text.trim(),
                    priceMinor: parsedPrice,
                    stockQuantity: parsedStock,
                    status: status,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  _reload();
                } on ApiException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ المنتج'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
  }

  Future<void> _createShop() async {
    final name = TextEditingController();
    final slug = TextEditingController();
    final area = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('إضافة متجر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم المتجر'),
            ),
            TextField(
              controller: slug,
              decoration: const InputDecoration(
                labelText: 'رابط مختصر بالإنجليزية',
              ),
            ),
            TextField(
              controller: area,
              decoration: const InputDecoration(labelText: 'المنطقة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().length < 3 ||
                  !RegExp(r'^[a-z0-9-]{3,180}$').hasMatch(slug.text.trim()) ||
                  area.text.trim().isEmpty) {
                return;
              }
              try {
                await MarketplaceApiClient().createShop(
                  name: name.text.trim(),
                  slug: slug.text.trim(),
                  areaLabel: area.text.trim(),
                );
                if (dialog.mounted) Navigator.pop(dialog);
                _reload();
              } on ApiException catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
            child: const Text('إرسال للمراجعة'),
          ),
        ],
      ),
    );
    name.dispose();
    slug.dispose();
    area.dispose();
  }

  Future<void> _createPaymentMethod() async {
    final name = TextEditingController();
    final holder = TextEditingController();
    final identifier = TextEditingController();
    final instructions = TextEditingController();
    var proofRequirement = 'reference';
    var providerCode = 'manual';
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة طريقة دفع يدوية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطريقة، مثال: محفظة أو نقد',
                  ),
                ),
                TextField(
                  controller: holder,
                  decoration: const InputDecoration(
                    labelText: 'اسم صاحب الحساب',
                  ),
                ),
                TextField(
                  controller: identifier,
                  decoration: const InputDecoration(
                    labelText: 'رقم الحساب أو المحفظة أو رقم نقطة البيع',
                  ),
                ),
                TextField(
                  controller: instructions,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'تعليمات للعميل',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: providerCode,
                  decoration: const InputDecoration(
                    labelText: 'مزود الدفع أو قناته',
                  ),
                  items: PaymentProviderCatalog.values
                      .map(
                        (provider) => DropdownMenuItem(
                          value: provider.code,
                          child: Text(provider.nameAr),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => providerCode = value ?? 'manual'),
                ),
                const SizedBox(height: 8),
                Text(
                  PaymentProviderCatalog.byCode(providerCode).activationNoteAr,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: proofRequirement,
                  decoration: const InputDecoration(
                    labelText: 'ما يقدمه العميل للمراجعة',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('لا شيء إضافي'),
                    ),
                    DropdownMenuItem(
                      value: 'reference',
                      child: Text('مرجع التحويل'),
                    ),
                    DropdownMenuItem(
                      value: 'screenshot',
                      child: Text('صورة إثبات'),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('المرجع وصورة الإثبات'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => proofRequirement = value ?? 'reference',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().length < 2 ||
                    holder.text.trim().length < 2 ||
                    identifier.text.trim().length < 3 ||
                    instructions.text.trim().length < 10) {
                  return;
                }
                final provider = PaymentProviderCatalog.byCode(providerCode);
                try {
                  await MarketplaceApiClient().saveMerchantPaymentMethod(
                    name: name.text.trim(),
                    accountHolderName: holder.text.trim(),
                    receivingIdentifier: identifier.text.trim(),
                    instructions: instructions.text.trim(),
                    proofRequirement: proofRequirement,
                    providerCode: provider.code,
                    providerMetadata: {
                      'payment_channel': provider.supportsQrOrPos
                          ? 'qr_or_pos'
                          : 'manual',
                      'integration_mode': provider.integrationMode,
                      'verification_state': provider.verificationState,
                    },
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _reload();
                } on ApiException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    holder.dispose();
    identifier.dispose();
    instructions.dispose();
  }

  Future<void> _editPaymentMethod(MerchantPaymentMethodSummary method) async {
    final holder = TextEditingController(text: method.accountHolderName);
    final identifier = TextEditingController(text: method.receivingIdentifier);
    final instructions = TextEditingController(text: method.instructions);
    var proofRequirement = method.proofRequirement;
    var providerCode = method.providerCode;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('تعديل ${method.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: providerCode,
                  decoration: const InputDecoration(
                    labelText: 'مزود الدفع أو قناته',
                  ),
                  items: PaymentProviderCatalog.values
                      .map(
                        (provider) => DropdownMenuItem(
                          value: provider.code,
                          child: Text(provider.nameAr),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(
                    () => providerCode = value ?? method.providerCode,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  PaymentProviderCatalog.byCode(providerCode).activationNoteAr,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                TextField(
                  controller: holder,
                  decoration: const InputDecoration(
                    labelText: 'اسم صاحب الحساب',
                  ),
                ),
                TextField(
                  controller: identifier,
                  decoration: const InputDecoration(
                    labelText: 'رقم الحساب أو المحفظة',
                  ),
                ),
                TextField(
                  controller: instructions,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'تعليمات للعميل',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: proofRequirement,
                  decoration: const InputDecoration(
                    labelText: 'ما يقدمه العميل للمراجعة',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('لا شيء إضافي'),
                    ),
                    DropdownMenuItem(
                      value: 'reference',
                      child: Text('مرجع التحويل'),
                    ),
                    DropdownMenuItem(
                      value: 'screenshot',
                      child: Text('صورة إثبات'),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      child: Text('المرجع وصورة الإثبات'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => proofRequirement = value ?? method.proofRequirement,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (holder.text.trim().length < 2 ||
                    identifier.text.trim().length < 3 ||
                    instructions.text.trim().length < 10) {
                  return;
                }
                try {
                  await MarketplaceApiClient().saveMerchantPaymentMethod(
                    id: method.id,
                    name: method.name,
                    accountHolderName: holder.text.trim(),
                    receivingIdentifier: identifier.text.trim(),
                    instructions: instructions.text.trim(),
                    proofRequirement: proofRequirement,
                    providerCode: providerCode,
                    providerMetadata: {
                      'payment_channel':
                          PaymentProviderCatalog.byCode(providerCode)
                              .supportsQrOrPos
                          ? 'qr_or_pos'
                          : 'manual',
                      'integration_mode': PaymentProviderCatalog.byCode(
                        providerCode,
                      ).integrationMode,
                      'verification_state': PaymentProviderCatalog.byCode(
                        providerCode,
                      ).verificationState,
                    },
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _reload();
                } on ApiException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
    holder.dispose();
    identifier.dispose();
    instructions.dispose();
  }

  Future<void> _configureFulfilment(MerchantShopSummary shop) async {
    final instructions = TextEditingController();
    var method = 'collection';
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('إعداد التنفيذ — ${shop.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'نوع التنفيذ'),
                items: const [
                  DropdownMenuItem(
                    value: 'collection',
                    child: Text('استلام من المتجر'),
                  ),
                  DropdownMenuItem(value: 'digital', child: Text('تسليم رقمي')),
                  DropdownMenuItem(
                    value: 'seller_arranged',
                    child: Text('تسليم يرتبه التاجر'),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => method = value ?? 'collection'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructions,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'تعليمات العميل'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await MarketplaceApiClient().setMerchantFulfilment(
                    shopId: shop.id,
                    method: method,
                    instructions: instructions.text.trim(),
                    isActive: true,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ إعداد التنفيذ.')),
                    );
                  }
                } on ApiException catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    instructions.dispose();
  }

  Widget _orderActions(MerchantManagedOrder order) {
    if (_updatingOrders.contains(order.id)) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final transitions = <String, String>{
      'pending': 'جاهز للاستلام',
      'ready': 'تسليم مرتّب',
      'arranged': 'تم التنفيذ',
      'completed': 'إلغاء الطلب',
    };
    if (order.fulfilmentStatus == 'cancelled') return const SizedBox.shrink();
    final controls = <Widget>[];
    if (order.codExpectedMinor > 0 && order.codStatus != 'collected') {
      controls.add(
        TextButton.icon(
          onPressed: () => _recordCodCollection(order),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('تحصيل نقدي'),
        ),
      );
    }
    if (order.paymentStatus == 'paid') {
      controls.add(
        PopupMenuButton<String>(
          onSelected: (status) => _updateOrderFulfilment(order, status),
          itemBuilder: (context) => [
            if (transitions.containsKey(order.fulfilmentStatus))
              PopupMenuItem(
                value: order.fulfilmentStatus == 'pending'
                    ? 'ready'
                    : order.fulfilmentStatus == 'ready'
                    ? 'arranged'
                    : order.fulfilmentStatus == 'arranged'
                    ? 'completed'
                    : 'cancelled',
                child: Text(transitions[order.fulfilmentStatus]!),
              ),
            if (order.fulfilmentStatus != 'completed')
              const PopupMenuItem(
                value: 'cancelled',
                child: Text('إلغاء الطلب'),
              ),
          ],
          child: const Icon(Icons.more_vert),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: controls);
  }

  Future<void> _recordCodCollection(MerchantManagedOrder order) async {
    final amount = TextEditingController(text: '${order.codExpectedMinor}');
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل التحصيل النقدي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'المتوقع: ${order.codExpectedMinor} YER. الدفع لن يصبح مدفوعاً إلا عند تطابق المبلغ.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المحصل'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'ملاحظة المطابقة أو الفرق',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final collected = int.tryParse(amount.text.trim());
              if (collected == null || collected < 0) return;
              try {
                await MarketplaceApiClient().recordCodCollection(
                  merchantOrderId: order.id,
                  collectedMinor: collected,
                  note: note.text.trim(),
                );
                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _reload();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تسجيل التحصيل وإضافة سجل المطابقة.'),
                  ),
                );
              } on ApiException catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error.message)));
                }
              }
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
    amount.dispose();
    note.dispose();
  }

  Future<void> _updateOrderFulfilment(
    MerchantManagedOrder order,
    String status,
  ) async {
    setState(() => _updatingOrders.add(order.id));
    try {
      await MarketplaceApiClient().updateMerchantFulfilment(
        merchantOrderId: order.id,
        fulfilmentStatus: status,
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة تنفيذ الطلب.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _updatingOrders.remove(order.id));
    }
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String detail;
  final IconData icon;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF006A63)),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(color: Color(0xFF68655F), height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}

class _SyncCenterPage extends StatefulWidget {
  const _SyncCenterPage();

  @override
  State<_SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends State<_SyncCenterPage> {
  final worker = OutboxReplayWorker(outbox: SecureCommandOutbox());
  late Future<List<OutboxDiagnostic>> diagnostics = worker.diagnostics();
  OutboxReplaySummary? lastSummary;
  bool busy = false;

  void refresh() {
    setState(() => diagnostics = worker.diagnostics());
  }

  Future<void> replay() async {
    setState(() => busy = true);
    try {
      final summary = await worker.replay();
      if (mounted) {
        setState(() => lastSummary = summary);
        refresh();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Row(
        children: [
          const Expanded(
            child: _SectionHeader(
              title: 'مركز المزامنة الآمنة',
              subtitle: 'أوامر غير مالية محفوظة محلياً بشكل مشفر. راقب المحاولات وأعد المحاولة عند توفر الاتصال.',
            ),
          ),
          FilledButton.icon(
            onPressed: busy ? null : replay,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('مزامنة الآن'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (lastSummary != null)
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(
              'آخر مزامنة: ${lastSummary!.completed} اكتمل · ${lastSummary!.failed} فشل · ${lastSummary!.skipped} محجوب',
            ),
            subtitle: Text(
              'قبل: ${lastSummary!.pendingBefore} · بعد: ${lastSummary!.pendingAfter}',
            ),
          ),
        ),
      const SizedBox(height: 8),
      FutureBuilder<List<OutboxDiagnostic>>(
        future: diagnostics,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          if (snapshot.hasError) {
            return const _InlineWarning('تعذر قراءة قائمة المزامنة المشفرة.');
          }
          final rows = snapshot.data ?? const <OutboxDiagnostic>[];
          if (rows.isEmpty) {
            return const _CatalogNotice(
              icon: Icons.cloud_done_outlined,
              title: 'لا توجد أوامر معلقة',
              detail: 'ستظهر هنا أوامر checkout والعروض غير المالية إذا انقطع الاتصال أثناء الحفظ.',
            );
          }
          return Column(
            children: rows
                .map(
                  (item) => Card(
                    child: ListTile(
                      leading: Icon(
                        item.state == 'blocked'
                            ? Icons.block
                            : item.state == 'failed'
                            ? Icons.warning_amber_outlined
                            : Icons.schedule,
                      ),
                      title: Text(_kindLabel(item.command.kind)),
                      subtitle: Text(
                        'الحالة: ${_stateLabel(item.state)} · محاولات: ${item.command.attempts}\nالمعرف: ${item.command.idempotencyKey}${item.command.lastError == null ? '' : '\nآخر خطأ: ${item.command.lastError}'}',
                      ),
                      isThreeLine: item.command.lastError != null,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: () async {
                              await worker.retry(item.command.idempotencyKey);
                              refresh();
                            },
                            icon: const Icon(Icons.replay),
                            tooltip: 'إعادة المحاولة',
                          ),
                          IconButton(
                            onPressed: () async {
                              await worker.discard(item.command.idempotencyKey);
                              refresh();
                            },
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'حذف الأمر',
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );

  static String _kindLabel(String kind) => switch (kind) {
    'checkout_create_orders' => 'إنشاء طلبات منفصلة',
    'apply_order_promotion' => 'تطبيق عرض',
    _ => kind,
  };

  static String _stateLabel(String state) => switch (state) {
    'pending' => 'قيد الانتظار',
    'failed' => 'يحتاج إعادة محاولة',
    'blocked' => 'محجوب بعد محاولات متعددة',
    _ => state,
  };
}

class _ServicesPage extends StatelessWidget {
  const _ServicesPage();

  static const services = [
    (
      title: 'توصيل وتتبع الطلب',
      detail: 'اختر التوصيل أو الاستلام من نقطة قريبة، مع حالات تجريبية من الاستلام حتى التسليم.',
      icon: Icons.local_shipping_outlined,
      status: 'جاهز للمعاينة',
    ),
    (
      title: 'تنبيهات واتساب و SMS',
      detail: 'معاينة رسائل تأكيد الطلب والتحديثات. لن تُرسل أي رسالة بدون تفعيل مزود معتمد وموافقة العميل.',
      icon: Icons.notifications_active_outlined,
      status: 'Mock فقط',
    ),
    (
      title: 'نقاط الولاء والإحالات',
      detail: 'عرض تجريبي للنقاط، مكافأة الإحالة، والقسائم. لا توجد قيمة مالية مخزنة أو مستحقة في النسخة التجريبية.',
      icon: Icons.card_giftcard_outlined,
      status: 'تجريبي',
    ),
    (
      title: 'قنوات اجتماعية',
      detail: 'معاينة مشاركة المنتج والكتالوج الخارجي. النشر والمزامنة يتطلبان حساباً وموافقة من القناة.',
      icon: Icons.share_outlined,
      status: 'قيد الإعداد',
    ),
    (
      title: 'خيارات تمويل',
      detail: 'معلومات توعوية فقط. لا يوجد عرض ائتماني أو قرار تمويل أو طلب بيانات مالية هنا.',
      icon: Icons.account_balance_outlined,
      status: 'محجوب',
    ),
  ];

  Future<void> _openSupportDialog(BuildContext context) async {
    final subject = TextEditingController();
    final description = TextEditingController();
    var category = 'order';
    var priority = 'normal';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('فتح تذكرة دعم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: const [
                    DropdownMenuItem(value: 'order', child: Text('طلب')),
                    DropdownMenuItem(value: 'payment', child: Text('دفع')),
                    DropdownMenuItem(value: 'delivery', child: Text('توصيل')),
                    DropdownMenuItem(value: 'account', child: Text('حساب')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => category = value ?? 'order'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'الأولوية'),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('عادية')),
                    DropdownMenuItem(value: 'high', child: Text('مرتفعة')),
                    DropdownMenuItem(value: 'urgent', child: Text('عاجلة')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => priority = value ?? 'normal'),
                ),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'وصف المشكلة'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (subject.text.trim().length < 3 ||
                    description.text.trim().length < 8) {
                  return;
                }
                try {
                  await MarketplaceApiClient().openSupportTicket(
                    category: category,
                    subject: subject.text.trim(),
                    description: description.text.trim(),
                    priority: priority,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم فتح تذكرة الدعم.')),
                    );
                  }
                } on ApiException catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
    children: [
      Text(
        'الخدمات المتقدمة',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        'ميزات إضافية نجهزها للسوق اليمني. بعضها يعتمد على مزودي خدمات خارجيين، لذلك تعرض هذه الصفحة بيانات توضيحية فقط.',
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _openSupportDialog(context),
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('فتح تذكرة دعم'),
      ),
      const SizedBox(height: 12),
      Card(
        color: const Color(0xFFEAF4F2),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'حماية المستخدم أولاً: لا دفع تلقائي، لا نقل أموال، ولا مشاركة بيانات مع مزود خارجي في وضع المعاينة.',
          ),
        ),
      ),
      const SizedBox(height: 18),
      ...services.map(
        (service) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE5F3EE),
              child: Icon(service.icon, color: const Color(0xFF006A63)),
            ),
            title: Text(
              service.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(service.detail),
            ),
            trailing: Chip(label: Text(service.status)),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(service.title),
                content: Text(
                  '${service.detail}\\n\\nهذه شاشة Mock؛ لن يتم تنفيذ أي اتصال خارجي أو عملية مالية حتى تفعيل مزود موثق.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _AdminPage extends StatefulWidget {
  const _AdminPage({this.user});
  final SessionUser? user;
  @override
  State<_AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<_AdminPage> {
  late Future<List<AdminIdentityCase>> _queue = MarketplaceApiClient()
      .adminIdentityQueue();
  @override
  Widget build(BuildContext context) {
    if (widget.user?.role != 'admin') {
      return const _CenteredPage(
        icon: Icons.lock_outline,
        title: 'صلاحية الإدارة مطلوبة',
        detail: 'تقتصر مراجعة وثائق الهوية على موظفي الإدارة المخوّلين.',
      );
    }
    return FutureBuilder<List<AdminIdentityCase>>(
      future: _queue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _CenteredPage(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل المراجعات',
            detail: 'تحقق من الصلاحية والاتصال ثم حاول مجدداً.',
          );
        }
        final queue = snapshot.data ?? [];
        if (queue.isEmpty) {
          return const _CenteredPage(
            icon: Icons.fact_check_outlined,
            title: 'لا توجد وثائق بانتظار المراجعة',
            detail: 'لا يظهر هنا سوى طلبات التحقق التي أرسلها التجار للمراجعة اليدوية.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'مراجعة هوية التجار',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'لا توجد مطابقة وجه آلية. القرار هنا لا يعتمد المتجر أو ينشره تلقائياً.',
            ),
            const SizedBox(height: 14),
            ...queue.map(
              (item) => Card(
                child: ListTile(
                  title: Text('طلب تاجر #${item.merchantId}'),
                  subtitle: Text('الحالة: ${item.status}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _openEvidence(item),
                        child: const Text('عرض الوثائق'),
                      ),
                      FilledButton(
                        onPressed: () => _review(item),
                        child: const Text('اتخاذ قرار'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _review(AdminIdentityCase item) async {
    final note = TextEditingController();
    var submitting = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> decide(bool approve) async {
            if (note.text.trim().length < 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'اكتب ملاحظة من ثلاثة أحرف على الأقل قبل اتخاذ القرار.',
                  ),
                ),
              );
              return;
            }
            setDialogState(() => submitting = true);
            try {
              await MarketplaceApiClient().reviewIdentityCase(
                identityCaseId: item.id,
                approve: approve,
                note: note.text.trim(),
              );
              if (mounted) {
                setState(
                  () => _queue = MarketplaceApiClient().adminIdentityQueue(),
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } on ApiException catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.message)));
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => submitting = false);
              }
            }
          }

          return AlertDialog(
            title: const Text('قرار مراجعة يدوي'),
            content: TextField(
              controller: note,
              enabled: !submitting,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'ملاحظة القرار المطلوبة',
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.tonal(
                onPressed: submitting ? null : () => decide(false),
                child: Text(submitting ? 'جارٍ الحفظ' : 'رفض'),
              ),
              FilledButton(
                onPressed: submitting ? null : () => decide(true),
                child: Text(submitting ? 'جارٍ الحفظ' : 'اعتماد'),
              ),
            ],
          );
        },
      ),
    );
    note.dispose();
  }

  Future<void> _openEvidence(AdminIdentityCase item) async {
    try {
      final evidence = await MarketplaceApiClient().adminIdentityEvidence(
        item.id,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('وثائق المراجعة المصرح بها'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: evidence
                .map(
                  (document) => ListTile(
                    title: Text(
                      document.kind == 'passport'
                          ? 'صورة جواز السفر'
                          : 'صورة السيلفي',
                    ),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () async {
                      await launchUrl(
                        Uri.parse(document.signedUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _CenteredPage extends StatelessWidget {
  const _CenteredPage({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFE2F2EC),
                foregroundColor: const Color(0xFF006A63),
                child: Icon(icon, size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                style: const TextStyle(color: Color(0xFF68655F), height: 1.7),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Destination {
  const _Destination(this.label, this.outlined, this.filled);
  final String label;
  final IconData outlined;
  final IconData filled;
}
