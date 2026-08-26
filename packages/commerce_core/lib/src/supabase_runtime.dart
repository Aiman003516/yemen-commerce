import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRuntime {
  const SupabaseRuntime._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const authRedirectUrl = String.fromEnvironment(
    'SUPABASE_AUTH_REDIRECT_URL',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<void> initialize() async {
    if (!isConfigured || Supabase.instance.isInitialized) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }

  static Future<void> sendMagicLink(String email) async {
    await client.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: authRedirectUrl.isNotEmpty
          ? authRedirectUrl
          : (kIsWeb ? Uri.base.origin : null),
    );
  }

  static Future<void> signOut() => client.auth.signOut();
}
