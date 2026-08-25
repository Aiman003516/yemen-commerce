import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseRuntime.initialize();
  runApp(const YemenCommerceApp());
}
