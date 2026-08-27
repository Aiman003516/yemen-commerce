import 'dart:async';

import 'edge_artifact_store.dart';
import 'edge_assistant.dart';
import 'edge_pilot.dart';
import 'edge_runtime.dart';

enum EdgePilotSessionState { idle, preparing, ready, running, failed, closed }

class EdgeInferenceBudget {
  const EdgeInferenceBudget({
    this.maxPromptCharacters = 2000,
    this.maxOutputTokens = 256,
    this.timeout = const Duration(seconds: 20),
  });

  final int maxPromptCharacters;
  final int maxOutputTokens;
  final Duration timeout;

  EdgeRuntimeRequest requestFor(EdgeAssistantRequest request) {
    final prompt = request.prompt.trim();
    if (prompt.isEmpty || prompt.length > maxPromptCharacters) {
      throw const EdgeRuntimeException(
        code: 'INFERENCE_INPUT_LIMIT',
        messageAr: 'نص المساعد فارغ أو يتجاوز الحد المسموح.',
      );
    }
    return EdgeRuntimeRequest(
      requestId: request.requestId,
      prompt: prompt,
      context: EdgeRedactor.redact(request.context),
      maxOutputTokens: maxOutputTokens.clamp(1, 512),
      locale: request.locale,
    );
  }
}

class EdgePilotInferenceOutcome {
  const EdgePilotInferenceOutcome({
    required this.proposal,
    required this.usedFallback,
    required this.runtimeCode,
    required this.elapsed,
  });

  final EdgeProposal proposal;
  final bool usedFallback;
  final String runtimeCode;
  final Duration elapsed;
}

/// M-3 lifecycle wrapper. It prepares and loads only a verified private
/// artifact, then bounds every inference and validates every returned proposal.
/// It never registers tools and never executes a proposal.
class EdgeLocalPilotSession {
  EdgeLocalPilotSession({
    required this.controller,
    required this.downloader,
    this.fallback = const EdgeRulesOnlyAssistant(),
    this.budget = const EdgeInferenceBudget(),
  });

  final EdgePilotController controller;
  final EdgeArtifactDownloader downloader;
  final EdgeRulesOnlyAssistant fallback;
  final EdgeInferenceBudget budget;
  EdgePilotSessionState _state = EdgePilotSessionState.idle;
  EdgeArtifactCacheEntry? _artifact;
  String? _requestInFlight;

  EdgePilotSessionState get state => _state;
  EdgeArtifactCacheEntry? get artifact => _artifact;

  Future<void> start(
    EdgePilotDecision decision, {
    void Function(EdgeArtifactProgress progress)? onProgress,
  }) async {
    if (_state == EdgePilotSessionState.closed) {
      throw const EdgeRuntimeException(
        code: 'PILOT_SESSION_CLOSED',
        messageAr: 'تم إغلاق جلسة المساعد المحلي.',
      );
    }
    _state = EdgePilotSessionState.preparing;
    try {
      final artifact = await controller.prepareArtifactIfEligible(
        decision,
        downloader: downloader,
        onProgress: onProgress,
      );
      await controller.loadIfEligible(decision, verifiedArtifact: artifact);
      _artifact = artifact;
      _state = EdgePilotSessionState.ready;
    } catch (_) {
      _state = EdgePilotSessionState.failed;
      rethrow;
    }
  }

  Future<EdgePilotInferenceOutcome> infer(EdgeAssistantRequest request) async {
    final started = DateTime.now();
    final fallbackProposal = fallback.interpret(request);
    if (_state != EdgePilotSessionState.ready) {
      return EdgePilotInferenceOutcome(
        proposal: fallbackProposal,
        usedFallback: true,
        runtimeCode: 'PILOT_NOT_READY',
        elapsed: DateTime.now().difference(started),
      );
    }
    if (_requestInFlight != null) {
      return EdgePilotInferenceOutcome(
        proposal: fallbackProposal,
        usedFallback: true,
        runtimeCode: 'MODEL_BUSY',
        elapsed: DateTime.now().difference(started),
      );
    }
    _requestInFlight = request.requestId;
    _state = EdgePilotSessionState.running;
    try {
      final runtimeRequest = budget.requestFor(request);
      final result = await controller.runtime
          .infer(runtimeRequest)
          .timeout(budget.timeout);
      final proposalJson = result.proposal;
      if (proposalJson == null) {
        return _fallback(fallbackProposal, 'EMPTY_PROPOSAL', started);
      }
      final proposal = EdgeProposal.fromJson(proposalJson);
      final validation = EdgeProposalValidator.validate(
        proposal,
        now: request.createdAt,
      );
      if (!validation.isValid || proposal.surface != request.surface) {
        return _fallback(fallbackProposal, 'INVALID_PROPOSAL', started);
      }
      return EdgePilotInferenceOutcome(
        proposal: proposal,
        usedFallback: false,
        runtimeCode: 'LOCAL_PROPOSAL_VALIDATED',
        elapsed: DateTime.now().difference(started),
      );
    } on TimeoutException {
      return _fallback(fallbackProposal, 'INFERENCE_TIMEOUT', started);
    } on EdgeRuntimeException catch (error) {
      return _fallback(fallbackProposal, error.code, started);
    } finally {
      _requestInFlight = null;
      if (_state != EdgePilotSessionState.closed) {
        _state = EdgePilotSessionState.ready;
      }
    }
  }

  Future<bool> cancel() async {
    final requestId = _requestInFlight;
    if (requestId == null) return false;
    return controller.runtime.cancel(requestId);
  }

  Future<void> close() async {
    if (_state == EdgePilotSessionState.closed) return;
    await controller.runtime.unloadModel();
    _state = EdgePilotSessionState.closed;
    _artifact = null;
    _requestInFlight = null;
  }

  EdgePilotInferenceOutcome _fallback(
    EdgeProposal proposal,
    String code,
    DateTime started,
  ) => EdgePilotInferenceOutcome(
    proposal: proposal,
    usedFallback: true,
    runtimeCode: code,
    elapsed: DateTime.now().difference(started),
  );
}
