import 'package:commerce_core/commerce_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 10);

  EdgeProposal proposal({
    String intent = 'shipment.record_status',
    EdgeRiskClass? riskClass,
    Map<String, dynamic> entities = const {
      'shipment_plan_id': 'shipment-1',
      'status': 'ready',
      'reason': 'تم تجهيز الطلب للاستلام',
    },
    List<String> missingFields = const [],
    bool requiresConfirmation = true,
    EdgeProposalState state = EdgeProposalState.proposalReady,
  }) => EdgeProposal(
    schemaVersion: 'edge_proposal.v1',
    surface: EdgeAppSurface.merchant,
    intent: intent,
    confidence: 0.9,
    locale: 'ar-YE',
    entities: entities,
    missingFields: missingFields,
    riskClass: riskClass ?? EdgeIntentCatalog.expectedRiskFor(intent),
    explanationAr: 'اقتراح قابل للمراجعة قبل التنفيذ.',
    requiresConfirmation: requiresConfirmation,
    createdAt: now,
    modelVersion: 'rules-0',
    state: state,
  );

  test('canonical JSON and proposal hash are key-order independent', () {
    final first = EdgeProposal(
      schemaVersion: 'edge_proposal.v1',
      surface: EdgeAppSurface.merchant,
      intent: 'shipment.record_status',
      confidence: 0.9,
      locale: 'ar-YE',
      entities: const {
        'status': 'ready',
        'shipment_plan_id': 'shipment-1',
        'reason': 'تم تجهيز الطلب للاستلام',
      },
      missingFields: const [],
      riskClass: EdgeRiskClass.reviewableOperational,
      explanationAr: 'اقتراح قابل للمراجعة قبل التنفيذ.',
      requiresConfirmation: true,
      createdAt: now,
    );
    final second = EdgeProposal(
      schemaVersion: 'edge_proposal.v1',
      surface: EdgeAppSurface.merchant,
      intent: 'shipment.record_status',
      confidence: 0.9,
      locale: 'ar-YE',
      entities: const {
        'reason': 'تم تجهيز الطلب للاستلام',
        'shipment_plan_id': 'shipment-1',
        'status': 'ready',
      },
      missingFields: const [],
      riskClass: EdgeRiskClass.reviewableOperational,
      explanationAr: 'اقتراح قابل للمراجعة قبل التنفيذ.',
      requiresConfirmation: true,
      createdAt: now,
    );

    expect(first.proposalHash, second.proposalHash);
    expect(first.proposalHash, hasLength(64));
    expect(first.toJson()['proposal_hash'], first.proposalHash);
  });

  test('redacts sensitive values recursively and bounds large strings', () {
    final redacted = EdgeRedactor.redact({
      'access_token': 'secret-token',
      'nested': {'payment_proof': 'private-proof', 'title': 'safe'},
      'long': 'x' * 2200,
    }) as Map<String, dynamic>;

    expect(redacted['access_token'], '[REDACTED]');
    expect((redacted['nested'] as Map)['payment_proof'], '[REDACTED]');
    expect(redacted['nested'], isNot(contains('private-proof')));
    expect((redacted['long'] as String).length, 2001);
    expect(EdgeRedactor.containsSecretLikeKey('service-role-key'), isTrue);
  });

  test('validates a reviewable operational proposal', () {
    final result = EdgeProposalValidator.validate(proposal(), now: now);

    expect(result.isValid, isTrue);
    expect(proposal().isExecutableCandidate, isTrue);
  });

  test('rejects prohibited or unsafe proposals', () {
    final result = EdgeProposalValidator.validate(
      proposal(
        intent: 'payment.mark_paid',
        riskClass: EdgeRiskClass.prohibited,
        entities: const {'payment_proof': 'secret'},
        requiresConfirmation: false,
      ),
      now: now,
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<String>['PROHIBITED_INTENT', 'INVALID_ENTITIES']),
    );
  });

  test('requires clarification for missing operational fields', () {
    final candidate = proposal(
      entities: const {'status': 'ready'},
      missingFields: const ['shipment_plan_id'],
      state: EdgeProposalState.needsClarification,
    );
    final result = EdgeProposalValidator.validate(candidate, now: now);

    expect(result.isValid, isTrue);
    expect(result.requiresClarification, isTrue);
  });

  test('rules-only assistant creates Arabic-safe shipment proposal', () {
    const assistant = EdgeRulesOnlyAssistant();
    final result = assistant.interpret(
      EdgeAssistantRequest(
        requestId: 'request-1',
        surface: EdgeAppSurface.merchant,
        locale: 'ar-YE',
        prompt: 'اجعل حالة shipment جاهز، تم تجهيز الطلب للاستلام',
        createdAt: now,
        context: const {'shipment_plan_id': 'shipment-1'},
      ),
    );

    expect(result.intent, 'shipment.record_status');
    expect(result.entities['status'], 'ready');
    expect(result.requiresConfirmation, isTrue);
    expect(result.proposalHash, hasLength(64));
    expect(EdgeProposalValidator.validate(result, now: now).isValid, isTrue);
  });

  test('rules-only assistant rejects a prohibited financial request', () {
    const assistant = EdgeRulesOnlyAssistant();
    final result = assistant.interpret(
      EdgeAssistantRequest(
        requestId: 'request-2',
        surface: EdgeAppSurface.merchant,
        locale: 'ar-YE',
        prompt: 'mark_paid لهذا الطلب',
        createdAt: now,
      ),
    );

    expect(result.intent, 'payment.mark_paid');
    expect(result.riskClass, EdgeRiskClass.prohibited);
    expect(EdgeProposalValidator.validate(result, now: now).issues, isNotEmpty);
  });
}
