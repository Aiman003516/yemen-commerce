import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_commerce/core/contracts.dart';
import 'package:yemen_commerce/features/marketplace_shell.dart';

Widget buildShell() => MaterialApp(
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: MarketplaceShell(
          market: const MarketConfig(id: 1, governorate: 'إب', city: 'إب', currency: 'YER', isPilot: true),
        ),
      );

void main() {
  testWidgets('uses RTL mobile navigation at a narrow phone width', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildShell());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('يمن كومرس'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('يمن كومرس'))), TextDirection.rtl);
  });

  testWidgets('uses desktop rail navigation at a wide width', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildShell());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('تسوّق محلياً، بثقة ووضوح.'), findsOneWidget);
  });
}
