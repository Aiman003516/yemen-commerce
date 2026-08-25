import 'package:flutter/material.dart';

import '../core/contracts.dart';
import '../core/api_client.dart';

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key, this.market, this.marketLoading = false});

  final MarketConfig? market;
  final bool marketLoading;

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
          TextButton.icon(onPressed: _comingSoon, icon: const Icon(Icons.login_rounded), label: const Text('تسجيل الدخول')),
          const SizedBox(width: 14),
        ],
      );

  Widget _pageFor(int index) => switch (index) {
        0 => _HomePage(market: widget.market, marketLoading: widget.marketLoading, onNavigate: (index) => setState(() => _selectedIndex = index)),
        1 => const _CartPage(),
        2 => const _OrdersPage(),
        3 => const _MerchantPage(),
        _ => const _AdminPage(),
      };

  void _comingSoon() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيُفتح تسجيل الدخول الآمن عند ربط هوية الحساب بالخادم.')));
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
  const _HomePage({required this.onNavigate, this.market, required this.marketLoading});
  final ValueChanged<int> onNavigate;
  final MarketConfig? market;
  final bool marketLoading;

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
            const _CatalogSection(),
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
  const _CatalogSection();

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
            return Wrap(spacing: 14, runSpacing: 14, children: products.map((product) => _ProductCard(product: product)).toList());
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
  const _ProductCard({required this.product});
  final MarketplaceProduct product;
  @override
  Widget build(BuildContext context) => SizedBox(width: 280, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.shopName, style: const TextStyle(color: Color(0xFF006A63), fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(product.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${product.priceMinor} ${product.currency}', style: const TextStyle(color: Color(0xFF68655F))),
        const SizedBox(height: 14),
        FilledButton.tonal(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجّل الدخول أولاً لإضافة المنتجات إلى السلة.'))), child: const Text('أضف إلى السلة')),
      ]))));
}

class _CartPage extends StatelessWidget {
  const _CartPage();
  @override
  Widget build(BuildContext context) => _CenteredPage(
        icon: Icons.shopping_bag_outlined,
        title: 'سلتك جاهزة لاستقبال اختياراتك',
        detail: 'عند إضافة منتجات من متاجر متعددة، ستبقى في سلة واحدة وتظهر في مجموعات مستقلة لكل تاجر قبل الدفع.',
      );
}

class _OrdersPage extends StatelessWidget {
  const _OrdersPage();
  @override
  Widget build(BuildContext context) => _CenteredPage(
        icon: Icons.receipt_long_outlined,
        title: 'تابع كل طلب على حدة',
        detail: 'ستعرض هذه الصفحة تعليمات الدفع، المرجع، إثبات التحويل، ومراحل التنفيذ لكل طلب تابع لمتجر مختلف.',
      );
}

class _MerchantPage extends StatelessWidget {
  const _MerchantPage();
  @override
  Widget build(BuildContext context) => _CenteredPage(
        icon: Icons.store_mall_directory_outlined,
        title: 'مساحة التاجر',
        detail: 'سجّل متجرك، أضف الكتالوج، عيّن وسائل الاستلام وبيانات الحساب المستلم، ثم انتظر اعتماد الإدارة قبل النشر.',
      );
}

class _AdminPage extends StatelessWidget {
  const _AdminPage();
  @override
  Widget build(BuildContext context) => _CenteredPage(
        icon: Icons.admin_panel_settings_outlined,
        title: 'ضوابط الإدارة والمراجعة',
        detail: 'بعد تسجيل الدخول الإداري، ستتمكن من اعتماد التجار والمتاجر وإدارة التصنيفات والقدرات وسجل التدقيق.',
      );
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
