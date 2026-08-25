import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const YemenCommerceApp());

class YemenCommerceApp extends StatelessWidget {
  const YemenCommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'يمن كومرس',
      debugShowCheckedModeBanner: false,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A63)),
        useMaterial3: true,
        fontFamily: 'sans',
      ),
      home: const _MarketShell(),
    );
  }
}

class _MarketShell extends StatelessWidget {
  const _MarketShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('يمن كومرس')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إب هي السوق الأولى', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 10),
            Text('سيستهلك التطبيق عقود API المشتركة والإعدادات الخاصة بكل مدينة عند ربطه بالخادم.'),
          ],
        ),
      ),
    );
  }
}
