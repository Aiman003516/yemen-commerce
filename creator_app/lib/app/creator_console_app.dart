import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:commerce_core/commerce_core.dart';
import 'package:commerce_data/commerce_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const creatorErpAuthoringSafetyMessage =
    'لا يتم تحديد الدفع أو حيازة أموال عبر هذه الشاشة.';
const creatorErpComposableSafetyMessage =
    'الامتدادات تحفظ metadata فقط ولا تشغّل WASM أو شبكة أو كتابة مباشرة.';

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
      const CreatorAiOperationsPage(),
      const CreatorErpOperationsPage(),
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
      NavigationRailDestination(
        icon: Icon(Icons.smart_toy_outlined),
        selectedIcon: Icon(Icons.smart_toy),
        label: Text('حوكمة الذكاء'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_outlined),
        selectedIcon: Icon(Icons.account_balance),
        label: Text('ERP'),
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
      NavigationDestination(
        icon: Icon(Icons.smart_toy_outlined),
        label: 'حوكمة الذكاء',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_outlined),
        label: 'ERP',
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

class CreatorAiOperationsPage extends StatefulWidget {
  const CreatorAiOperationsPage({super.key});

  @override
  State<CreatorAiOperationsPage> createState() =>
      _CreatorAiOperationsPageState();
}

class _CreatorAiOperationsPageState extends State<CreatorAiOperationsPage> {
  final _repository = CreatorRepository();
  late Future<List<dynamic>> _load;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future.wait<dynamic>([
      _repository.aiPlatformSettings(),
      _repository.aiActionDefinitions(),
      _repository.aiWorkflows(),
      _repository.aiEvaluationSummary(),
    ]);
  }

  Future<String?> _reasonDialog(String title) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'سبب التغيير',
            hintText: 'اكتب سبباً واضحاً للمراجعة والتدقيق',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 3) Navigator.pop(context, value);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _publish(
    Map<String, dynamic> current,
    String field,
    bool value,
  ) async {
    if (_saving) return;
    final reason = await _reasonDialog('تأكيد تغيير إعداد الذكاء الاصطناعي');
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      await _repository.publishAiPlatformSettings(
        model: current['model']?.toString(),
        providerEnabled: field == 'provider_enabled'
            ? value
            : current['provider_enabled'] == true,
        backgroundEnabled: field == 'background_enabled'
            ? value
            : current['background_enabled'] == true,
        knowledgeEnabled: field == 'knowledge_enabled'
            ? value
            : current['knowledge_enabled'] == true,
        externalAgentEnabled: field == 'external_agent_enabled'
            ? value
            : current['external_agent_enabled'] == true,
        maxToolCalls: (current['max_tool_calls'] as num?)?.toInt() ?? 8,
        maxWorkflowAttempts:
            (current['max_workflow_attempts'] as num?)?.toInt() ?? 3,
        reason: reason,
      );
      if (mounted) setState(() => _reload());
    } catch (_) {
      if (mounted) _showMessage('تعذر نشر الإعداد. لم يتغير أي مسار تشغيل.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAction(Map<String, dynamic> action, bool value) async {
    if (_saving) return;
    final reason = await _reasonDialog('تأكيد تغيير إتاحة الإجراء');
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      await _repository.setAiActionEnabled(
        actionKey: action['action_key'].toString(),
        enabled: value,
        reason: reason,
      );
      if (mounted) setState(() => _reload());
    } catch (_) {
      if (mounted) _showMessage('تعذر تغيير إتاحة الإجراء.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createKnowledgeSource() async {
    final scopeType = ValueNotifier<String>('global');
    final sourceKind = ValueNotifier<String>('guide');
    final status = ValueNotifier<String>('draft');
    final trustClass = ValueNotifier<String>('internal');
    final scopeId = TextEditingController();
    final sourceKey = TextEditingController();
    final title = TextEditingController();
    final sourceUri = TextEditingController();
    final sourceVersion = TextEditingController(text: '1');
    final contentHash = TextEditingController();
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مصدر معرفة مُدار'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: scopeType,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'النطاق'),
                  items: const [
                    DropdownMenuItem(
                      value: 'global',
                      child: Text('عام للمنصة'),
                    ),
                    DropdownMenuItem(value: 'market', child: Text('سوق محدد')),
                    DropdownMenuItem(value: 'shop', child: Text('متجر محدد')),
                  ],
                  onChanged: (next) => scopeType.value = next ?? 'global',
                ),
              ),
              TextField(
                controller: scopeId,
                decoration: const InputDecoration(
                  labelText: 'معرّف السوق/المتجر عند الحاجة',
                ),
              ),
              TextField(
                controller: sourceKey,
                decoration: const InputDecoration(labelText: 'مفتاح المصدر'),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'عنوان المصدر'),
              ),
              TextField(
                controller: sourceUri,
                decoration: const InputDecoration(
                  labelText: 'رابط مرجعي اختياري — لا يتم جلبه تلقائياً',
                ),
              ),
              TextField(
                controller: sourceVersion,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الإصدار'),
              ),
              TextField(
                controller: contentHash,
                decoration: const InputDecoration(
                  labelText: 'بصمة المحتوى SHA-256',
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: sourceKind,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'نوع المصدر'),
                  items: const [
                    DropdownMenuItem(value: 'policy', child: Text('سياسة')),
                    DropdownMenuItem(value: 'catalog', child: Text('كتالوج')),
                    DropdownMenuItem(value: 'faq', child: Text('أسئلة شائعة')),
                    DropdownMenuItem(value: 'guide', child: Text('دليل')),
                    DropdownMenuItem(value: 'support', child: Text('دعم')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (next) => sourceKind.value = next ?? 'guide',
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(
                      value: 'ready',
                      child: Text('جاهز للاسترجاع'),
                    ),
                    DropdownMenuItem(value: 'archived', child: Text('مؤرشف')),
                  ],
                  onChanged: (next) => status.value = next ?? 'draft',
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: trustClass,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'درجة الثقة'),
                  items: const [
                    DropdownMenuItem(value: 'internal', child: Text('داخلي')),
                    DropdownMenuItem(
                      value: 'merchant_provided',
                      child: Text('مقدم من تاجر'),
                    ),
                    DropdownMenuItem(
                      value: 'external_unverified',
                      child: Text('خارجي غير موثق'),
                    ),
                  ],
                  onChanged: (next) => trustClass.value = next ?? 'internal',
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
            onPressed: () {
              final version = int.tryParse(sourceVersion.text.trim());
              if (sourceKey.text.trim().length >= 2 &&
                  title.text.trim().length >= 2 &&
                  (version ?? 0) > 0 &&
                  contentHash.text.trim().length >= 16 &&
                  (scopeType.value == 'global' ||
                      scopeId.text.trim().isNotEmpty)) {
                Navigator.pop(dialogContext, {
                  'scope_type': scopeType.value,
                  'scope_id': scopeId.text.trim().isEmpty
                      ? null
                      : scopeId.text.trim(),
                  'source_key': sourceKey.text.trim(),
                  'title': title.text.trim(),
                  'source_uri': sourceUri.text.trim().isEmpty
                      ? null
                      : sourceUri.text.trim(),
                  'source_version': version,
                  'content_hash': contentHash.text.trim(),
                  'source_kind': sourceKind.value,
                  'status': status.value,
                  'trust_class': trustClass.value,
                });
              }
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    scopeType.dispose();
    sourceKind.dispose();
    status.dispose();
    trustClass.dispose();
    scopeId.dispose();
    sourceKey.dispose();
    title.dispose();
    sourceUri.dispose();
    sourceVersion.dispose();
    contentHash.dispose();
    if (values == null || !mounted) return;
    final reason = await _reasonDialog('تأكيد إضافة مصدر المعرفة');
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      await _repository.aiUpsertKnowledgeSource(
        scopeType: values['scope_type'] as String,
        scopeId: values['scope_id'] as String?,
        sourceKey: values['source_key'] as String,
        title: values['title'] as String,
        sourceKind: values['source_kind'] as String,
        sourceUri: values['source_uri'] as String?,
        sourceVersion: values['source_version'] as int,
        status: values['status'] as String,
        trustClass: values['trust_class'] as String,
        contentHash: values['content_hash'] as String,
        reason: reason,
      );
      if (mounted) {
        _showMessage('تم حفظ المصدر. أضف أجزاءً منفصلة قبل تفعيل الاسترجاع.');
        setState(() => _reload());
      }
    } catch (_) {
      if (mounted) _showMessage('تعذر حفظ مصدر المعرفة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addKnowledgeChunk() async {
    final sourceId = TextEditingController();
    final ordinal = TextEditingController(text: '0');
    final content = TextEditingController();
    final contentHash = TextEditingController();
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة جزء معرفة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sourceId,
                decoration: const InputDecoration(labelText: 'معرّف المصدر'),
              ),
              TextField(
                controller: ordinal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الترتيب'),
              ),
              TextField(
                controller: content,
                minLines: 4,
                maxLines: 8,
                maxLength: 8000,
                decoration: const InputDecoration(
                  labelText: 'المحتوى العربي أو المختلط',
                ),
              ),
              TextField(
                controller: contentHash,
                decoration: const InputDecoration(
                  labelText: 'بصمة الجزء SHA-256',
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
            onPressed: () {
              final index = int.tryParse(ordinal.text.trim());
              if (sourceId.text.trim().isNotEmpty &&
                  (index ?? -1) >= 0 &&
                  content.text.trim().isNotEmpty &&
                  contentHash.text.trim().length >= 16) {
                Navigator.pop(dialogContext, {
                  'source_id': sourceId.text.trim(),
                  'ordinal': index,
                  'content': content.text.trim(),
                  'content_hash': contentHash.text.trim(),
                });
              }
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    sourceId.dispose();
    ordinal.dispose();
    content.dispose();
    contentHash.dispose();
    if (values == null || !mounted) return;
    final reason = await _reasonDialog('تأكيد إضافة جزء المعرفة');
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      await _repository.aiAddKnowledgeChunk(
        sourceId: values['source_id'] as String,
        ordinal: values['ordinal'] as int,
        content: values['content'] as String,
        contentHash: values['content_hash'] as String,
        reason: reason,
      );
      if (mounted) _showMessage('تم حفظ جزء المعرفة مع سجل التدقيق.');
    } catch (_) {
      if (mounted) _showMessage('تعذر حفظ جزء المعرفة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createTerminologyEntry() async {
    final scopeType = ValueNotifier<String>('global');
    final status = ValueNotifier<String>('draft');
    final scopeId = TextEditingController();
    final termKey = TextEditingController();
    final termArabic = TextEditingController();
    final canonicalTerm = TextEditingController();
    final aliases = TextEditingController();
    final definition = TextEditingController();
    final sourceId = TextEditingController();
    final contentHash = TextEditingController();
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مصطلح عربي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: scopeType,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'النطاق'),
                  items: const [
                    DropdownMenuItem(
                      value: 'global',
                      child: Text('عام للمنصة'),
                    ),
                    DropdownMenuItem(value: 'market', child: Text('سوق محدد')),
                    DropdownMenuItem(value: 'shop', child: Text('متجر محدد')),
                  ],
                  onChanged: (next) => scopeType.value = next ?? 'global',
                ),
              ),
              TextField(
                controller: scopeId,
                decoration: const InputDecoration(
                  labelText: 'معرّف السوق/المتجر عند الحاجة',
                ),
              ),
              TextField(
                controller: termKey,
                decoration: const InputDecoration(labelText: 'مفتاح المصطلح'),
              ),
              TextField(
                controller: termArabic,
                decoration: const InputDecoration(labelText: 'المصطلح العربي'),
              ),
              TextField(
                controller: canonicalTerm,
                decoration: const InputDecoration(labelText: 'المصطلح القياسي'),
              ),
              TextField(
                controller: aliases,
                decoration: const InputDecoration(
                  labelText: 'مرادفات مفصولة بفواصل',
                ),
              ),
              TextField(
                controller: definition,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'تعريف أو ملاحظة تشغيلية',
                ),
              ),
              TextField(
                controller: sourceId,
                decoration: const InputDecoration(
                  labelText: 'معرّف مصدر المعرفة الاختياري',
                ),
              ),
              TextField(
                controller: contentHash,
                decoration: const InputDecoration(
                  labelText: 'بصمة المحتوى SHA-256',
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(
                      value: 'ready',
                      child: Text('جاهز للاسترجاع'),
                    ),
                    DropdownMenuItem(value: 'archived', child: Text('مؤرشف')),
                  ],
                  onChanged: (next) => status.value = next ?? 'draft',
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
            onPressed: () {
              if (termKey.text.trim().length >= 2 &&
                  termArabic.text.trim().isNotEmpty &&
                  canonicalTerm.text.trim().isNotEmpty &&
                  contentHash.text.trim().length >= 16 &&
                  (scopeType.value == 'global' ||
                      scopeId.text.trim().isNotEmpty)) {
                Navigator.pop(dialogContext, {
                  'scope_type': scopeType.value,
                  'scope_id': scopeId.text.trim().isEmpty
                      ? null
                      : scopeId.text.trim(),
                  'term_key': termKey.text.trim(),
                  'term_ar': termArabic.text.trim(),
                  'canonical_term': canonicalTerm.text.trim(),
                  'aliases': aliases.text
                      .split(',')
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList(growable: false),
                  'definition': definition.text.trim(),
                  'source_id': sourceId.text.trim().isEmpty
                      ? null
                      : sourceId.text.trim(),
                  'content_hash': contentHash.text.trim(),
                  'status': status.value,
                });
              }
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    scopeType.dispose();
    status.dispose();
    scopeId.dispose();
    termKey.dispose();
    termArabic.dispose();
    canonicalTerm.dispose();
    aliases.dispose();
    definition.dispose();
    sourceId.dispose();
    contentHash.dispose();
    if (values == null || !mounted) return;
    final reason = await _reasonDialog('تأكيد حفظ المصطلح العربي');
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      await _repository.aiUpsertTerminologyEntry(
        scopeType: values['scope_type'] as String,
        scopeId: values['scope_id'] as String?,
        termKey: values['term_key'] as String,
        termArabic: values['term_ar'] as String,
        canonicalTerm: values['canonical_term'] as String,
        aliases: (values['aliases'] as List<dynamic>).cast<String>(),
        definition: values['definition'] as String,
        sourceId: values['source_id'] as String?,
        status: values['status'] as String,
        contentHash: values['content_hash'] as String,
        reason: reason,
      );
      if (mounted) _showMessage('تم حفظ المصطلح مع سجل التدقيق.');
    } catch (_) {
      if (mounted) _showMessage('تعذر حفظ المصطلح العربي.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createEvaluationSuite() async {
    final suiteKey = TextEditingController();
    final version = TextEditingController(text: '1');
    final name = TextEditingController();
    final description = TextEditingController();
    final locale = ValueNotifier<String>('ar');
    final status = ValueNotifier<String>('draft');
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مجموعة تقييم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: suiteKey,
                decoration: const InputDecoration(labelText: 'مفتاح المجموعة'),
              ),
              TextField(
                controller: version,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الإصدار'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              ValueListenableBuilder<String>(
                valueListenable: locale,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'اللغة'),
                  items: const [
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    DropdownMenuItem(value: 'en', child: Text('الإنجليزية')),
                    DropdownMenuItem(value: 'mixed', child: Text('مختلطة')),
                  ],
                  onChanged: (next) => locale.value = next ?? 'ar',
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, value, _) => DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                    DropdownMenuItem(value: 'active', child: Text('نشطة')),
                    DropdownMenuItem(value: 'retired', child: Text('متقاعدة')),
                  ],
                  onChanged: (next) => status.value = next ?? 'draft',
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
            onPressed: () {
              final parsed = int.tryParse(version.text.trim());
              if (suiteKey.text.trim().length >= 2 &&
                  name.text.trim().length >= 2 &&
                  (parsed ?? 0) > 0) {
                Navigator.pop(dialogContext, {
                  'suite_key': suiteKey.text.trim(),
                  'version': parsed,
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'locale': locale.value,
                  'status': status.value,
                });
              }
            },
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    suiteKey.dispose();
    version.dispose();
    name.dispose();
    description.dispose();
    locale.dispose();
    status.dispose();
    if (values == null || !mounted) return;
    final reason = await _reasonDialog('تأكيد حفظ مجموعة التقييم');
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      await _repository.aiUpsertEvaluationSuite(
        suiteKey: values['suite_key'] as String,
        version: values['version'] as int,
        name: values['name'] as String,
        description: values['description'] as String,
        locale: values['locale'] as String,
        status: values['status'] as String,
        reason: reason,
      );
      if (mounted) {
        _showMessage('تم حفظ مجموعة التقييم.');
        setState(() => _reload());
      }
    } catch (_) {
      if (mounted) _showMessage('تعذر حفظ مجموعة التقييم.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingPage();
      }
      if (snapshot.hasError || snapshot.data == null) {
        return const _FailurePage(
          message: 'تعذر تحميل حوكمة الذكاء الاصطناعي.',
        );
      }
      final settings = Map<String, dynamic>.from(snapshot.data![0] as Map);
      final actions = (snapshot.data![1] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final workflows = (snapshot.data![2] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final evaluations = (snapshot.data![3] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'حوكمة الذكاء الاصطناعي',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'إعدادات المالك والإجراءات لا تتجاوز سياسات Supabase. كل تغيير يحتاج سبباً واضحاً ويسجل في سجل التدقيق.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإعدادات العامة — الإصدار ${settings['version'] ?? '-'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'مفاتيح مزود الذكاء الاصطناعي لا تظهر هنا ولا تحفظ في التطبيق. التفعيل وحده لا يثبت جاهزية المزود.',
                  ),
                  SwitchListTile(
                    title: const Text('تشغيل المزود'),
                    value: settings['provider_enabled'] == true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _publish(settings, 'provider_enabled', value),
                  ),
                  SwitchListTile(
                    title: const Text('تشغيل المعرفة المُدارة'),
                    value: settings['knowledge_enabled'] == true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _publish(settings, 'knowledge_enabled', value),
                  ),
                  SwitchListTile(
                    title: const Text('تشغيل سير العمل الخلفي'),
                    value: settings['background_enabled'] == true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _publish(settings, 'background_enabled', value),
                  ),
                  SwitchListTile(
                    title: const Text('الوصول الخارجي المتوافق مع MCP'),
                    value: settings['external_agent_enabled'] == true,
                    onChanged: _saving
                        ? null
                        : (value) => _publish(
                            settings,
                            'external_agent_enabled',
                            value,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إجراءات التاجر',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'الإجراءات قابلة للمراجعة فقط، وتظل الموافقة والتنفيذ منفصلين وبمعاملات RPC موجودة.',
                  ),
                  ...actions.map(
                    (action) => SwitchListTile(
                      title: Text(action['action_key']?.toString() ?? 'إجراء'),
                      subtitle: Text(action['description']?.toString() ?? ''),
                      value: action['enabled'] == true,
                      onChanged: _saving
                          ? null
                          : (value) => _toggleAction(action, value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'المعرفة المُدارة',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _createKnowledgeSource,
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('إضافة مصدر'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _addKnowledgeChunk,
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('إضافة جزء'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _createTerminologyEntry,
                        icon: const Icon(Icons.translate_outlined),
                        label: const Text('إضافة مصطلح'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'الإدخال مقسم ومُدار من المالك. الروابط تحفظ كمرجع فقط ولا يتم جلبها تلقائياً، ولا يصبح المصدر أو المصطلح قابلاً للاسترجاع إلا بعد اعتماد الحالة. المصطلحات تحفظ المعنى العربي والمرادفات وبصمة المصدر.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'مجموعات التقييم',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _createEvaluationSuite,
                        icon: const Icon(Icons.add_chart_outlined),
                        label: const Text('إضافة مجموعة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (evaluations.isEmpty)
                    const Text('لا توجد مجموعات تقييم بعد.'),
                  ...evaluations
                      .take(20)
                      .map(
                        (evaluation) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.assessment_outlined),
                          title: Text(
                            '${evaluation['suite_key'] ?? 'مجموعة'} · الإصدار ${evaluation['version'] ?? '-'}',
                          ),
                          subtitle: Text(
                            'الحالة: ${evaluation['status'] ?? '-'} · التشغيلات: ${evaluation['run_count'] ?? 0} · آخر حالة: ${evaluation['latest_run_status'] ?? '-'} · متوسط آخر نتيجة: ${evaluation['latest_average_score'] ?? '-'}',
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سير العمل الأخيرة',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (workflows.isEmpty)
                    const Text('لا توجد عمليات خلفية مسجلة.'),
                  ...workflows
                      .take(20)
                      .map(
                        (workflow) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.sync_alt),
                          title: Text(
                            workflow['workflow_key']?.toString() ?? 'سير عمل',
                          ),
                          subtitle: Text(
                            '${workflow['status'] ?? '-'} — المحاولات ${workflow['attempts'] ?? 0}/${workflow['max_attempts'] ?? 0}',
                          ),
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

class CreatorErpOperationsPage extends StatefulWidget {
  const CreatorErpOperationsPage({super.key});

  @override
  State<CreatorErpOperationsPage> createState() =>
      _CreatorErpOperationsPageState();
}

class _CreatorErpOperationsPageState extends State<CreatorErpOperationsPage> {
  final repository = CreatorRepository();
  late Future<List<Map<String, dynamic>>> features;
  late Future<List<Map<String, dynamic>>> composableModules;
  final organizationController = TextEditingController();
  Future<Map<String, dynamic>?>? dashboard;
  Future<Map<String, dynamic>?>? eventMesh;

  @override
  void initState() {
    super.initState();
    features = repository.erpFeatureRegistry();
    composableModules = repository.erpComposableModules();
  }

  @override
  void dispose() {
    organizationController.dispose();
    super.dispose();
  }

  void loadDashboard() {
    final organizationId = organizationController.text.trim();
    if (organizationId.isEmpty) return;
    setState(() {
      dashboard = repository.erpOrganizationDashboard(organizationId);
      eventMesh = repository.erpEventMeshDashboard(organizationId);
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: features,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingPage();
      }
      if (snapshot.hasError) {
        return const _FailurePage(
          message: 'تعذر تحميل سجل وحدات ERP. تحقق من صلاحية حساب المنشئ.',
        );
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      final enabledCount = rows.where((row) => row['enabled'] == true).length;
      final providerCount = rows
          .where((row) => row['provider_required'] == true)
          .length;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'مركز ERP المؤسسي',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'هذه الصفحة تعرض الوحدات المؤسسية ومراحل جاهزيتها. التفعيل لا ينشئ صلاحية مالية ولا يسمح بحيازة أموال التجار. كل الترحيلات والكتابات المحاسبية تمر عبر Supabase وRPCs المدققة.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ErpMetric(label: 'الوحدات المسجلة', value: '${rows.length}'),
              _ErpMetric(label: 'المفعّل حالياً', value: '$enabledCount'),
              _ErpMetric(label: 'يحتاج مزوداً', value: '$providerCount'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لوحة منظمة اختيارية',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أدخل UUID منظمة تملكها للوصول إلى مؤشرات bounded فقط. لا تعرض اللوحة هويات العملاء أو أدلة الدفع.',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: organizationController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'معرّف المنظمة',
                      hintText: 'UUID',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      onPressed: loadDashboard,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('تحميل المؤشرات'),
                    ),
                  ),
                  if (dashboard != null)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: dashboard,
                      builder: (context, result) {
                        if (result.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (result.hasError || result.data == null) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'لا توجد منظمة مرئية بهذا المعرّف أو لا تملك الصلاحية.',
                            ),
                          );
                        }
                        final item = result.data!;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Text('المنظمة: ${item['name_ar'] ?? '-'}'),
                              Text(
                                'الكيانات: ${item['legal_entity_count'] ?? 0}',
                              ),
                              Text(
                                'الدفاتر النشطة: ${item['active_book_count'] ?? 0}',
                              ),
                              Text(
                                'قيود مسودة: ${item['draft_journal_count'] ?? 0}',
                              ),
                              Text(
                                'فواتير مفتوحة: ${item['open_bill_count'] ?? 0}',
                              ),
                              Text(
                                'أحداث معلقة: ${item['open_event_count'] ?? 0}',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ErpAuthoringPanel(
            repository: repository,
            onChanged: () {
              setState(() {
                features = repository.erpFeatureRegistry();
                composableModules = repository.erpComposableModules();
                if (organizationController.text.trim().isNotEmpty) {
                  dashboard = repository.erpOrganizationDashboard(
                    organizationController.text.trim(),
                  );
                  eventMesh = repository.erpEventMeshDashboard(
                    organizationController.text.trim(),
                  );
                }
              });
            },
          ),
          const SizedBox(height: 16),
          _ComposableErpPanel(
            repository: repository,
            modules: composableModules,
            eventMesh: eventMesh,
            organizationId: organizationController.text.trim(),
            onChanged: () {
              setState(() {
                composableModules = repository.erpComposableModules();
                if (organizationController.text.trim().isNotEmpty) {
                  eventMesh = repository.erpEventMeshDashboard(
                    organizationController.text.trim(),
                  );
                }
              });
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خريطة القدرات المؤسسية',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...rows.map(
                    (row) => ListTile(
                      dense: true,
                      leading: Icon(
                        row['provider_required'] == true
                            ? Icons.extension_outlined
                            : Icons.checklist_outlined,
                      ),
                      title: Text(
                        '${row['name_ar'] ?? row['feature_key']} · ${row['name_en'] ?? ''}',
                      ),
                      subtitle: Text(
                        '${row['module_key'] ?? '-'} · ${row['implementation_status'] ?? '-'} · ${row['description'] ?? ''}',
                      ),
                      trailing: Chip(
                        label: Text(row['enabled'] == true ? 'مفعّل' : 'معطّل'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'حالة المزودات: OCR والضرائب وكشوف الحساب والرسائل والتوقيع وتحسين المسارات ممثلة بعقود آمنة لكنها معطلة افتراضياً. تفعيل أي مزود يتطلب مراجعة المالك، إعداد أسرار على الخادم فقط، فحص الخصوصية والامتثال، واختبارات معزولة.',
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ErpAuthoringPanel extends StatefulWidget {
  const _ErpAuthoringPanel({required this.repository, required this.onChanged});

  final CreatorRepository repository;
  final VoidCallback onChanged;

  @override
  State<_ErpAuthoringPanel> createState() => _ErpAuthoringPanelState();
}

class _ErpAuthoringPanelState extends State<_ErpAuthoringPanel> {
  bool busy = false;

  String _label(String field) => switch (field) {
    'marketId' => 'معرّف السوق (UUID)',
    'organizationId' => 'معرّف المنظمة (UUID)',
    'legalEntityId' => 'معرّف الكيان القانوني (UUID)',
    'bookId' => 'معرّف الدفتر (UUID)',
    'debitAccountId' => 'حساب المدين (UUID)',
    'creditAccountId' => 'حساب الدائن (UUID)',
    'parentAccountId' => 'الحساب الأب (اختياري، UUID)',
    'merchantId' => 'معرّف التاجر (اختياري، UUID)',
    'code' => 'الرمز',
    'nameAr' => 'الاسم بالعربية',
    'legalName' => 'الاسم القانوني (اختياري)',
    'registrationReference' => 'مرجع التسجيل (اختياري)',
    'taxReference' => 'المرجع الضريبي (اختياري)',
    'basis' => 'أساس المحاسبة (مثل management)',
    'currency' => 'العملة (مثل YER)',
    'type' => 'نوع الحساب (مثل asset)',
    'balance' => 'الرصيد الطبيعي (debit أو credit)',
    'amountMinor' => 'المبلغ بوحدات العملة الصغرى',
    'descriptionAr' => 'وصف القيد بالعربية (اختياري)',
    'reason' => 'سبب العملية (مطلوب)',
    _ => field,
  };

  Future<Map<String, String>?> _formDialog({
    required String title,
    required List<String> fields,
    required Map<String, String> initial,
  }) async {
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field: TextEditingController(text: initial[field] ?? ''),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[field],
                      textDirection:
                          field.contains('id') ||
                              field.contains('code') ||
                              field == 'currency' ||
                              field == 'type' ||
                              field == 'balance' ||
                              field == 'basis'
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      minLines: field == 'reason' ? 2 : 1,
                      maxLines: field == 'reason' ? 4 : 1,
                      decoration: InputDecoration(labelText: _label(field)),
                    ),
                  ),
                ),
                const Text(
                  'كل كتابة تمر عبر RPC مصرح بها وتُسجل في سجل التدقيق. اترك المزودات الخارجية معطلة.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final values = <String, String>{
                for (final field in fields)
                  field: controllers[field]!.text.trim(),
              };
              if (fields.any(
                (field) => field == 'reason' && values[field]!.length < 3,
              )) {
                return;
              }
              Navigator.pop(dialogContext, values);
            },
            child: const Text('حفظ عبر Supabase'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) {
        widget.onChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ العملية وتسجيلها.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('رفض Supabase العملية: ${error.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تنفيذ العملية. تحقق من المعرفات والصلاحية.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _createOrganization() async {
    final values = await _formDialog(
      title: 'إنشاء منظمة ERP',
      fields: const [
        'marketId',
        'code',
        'nameAr',
        'legalName',
        'merchantId',
        'reason',
      ],
      initial: const {},
    );
    if (values == null) return;
    if (values['marketId']!.isEmpty ||
        values['code']!.length < 2 ||
        values['nameAr']!.length < 2) {
      return;
    }
    await _run(() async {
      await widget.repository.erpCreateOrganization(
        marketId: values['marketId']!,
        code: values['code']!,
        nameAr: values['nameAr']!,
        legalName: values['legalName'],
        merchantId: values['merchantId'],
        reason: values['reason']!,
      );
    });
  }

  Future<void> _createLegalEntity() async {
    final values = await _formDialog(
      title: 'إضافة كيان قانوني',
      fields: const [
        'organizationId',
        'code',
        'nameAr',
        'registrationReference',
        'taxReference',
        'reason',
      ],
      initial: const {},
    );
    if (values == null ||
        values['organizationId']!.isEmpty ||
        values['code']!.length < 2 ||
        values['nameAr']!.length < 2) {
      return;
    }
    await _run(() async {
      await widget.repository.erpCreateLegalEntity(
        organizationId: values['organizationId']!,
        code: values['code']!,
        nameAr: values['nameAr']!,
        registrationReference: values['registrationReference'],
        taxReference: values['taxReference'],
        reason: values['reason']!,
      );
    });
  }

  Future<void> _createBook() async {
    final values = await _formDialog(
      title: 'إضافة دفتر محاسبي',
      fields: const [
        'legalEntityId',
        'code',
        'nameAr',
        'basis',
        'currency',
        'reason',
      ],
      initial: const {'basis': 'management', 'currency': 'YER'},
    );
    if (values == null ||
        values['legalEntityId']!.isEmpty ||
        values['code']!.length < 2 ||
        values['nameAr']!.length < 2) {
      return;
    }
    await _run(() async {
      await widget.repository.erpCreateBook(
        legalEntityId: values['legalEntityId']!,
        code: values['code']!,
        nameAr: values['nameAr']!,
        accountingBasis: values['basis']!,
        currency: values['currency']!.isEmpty ? 'YER' : values['currency']!,
        reason: values['reason']!,
      );
    });
  }

  Future<void> _createAccount() async {
    final values = await _formDialog(
      title: 'إضافة حساب إلى الدليل',
      fields: const [
        'bookId',
        'parentAccountId',
        'code',
        'nameAr',
        'type',
        'balance',
        'reason',
      ],
      initial: const {'type': 'asset', 'balance': 'debit'},
    );
    if (values == null ||
        values['bookId']!.isEmpty ||
        values['code']!.length < 2 ||
        values['nameAr']!.length < 2) {
      return;
    }
    await _run(() async {
      await widget.repository.erpCreateAccount(
        bookId: values['bookId']!,
        parentAccountId: values['parentAccountId']!.isEmpty
            ? null
            : values['parentAccountId'],
        code: values['code']!,
        nameAr: values['nameAr']!,
        accountType: values['type']!,
        normalBalance: values['balance']!,
        reason: values['reason']!,
      );
    });
  }

  Future<void> _draftAndPostJournal() async {
    final values = await _formDialog(
      title: 'مسودة قيد متوازن من سطرين',
      fields: const [
        'organizationId',
        'bookId',
        'debitAccountId',
        'creditAccountId',
        'amountMinor',
        'descriptionAr',
        'reason',
      ],
      initial: const {},
    );
    if (values == null ||
        values['organizationId']!.isEmpty ||
        values['bookId']!.isEmpty ||
        values['debitAccountId']!.isEmpty ||
        values['creditAccountId']!.isEmpty ||
        int.tryParse(values['amountMinor']!) == null ||
        int.parse(values['amountMinor']!) <= 0) {
      return;
    }
    String? batchId;
    await _run(() async {
      final batch = await widget.repository.erpCreateJournalBatch(
        organizationId: values['organizationId']!,
        bookId: values['bookId']!,
        sourceType: 'creator_console',
        idempotencyKey:
            'creator-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        descriptionAr: values['descriptionAr'],
        reason: values['reason']!,
      );
      batchId = batch['journal_batch_id']?.toString();
      if (batchId == null || batchId!.isEmpty) {
        throw StateError('missing batch id');
      }
      final amount = int.parse(values['amountMinor']!);
      await widget.repository.erpAddJournalLine(
        batchId: batchId!,
        accountId: values['debitAccountId']!,
        lineNumber: 1,
        debitMinor: amount,
        creditMinor: 0,
        descriptionAr: values['descriptionAr'],
      );
      await widget.repository.erpAddJournalLine(
        batchId: batchId!,
        accountId: values['creditAccountId']!,
        lineNumber: 2,
        debitMinor: 0,
        creditMinor: amount,
        descriptionAr: values['descriptionAr'],
      );
    });
    if (batchId == null || !mounted) return;
    final postReason = await _askReason(
      context,
      title: 'سبب ترحيل القيد بعد مراجعة السطرين',
    );
    if (postReason == null || !mounted) return;
    await _run(() async {
      await widget.repository.erpPostJournalBatch(
        batchId: batchId!,
        reason: postReason,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تأليف ERP الآمن',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'واجهة أولية للمنشئ: إنشاء الهيكل المحاسبي ثم إنشاء قيد مسودة متوازن ومراجعته قبل الترحيل. كل نموذج يتطلب سبباً لا يقل عن ثلاثة أحرف؛ $creatorErpAuthoringSafetyMessage',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : _createOrganization,
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('منظمة'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _createLegalEntity,
                icon: const Icon(Icons.domain_outlined),
                label: const Text('كيان قانوني'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _createBook,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('دفتر'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : _createAccount,
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('حساب'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : _draftAndPostJournal,
                icon: const Icon(Icons.post_add_outlined),
                label: const Text('قيد من سطرين ثم ترحيل'),
              ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    ),
  );
}

class _ComposableErpPanel extends StatefulWidget {
  const _ComposableErpPanel({
    required this.repository,
    required this.modules,
    required this.eventMesh,
    required this.organizationId,
    required this.onChanged,
  });

  final CreatorRepository repository;
  final Future<List<Map<String, dynamic>>> modules;
  final Future<Map<String, dynamic>?>? eventMesh;
  final String organizationId;
  final VoidCallback onChanged;

  @override
  State<_ComposableErpPanel> createState() => _ComposableErpPanelState();
}

class _ComposableErpPanelState extends State<_ComposableErpPanel> {
  bool busy = false;

  Future<Map<String, String>?> _manifestDialog() async {
    final controllers = <String, TextEditingController>{
      for (final field in const ['extensionKey', 'nameAr', 'version', 'reason'])
        field: TextEditingController(),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة امتداد قابل للمراجعة'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in controllers.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[field],
                      textDirection:
                          field == 'extensionKey' || field == 'version'
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                      minLines: field == 'reason' ? 2 : 1,
                      maxLines: field == 'reason' ? 4 : 1,
                      decoration: InputDecoration(
                        labelText: switch (field) {
                          'extensionKey' => 'مفتاح الامتداد (LTR)',
                          'nameAr' => 'اسم الامتداد بالعربية',
                          'version' => 'الإصدار (LTR)',
                          _ => 'سبب المراجعة (مطلوب)',
                        },
                      ),
                    ),
                  ),
                const Text(
                  'يتم تسجيل الوصف فقط. لا يتم تشغيل WASM أو تحميل كود خارجي، ولا توجد صلاحية شبكة أو قاعدة بيانات للامتداد.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final values = <String, String>{
                for (final entry in controllers.entries)
                  entry.key: entry.value.text.trim(),
              };
              if (values.values.any((value) => value.length < 3)) return;
              Navigator.pop(dialogContext, values);
            },
            child: const Text('إرسال للمراجعة'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _saveManifest() async {
    if (busy) return;
    final values = await _manifestDialog();
    if (values == null) return;
    setState(() => busy = true);
    try {
      await widget.repository.erpSaveExtensionManifest(
        organizationId: widget.organizationId.isEmpty
            ? null
            : widget.organizationId,
        extensionKey: values['extensionKey']!,
        nameAr: values['nameAr']!,
        version: values['version']!,
        reason: values['reason']!,
      );
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الامتداد للمراجعة، ولم يتم تشغيل أي كود.'),
        ),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('رفض Supabase الامتداد: ${error.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تسجيل الامتداد للمراجعة.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _moduleStatus(Map<String, dynamic> row) {
    final enabled = row['enabled'] == true;
    final provider = row['provider_required'] == true;
    return ListTile(
      dense: true,
      leading: Icon(
        enabled ? Icons.extension_outlined : Icons.extension_off_outlined,
      ),
      title: Text('${row['name_ar'] ?? row['module_key'] ?? '-'}'),
      subtitle: Text(
        '${row['bounded_context'] ?? '-'} · ${row['api_version'] ?? 'v1'} · ${row['implementation_status'] ?? '-'}',
      ),
      trailing: Chip(
        label: Text(
          provider
              ? 'مزود معطل'
              : enabled
              ? 'متاح'
              : 'مؤجل',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مركز ERP القابل للتركيب',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'تعمل الوحدات حالياً داخل بنية Supabase معيارية بحدود عقود واضحة. لا يعني ظهور الوحدة أنها تمنح صلاحية أو تشغّل مزوداً خارجياً.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: widget.modules,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return const Text('تعذر تحميل سجل الوحدات القابلة للتركيب.');
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              return Column(children: rows.map(_moduleStatus).toList());
            },
          ),
          const Divider(height: 24),
          Text(
            'صحة شبكة الأحداث والإسقاطات',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          if (widget.eventMesh == null)
            const Text('أدخل معرّف منظمة مرئية ثم حمّل المؤشرات لعرض الحالة.')
          else
            FutureBuilder<Map<String, dynamic>?>(
              future: widget.eventMesh,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const Text('لا توجد صحة أحداث مرئية بهذه المنظمة.');
                }
                final item = snapshot.data!;
                return Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    Text('أحداث معلقة: ${item['pending_event_count'] ?? 0}'),
                    Text('رسائل فاشلة: ${item['inbox_failed_count'] ?? 0}'),
                    Text(
                      'Dead-letter: ${item['dead_letter_event_count'] ?? 0}',
                    ),
                    Text('الإسقاطات: ${item['checkpoint_count'] ?? 0}'),
                    const Chip(label: Text('الإرسال الخارجي معطل')),
                  ],
                );
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _saveManifest,
            icon: const Icon(Icons.extension_outlined),
            label: const Text('تسجيل امتداد للمراجعة فقط'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 8),
          const Text(creatorErpComposableSafetyMessage),
        ],
      ),
    ),
  );
}

class _ErpMetric extends StatelessWidget {
  const _ErpMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    ),
  );
}
