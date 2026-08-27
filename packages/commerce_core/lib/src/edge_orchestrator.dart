import 'dart:async';

import 'edge_assistant.dart';
import 'edge_pilot_session.dart';

enum EdgeAssistantRoute {
  rulesOnly('rules_only'),
  localModel('local_model'),
  governedCloud('governed_cloud');

  const EdgeAssistantRoute(this.value);
  final String value;
}

class EdgeOrchestratorPolicy {
  const EdgeOrchestratorPolicy({
    this.enableLocal = true,
    this.enableCloud = false,
    this.maxAttemptsPerSession = 3,
    this.allowCloudForCreator = false,
    this.cloudTimeout = const Duration(seconds: 12),
  });

  final bool enableLocal;
  final bool enableCloud;
  final int maxAttemptsPerSession;
  final bool allowCloudForCreator;
  final Duration cloudTimeout;

  bool canUseCloud(EdgeAppSurface surface) =>
      enableCloud &&
      (surface != EdgeAppSurface.creator || allowCloudForCreator);
}

class EdgeOrchestrationDecision {
  const EdgeOrchestrationDecision({
    required this.route,
    required this.code,
    required this.sanitizedContext,
    required this.localEligible,
    required this.cloudEligible,
  });

  final EdgeAssistantRoute route;
  final String code;
  final Map<String, dynamic> sanitizedContext;
  final bool localEligible;
  final bool cloudEligible;

  Map<String, dynamic> toJson() => {
    'route': route.value,
    'code': code,
    'local_eligible': localEligible,
    'cloud_eligible': cloudEligible,
    'context_keys': sanitizedContext.keys.toList(growable: false)..sort(),
  };
}

class EdgeOrchestrationResult {
  const EdgeOrchestrationResult({
    required this.proposal,
    required this.route,
    required this.code,
    required this.usedFallback,
    required this.elapsed,
    required this.decision,
  });

  final EdgeProposal proposal;
  final EdgeAssistantRoute route;
  final String code;
  final bool usedFallback;
  final Duration elapsed;
  final EdgeOrchestrationDecision decision;

  Map<String, dynamic> toSanitizedJson() => {
    'intent': proposal.intent,
    'surface': proposal.surface.value,
    'risk_class': proposal.riskClass.value,
    'route': route.value,
    'code': code,
    'used_fallback': usedFallback,
    'elapsed_ms': elapsed.inMilliseconds,
    'decision': decision.toJson(),
  };
}

abstract interface class EdgeGovernedCloudProvider {
  Future<EdgeProposal?> propose(
    EdgeAssistantRequest request, {
    required Map<String, dynamic> sanitizedContext,
    required Duration timeout,
  });
}

class EdgePrivacyBoundary {
  const EdgePrivacyBoundary();

  static const _dropKeys = <String>{
    'identity_evidence',
    'payment_proof',
    'customer_phone',
    'customer_email',
    'access_token',
    'authorization',
    'secret',
    'private_key',
    'service_role',
  };

  Map<String, dynamic> sanitize(Map<String, dynamic> context) {
    final output = <String, dynamic>{};
    for (final entry in context.entries) {
      final normalized = entry.key.toLowerCase().replaceAll('-', '_');
      if (_dropKeys.any(normalized.contains)) continue;
      final redacted = EdgeRedactor.redact(entry.value);
      if (redacted != '[REDACTED]') output[entry.key] = redacted;
    }
    return Map.unmodifiable(output);
  }
}

/// Rules-first routing boundary. The model/provider is never permitted to
/// select a cloud route or execute a tool, and all routes return proposals.
class EdgeAssistantOrchestrator {
  EdgeAssistantOrchestrator({
    this.rules = const EdgeRulesOnlyAssistant(),
    this.localSession,
    this.cloudProvider,
    this.policy = const EdgeOrchestratorPolicy(),
    this.privacy = const EdgePrivacyBoundary(),
  });

