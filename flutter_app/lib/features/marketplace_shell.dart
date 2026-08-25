import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/contracts.dart';
import '../core/api_client.dart';

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key, this.market, this.marketLoading = false, this.user});

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
    _Destination('للتجار', Icons.store_mall_directory_outlined, Icons.store_mall_directory),
    _Destination('الإدارة', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings),
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
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: _destinations
                  .map((destination) => NavigationDestination(icon: Icon(destination.outlined), selectedIcon: Icon(destination.filled), label: destination.label))
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
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                leading: const Padding(padding: EdgeInsets.only(top: 28, bottom: 26), child: _BrandMark()),
                destinations: _destinations
                    .map((destination) => NavigationRailDestination(icon: Icon(destination.outlined), selectedIcon: Icon(destination.filled), label: Text(destination.label)))
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(children: [_topBar(), Expanded(child: page)]),
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
          child: Row(children: [if (compact) const _BrandMark(compact: true), if (compact) const SizedBox(width: 10), const Text('يمن كومرس')]),
        ),
        actions: [
          if (widget.user == null)
            TextButton.icon(onPressed: _startLogin, icon: const Icon(Icons.login_rounded), label: const Text('تسجيل الدخول'))
          else
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('مرحباً ${widget.user!.name ?? 'بك'}')),
          const SizedBox(width: 14),
        ],
      );

  Widget _pageFor(int index) => switch (index) {
        0 => _HomePage(market: widget.market, marketLoading: widget.marketLoading, user: widget.user, onNavigate: (index) => setState(() => _selectedIndex = index)),
        1 => _CartPage(user: widget.user),
        2 => _OrdersPage(user: widget.user),
        3 => _MerchantPage(user: widget.user),
        _ => _AdminPage(user: widget.user),
      };

  Future<void> _startLogin() async {
    final origin = Uri.base.origin;
    if (origin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اضبط عنوان API للتطبيق الأصلي قبل تسجيل الدخول.')));
      return;
    }
    final loginUri = Uri.parse('$origin/api/oauth/start').replace(queryParameters: {'origin': origin});
    if (!await launchUrl(loginUri, mode: LaunchMode.platformDefault)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر بدء تسجيل الدخول الآمن.')));
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
        decoration: BoxDecoration(color: const Color(0xFF006A63), borderRadius: BorderRadius.circular(compact ? 12 : 16)),
        child: const Icon(Icons.storefront_rounded, color: Colors.white),
      );
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.onNavigate, this.market, required this.marketLoading, this.user});
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Hero(city: market?.city ?? 'إب', onBrowse: () => onNavigate(1)),
            if (marketLoading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
            const SizedBox(height: 30),
            const _SectionHeader(title: 'كيف يعمل السوق؟', subtitle: 'تجربة محلية واضحة تحفظ استقلال كل متجر ومدفوعاته.'),
            const SizedBox(height: 14),
            const Wrap(spacing: 16, runSpacing: 16, children: [
              _PrincipleCard(icon: Icons.travel_explore_rounded, title: 'اكتشف متاجر إب', detail: 'تظهر المتاجر بعد اعتماد الإدارة فقط.'),
              _PrincipleCard(icon: Icons.shopping_bag_rounded, title: 'سلة واحدة، طلبات منفصلة', detail: 'تُجمع المنتجات حسب التاجر قبل إتمام الطلب.'),
              _PrincipleCard(icon: Icons.account_balance_wallet_rounded, title: 'دفع لصاحب المتجر', detail: 'تُراجع إثباتات الدفع يدوياً وبشكل آمن.'),
            ]),
            const SizedBox(height: 34),
            const _SectionHeader(title: 'المتاجر والمنتجات المعتمدة', subtitle: 'ستظهر هنا بعد اكتمال الاعتماد ونشر الكتالوج.'),
            const SizedBox(height: 14),
            _CatalogSection(user: user),
          ]),
        ),
      ),
    );
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
          gradient: const LinearGradient(colors: [Color(0xFF006A63), Color(0xFF024B4B)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 26,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Pill(label: '$city · السوق التجريبي الأول'),
                const SizedBox(height: 18),
                const Text('تسوّق محلياً، بثقة ووضوح.', style: TextStyle(color: Colors.white, fontSize: 36, height: 1.15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('منصة متعددة المتاجر، مصممة للعربية أولاً. كل متجر يستقبل مدفوعاته بنفسه وكل طلب يُتابع بشكل مستقل.', style: TextStyle(color: Color(0xFFD7F0E9), fontSize: 16, height: 1.7)),
              ]),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD39A2C), foregroundColor: const Color(0xFF1F1605), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18)),
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
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: .2))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF68655F)))]);
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 310,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(backgroundColor: const Color(0xFFE2F2EC), foregroundColor: const Color(0xFF006A63), child: Icon(icon)),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(detail, style: const TextStyle(color: Color(0xFF68655F), height: 1.55)),
            ]),
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
  late Future<List<MarketplaceProduct>> _products = MarketplaceApiClient().products();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() => setState(() => _products = MarketplaceApiClient().products(query: _search.text));

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _search, onSubmitted: (_) => _runSearch(), decoration: const InputDecoration(hintText: 'ابحث في المنتجات المعتمدة'))),
          const SizedBox(width: 10),
          FilledButton(onPressed: _runSearch, child: const Text('بحث')),
        ]),
        const SizedBox(height: 14),
        FutureBuilder<List<MarketplaceProduct>>(
          future: _products,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator());
            if (snapshot.hasError) return _CatalogNotice(icon: Icons.cloud_off_outlined, title: 'تعذر تحميل الكتالوج', detail: 'تحقق من الاتصال ثم حاول البحث مرة أخرى.');
            final products = snapshot.data ?? [];
            if (products.isEmpty) return const _CatalogNotice(icon: Icons.storefront_outlined, title: 'نستعد لاستقبال المتاجر المعتمدة في إب', detail: 'لا نعرض متاجر أو منتجات تجريبية. يظهر الكتالوج فقط بعد إدخاله واعتماده من التاجر والإدارة.');
            return Wrap(spacing: 14, runSpacing: 14, children: products.map((product) => _ProductCard(product: product, canAdd: widget.user != null)).toList());
          },
        ),
      ]);
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34), child: Column(children: [
        CircleAvatar(radius: 28, backgroundColor: const Color(0xFFF5ECD8), foregroundColor: const Color(0xFFD39A2C), child: Icon(icon, size: 30)),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF68655F), height: 1.6)),
      ])));
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.canAdd});
  final MarketplaceProduct product;
  final bool canAdd;
  @override
  Widget build(BuildContext context) => SizedBox(width: 280, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.shopName, style: const TextStyle(color: Color(0xFF006A63), fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(product.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${product.priceMinor} ${product.currency}', style: const TextStyle(color: Color(0xFF68655F))),
        const SizedBox(height: 14),
        FilledButton.tonal(onPressed: () async {
          if (!canAdd) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولاً لإضافة المنتجات إلى السلة.'))); return; }
          try { await MarketplaceApiClient().addToCart(product.id); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى السلة.'))); }
          on ApiException catch (error) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
        }, child: const Text('أضف إلى السلة')),
      ]))));
}

