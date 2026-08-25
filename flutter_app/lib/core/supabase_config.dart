import 'package:flutter/foundation.dart';

/// Public client configuration only. Never place a service-role key or database
/// connection string in Flutter or browser builds.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static String get missingConfigurationMessage {
    if (kIsWeb) {
      return 'Supabase غير مهيأ لهذا الإصدار من الويب.';
    }
    return 'Supabase غير مهيأ لهذا الإصدار من التطبيق.';
  }
}
