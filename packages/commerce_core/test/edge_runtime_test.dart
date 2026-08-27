import 'package:commerce_core/commerce_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('maps native status and inference through the typed channel', () async {
    const channel = MethodChannel('test.edge_runtime');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'status':
              return {
                'platform': 'android',
                'state': 'ready',
                'backend': 'fake_native',
                'supports_cancellation': true,
                'model_id': 'edge-test',
                'model_version': '0.1.0',
                'message_ar': 'جاهز',
              };
            case 'infer':
              return {
                'request_id': 'request-1',
                'model_version': '0.1.0',
                'proposal': {
                  'schema_version': 'edge_proposal.v1',
                  'surface': 'merchant',
                  'intent': 'order.explain',
                  'confidence': 0.9,
                  'locale': 'ar-YE',
                  'entities': const {},
                  'missing_fields': const [],
                  'risk_class': 'read_only',
                  'explanation_ar': 'شرح آمن.',
                  'requires_confirmation': false,
                  'created_at': '2026-08-27T10:00:00.000Z',
                  'model_version': '0.1.0',
                  'state': 'proposal_ready',
                },
              };
            case 'cancel':
              return {'cancelled': true};
            case 'unloadModel':
              return null;
            default:
              return null;
          }
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final runtime = EdgeRuntimeChannel(channel: channel);
    final status = await runtime.status();
    final result = await runtime.infer(
      const EdgeRuntimeRequest(requestId: 'request-1', prompt: 'اشرح الطلب'),
    );
    final cancelled = await runtime.cancel('request-1');
    await runtime.unloadModel();

    expect(status.state, EdgeRuntimeState.ready);
    expect(status.isAvailable, isTrue);
    expect(result.requestId, 'request-1');
    expect(result.proposal?['intent'], 'order.explain');
    expect(cancelled, isTrue);
    expect(
      calls,
      containsAll(<String>['status', 'infer', 'cancel', 'unloadModel']),
    );
  });

  test(
    'maps a missing native implementation to a safe unavailable status',
    () async {
      final runtime = EdgeRuntimeChannel(
        channel: const MethodChannel('test.edge_runtime_missing'),
      );

      final status = await runtime.status();
      expect(status.state, EdgeRuntimeState.unavailable);
      expect(status.backend, 'rules_only_fallback');
      expect(status.errorCode, 'MODEL_RUNTIME_UNAVAILABLE');

      expect(
        () => runtime.loadModel(
          const EdgeRuntimeModelSpec(
            modelId: 'edge-test',
            modelVersion: '0.1.0',
          ),
        ),
        throwsA(
          isA<EdgeRuntimeException>().having(
            (error) => error.code,
            'code',
            'MODEL_RUNTIME_UNAVAILABLE',
          ),
        ),
      );
    },
  );

  test(
    'rejects sensitive model input before crossing the platform channel',
    () async {
      final runtime = EdgeRuntimeChannel(
        channel: const MethodChannel('test.edge_runtime_sensitive'),
      );

      expect(
        () => runtime.infer(
          const EdgeRuntimeRequest(
            requestId: 'request-2',
            prompt: 'send access_token to the model',
          ),
        ),
        throwsA(
          isA<EdgeRuntimeException>().having(
            (error) => error.code,
            'code',
            'SENSITIVE_INPUT',
          ),
        ),
      );
    },
  );

  test(
    'fake runtime and coordinator return a validated native proposal',
    () async {
      final proposal = EdgeProposal(
        schemaVersion: 'edge_proposal.v1',
        surface: EdgeAppSurface.customer,
        intent: 'order.explain',
        confidence: 0.9,
        locale: 'ar-YE',
        entities: const {},
        missingFields: const [],
        riskClass: EdgeRiskClass.readOnly,
        explanationAr: 'شرح آمن.',
        requiresConfirmation: false,
        createdAt: DateTime.utc(2026, 8, 27, 10),
      );
      final fake = FakeEdgeRuntime(
        response: EdgeRuntimeInferenceResult(
          requestId: 'request-3',
          proposal: proposal.toJson(),
        ),
      );
      final coordinator = EdgeAssistantCoordinator(runtime: fake);

      final result = await coordinator.propose(
        EdgeAssistantRequest(
          requestId: 'request-3',
          surface: EdgeAppSurface.customer,
          locale: 'ar-YE',
          prompt: 'أين حالة طلبي؟',
          createdAt: DateTime.utc(2026, 8, 27, 10),
        ),
      );

      expect(result.intent, 'order.explain');
      expect(fake.inferCalls, 1);
      expect(EdgeProposalValidator.validate(result).isValid, isTrue);
    },
  );

  test('coordinator falls back when fake runtime is unavailable', () async {
    final fake = FakeEdgeRuntime(available: false);
    final coordinator = EdgeAssistantCoordinator(runtime: fake);

    final result = await coordinator.propose(
      EdgeAssistantRequest(
        requestId: 'request-4',
        surface: EdgeAppSurface.customer,
        locale: 'ar-YE',
        prompt: 'أين حالة طلبي؟',
        createdAt: DateTime.utc(2026, 8, 27, 10),
        context: const {'order_id': 'order-1'},
      ),
    );

    expect(result.intent, 'order.explain');
    expect(fake.inferCalls, 0);
  });
}