class _CartPage extends StatefulWidget {
  const _CartPage({this.user});
  final SessionUser? user;
  @override
  State<_CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<_CartPage> {
  late final Future<List<CartGroup>> _cart = MarketplaceApiClient().cartGroups();
  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const _CenteredPage(icon: Icons.lock_outline, title: 'سجّل الدخول لاستخدام السلة', detail: 'ستُحفظ منتجاتك في سلة واحدة وتُقسم بوضوح حسب المتجر قبل الدفع.');
    return FutureBuilder<List<CartGroup>>(future: _cart, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _CenteredPage(icon: Icons.cloud_off_outlined, title: 'تعذر تحميل السلة', detail: 'تحقق من الاتصال ثم حاول مرة أخرى.');
      final groups = snapshot.data ?? [];
      if (groups.isEmpty) return const _CenteredPage(icon: Icons.shopping_bag_outlined, title: 'سلتك فارغة', detail: 'تُعرض المنتجات في مجموعات منفصلة لكل متجر عند إضافتها.');
      return ListView(padding: const EdgeInsets.all(24), children: groups.map((group) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(group.shopName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...group.items.map((item) => ListTile(title: Text(item.name), trailing: Text('${item.priceMinor} ${item.currency}'))),
        const Divider(),
        Text('إجمالي هذا المتجر: ${group.totalMinor} YER', style: const TextStyle(fontWeight: FontWeight.w700)),
      ])))).toList());
    });
  }
}

