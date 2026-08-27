import 'package:creator_app/app/edge_rules_assistant_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creator card prepares a local provider-readiness proposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreatorEdgeRulesAssistantCard())),
    );

    await tester.enterText(find.byType(TextField), 'اعرض حالة جاهزية المزودات');
    await tester.tap(find.text('تحقق من الطلب'));
    await tester.pump();

    expect(find.text('الاقتراح: جاهزية المزودات'), findsOneWidget);
    expect(find.text('أؤكد الاقتراح محلياً'), findsOneWidget);
    expect(find.textContaining('لم يتم تغيير صلاحية'), findsNothing);

    await tester.tap(find.text('أؤكد الاقتراح محلياً'));
    await tester.pump();
    expect(find.textContaining('لم يتم تغيير صلاحية'), findsOneWidget);
  });
}
