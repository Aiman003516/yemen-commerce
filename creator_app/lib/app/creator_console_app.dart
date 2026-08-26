import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:commerce_core/commerce_core.dart';
import 'package:commerce_data/commerce_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatorConsoleApp extends StatelessWidget {
  const CreatorConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF173B63);
    return MaterialApp(
      title: 'لوحة منشئ يمن كومرس',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          primary: brand,
          secondary: const Color(0xFFD39A2C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const CreatorSessionGate(),
    );
  }
}

class CreatorSessionGate extends StatelessWidget {
  const CreatorSessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseRuntime.isConfigured) return const _CreatorConfigPage();
    return StreamBuilder<AuthState>(
      stream: SupabaseRuntime.authStateChanges,
      builder: (context, _) {
        final user = SupabaseRuntime.client.auth.currentUser;
        if (user == null) return const _CreatorLoginPage();
        return FutureBuilder<CreatorAccess>(
          future: CreatorRepository().loadAccess(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingPage();
            }
            if (snapshot.hasError) {
              return _FailurePage(
                message: 'تعذر التحقق من صلاحيات الحساب. لا يوجد وصول إلى لوحة المنشئ.',
              );
            }
            final access = snapshot.data!;
            if (access.accountStatus != 'active' ||
                (!access.isCreator &&
                    !access.can(CreatorCapability.managePeople))) {
              return const _FailurePage(
                message: 'هذا الحساب لا يملك صلاحية الوصول إلى لوحة المنشئ.',
              );
            }
            return CreatorConsoleShell(access: access);
          },
        );
      },
    );
  }
}

class CreatorConsoleShell extends StatefulWidget {
  const CreatorConsoleShell({super.key, required this.access});
  final CreatorAccess access;

  @override
  State<CreatorConsoleShell> createState() => _CreatorConsoleShellState();
}

class _CreatorConsoleShellState extends State<CreatorConsoleShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const CreatorDashboardPage(),
      const CreatorPeoplePage(),
      const CreatorMerchantGovernancePage(),
      const CreatorGlobalPolicyPage(),
      const CreatorMarketOperationsPage(),
      const CreatorProviderHubPage(),
      const CreatorTrustSupportPage(),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final body = Row(
            children: [
              if (wide)
                _CreatorRail(
                  selectedIndex: selectedIndex,
                  onSelected: (value) => setState(() => selectedIndex = value),
                ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: pages[selectedIndex]),
                    if (!wide)
                      _CreatorBottomBar(
                        selectedIndex: selectedIndex,
                        onSelected: (value) =>
                            setState(() => selectedIndex = value),
                      ),
                  ],
                ),
              ),
            ],
          );
          return Scaffold(
            appBar: AppBar(
              title: const Text('لوحة منشئ يمن كومرس'),
              actions: [
                IconButton(
                  onPressed: SupabaseRuntime.signOut,
                  tooltip: 'تسجيل الخروج',
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            body: body,
          );
        },
      ),
    );
  }
}

class _CreatorRail extends StatelessWidget {
  const _CreatorRail({required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    labelType: NavigationRailLabelType.all,
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('الرئيسية'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('الأشخاص'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.storefront_outlined),
        selectedIcon: Icon(Icons.storefront),
        label: Text('التجار'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.public_outlined),
        selectedIcon: Icon(Icons.public),
        label: Text('الأسواق'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.alt_route_outlined),
        selectedIcon: Icon(Icons.alt_route),
        label: Text('التشغيل'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: Text('التكاملات'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.fact_check_outlined),
        selectedIcon: Icon(Icons.fact_check),
        label: Text('التدقيق'),
      ),
    ],
  );
}

class _CreatorBottomBar extends StatelessWidget {
  const _CreatorBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        label: 'الرئيسية',
      ),
      NavigationDestination(icon: Icon(Icons.people_outline), label: 'الأشخاص'),
      NavigationDestination(
        icon: Icon(Icons.storefront_outlined),
        label: 'التجار',
      ),
      NavigationDestination(
        icon: Icon(Icons.public_outlined),
        label: 'الأسواق',
      ),
      NavigationDestination(
        icon: Icon(Icons.alt_route_outlined),
        label: 'التشغيل',
      ),
      NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'التكاملات'),
      NavigationDestination(
        icon: Icon(Icons.fact_check_outlined),
        label: 'التدقيق',
      ),
    ],
  );
}

