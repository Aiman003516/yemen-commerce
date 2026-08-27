import 'package:flutter_test/flutter_test.dart';
import 'package:commerce_core/commerce_core.dart';

void main() {
  test(
    'web always remains rules-only even when experimental define is present',
    () {
      const capabilities = EdgeDeviceCapabilities(
        platform: 'web',
        osVersion: '0.0.0',
        deviceModel: 'browser',
        memoryMb: 16384,
        supportsNativeRuntime: true,
        supportsHardwareAcceleration: true,
      );
      final selection = EdgeDeviceTierPolicy.select(capabilities);
      expect(selection.tier, EdgeDeviceTier.webFallback);
      expect(selection.backend, 'rules_only');
      expect(selection.isModelEligible, isFalse);
      expect(EdgeWebRuntimePolicy.isSafeToAttempt, isFalse);
    },
  );

  test('low-memory native devices use the rules-only fallback', () {
    const capabilities = EdgeDeviceCapabilities(
      platform: 'android',
      osVersion: '14.0.0',
      deviceModel: 'low-memory',
      memoryMb: 1536,
      supportsNativeRuntime: true,
      supportsHardwareAcceleration: true,
    );
    final selection = EdgeDeviceTierPolicy.select(capabilities);
    expect(selection.tier, EdgeDeviceTier.unavailable);
    expect(selection.isModelEligible, isFalse);
  });

  test('device tiers select conservative CPU before optional acceleration', () {
    const economy = EdgeDeviceCapabilities(
      platform: 'android',
      osVersion: '14.0.0',
      deviceModel: 'economy',
      memoryMb: 3072,
      supportsNativeRuntime: true,
      supportsHardwareAcceleration: true,
    );
    const performance = EdgeDeviceCapabilities(
      platform: 'ios',
      osVersion: '18.0.0',
      deviceModel: 'performance',
      memoryMb: 8192,
      supportsNativeRuntime: true,
      supportsHardwareAcceleration: true,
    );
    expect(EdgeDeviceTierPolicy.select(economy).backend, 'cpu');
    expect(
      EdgeDeviceTierPolicy.select(performance).tier,
      EdgeDeviceTier.performance,
    );
    expect(EdgeDeviceTierPolicy.select(performance).backend, 'gpu_optional');
  });
}
