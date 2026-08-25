# Yemen Commerce Flutter client

This is the canonical Flutter application for Yemen Commerce. The same Dart codebase targets Android, iOS, and Flutter Web with Arabic-first RTL presentation and an English-ready localization structure.

## Backend boundary

The target backend is the connected Supabase project. The Flutter client uses `supabase_flutter` with only the public project URL and publishable key. Supabase Auth, PostgreSQL RLS, private Storage, and PostgreSQL RPC functions remain authoritative for identity, authorization, pricing, stock, checkout splitting, payment review, fulfilment transitions, and audit history.

The legacy HTTP/tRPC adapter remains in `lib/core/api_client.dart` only as a migration reference while feature repositories are moved to `SupabaseMarketplaceClient`. New feature work must not add dependencies on `/api/trpc`, Manus OAuth, Forge storage, MySQL, or service-role credentials.

## Run with Supabase

Supply public client configuration at build time. Do not commit the values in source control.

```text
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
flutter build web --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Native builds use the same two defines. The service-role key and database connection string are never valid Flutter configuration values.

## Feature organization

The application is being refactored from the original monolithic responsive shell into feature modules for authentication, market configuration, catalogue, cart, checkout, customer orders, merchant operations, payments, identity verification, and administration. Each module should expose typed Dart state and repository operations, while display labels and status text remain localized independently from stable database values.

## Validation

Run `flutter analyze`, `flutter test`, and the integration tests after installing the Flutter SDK. Supabase policy tests belong under the repository-level `supabase/tests/` directory. The minimum acceptance checks are public-catalogue visibility, customer and merchant isolation, private proof/evidence access, atomic grouped checkout, immutable payment snapshots, payment-before-fulfilment, and Arabic RTL rendering at phone and desktop widths.
