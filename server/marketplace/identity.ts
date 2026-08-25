export type IdentityVerificationStatus = "draft" | "submitted" | "under_review" | "verified" | "rejected" | "expired";

/** Evidence upload requests staff review; it must never verify the merchant automatically. */
export function identityStatusAfterSubmission(previous: IdentityVerificationStatus | null): IdentityVerificationStatus {
  return previous === "verified" || previous === "rejected" || previous === null ? "submitted" : "submitted";
}

export function mayStartManualIdentityReview(status: IdentityVerificationStatus): boolean {
  return status === "submitted";
}

export function mayDecideManualIdentityReview(status: IdentityVerificationStatus, reason: string): boolean {
  return status === "submitted" || status === "under_review" ? reason.trim().length >= 3 : false;
}

export function canAccessIdentityEvidence({ requesterRole, isCaseMerchant }: { requesterRole: "customer" | "merchant" | "admin"; isCaseMerchant: boolean }): boolean {
  return requesterRole === "admin" || (requesterRole === "merchant" && isCaseMerchant);
}
