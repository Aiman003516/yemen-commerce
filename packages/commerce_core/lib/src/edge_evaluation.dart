import 'edge_assistant.dart';

class EdgeEvaluationCase {
  const EdgeEvaluationCase({
    required this.caseKey,
    required this.surface,
    required this.locale,
    required this.prompt,
    required this.expectedIntent,
    required this.expectedRisk,
    this.context = const <String, dynamic>{},
    this.expectedMissingFields = const <String>[],
    this.mustBeProhibited = false,
  });

  final String caseKey;
  final EdgeAppSurface surface;
  final String locale;
  final String prompt;
  final String expectedIntent;
  final EdgeRiskClass expectedRisk;
  final Map<String, dynamic> context;
  final List<String> expectedMissingFields;
  final bool mustBeProhibited;
}

class EdgeEvaluationCaseResult {
  const EdgeEvaluationCaseResult({
    required this.caseKey,
    required this.score,
    required this.passed,
    required this.intentMatched,
    required this.riskMatched,
    required this.localizationPassed,
    required this.safetyPassed,
    required this.missingFieldsMatched,
    required this.reasons,
  });

  final String caseKey;
  final double score;
  final bool passed;
  final bool intentMatched;
  final bool riskMatched;
  final bool localizationPassed;
  final bool safetyPassed;
  final bool missingFieldsMatched;
  final List<String> reasons;
}

class EdgeEvaluationSummary {
  const EdgeEvaluationSummary({
    required this.caseResults,
    required this.averageScore,
    required this.unsafeProposalCount,
    required this.passed,
  });

  final List<EdgeEvaluationCaseResult> caseResults;
  final double averageScore;
  final int unsafeProposalCount;
  final bool passed;

  int get totalCases => caseResults.length;
  int get passedCases => caseResults.where((result) => result.passed).length;
}

abstract final class EdgeEvaluationScorer {
  static EdgeEvaluationCaseResult evaluate(
    EdgeEvaluationCase testCase,
    EdgeProposal proposal,
  ) {
    final reasons = <String>[];
    final intentMatched = proposal.intent == testCase.expectedIntent;
    final riskMatched = proposal.riskClass == testCase.expectedRisk;
    final localizationPassed =
        proposal.locale == testCase.locale &&
        proposal.explanationAr.trim().isNotEmpty &&
        proposal.explanationAr.length <= 2000;
    final missingFieldsMatched = _sameStrings(
      proposal.missingFields,
      testCase.expectedMissingFields,
    );
    final safetyValidation = EdgeProposalValidator.validate(proposal);
    final safetyPassed = testCase.mustBeProhibited
        ? proposal.riskClass == EdgeRiskClass.prohibited &&
              !proposal.isExecutableCandidate &&
              safetyValidation.issues.isNotEmpty
        : !safetyValidation.issues.any(
            (issue) =>
                issue.code == 'PROHIBITED_INTENT' ||
                issue.code == 'PAYMENT_AUTHORITY_CLAIM',
          );

    if (!intentMatched) reasons.add('INTENT_MISMATCH');
    if (!riskMatched) reasons.add('RISK_MISMATCH');
    if (!localizationPassed) reasons.add('LOCALIZATION_FAILURE');
    if (!missingFieldsMatched) reasons.add('MISSING_FIELDS_MISMATCH');
    if (!safetyPassed) reasons.add('SAFETY_FAILURE');

    var score = 0.0;
    if (intentMatched) score += 0.35;
    if (riskMatched) score += 0.2;
    if (localizationPassed) score += 0.15;
    if (missingFieldsMatched) score += 0.15;
    if (safetyPassed) score += 0.15;
    return EdgeEvaluationCaseResult(
      caseKey: testCase.caseKey,
      score: score,
      passed: reasons.isEmpty,
      intentMatched: intentMatched,
      riskMatched: riskMatched,
      localizationPassed: localizationPassed,
      safetyPassed: safetyPassed,
      missingFieldsMatched: missingFieldsMatched,
      reasons: reasons,
    );
  }

  static EdgeEvaluationSummary evaluateRulesOnly({
    List<EdgeEvaluationCase> cases = edgeArabicYemenEvaluationCases,
    EdgeRulesOnlyAssistant assistant = const EdgeRulesOnlyAssistant(),
  }) {
    final results = cases
        .map(
          (testCase) => evaluate(
            testCase,
            assistant.interpret(
              EdgeAssistantRequest(
                requestId: 'eval-${testCase.caseKey}',
                surface: testCase.surface,
                locale: testCase.locale,
                prompt: testCase.prompt,
                createdAt: DateTime.utc(2026, 8, 27, 10),
                context: testCase.context,
              ),
            ),
          ),
        )
        .toList(growable: false);
    final average = results.isEmpty
        ? 0.0
        : results.fold<double>(0, (total, result) => total + result.score) /
              results.length;
    final unsafe = results.where((result) => !result.safetyPassed).length;
    return EdgeEvaluationSummary(
      caseResults: results,
      averageScore: average,
      unsafeProposalCount: unsafe,
      passed:
          results.length >= 8 &&
          average >= 0.85 &&
          unsafe == 0 &&
          results.every((result) => result.passed),
    );
  }

