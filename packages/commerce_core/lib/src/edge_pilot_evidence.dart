import 'edge_device_tiers.dart';

class EdgePilotEvidence {
  const EdgePilotEvidence({
    required this.modelId,
    required this.modelVersion,
    required this.deviceTier,
    required this.platform,
    required this.latencyMs,
    required this.peakMemoryMb,
    required this.batteryDeltaPercent,
    required this.crashCount,
    required this.cancelledCount,
    required this.completedCount,
    required this.unsafeProposalCount,
    required this.evaluationCaseCount,
    required this.evaluationPassed,
    required this.recordedAt,
  });

  final String modelId;
  final String modelVersion;
  final EdgeDeviceTier deviceTier;
  final String platform;
  final int latencyMs;
  final int peakMemoryMb;
  final double batteryDeltaPercent;
  final int crashCount;
  final int cancelledCount;
  final int completedCount;
  final int unsafeProposalCount;
  final int evaluationCaseCount;
  final bool evaluationPassed;
  final DateTime recordedAt;

  Map<String, dynamic> toSanitizedJson() => {
    'model_id': modelId,
    'model_version': modelVersion,
    'device_tier': deviceTier.name,
    'platform': platform,
    'latency_ms': latencyMs,
    'peak_memory_mb': peakMemoryMb,
    'battery_delta_percent': batteryDeltaPercent,
    'crash_count': crashCount,
    'cancelled_count': cancelledCount,
    'completed_count': completedCount,
    'unsafe_proposal_count': unsafeProposalCount,
    'evaluation_case_count': evaluationCaseCount,
    'evaluation_passed': evaluationPassed,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
  };
}

class EdgePilotReadinessDecision {
  const EdgePilotReadinessDecision({
    required this.ready,
    required this.code,
    required this.messageAr,
    required this.failedGates,
  });

  final bool ready;
  final String code;
  final String messageAr;
  final List<String> failedGates;
}

class EdgePilotReadinessGate {
  const EdgePilotReadinessGate({
    this.maxLatencyMs = 5000,
    this.maxPeakMemoryMb = 4096,
    this.maxBatteryDeltaPercent = 8,
    this.maxCrashCount = 0,
  });

  final int maxLatencyMs;
  final int maxPeakMemoryMb;
  final double maxBatteryDeltaPercent;
  final int maxCrashCount;

  EdgePilotReadinessDecision evaluate(EdgePilotEvidence evidence) {
    final failures = <String>[];
    if (evidence.evaluationCaseCount == 0) failures.add('EMPTY_EVALUATION');
    if (!evidence.evaluationPassed) failures.add('EVALUATION_FAILED');
    if (evidence.unsafeProposalCount != 0) failures.add('UNSAFE_PROPOSALS');
    if (evidence.latencyMs > maxLatencyMs) failures.add('LATENCY_LIMIT');
    if (evidence.peakMemoryMb > maxPeakMemoryMb) failures.add('MEMORY_LIMIT');
    if (evidence.batteryDeltaPercent > maxBatteryDeltaPercent) {
      failures.add('BATTERY_LIMIT');
    }
    if (evidence.crashCount > maxCrashCount) failures.add('CRASHES');
    if (evidence.completedCount == 0) failures.add('NO_COMPLETIONS');
    return failures.isEmpty
        ? const EdgePilotReadinessDecision(
            ready: true,
            code: 'READY_FOR_REVIEW',
            messageAr: 'بيانات التجربة جاهزة لمراجعة الإصدار.',
            failedGates: [],
          )
        : EdgePilotReadinessDecision(
            ready: false,
            code: 'NOT_READY',
            messageAr: 'لا يسمح دليل التجربة بتفعيل النموذج حالياً.',
            failedGates: List.unmodifiable(failures),
          );
  }
}