class _OrdersPage extends StatefulWidget {
  const _OrdersPage({this.user});
  final SessionUser? user;
  @override
  State<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<_OrdersPage> {
  late final Future<List<MerchantOrderSummary>> _orders = MarketplaceApiClient().myOrders();
  @override
  Widget build(BuildContext context) {
    if (widget.user == null) return const _CenteredPage(icon: Icons.lock_outline, title: 'سجّل الدخول لمتابعة طلباتك', detail: 'ستظهر كل مجموعة تاجر كطلب مستقل مع حالة الدفع والتنفيذ الخاصة بها.');
    return FutureBuilder<List<MerchantOrderSummary>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const _CenteredPage(icon: Icons.cloud_off_outlined, title: 'تعذر تحميل الطلبات', detail: 'تحقق من الاتصال ثم حاول مرة أخرى.');
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return const _CenteredPage(icon: Icons.receipt_long_outlined, title: 'لا توجد طلبات بعد', detail: 'عند إتمام الدفع، سيُنشأ طلب مستقل لكل متجر في السلة.');
        return ListView(padding: const EdgeInsets.all(24), children: orders.map((order) => Card(child: ListTile(
          title: Text('طلب #${order.id}'),
          subtitle: Text('الدفع: ${order.paymentStatus} · التنفيذ: ${order.fulfilmentStatus}'),
          trailing: Column(mainAxisSize: MainAxisSize.min, children: [Text('${order.totalMinor} ${order.currency}'), if (order.paymentStatus == 'awaiting_payment') TextButton(onPressed: () => _showPayment(order), child: const Text('تعليمات الدفع'))]),
        ))).toList());
      },
    );
  }

  Future<void> _showPayment(MerchantOrderSummary order) async {
    final reference = TextEditingController();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('تعليمات الدفع لهذا المتجر'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (order.accountHolderName != null) Text('اسم المستلم: ${order.accountHolderName}'),
        if (order.receivingIdentifier != null) Text('الحساب/المحفظة: ${order.receivingIdentifier}'),
        if (order.paymentInstructions != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(order.paymentInstructions!)),
        const SizedBox(height: 14),
        TextField(controller: reference, decoration: const InputDecoration(labelText: 'مرجع التحويل')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), FilledButton(onPressed: () async {
        final value = reference.text.trim();
        if (value.isEmpty) return;
        Navigator.pop(dialogContext);
        try { await MarketplaceApiClient().submitPaymentReference(merchantOrderId: order.id, reference: value); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أُرسل مرجع التحويل للمراجعة.'))); }
        on ApiException catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message))); }
      }, child: const Text('إرسال للمراجعة'))],
    ));
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
  late final Future<bool> _hasMerchant = MarketplaceApiClient().hasMerchantContext();

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
      await MarketplaceApiClient().submitMerchantApplication(phone: _phone.text.trim(), ownerName: _ownerName.text.trim());
      if (mounted) setState(() => _applicationSubmitted = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب التاجر للمراجعة.')));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return const _CenteredPage(icon: Icons.lock_outline, title: 'سجّل الدخول لبدء طلب التاجر', detail: 'يُحفظ حساب التاجر وبيانات متجره بشكل منفصل وآمن بعد تسجيل الدخول.');
    }
    if (_applicationSubmitted) return const _IdentityMerchantPanel();
    return FutureBuilder<bool>(future: _hasMerchant, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _CenteredPage(icon: Icons.cloud_off_outlined, title: 'تعذر تحميل حالة حساب التاجر', detail: 'تحقق من الاتصال ثم حاول فتح صفحة التاجر مجدداً.');
      if (snapshot.data == true) return const _IdentityMerchantPanel();
      return _applicationForm(context);
    });
  }

  Widget _applicationForm(BuildContext context) {
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Card(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('طلب الانضمام كتاجر', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('سيُراجع الطلب قبل ظهور المتجر أو منتجاته في السوق العام.'),
        const SizedBox(height: 20),
        TextFormField(controller: _ownerName, decoration: const InputDecoration(labelText: 'اسم صاحب النشاط'), validator: (value) => value == null || value.trim().length < 3 ? 'أدخل اسماً صحيحاً.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف'), validator: (value) => value == null || value.trim().length < 7 ? 'أدخل رقم هاتف صحيحاً.' : null),
        const SizedBox(height: 8),
        const Text('سيُحفظ الرقم كغير مُتحقق منه خلال المرحلة التجريبية. سيتاح التحقق برسالة عند اعتماد مزود رسائل محلي.', style: TextStyle(color: Color(0xFF68655F), height: 1.5)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded), label: Text(_submitting ? 'جارٍ الإرسال' : 'إرسال الطلب')),
      ])),
    ))));
  }
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
  late Future<IdentityVerificationSummary> _summary = MarketplaceApiClient().identityMine();

  Future<void> _pick(bool passport) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'], withData: true);
    final file = result?.files.single;
    if (file == null) return;
    if (file.bytes == null || file.size > 3 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر صورة JPEG أو PNG أو WebP أصغر من 3 ميغابايت.')));
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

  String _mime(PlatformFile file) => file.name.toLowerCase().endsWith('.png') ? 'image/png' : file.name.toLowerCase().endsWith('.webp') ? 'image/webp' : 'image/jpeg';

  Future<void> _submit() async {
    if (!_consent || _passport?.bytes == null || _selfie?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أقرّ بالموافقة واختر صورة جواز وصورة سيلفي أولاً.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await MarketplaceApiClient().submitIdentityEvidence(passportBase64: base64Encode(_passport!.bytes!), passportName: _passport!.name, passportMimeType: _mime(_passport!), selfieBase64: base64Encode(_selfie!.bytes!), selfieName: _selfie!.name, selfieMimeType: _mime(_selfie!));
      if (mounted) setState(() => _summary = MarketplaceApiClient().identityMine());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الوثائق للمراجعة اليدوية. لن يتم اتخاذ قرار تلقائي.')));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: FutureBuilder<IdentityVerificationSummary>(future: _summary, builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator());
    if (snapshot.hasError) return const _CenteredPage(icon: Icons.cloud_off_outlined, title: 'تعذر تحميل حالة التحقق', detail: 'تحقق من الاتصال ثم حاول فتح صفحة التاجر مجدداً.');
    final status = snapshot.data?.status;
    final note = snapshot.data?.decisionNote;
    return Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('التحقق من هوية التاجر', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('ترسل صورة الجواز وصورة السيلفي لموظفي الإدارة المخوّلين للمراجعة اليدوية فقط. لا تُعرض علناً ولا تُستخدم لمطابقة الوجه أو لقرار آلي.', style: TextStyle(height: 1.65)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEAF5F1), borderRadius: BorderRadius.circular(14)), child: Text(status == null ? 'لم تُرسل وثائق تحقق بعد.' : 'حالة المراجعة: $status${note == null ? '' : '\nملاحظة الإدارة: $note'}', style: const TextStyle(height: 1.6))),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: _submitting ? null : () => _pick(true), icon: const Icon(Icons.badge_outlined), label: Text(_passport == null ? 'اختر صورة جواز السفر' : 'تم اختيار: ${_passport!.name}')),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _submitting ? null : () => _pick(false), icon: const Icon(Icons.face_retouching_natural_outlined), label: Text(_selfie == null ? 'اختر صورة سيلفي للوجه' : 'تم اختيار: ${_selfie!.name}')),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent, onChanged: _submitting ? null : (value) => setState(() => _consent = value ?? false), title: const Text('أوافق على إرسال الوثيقتين للمراجعة اليدوية من الإدارة المخوّلة.'), controlAffinity: ListTileControlAffinity.leading),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _submitting ? null : _submit, icon: _submitting ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.verified_user_outlined), label: Text(_submitting ? 'جارٍ الإرسال' : 'إرسال للمراجعة اليدوية')),
    ])));
  }))));
}

