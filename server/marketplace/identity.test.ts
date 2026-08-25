import { describe, expect, it } from "vitest";
import { canAccessIdentityEvidence, identityStatusAfterSubmission, mayDecideManualIdentityReview, mayStartManualIdentityReview } from "./identity";

describe("manual merchant identity verification", () => {
  it("keeps new evidence in staff-review submission state, never verified automatically", () => {
    expect(identityStatusAfterSubmission(null)).toBe("submitted");
    expect(identityStatusAfterSubmission("rejected")).toBe("submitted");
    expect(identityStatusAfterSubmission("submitted")).not.toBe("verified");
  });

  it("requires a staff-review transition and a documented decision", () => {
    expect(mayStartManualIdentityReview("submitted")).toBe(true);
    expect(mayStartManualIdentityReview("verified")).toBe(false);
    expect(mayDecideManualIdentityReview("under_review", "تطابقت الوثائق يدوياً")).toBe(true);
    expect(mayDecideManualIdentityReview("under_review", " ")).toBe(false);
  });

  it("does not allow a different merchant or customer to access identity evidence", () => {
    expect(canAccessIdentityEvidence({ requesterRole: "admin", isCaseMerchant: false })).toBe(true);
    expect(canAccessIdentityEvidence({ requesterRole: "merchant", isCaseMerchant: true })).toBe(true);
    expect(canAccessIdentityEvidence({ requesterRole: "merchant", isCaseMerchant: false })).toBe(false);
    expect(canAccessIdentityEvidence({ requesterRole: "customer", isCaseMerchant: false })).toBe(false);
  });
});
