enum CreatorCapability {
  managePeople('manage_people'),
  manageMerchants('manage_merchants'),
  reviewIdentity('review_identity'),
  manageMarkets('manage_markets'),
  managePolicies('manage_policies'),
  manageCapabilities('manage_capabilities'),
  viewAudit('view_audit'),
  viewSensitiveEvidence('view_sensitive_evidence'),
  manageReports('manage_reports'),
  exportOperationalData('export_operational_data');

  const CreatorCapability(this.value);
  final String value;
}

enum CreatorRole {
  creator('creator'),
  platformOperator('platform_operator'),
  reviewAgent('review_agent'),
  supportAgent('support_agent');

  const CreatorRole(this.value);
  final String value;
}

class CreatorAccess {
  const CreatorAccess({
    required this.userId,
    required this.isCreator,
    required this.capabilities,
    required this.accountStatus,
  });
  final String userId;
  final bool isCreator;
  final Set<String> capabilities;
  final String accountStatus;

  bool can(CreatorCapability capability) =>
      isCreator || capabilities.contains(capability.value);
}
