# Verification Notes

## 2026-08-25 — Flutter Web release

The staged Flutter Web application rendered successfully at the project root in a browser. The Arabic RTL desktop marketplace shell, navigation rail, login affordance, Ibb pilot hero, search field, and non-fabricated empty catalogue state were visible. The identity-verification screens require an authenticated merchant or administrator and were validated through static analysis, widget tests, and backend API contract checks rather than browser authentication in this pass.

## 2026-08-25 — Flutter Web runtime repair

The development entry page now loads Flutter with a root base URL and the standard non-module bootstrap. A legacy `assets/AssetManifest.json` request returns JSON rather than the SPA HTML fallback. Reloading `/?from_webdev=1` rendered the marketplace successfully and the browser console contained no new output, including no JavaScript parsing error.

## 2026-08-25 — Merchant workspace release

The Flutter Web release with the merchant workspace loaded at `/?from_webdev=1` without console output or a JavaScript runtime error. The public catalogue was still resolving at capture time; this is an existing data-load state and does not indicate a bootstrap failure.

## 2026-08-25 — Merchant configuration extension

The rebuilt release after merchant fulfilment, order-transition, and payment-proof configuration additions continued to render at `/?from_webdev=1`. The original JavaScript parsing error did not recur during this browser verification.

## 2026-08-25 — Split checkout release

The Flutter Web build with grouped customer checkout selection loaded at `/?from_webdev=1` without browser-console errors. The public-catalogue loading indicator persisted during the unauthenticated capture; authenticated cart and checkout actions remain server-protected.