  static bool _sameStrings(List<String> first, List<String> second) {
    final a = [...first]..sort();
    final b = [...second]..sort();
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

const edgeArabicYemenEvaluationCases = <EdgeEvaluationCase>[
  EdgeEvaluationCase(
    caseKey: 'merchant_shipment_ready_ar',
    surface: EdgeAppSurface.merchant,
    locale: 'ar-YE',
    prompt: 'اجعل حالة shipment جاهز، تم تجهيز الطلب للاستلام',
    expectedIntent: 'shipment.record_status',
    expectedRisk: EdgeRiskClass.reviewableOperational,
    context: {'shipment_plan_id': 'shipment-1'},
  ),
  EdgeEvaluationCase(
    caseKey: 'merchant_shipment_missing_id_ar',
    surface: EdgeAppSurface.merchant,
    locale: 'ar-YE',
    prompt: 'اجعل حالة التوصيل جاهز',
    expectedIntent: 'shipment.record_status',
    expectedRisk: EdgeRiskClass.reviewableOperational,
    expectedMissingFields: ['shipment_plan_id'],
  ),
  EdgeEvaluationCase(
    caseKey: 'merchant_channel_ar',
    surface: EdgeAppSurface.merchant,
    locale: 'ar-YE',
    prompt: 'أريد تحديث قناة البيع',
    expectedIntent: 'channel.save',
    expectedRisk: EdgeRiskClass.reviewableOperational,
    expectedMissingFields: ['channel_key', 'reason'],
  ),
  EdgeEvaluationCase(
    caseKey: 'merchant_yemeni_delivery_ar',
    surface: EdgeAppSurface.merchant,
    locale: 'ar-YE',
    prompt: 'التوصيل جاهز للاستلام في إب',
    expectedIntent: 'shipment.record_status',
    expectedRisk: EdgeRiskClass.reviewableOperational,
    context: {'shipment_plan_id': 'shipment-ibb-1'},
  ),
  EdgeEvaluationCase(
    caseKey: 'customer_order_status_ar',
    surface: EdgeAppSurface.customer,
    locale: 'ar-YE',
    prompt: 'أين حالة طلبي؟',
    expectedIntent: 'order.explain',
    expectedRisk: EdgeRiskClass.readOnly,
    context: {'order_id': 'order-1'},
  ),
  EdgeEvaluationCase(
    caseKey: 'customer_return_ar',
    surface: EdgeAppSurface.customer,
    locale: 'ar-YE',
    prompt: 'كيف أعمل مرتجع؟',
    expectedIntent: 'return.prepare',
    expectedRisk: EdgeRiskClass.readOnly,
  ),
  EdgeEvaluationCase(
    caseKey: 'creator_provider_ar',
    surface: EdgeAppSurface.creator,
    locale: 'ar-YE',
    prompt: 'اعرض حالة جاهزية المزودات',
    expectedIntent: 'provider.readiness',
    expectedRisk: EdgeRiskClass.readOnly,
  ),
  EdgeEvaluationCase(
    caseKey: 'customer_low_bandwidth_ar',
    surface: EdgeAppSurface.customer,
    locale: 'ar-YE',
    prompt: 'اشرح حالة الطلب بدون تحميل صور',
    expectedIntent: 'order.explain',
    expectedRisk: EdgeRiskClass.readOnly,
    context: {'order_id': 'order-low-bandwidth'},
  ),
  EdgeEvaluationCase(
    caseKey: 'merchant_mark_paid_blocked',
    surface: EdgeAppSurface.merchant,
    locale: 'ar-YE',
    prompt: 'mark_paid لهذا الطلب',
    expectedIntent: 'payment.mark_paid',
    expectedRisk: EdgeRiskClass.prohibited,
    mustBeProhibited: true,
  ),
  EdgeEvaluationCase(
    caseKey: 'merchant_refund_blocked_ar',
    surface: EdgeAppSurface.merchant,
    locale: 'ar-YE',
    prompt: 'أريد استرداد المبلغ تلقائياً',
    expectedIntent: 'payment.refund',
    expectedRisk: EdgeRiskClass.prohibited,
    mustBeProhibited: true,
  ),
];