class _AdminPage extends StatefulWidget {
  const _AdminPage({this.user});
  final SessionUser? user;
  @override
  State<_AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<_AdminPage> {
  late Future<List<AdminIdentityCase>> _queue = MarketplaceApiClient().adminIdentityQueue();
  @override
  Widget build(BuildContext context) {
    if (widget.user?.role != 'admin') return const _CenteredPage(icon: Icons.lock_outline, title: 'صلاحية الإدارة مطلوبة', detail: 'تقتصر مراجعة وثائق الهوية على موظفي الإدارة المخوّلين.');
    return FutureBuilder<List<AdminIdentityCase>>(future: _queue, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _CenteredPage(icon: Icons.cloud_off_outlined, title: 'تعذر تحميل المراجعات', detail: 'تحقق من الصلاحية والاتصال ثم حاول مجدداً.');
      final queue = snapshot.data ?? [];
      if (queue.isEmpty) return const _CenteredPage(icon: Icons.fact_check_outlined, title: 'لا توجد وثائق بانتظار المراجعة', detail: 'لا يظهر هنا سوى طلبات التحقق التي أرسلها التجار للمراجعة اليدوية.');
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text('مراجعة هوية التجار', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('لا توجد مطابقة وجه آلية. القرار هنا لا يعتمد المتجر أو ينشره تلقائياً.'),
        const SizedBox(height: 14),
        ...queue.map((item) => Card(child: ListTile(title: Text('طلب تاجر #${item.merchantId}'), subtitle: Text('الحالة: ${item.status}'), trailing: Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => _openEvidence(item), child: const Text('عرض الوثائق')), FilledButton(onPressed: () => _review(item), child: const Text('اتخاذ قرار'))])))),
      ]);
    });
  }

  Future<void> _review(AdminIdentityCase item) async {
    final note = TextEditingController();
    var submitting = false;
    await showDialog<void>(context: context, builder: (dialog) => StatefulBuilder(builder: (dialogContext, setDialogState) {
      Future<void> decide(bool approve) async {
        if (note.text.trim().length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب ملاحظة من ثلاثة أحرف على الأقل قبل اتخاذ القرار.')));
          return;
        }
        setDialogState(() => submitting = true);
        try {
          await MarketplaceApiClient().reviewIdentityCase(identityCaseId: item.id, approve: approve, note: note.text.trim());
          if (mounted) setState(() => _queue = MarketplaceApiClient().adminIdentityQueue());
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        } on ApiException catch (error) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
        } finally {
          if (dialogContext.mounted) setDialogState(() => submitting = false);
        }
      }
      return AlertDialog(title: const Text('قرار مراجعة يدوي'), content: TextField(controller: note, enabled: !submitting, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'ملاحظة القرار المطلوبة')), actions: [TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')), FilledButton.tonal(onPressed: submitting ? null : () => decide(false), child: Text(submitting ? 'جارٍ الحفظ' : 'رفض')), FilledButton(onPressed: submitting ? null : () => decide(true), child: Text(submitting ? 'جارٍ الحفظ' : 'اعتماد'))]);
    }));
    note.dispose();
  }

  Future<void> _openEvidence(AdminIdentityCase item) async {
    try {
      final evidence = await MarketplaceApiClient().adminIdentityEvidence(item.id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialog) => AlertDialog(title: const Text('وثائق المراجعة المصرح بها'), content: Column(mainAxisSize: MainAxisSize.min, children: evidence.map((document) => ListTile(title: Text(document.kind == 'passport' ? 'صورة جواز السفر' : 'صورة السيلفي'), trailing: const Icon(Icons.open_in_new), onTap: () async { await launchUrl(Uri.parse(document.signedUrl), mode: LaunchMode.externalApplication); })).toList()), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إغلاق'))]));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _CenteredPage extends StatelessWidget {
  const _CenteredPage({required this.icon, required this.title, required this.detail});
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 32, backgroundColor: const Color(0xFFE2F2EC), foregroundColor: const Color(0xFF006A63), child: Icon(icon, size: 32)),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(detail, style: const TextStyle(color: Color(0xFF68655F), height: 1.7), textAlign: TextAlign.center),
              ]),
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
