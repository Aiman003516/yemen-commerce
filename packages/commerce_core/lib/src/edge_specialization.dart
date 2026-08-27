enum EdgeSpecializationState { disabled, candidate, approved, rejected }

class EdgeSpecializationCandidate {
  const EdgeSpecializationCandidate({
    required this.candidateId,
    required this.baseModelId,
    required this.baseModelVersion,
    required this.datasetVersion,
    required this.trainingCodeVersion,
    required this.licenseReviewed,
    required this.privacyReviewed,
    required this.heldOutCaseCount,
    required this.heldOutPassed,
    required this.unsafeProposalCount,
    required this.state,
  });

  final String candidateId;
  final String baseModelId;
  final String baseModelVersion;
  final String datasetVersion;
  final String trainingCodeVersion;
  final bool licenseReviewed;
  final bool privacyReviewed;
  final int heldOutCaseCount;
  final bool heldOutPassed;
  final int unsafeProposalCount;
  final EdgeSpecializationState state;

  Map<String, dynamic> toSanitizedJson() => {
    'candidate_id': candidateId,
    'base_model_id': baseModelId,
    'base_model_version': baseModelVersion,
    'dataset_version': datasetVersion,
    'training_code_version': trainingCodeVersion,
    'license_reviewed': licenseReviewed,
    'privacy_reviewed': privacyReviewed,
    'held_out_case_count': heldOutCaseCount,
    'held_out_passed': heldOutPassed,
    'unsafe_proposal_count': unsafeProposalCount,
    'state': state.name,
  };
}

class EdgeSpecializationDecision {
  const EdgeSpecializationDecision({
    required this.allowed,
    required this.code,
    required this.messageAr,
    required this.failedGates,
  });

  final bool allowed;
  final String code;
  final String messageAr;
  final List<String> failedGates;
}

class EdgeSpecializationGate {
  const EdgeSpecializationGate();

  EdgeSpecializationDecision evaluate(EdgeSpecializationCandidate candidate) {
    final failures = <String>[];
    if (candidate.state != EdgeSpecializationState.candidate) {
      failures.add('INVALID_STATE');
    }
    if (!candidate.licenseReviewed) failures.add('LICENSE_REVIEW_REQUIRED');
    if (!candidate.privacyReviewed) failures.add('PRIVACY_REVIEW_REQUIRED');
    if (candidate.heldOutCaseCount == 0) failures.add('EMPTY_HELD_OUT_SET');
    if (!candidate.heldOutPassed) failures.add('HELD_OUT_EVALUATION_FAILED');
    if (candidate.unsafeProposalCount != 0) failures.add('UNSAFE_PROPOSALS');
    if (candidate.candidateId.trim().isEmpty ||
        candidate.baseModelId.trim().isEmpty ||
        candidate.datasetVersion.trim().isEmpty ||
        candidate.trainingCodeVersion.trim().isEmpty) {
      failures.add('MISSING_REPRODUCIBILITY_ID');
    }
    return failures.isEmpty
        ? const EdgeSpecializationDecision(
            allowed: true,
            code: 'READY_FOR_CREATOR_APPROVAL',
            messageAr:
                'المرشح جاهز لموافقة المنشئ فقط؛ لم يتم تدريب أو تفعيل نموذج.',
            failedGates: [],
          )
        : EdgeSpecializationDecision(
            allowed: false,
            code: 'SPECIALIZATION_BLOCKED',
            messageAr: 'التخصيص محظور حتى اكتمال بوابات الخصوصية والتقييم.',
            failedGates: List.unmodifiable(failures),
          );
  }
}
