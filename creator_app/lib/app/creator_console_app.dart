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
      _PlaceholderPage(
        title: 'حوكمة التجار والمتاجر',
        detail: 'ستُضاف مراجعة التجار واعتماد المتاجر في المرحلة التالية.',
      ),
      _PlaceholderPage(
        title: 'الأسواق والسياسات',
        detail:
            'إدارة الأسواق والإصدارات والسياسات ستكون مقيدة بصلاحيات المنشئ.',
      ),
      _PlaceholderPage(
        title: 'التقارير والتدقيق',
        detail: 'ستظهر هنا التقارير وسجل التدقيق بعد إضافة استعلامات الإدارة.',
      ),
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.detail});
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
