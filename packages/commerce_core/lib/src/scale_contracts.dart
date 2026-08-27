import 'dart:convert';

class CommerceKeysetCursor {
  const CommerceKeysetCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;

  String get token => base64UrlEncode(
    utf8.encode('${createdAt.toUtc().toIso8601String()}|$id'),
  );

  static CommerceKeysetCursor? fromToken(String? value) {
    if (value == null || value.length > 400) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(base64Url.normalize(value)));
      final split = decoded.split('|');
      if (split.length != 2 || split[1].isEmpty || split[1].length > 120) {
        return null;
      }
      final createdAt = DateTime.tryParse(split[0]);
      if (createdAt == null) return null;
      return CommerceKeysetCursor(createdAt: createdAt, id: split[1]);
    } catch (_) {
      return null;
    }
  }
}

class CommercePageRequest {
  const CommercePageRequest({this.limit = 50, this.after});

  final int limit;
  final CommerceKeysetCursor? after;

  int get safeLimit => limit.clamp(1, 100);

  Map<String, dynamic> toJson() => {
    'limit': safeLimit,
    if (after != null) ...{
      'after_created_at': after!.createdAt.toUtc().toIso8601String(),
      'after_id': after!.id,
    },
  };
}

class CommercePage<T> {
  const CommercePage({
    required this.items,
    required this.hasMore,
    this.nextAfter,
  });

  final List<T> items;
  final bool hasMore;
  final CommerceKeysetCursor? nextAfter;
}

class CommerceQueryBudget {
  const CommerceQueryBudget({
    this.maxRows = 100,
    this.maxDurationMs = 1500,
    this.maxPayloadBytes = 512 * 1024,
  });

  final int maxRows;
  final int maxDurationMs;
  final int maxPayloadBytes;

  int get safeMaxRows => maxRows.clamp(1, 100);
}

class ScalePerformanceSample {
  const ScalePerformanceSample({
    required this.operation,
    required this.pageSize,
    required this.durationMs,
    required this.payloadBytes,
    required this.resultCount,
    required this.failed,
  });

  final String operation;
  final int pageSize;
  final int durationMs;
  final int payloadBytes;
  final int resultCount;
  final bool failed;

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'page_size': pageSize.clamp(1, 100),
    'duration_ms': durationMs,
    'payload_bytes': payloadBytes,
    'result_count': resultCount,
    'failed': failed,
  };
}

class ScaleGateDecision {
  const ScaleGateDecision({
    required this.passed,
    required this.code,
    required this.failedGates,
  });

  final bool passed;
  final String code;
  final List<String> failedGates;
}

class ScaleGate {
  const ScaleGate({
    this.maxDurationMs = 1500,
    this.maxPayloadBytes = 512 * 1024,
    this.maxFailedSamples = 0,
  });

  final int maxDurationMs;
  final int maxPayloadBytes;
  final int maxFailedSamples;

  ScaleGateDecision evaluate(List<ScalePerformanceSample> samples) {
    final failures = <String>[];
    if (samples.isEmpty) failures.add('EMPTY_SAMPLE_SET');
    if (samples.any((sample) => sample.durationMs > maxDurationMs)) {
      failures.add('QUERY_LATENCY_LIMIT');
    }
    if (samples.any((sample) => sample.payloadBytes > maxPayloadBytes)) {
      failures.add('PAYLOAD_LIMIT');
    }
    if (samples.where((sample) => sample.failed).length > maxFailedSamples) {
      failures.add('FAILED_SAMPLES');
    }
    return failures.isEmpty
        ? const ScaleGateDecision(passed: true, code: 'PASS', failedGates: [])
        : ScaleGateDecision(
            passed: false,
            code: 'SCALE_GATE_FAILED',
            failedGates: List.unmodifiable(failures),
          );
  }
}
