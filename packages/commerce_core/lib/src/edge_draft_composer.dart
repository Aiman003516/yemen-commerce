import 'edge_assistant.dart';

class EdgeDraftField {
  const EdgeDraftField({
    required this.key,
    required this.value,
    required this.labelAr,
  });

  final String key;
  final String value;
  final String labelAr;

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'label_ar': labelAr,
  };
}

class EdgeDraftComposition {
  const EdgeDraftComposition({
    required this.intent,
    required this.surface,
    required this.fields,
    required this.sourceProposalHash,
    required this.isCommitted,
  });

  final String intent;
  final EdgeAppSurface surface;
  final List<EdgeDraftField> fields;
  final String sourceProposalHash;
  final bool isCommitted;

  Map<String, String> get formValues => {
    for (final field in fields) field.key: field.value,
  };

  Map<String, dynamic> toJson() => {
    'intent': intent,
    'surface': surface.value,
    'fields': fields.map((field) => field.toJson()).toList(growable: false),
    'source_proposal_hash': sourceProposalHash,
    'is_committed': isCommitted,
  };
}

class EdgeDraftComposer {
  const EdgeDraftComposer();

  EdgeDraftComposition? compose(EdgeProposal proposal) {
    final validation = EdgeProposalValidator.validate(proposal);
    if (!validation.isValid ||
        proposal.state != EdgeProposalState.proposalReady) {
      return null;
    }
    if (proposal.intent == EdgeIntentCatalog.navigationOpen) return null;
    final fields = <EdgeDraftField>[];
    final allowed = _allowedFields[proposal.intent] ?? const <String>{};
    for (final key in allowed) {
      final value = proposal.entities[key];
      if (value is String && value.trim().isNotEmpty && value.length <= 500) {
        fields.add(
          EdgeDraftField(
            key: key,
            value: value.trim(),
            labelAr: _labels[key] ?? key,
          ),
        );
      }
    }
    return EdgeDraftComposition(
      intent: proposal.intent,
      surface: proposal.surface,
      fields: List.unmodifiable(fields),
      sourceProposalHash: proposal.proposalHash,
      isCommitted: false,
    );
  }

  static const _allowedFields = <String, Set<String>>{
    'catalog.draft_description': {'title', 'description'},
    'support.draft': {'subject', 'body'},
    'governance.draft': {'title', 'summary'},
    'policy.propose': {'title', 'summary'},
  };

  static const _labels = <String, String>{
    'title': 'العنوان',
    'description': 'الوصف',
    'subject': 'الموضوع',
    'body': 'النص',
    'summary': 'الملخص',
  };
}
