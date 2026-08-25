import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'core/contracts.dart';
import 'features/marketplace_shell.dart';

class YemenCommerceApp extends StatefulWidget {
  const YemenCommerceApp({super.key});

  @override
  State<YemenCommerceApp> createState() => _YemenCommerceAppState();
}

class _YemenCommerceAppState extends State<YemenCommerceApp> {
  late final Future<MarketConfig> _market = MarketplaceApiClient().activeMarket();

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF006A63);
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
      home: FutureBuilder<MarketConfig>(
        future: _market,
        builder: (context, snapshot) => MarketplaceShell(
          market: snapshot.data,
          marketLoading: snapshot.connectionState == ConnectionState.waiting,
        ),
      ),
    );
  }
}
