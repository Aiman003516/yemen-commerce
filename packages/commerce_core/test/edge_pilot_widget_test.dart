import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opt-in gate stays safe when no signed manifest is present', (
    tester,
  ) async {
    final preferences = InMemoryEdgePilotPreferences();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EdgePilotGateCard(
            surface: EdgeAppSurface.customer,
            titleAr: 'تجربة الذكاء المحلي الاختيارية',
            preferences: preferences,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('قراءة فقط'), findsOneWidget);
    expect(
      find.text('متوقفة افتراضياً ويمكن إيقافها في أي وقت.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(await preferences.readOptIn(), EdgePilotOptInState.enabled);
    expect(
      find.text('لا يوجد manifest موقع ومفعّل لهذا الإصدار.'),
      findsOneWidget,
    );
    expect(find.textContaining('لا تنفذ عمليات'), findsOneWidget);
  });
}
