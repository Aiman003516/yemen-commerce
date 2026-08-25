import 'package:creator_app/app/creator_console_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the creator console root', (tester) async {
    await tester.pumpWidget(const CreatorConsoleApp());
    await tester.pump();
    expect(find.textContaining('لوحة'), findsWidgets);
  });
}
