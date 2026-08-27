import 'edge_pilot.dart';

enum EdgeDeviceTier { unavailable, economy, standard, performance, webFallback }

class EdgeDeviceTierSelection {
  const EdgeDeviceTierSelection({
    required this.tier,
    required this.backend,
    required this.maxOutputTokens,
    required this.isModelEligible,
    required this.messageAr,
  });

  final EdgeDeviceTier tier;
  final String backend;
  final int maxOutputTokens;
  final bool isModelEligible;
  final String messageAr;
}

abstract final class EdgeDeviceTierPolicy {
  static EdgeDeviceTierSelection select(EdgeDeviceCapabilities capabilities) {
    if (capabilities.platform == 'web') {
      return const EdgeDeviceTierSelection(
        tier: EdgeDeviceTier.webFallback,
        backend: 'rules_only',
        maxOutputTokens: 256,
        isModelEligible: false,
        messageAr:
            'نسخة الويب تستخدم المساعد الآمن دون تشغيل نموذج محلي تجريبي.',
      );
    }
    if (!capabilities.supportsNativeRuntime || capabilities.memoryMb < 2048) {
      return const EdgeDeviceTierSelection(
        tier: EdgeDeviceTier.unavailable,
        backend: 'rules_only',
        maxOutputTokens: 256,
        isModelEligible: false,
        messageAr: 'مواصفات الجهاز الحالية لا تسمح بتجربة النموذج المحلي.',
      );
    }
    if (capabilities.memoryMb < 4096) {
      return const EdgeDeviceTierSelection(
        tier: EdgeDeviceTier.economy,
        backend: 'cpu',
        maxOutputTokens: 256,
        isModelEligible: true,
        messageAr: 'الجهاز مؤهل لنموذج صغير بحدود محافظة وعلى المعالج فقط.',
      );
    }
    if (capabilities.memoryMb < 8192 ||
        !capabilities.supportsHardwareAcceleration) {
      return const EdgeDeviceTierSelection(
        tier: EdgeDeviceTier.standard,
        backend: 'cpu',
        maxOutputTokens: 384,
        isModelEligible: true,
        messageAr: 'الجهاز مؤهل لنموذج قياسي محافظ على المعالج.',
      );
    }
    return EdgeDeviceTierSelection(
      tier: EdgeDeviceTier.performance,
      backend: 'gpu_optional',
      maxOutputTokens: 512,
      isModelEligible: true,
      messageAr: capabilities.isLowPowerMode
          ? 'الجهاز قوي، لكن وضع توفير الطاقة يفرض تشغيل النموذج بشكل محافظ.'
          : 'الجهاز مؤهل للنموذج القياسي؛ تسريع GPU اختياري بعد اجتياز القياس.',
    );
  }
}

abstract final class EdgeWebRuntimePolicy {
  static const experimentalEnabled = bool.fromEnvironment(
    'EDGE_WEBGPU_EXPERIMENTAL',
    defaultValue: false,
  );

  static bool get isSafeToAttempt => false;

  static String get statusAr => experimentalEnabled
      ? 'مسار WebGPU تجريبي مضمّن في البناء لكنه غير مفعّل للتنفيذ.'
      : 'مسار WebGPU/JavaScript اختياري وغير مفعّل؛ يعمل المساعد بالقواعد فقط.';
}
