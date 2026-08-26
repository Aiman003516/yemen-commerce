import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/outbox_background_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseRuntime.initialize();
  await outboxBackgroundScheduler.start();
  runApp(const YemenCommerceApp());
}
