import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_commerce/core/contracts.dart';
import 'package:yemen_commerce/features/marketplace_shell.dart';

void main() {
  testWidgets('renders the Arabic-first marketplace shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplaceShell(
          market: MarketConfig(
            id: 'test-market',
            governorate: 'إب',
            city: 'إب',
            currency: 'YER',
            isPilot: true,
          ),
        ),
      ),
    );
    expect(find.text('يمن كومرس'), findsOneWidget);
    expect(find.text('تسوّق محلياً، بثقة ووضوح.'), findsOneWidget);
  });
}
