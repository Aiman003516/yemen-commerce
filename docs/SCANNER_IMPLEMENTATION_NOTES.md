## Verified scanner dependency

The official pub.dev page for `mobile_scanner` 7.4.0 states that it supports Android, iOS, macOS, and Web, using CameraX/ML Kit on Android, AVFoundation/Apple Vision on iOS/macOS, and ZXing-based detection on Web. It documents `MobileScanner(onDetect: ...)`, multiple barcode formats, real-time detection, and camera configuration. iOS requires `NSCameraUsageDescription`; Android uses the package camera implementation. Web camera permission and browser support remain runtime requirements, and Web detection may use native BarcodeDetector or a ZXing fallback.

Source: https://pub.dev/packages/mobile_scanner
