import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/contracts.dart';
import 'core/supabase_config.dart';
import 'core/supabase_marketplace_client.dart';
import 'features/marketplace_shell.dart';

class YemenCommerceApp extends StatelessWidget {
  const YemenCommerceApp({super.key});

  Widget _shell() {
    final api = MarketplaceApiClient();
    return FutureBuilder<SessionUser?>(
      future: api.currentUser(),
      builder: (context, sessionSnapshot) => FutureBuilder<MarketConfig>(
        future: api.activeMarket(),
        builder: (context, marketSnapshot) => MarketplaceShell(
          market: marketSnapshot.data,
          marketLoading: marketSnapshot.connectionState == ConnectionState.waiting,
          user: sessionSnapshot.data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF006A63);
    final home = SupabaseConfig.isConfigured
        ? StreamBuilder<AuthState>(
            stream: SupabaseMarketplaceClient().authStateChanges,
            builder: (context, _) => _shell(),
          )
        : _shell();

    return MaterialApp(
      title: 'يمن كومرس',
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
          surface: const Color(0xFFFFFCF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFCF7),
        appBarTheme: const AppBarTheme(centerTitle: false, surfaceTintColor: Colors.transparent),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F4EE),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      home: home,
    );
  }
}
