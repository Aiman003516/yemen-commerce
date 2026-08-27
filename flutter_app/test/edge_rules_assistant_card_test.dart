import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yemen_commerce/features/edge_rules_assistant_card.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('merchant card creates a reviewable local shipment proposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const EdgeRulesOnlyAssistantCard(
          surface: EdgeAppSurface.merchant,
          context: {'shipment_plan_id': 'shipment-1'},
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'اجعل حالة shipment جاهز، تم تجهيز الطلب للاستلام',
    );
    await tester.tap(find.text('تحقق من الطلب'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();

    expect(find.text('الاقتراح: تحديث حالة التوصيل'), findsOneWidget);
    expect(find.text('أؤكد الاقتراح محلياً'), findsOneWidget);
    expect(find.textContaining('لن تتغير حالة الدفع'), findsOneWidget);

    await tester.tap(find.text('أؤكد الاقتراح محلياً'));
    await tester.pump();
    expect(find.textContaining('تم تأكيد المسودة محلياً'), findsOneWidget);
  });

  testWidgets('customer card does not offer prohibited payment execution', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const EdgeRulesOnlyAssistantCard(surface: EdgeAppSurface.customer),
      ),
    );

    await tester.enterText(find.byType(TextField), 'mark_paid لهذا الطلب');
    await tester.tap(find.text('تحقق من الطلب'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();

    expect(
      find.textContaining('لا يمكن للمساعد تنفيذ هذه العملية'),
      findsOneWidget,
    );
    expect(find.text('أؤكد الاقتراح محلياً'), findsNothing);
  });
}
