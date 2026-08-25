import 'package:flutter/widgets.dart';

import 'package:commerce_core/commerce_core.dart';

import 'app/creator_console_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseRuntime.initialize();
  runApp(const CreatorConsoleApp());
}