  final EdgeRulesOnlyAssistant rules;
  final EdgeLocalPilotSession? localSession;
  final EdgeGovernedCloudProvider? cloudProvider;
  final EdgeOrchestratorPolicy policy;
  final EdgePrivacyBoundary privacy;
  int _attempts = 0;

  Future<EdgeOrchestrationResult> propose(EdgeAssistantRequest request) async {
    final started = DateTime.now();
    final fallback = rules.interpret(request);
    final sanitizedContext = privacy.sanitize(request.context);
    final localEligible =
        policy.enableLocal &&
        localSession?.state == EdgePilotSessionState.ready &&
        _attempts < policy.maxAttemptsPerSession &&
        _localMayAssist(fallback);
    final cloudEligible =
        policy.canUseCloud(request.surface) &&
        cloudProvider != null &&
        _attempts < policy.maxAttemptsPerSession &&
        _localMayAssist(fallback);
    final decision = EdgeOrchestrationDecision(
      route: localEligible
          ? EdgeAssistantRoute.localModel
          : cloudEligible
          ? EdgeAssistantRoute.governedCloud
          : EdgeAssistantRoute.rulesOnly,
      code: localEligible
          ? 'LOCAL_ELIGIBLE'
          : cloudEligible
          ? 'CLOUD_ELIGIBLE_BY_POLICY'
          : 'RULES_FIRST_FALLBACK',
      sanitizedContext: sanitizedContext,
      localEligible: localEligible,
      cloudEligible: cloudEligible,
    );

    if (localEligible) {
      _attempts++;
      final outcome = await localSession!.infer(
        EdgeAssistantRequest(
          requestId: request.requestId,
          surface: request.surface,
          locale: request.locale,
          prompt: request.prompt,
          createdAt: request.createdAt,
          context: sanitizedContext,
          modelVersion: request.modelVersion,
        ),
      );
      return EdgeOrchestrationResult(
        proposal: outcome.proposal,
        route: outcome.usedFallback
            ? EdgeAssistantRoute.rulesOnly
            : EdgeAssistantRoute.localModel,
        code: outcome.runtimeCode,
        usedFallback: outcome.usedFallback,
        elapsed: DateTime.now().difference(started),
        decision: decision,
      );
    }
    if (cloudEligible) {
      _attempts++;
      try {
        final safeRequest = EdgeAssistantRequest(
          requestId: request.requestId,
          surface: request.surface,
          locale: request.locale,
          prompt: request.prompt,
          createdAt: request.createdAt,
          context: sanitizedContext,
          modelVersion: request.modelVersion,
        );
        final proposal = await cloudProvider!
            .propose(
              safeRequest,
              sanitizedContext: sanitizedContext,
              timeout: policy.cloudTimeout,
            )
            .timeout(policy.cloudTimeout);
        if (proposal != null &&
            proposal.surface == request.surface &&
            EdgeProposalValidator.validate(
              proposal,
              now: request.createdAt,
            ).isValid) {
          return EdgeOrchestrationResult(
            proposal: proposal,
            route: EdgeAssistantRoute.governedCloud,
            code: 'CLOUD_PROPOSAL_VALIDATED',
            usedFallback: false,
            elapsed: DateTime.now().difference(started),
            decision: decision,
          );
        }
      } catch (_) {
        // Cloud is an optional enhancement; failures must fall through.
      }
    }
    return EdgeOrchestrationResult(
      proposal: fallback,
      route: EdgeAssistantRoute.rulesOnly,
      code: 'RULES_ONLY',
      usedFallback: true,
      elapsed: DateTime.now().difference(started),
      decision: decision,
    );
  }

  bool _localMayAssist(EdgeProposal proposal) =>
      proposal.riskClass == EdgeRiskClass.readOnly ||
      proposal.riskClass == EdgeRiskClass.draftOnly ||
      proposal.intent == EdgeIntentCatalog.clarify;
}