class CreatorDashboardPage extends StatelessWidget {
  const CreatorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<CreatorDashboardSummary>(
    future: CreatorRepository().dashboardSummary(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingPage();
      }
      if (snapshot.hasError) {
        return const _FailurePage(
          message: 'تعذر تحميل مؤشرات لوحة المنشئ. تحقق من صلاحية الحساب واتصال Supabase.',
        );
      }
      final summary = snapshot.data!;
      final cards = [
        _MetricCard(
          label: 'الأسواق النشطة',
          value: summary.activeMarkets,
          icon: Icons.public,
        ),
        _MetricCard(
          label: 'طلبات التجار',
          value: summary.pendingMerchants,
          icon: Icons.storefront,
        ),
        _MetricCard(
          label: 'حالات الهوية',
          value: summary.pendingIdentityCases,
          icon: Icons.verified_user,
        ),
        _MetricCard(
          label: 'اعتماد المتاجر',
          value: summary.pendingShopApprovals,
          icon: Icons.fact_check,
        ),
        _MetricCard(
          label: 'مراجعة المدفوعات',
          value: summary.paymentClaimsUnderReview,
          icon: Icons.payments,
        ),
        _MetricCard(
          label: 'التقارير المفتوحة',
          value: summary.openReports,
          icon: Icons.report_problem,
        ),
      ];
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'نظرة تشغيلية',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'ملخص آمن للعمليات التي تحتاج إلى قرار من منشئ النظام أو المشغل المخوّل.',
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 1100 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.3,
            children: cards,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF173B63)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'كل عمليات إدارة الأشخاص والصلاحيات يجب أن تمر عبر RPC مقيد في Supabase وتُسجل في سجل التدقيق.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CreatorPeoplePage extends StatefulWidget {
  const CreatorPeoplePage({super.key});
  @override
  State<CreatorPeoplePage> createState() => _CreatorPeoplePageState();
}

class _CreatorPeoplePageState extends State<CreatorPeoplePage> {
  final queryController = TextEditingController();
  late Future<List<CreatorPerson>> people;

  @override
  void initState() {
    super.initState();
    people = CreatorRepository().searchPeople();
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  void search() => setState(
    () =>
        people = CreatorRepository().searchPeople(query: queryController.text),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'إدارة الأشخاص',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'ابحث عن المستخدمين وأدر الأدوار والحالة من خلال صلاحيات منشئ النظام.',
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: queryController,
              onSubmitted: (_) => search(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'الاسم أو البريد أو رقم الهاتف',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: search,
            icon: const Icon(Icons.search),
            label: const Text('بحث'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      FutureBuilder<List<CreatorPerson>>(
        future: people,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const _FailurePage(
              message: 'تعذر تحميل الأشخاص. تأكد من صلاحية manage_people.',
            );
          }
          final rows = snapshot.data ?? const <CreatorPerson>[];
          if (rows.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد نتائج.'),
              ),
            );
          }
          return Card(child: Column(children: rows.map(_personTile).toList()));
        },
      ),
    ],
  );

  Widget _personTile(CreatorPerson person) => ListTile(
    leading: CircleAvatar(
      child: Text((person.displayName ?? '?').characters.first.toUpperCase()),
    ),
    title: Text(
      person.displayName?.isNotEmpty == true
          ? person.displayName!
          : 'مستخدم بلا اسم',
    ),
    subtitle: Text(
      [
        person.email,
        person.phone,
        person.roles.join('، '),
        'الحالة: ${person.accountStatus}',
      ].whereType<String>().where((value) => value.isNotEmpty).join(' • '),
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (action) => _handleAction(person, action),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'operator', child: Text('منح دور مشغل')),
        PopupMenuItem(value: 'review', child: Text('منح دور مراجعة')),
        PopupMenuItem(value: 'suspend', child: Text('تعليق الحساب')),
        PopupMenuItem(value: 'restore', child: Text('استعادة الحساب')),
      ],
    ),
  );

  Future<void> _handleAction(CreatorPerson person, String action) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('سبب الإجراء'),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'السبب مطلوب'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.length < 3 || !mounted) return;
    try {
      final repository = CreatorRepository();
      if (action == 'suspend' || action == 'restore') {
        await repository.setAccountStatus(
          userId: person.userId,
          status: action == 'suspend' ? 'suspended' : 'active',
          reason: reason,
        );
      } else {
        await repository.setRole(
          userId: person.userId,
          role: action == 'operator'
              ? CreatorRole.platformOperator
              : CreatorRole.reviewAgent,
          reason: reason,
        );
      }
      if (mounted) {
        setState(
          () => people = CreatorRepository().searchPeople(
            query: queryController.text,
          ),
        );
      }
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'رفض Supabase العملية. تحقق من دور المنشئ ونطاق الصلاحيات.',
            ),
          ),
        );
      }
    }
  }
}

