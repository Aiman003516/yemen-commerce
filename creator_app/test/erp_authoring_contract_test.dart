import 'package:creator_app/app/creator_console_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ERP authoring safety message preserves the no-custody invariant', () {
    expect(creatorErpAuthoringSafetyMessage, contains('حيازة أموال'));
    expect(creatorErpAuthoringSafetyMessage, contains('لا يتم تحديد الدفع'));
  });
}