class _CreatorLoginPage extends StatefulWidget {
  const _CreatorLoginPage();
  @override
  State<_CreatorLoginPage> createState() => _CreatorLoginPageState();
}

class _CreatorLoginPageState extends State<_CreatorLoginPage> {
  final emailController = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (emailController.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await SupabaseRuntime.sendMagicLink(emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال رابط الدخول.')));
      }
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال رابط الدخول.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 54),
                const SizedBox(height: 16),
                const Text(
                  'دخول لوحة المنشئ',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هذا التطبيق مخصص لمنشئ النظام والمشغلين المفوضين فقط.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: sending ? null : send,
                    child: Text(
                      sending ? 'جارٍ الإرسال...' : 'إرسال رابط الدخول',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CreatorConfigPage extends StatelessWidget {
  const _CreatorConfigPage();
  @override
  Widget build(BuildContext context) => const _FailurePage(
    message: 'أضف SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY إلى إعدادات البناء قبل تشغيل لوحة المنشئ.',
  );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _FailurePage extends StatelessWidget {
  const _FailurePage({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );
}

class CreatorProviderHubPage extends StatelessWidget {
  const CreatorProviderHubPage({super.key});

  static const providers = [
    (
      name: 'واتساب للأعمال',
      category: 'رسائل و CRM',
      status: 'جاهز للربط',
      mode: 'mock',
      detail: 'قوالب حالة الطلب، موافقات العملاء، و Webhook للحالات الواردة.',
    ),
    (
      name: 'SMS اليمن',
      category: 'رسائل منخفضة النطاق',
      status: 'تجريبي',
      mode: 'mock',
      detail:
          'تجربة OTP والتنبيهات عبر مزود SMS قابل للاستبدال، بدون إرسال فعلي.',
    ),
    (
      name: 'شبكة التوصيل المحلية',
      category: 'شحن وتتبع',
      status: 'تشغيل يدوي',
      mode: 'manual',
      detail: 'إنشاء شحنة يدوياً، رقم تتبع، حالات استلام وتسليم، ورسوم حسب المنطقة.',
    ),
    (
      name: 'خرائط ومناطق الخدمة',
      category: 'مواقع وعناوين',
      status: 'مخطط',
      mode: 'pending_approval',
      detail: 'ترميز جغرافي اختياري مع بديل آمن يعتمد على الحي ونقطة الاستلام.',
    ),
    (
      name: 'قنوات البيع الخارجية',
      category: 'قنوات وتزامن',
      status: 'Mock فقط',
      mode: 'mock',
      detail: 'كتالوج تجريبي لقنوات اجتماعية وأسواق خارجية، بلا نشر أو مزامنة حقيقية.',
    ),
    (
      name: 'تمويل التجار',
      category: 'خدمات مالية',
      status: 'محجوب',
      mode: 'blocked',
      detail:
          'واجهة عرض فقط إلى حين شريك مرخص، تقييم ائتماني، ومراجعة قانونية.',
    ),
    (
      name: 'تحليلات متقدمة',
      category: 'بيانات ونمو',
      status: 'بيانات تجريبية',
      mode: 'mock',
      detail:
          'شرائح العملاء، القنوات، ومؤشرات التحويل مبنية على بيانات توضيحية.',
    ),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'مركز التكاملات ومزودي الخدمات',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'هذه لوحة تخطيط وتشغيل آمن. البيانات التجريبية لا ترسل رسائل، ولا تنشئ شحنات، ولا تتحقق من المدفوعات، ولا تنقل أموالاً.',
      ),
      const SizedBox(height: 18),
      Card(
        color: const Color(0xFFFFF8E7),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'قبل تفعيل أي مزود: خزّن المفاتيح خارج التطبيق، تحقق من توقيع Webhook، ثبّت سياسة الموافقة، وراجع التسوية والامتثال في اليمن.',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisExtent: 210,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: providers.length,
        itemBuilder: (context, index) {
          final provider = providers[index];
          final color = switch (provider.mode) {
            'blocked' => Colors.red,
            'manual' => Colors.orange,
            'pending_approval' => Colors.indigo,
            _ => Colors.teal,
          };
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.extension_outlined, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(
                        label: Text(provider.status),
                        side: BorderSide(color: color.withValues(alpha: .35)),
                      ),
                    ],
                  ),
                  Text(provider.category, style: TextStyle(color: color)),
                  const SizedBox(height: 8),
                  Expanded(child: Text(provider.detail)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton(
                      onPressed: () => _showProviderDialog(context, provider),
                      child: const Text('عرض الخطة التجريبية'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  static Future<void> _showProviderDialog(
    BuildContext context,
    dynamic provider,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(provider.name),
      content: Text(
        'الحالة الحالية: ${provider.status}\n\n${provider.detail}\n\nلا يوجد اتصال خارجي في هذه النسخة التجريبية. عند توفر الاعتماد، سيُضاف Adapter مستقل مع Webhook موثق واختبارات عزل.',
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

class CreatorMarketOperationsPage extends StatefulWidget {
  const CreatorMarketOperationsPage({super.key});

  @override
  State<CreatorMarketOperationsPage> createState() =>
      _CreatorMarketOperationsPageState();
}

class _CreatorMarketOperationsPageState
    extends State<CreatorMarketOperationsPage> {
  final repository = CreatorRepository();
  late Future<List<CreatorMarket>> markets;
  String? selectedMarketId;

  @override
  void initState() {
    super.initState();
    markets = repository.listMarkets();
  }

  void refresh() {
    setState(() => markets = repository.listMarkets());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CreatorMarket>>(
    future: markets,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _InlineLoading();
      }
      if (snapshot.hasError ||
          snapshot.data == null ||
          snapshot.data!.isEmpty) {
        return const _FailurePage(
          message: 'تعذر تحميل الأسواق لتشغيل مناطق الخدمة.',
        );
      }
      final availableMarkets = snapshot.data!;
      final selected = availableMarkets.firstWhere(
        (market) => market.id == selectedMarketId,
        orElse: () => availableMarkets.first,
      );
      if (selectedMarketId != selected.id) selectedMarketId = selected.id;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'تشغيل مناطق الخدمة ونقاط الاستلام',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'أدر التغطية حسب السوق والحي. لا يتم توسيع التغطية تلقائياً، وكل تغيير يحتاج صلاحية manage_markets وسبباً وسجل تدقيق.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: selected.id,
            decoration: const InputDecoration(labelText: 'السوق'),
            items: availableMarkets
                .map(
                  (market) => DropdownMenuItem(
                    value: market.id,
                    child: Text('${market.city} · ${market.governorate}'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => selectedMarketId = value),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<dynamic>>(
            future: Future.wait<dynamic>([
              repository.listServiceAreas(selected.id),
              repository.listPickupPoints(selected.id),
            ]),
            builder: (context, operationsSnapshot) {
              if (operationsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const _InlineLoading();
              }
              if (operationsSnapshot.hasError) {
                return const _InlineError(
                  message: 'تعذر تحميل مناطق الخدمة ونقاط الاستلام.',
                );
              }
              final areas =
                  operationsSnapshot.data?[0] as List<CreatorServiceArea>? ??
                  const [];
              final points =
                  operationsSnapshot.data?[1] as List<CreatorPickupPoint>? ??
                  const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MarketOpsSection(
                    title: 'مناطق الخدمة',
                    icon: Icons.map_outlined,
                    actionLabel: 'إضافة منطقة',
                    onAction: () => _showAreaDialog(selected.id),
                    children: areas.isEmpty
                        ? [const Text('لا توجد مناطق مهيأة لهذا السوق.')]
                        : areas
                              .map(
                                (area) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${area.nameAr} · ${area.areaCode}',
                                  ),
                                  subtitle: Text(
                                    'الحالة: ${area.status} · توصيل: ${area.deliveryEnabled ? 'نعم' : 'لا'} · استلام: ${area.pickupEnabled ? 'نعم' : 'لا'}',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _showAreaDialog(
                                      selected.id,
                                      area: area,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 16),
                  _MarketOpsSection(
                    title: 'نقاط الاستلام',
                    icon: Icons.location_on_outlined,
                    actionLabel: 'إضافة نقطة',
                    onAction: () => _showPickupDialog(selected.id),
                    children: points.isEmpty
                        ? [const Text('لا توجد نقاط استلام مهيأة لهذا السوق.')]
                        : points
                              .map(
                                (point) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(point.nameAr),
                                  subtitle: Text(
                                    '${point.addressDetails} · ${point.status}',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () => _showPickupDialog(
                                      selected.id,
                                      point: point,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ),
                              )
                              .toList(),
                  ),
                ],
              );
            },
          ),
        ],
      );
    },
  );

  Future<void> _showAreaDialog(
    String marketId, {
    CreatorServiceArea? area,
  }) async {
    final name = TextEditingController(text: area?.nameAr);
    final code = TextEditingController(text: area?.areaCode);
    final reason = TextEditingController();
    var status = area?.status ?? 'draft';
    var delivery = area?.deliveryEnabled ?? true;
    var pickup = area?.pickupEnabled ?? true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(area == null ? 'إضافة منطقة خدمة' : 'تعديل منطقة خدمة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                  ),
                ),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'رمز المنطقة'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(value: 'active', child: Text('نشطة')),
                    DropdownMenuItem(value: 'paused', child: Text('متوقفة')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? 'draft'),
                ),
                SwitchListTile(
                  title: const Text('تفعيل التوصيل'),
                  value: delivery,
                  onChanged: (value) => setDialogState(() => delivery = value),
                ),
                SwitchListTile(
                  title: const Text('تفعيل الاستلام'),
                  value: pickup,
                  onChanged: (value) => setDialogState(() => pickup = value),
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'سبب التغيير'),
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
                    code.text.trim().length < 2 ||
                    reason.text.trim().length < 3) {
                  return;
                }
                try {
                  await repository.saveServiceArea(
                    id: area?.id,
                    marketId: marketId,
                    nameAr: name.text,
                    areaCode: code.text,
                    status: status,
                    deliveryEnabled: delivery,
                    pickupEnabled: pickup,
                    reason: reason.text,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  refresh();
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('تعذر حفظ منطقة الخدمة.')),
                    );
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
    code.dispose();
    reason.dispose();
  }

  Future<void> _showPickupDialog(
    String marketId, {
    CreatorPickupPoint? point,
  }) async {
    final name = TextEditingController(text: point?.nameAr);
    final address = TextEditingController(text: point?.addressDetails);
    final phone = TextEditingController(text: point?.contactPhone);
    final hours = TextEditingController(text: point?.operatingHours);
    final reason = TextEditingController();
    var status = point?.status ?? 'draft';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            point == null ? 'إضافة نقطة استلام' : 'تعديل نقطة استلام',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                  ),
                ),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل العنوان',
                  ),
                ),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'هاتف التواصل'),
                ),
                TextField(
                  controller: hours,
                  decoration: const InputDecoration(labelText: 'ساعات العمل'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(value: 'active', child: Text('نشطة')),
                    DropdownMenuItem(value: 'paused', child: Text('متوقفة')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? 'draft'),
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'سبب التغيير'),
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
                    address.text.trim().length < 5 ||
                    reason.text.trim().length < 3) {
                  return;
                }
                try {
                  await repository.savePickupPoint(
                    id: point?.id,
                    marketId: marketId,
                    nameAr: name.text,
                    addressDetails: address.text,
                    contactPhone: phone.text,
                    operatingHours: hours.text,
                    status: status,
                    reason: reason.text,
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  refresh();
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('تعذر حفظ نقطة الاستلام.')),
                    );
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
    address.dispose();
    phone.dispose();
    hours.dispose();
    reason.dispose();
  }
}

class _MarketOpsSection extends StatelessWidget {
  const _MarketOpsSection({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class CreatorTrustSupportPage extends StatelessWidget {
  const CreatorTrustSupportPage({super.key});

  static const tickets = [
    ('YC-1042', 'تأخر التوصيل', 'عاجلة', 'مفتوحة'),
    ('YC-1038', 'اختلاف تحصيل نقدي', 'مرتفعة', 'قيد المعالجة'),
    ('YC-1031', 'تعديل بيانات متجر', 'عادية', 'بانتظار العميل'),
  ];
  static const signals = [
    ('إشارة نمط مراجعات', 'متوسطة', 'تحتاج مراجعة بشرية'),
    ('فشل تسليم متكرر', 'مرتفعة', 'لا يوجد حظر تلقائي'),
    ('استخدام قسيمة غير معتاد', 'منخفضة', 'للمراقبة فقط'),
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'الثقة والدعم والتشغيل',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'واجهة تشغيلية تجريبية للفرق المصرح لها. الإشارات تساعد على المراجعة ولا تؤدي وحدها إلى حظر أو تغيير حالة دفع أو إلغاء طلب.',
      ),
      const SizedBox(height: 18),
      Card(
        color: const Color(0xFFFFF8E7),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'كل قرار حساس يحتاج سبباً واضحاً، صلاحية مناسبة، وسجلاً تدقيقياً. البيانات الظاهرة هنا توضيحية إلى أن تُربط بقوائم RPC الحقيقية.',
          ),
        ),
      ),
      const SizedBox(height: 18),
      _TrustSection(
        title: 'تذاكر الدعم',
        icon: Icons.support_agent_outlined,
        children: tickets
            .map(
              (ticket) => ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: Text('${ticket.$1} · ${ticket.$2}'),
                subtitle: Text('${ticket.$3} · ${ticket.$4}'),
                trailing: OutlinedButton(
                  onPressed: () =>
                      _showMockAction(context, 'فتح التذكرة ${ticket.$1}'),
                  child: const Text('معاينة'),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      _TrustSection(
        title: 'إشارات المخاطر',
        icon: Icons.shield_outlined,
        children: signals
            .map(
              (signal) => ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(signal.$1),
                subtitle: Text('${signal.$2} · ${signal.$3}'),
                trailing: OutlinedButton(
                  onPressed: () => _showMockAction(context, signal.$1),
                  child: const Text('مراجعة'),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      _TrustSection(
        title: 'مؤشرات جودة المتاجر',
        icon: Icons.insights_outlined,
        children: const [
          ListTile(
            title: Text('متجر تجريبي · إب'),
            subtitle: Text('إتمام 87% · متوسط تقييم 4.4 · نزاعان مفتوحان'),
            trailing: Chip(label: Text('تفسيري')),
          ),
          ListTile(
            title: Text('متجر تجريبي · إب'),
            subtitle: Text('إتمام 72% · متوسط تقييم 3.8 · يحتاج دعماً'),
            trailing: Chip(label: Text('مراقبة')),
          ),
        ],
      ),
    ],
  );

  static Future<void> _showMockAction(BuildContext context, String title) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text(
            'هذه معاينة Mock. لن يتم تعديل حالة مستخدم أو طلب أو دفع حتى تُنفذ العملية من خلال RPC مصرح بها مع سبب وسجل تدقيق.',
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

class _TrustSection extends StatelessWidget {
  const _TrustSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class CreatorMerchantGovernancePage extends StatefulWidget {
  const CreatorMerchantGovernancePage({super.key});

  @override
  State<CreatorMerchantGovernancePage> createState() =>
      _CreatorMerchantGovernancePageState();
}

class _CreatorMerchantGovernancePageState
    extends State<CreatorMerchantGovernancePage> {
  late Future<List<CreatorMerchant>> merchants;
  late Future<List<CreatorShop>> shops;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    merchants = CreatorRepository().listMerchants();
    shops = CreatorRepository().listShops();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'حوكمة التجار والمتاجر',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'راجع طلبات التجار واعتمد المتاجر أو أوقفها مع تسجيل سبب كل قرار في سجل التدقيق.',
      ),
      const SizedBox(height: 24),
      _sectionTitle('طلبات التجار', Icons.storefront),
      FutureBuilder<List<CreatorMerchant>>(
        future: merchants,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _InlineLoading();
          }
          if (snapshot.hasError) {
            return const _InlineError(message: 'تعذر تحميل طلبات التجار.');
          }
          final rows = snapshot.data ?? const <CreatorMerchant>[];
          if (rows.isEmpty) {
            return const _EmptyCard(message: 'لا توجد طلبات تجار حالياً.');
          }
          return Card(
            child: Column(children: rows.map(_merchantTile).toList()),
          );
        },
      ),
      const SizedBox(height: 28),
      _sectionTitle('اعتماد المتاجر', Icons.fact_check),
      FutureBuilder<List<CreatorShop>>(
        future: shops,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _InlineLoading();
          }
          if (snapshot.hasError) {
            return const _InlineError(message: 'تعذر تحميل المتاجر.');
          }
          final rows = snapshot.data ?? const <CreatorShop>[];
          if (rows.isEmpty) {
            return const _EmptyCard(message: 'لا توجد متاجر تحتاج إلى مراجعة.');
          }
          return Card(child: Column(children: rows.map(_shopTile).toList()));
        },
      ),
    ],
  );

  Widget _sectionTitle(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _merchantTile(CreatorMerchant merchant) => ListTile(
    leading: CircleAvatar(
      child: Text(
        merchant.ownerName.isEmpty ? '?' : merchant.ownerName.substring(0, 1),
      ),
    ),
    title: Text(
      merchant.ownerName.isEmpty ? 'تاجر بلا اسم' : merchant.ownerName,
    ),
    subtitle: Text('${merchant.phone} • ${merchant.verificationStatus}'),
    trailing: PopupMenuButton<String>(
      onSelected: (status) => _changeMerchantStatus(merchant, status),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'verified', child: Text('اعتماد التاجر')),
        PopupMenuItem(value: 'rejected', child: Text('رفض الطلب')),
        PopupMenuItem(value: 'pending', child: Text('إعادته للمراجعة')),
      ],
    ),
  );

  Widget _shopTile(CreatorShop shop) => ListTile(
    leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
    title: Text(shop.name),
    subtitle: Text(
      '${shop.slug} • ${shop.areaLabel ?? 'دون منطقة'} • ${shop.status}',
    ),
    trailing: PopupMenuButton<String>(
      onSelected: (status) => _changeShopStatus(shop, status),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'approved', child: Text('اعتماد المتجر')),
        PopupMenuItem(value: 'suspended', child: Text('تعليق المتجر')),
        PopupMenuItem(value: 'pending', child: Text('إعادته للمراجعة')),
      ],
    ),
  );

  Future<void> _changeMerchantStatus(
    CreatorMerchant merchant,
    String status,
  ) async {
    final reason = await _askReason(context, title: 'سبب قرار التاجر');
    if (reason == null || !mounted) return;
    try {
      await CreatorRepository().setMerchantVerification(
        merchantId: merchant.id,
        status: status,
        reason: reason,
      );
      setState(_reload);
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رفض Supabase قرار التاجر.')),
        );
      }
    }
  }

  Future<void> _changeShopStatus(CreatorShop shop, String status) async {
    final reason = await _askReason(context, title: 'سبب قرار المتجر');
    if (reason == null || !mounted) return;
    try {
      await CreatorRepository().setShopStatus(
        shopId: shop.id,
        status: status,
        reason: reason,
      );
      setState(_reload);
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رفض Supabase قرار المتجر.')),
        );
      }
    }
  }
}

class CreatorGlobalPolicyPage extends StatefulWidget {
  const CreatorGlobalPolicyPage({super.key});

  @override
  State<CreatorGlobalPolicyPage> createState() =>
      _CreatorGlobalPolicyPageState();
}

class _CreatorGlobalPolicyPageState extends State<CreatorGlobalPolicyPage> {
  late Future<List<CreatorMarket>> markets;
  String? selectedMarketId;

  @override
  void initState() {
    super.initState();
    markets = CreatorRepository().listMarkets();
  }

  void _reloadMarkets() =>
      setState(() => markets = CreatorRepository().listMarkets());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CreatorMarket>>(
    future: markets,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingPage();
      }
      if (snapshot.hasError) {
        return const _FailurePage(
          message: 'تعذر تحميل الأسواق والسياسات. تحقق من صلاحيات manage_markets و manage_policies.',
        );
      }
      final rows = snapshot.data ?? const <CreatorMarket>[];
      if (rows.isEmpty) {
        return const _FailurePage(message: 'لا توجد أسواق مهيأة بعد.');
      }
      final market = rows.firstWhere(
        (item) => item.id == selectedMarketId,
        orElse: () => rows.first,
      );
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'الأسواق والسياسات العامة',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'فعّل الأسواق وأدر إصدارات السياسات والقدرات الاختيارية دون تعديل السجل التاريخي.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.public),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: market.id,
                      isExpanded: true,
                      items: rows
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.governorate} / ${item.city} (${item.status})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedMarketId = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: market.status,
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(value: 'paused', child: Text('متوقف')),
                    ],
                    onChanged: (value) => value == null
                        ? null
                        : _changeMarketStatus(market, value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PolicySection(marketId: market.id, onEdit: _editPolicy),
          const SizedBox(height: 20),
          _CapabilitySection(marketId: market.id),
        ],
      );
    },
  );

  Future<void> _changeMarketStatus(CreatorMarket market, String status) async {
    final reason = await _askReason(context, title: 'سبب تغيير حالة السوق');
    if (reason == null || !mounted) return;
    try {
      await CreatorRepository().setMarketStatus(
        marketId: market.id,
        status: status,
        reason: reason,
      );
      _reloadMarkets();
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رفض Supabase تغيير حالة السوق.')),
        );
      }
    }
  }

  Future<void> _editPolicy(String marketId, CreatorPolicy? policy) async {
    final keyController = TextEditingController(text: policy?.key ?? '');
    final valueController = TextEditingController(
      text: jsonEncode(policy?.value ?? {'enabled': true}),
    );
    final reasonController = TextEditingController();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(policy == null ? 'إضافة سياسة' : 'إصدار سياسة جديد'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'مفتاح السياسة'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: valueController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'القيمة JSON'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'سبب التغيير'),
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
            onPressed: () {
              try {
                final value = jsonDecode(valueController.text);
                if (value is! Map<String, dynamic> ||
                    keyController.text.trim().isEmpty ||
                    reasonController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, {
                  'key': keyController.text.trim(),
                  'value': value,
                  'reason': reasonController.text.trim(),
                });
              } on FormatException {
                // Keep the dialog open until the creator enters valid JSON.
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    keyController.dispose();
    valueController.dispose();
    reasonController.dispose();
    if (payload == null || !mounted) return;
    try {
      await CreatorRepository().upsertPolicy(
        marketId: marketId,
        key: payload['key'] as String,
        value: Map<String, dynamic>.from(payload['value'] as Map),
        reason: payload['reason'] as String,
      );
      setState(() {});
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رفض Supabase إصدار السياسة.')),
        );
      }
    }
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.marketId, required this.onEdit});
  final String marketId;
  final Future<void> Function(String, CreatorPolicy?) onEdit;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CreatorPolicy>>(
    future: CreatorRepository().listPolicies(marketId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _InlineLoading();
      }
      if (snapshot.hasError) {
        return const _InlineError(message: 'تعذر تحميل إصدارات السياسات.');
      }
      final policies = snapshot.data ?? const <CreatorPolicy>[];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.policy_outlined),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'إصدارات السياسات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onEdit(marketId, null),
                    icon: const Icon(Icons.add),
                    tooltip: 'إضافة سياسة',
                  ),
                ],
              ),
              if (policies.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('لا توجد سياسات لهذا السوق.'),
                )
              else
                ...policies.map(
                  (policy) => ListTile(
                    title: Text(policy.key),
                    subtitle: Text(
                      'الإصدار ${policy.version} • ${policy.isActive ? 'فعال' : 'غير فعال'}\n${jsonEncode(policy.value)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      onPressed: () => onEdit(marketId, policy),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'إصدار جديد',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _CapabilitySection extends StatefulWidget {
  const _CapabilitySection({required this.marketId});
  final String marketId;
  @override
  State<_CapabilitySection> createState() => _CapabilitySectionState();
}

class _CapabilitySectionState extends State<_CapabilitySection> {
  late Future<List<CreatorCapabilityState>> capabilities = CreatorRepository()
      .listCapabilities(widget.marketId);

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<CreatorCapabilityState>>(
    future: capabilities,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _InlineLoading();
      }
      if (snapshot.hasError) {
        return const _InlineError(message: 'تعذر تحميل قدرات السوق.');
      }
      final rows = snapshot.data ?? const <CreatorCapabilityState>[];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.toggle_on_outlined),
                  SizedBox(width: 8),
                  Text(
                    'القدرات الاختيارية',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Text('لا توجد قدرات مهيأة.')
              else
                ...rows.map(
                  (capability) => SwitchListTile(
                    title: Text(capability.key),
                    subtitle: Text(
                      capability.reasonAr ??
                          'الحالة الافتراضية: ${capability.defaultEnabled ? 'مفعلة' : 'متوقفة'}',
                    ),
                    value: capability.enabled,
                    onChanged: (enabled) => _toggle(capability, enabled),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _toggle(CreatorCapabilityState capability, bool enabled) async {
    final reason = await _askReason(context, title: 'سبب تغيير القدرة');
    if (reason == null || !mounted) return;
    try {
      await CreatorRepository().setMarketCapability(
        marketId: widget.marketId,
        capabilityId: capability.id,
        enabled: enabled,
        reason: reason,
      );
      setState(
        () => capabilities = CreatorRepository().listCapabilities(
          widget.marketId,
        ),
      );
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رفض Supabase تغيير القدرة.')),
        );
      }
    }
  }
}

Future<String?> _askReason(
  BuildContext context, {
  required String title,
}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'السبب مطلوب'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
  controller.dispose();
  return reason == null || reason.length < 3 ? null : reason;
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
  );
}
