import { describe, expect, it } from "vitest";
import { marketPolicySchema } from "../../shared/domain";
import { canAdvanceFulfilment, canReviewPayment, canSubmitPaymentClaim, groupCartLinesByMerchant, hasIndependentMerchantSelections, resolveFeatureAvailability } from "./rules";

describe("multi-merchant marketplace rules", () => {
  it("splits a cross-merchant cart into one independently totalled group per merchant", () => {
    const groups = groupCartLinesByMerchant([
      { productId: 1, shopId: 10, merchantId: 100, quantity: 2, unitPriceMinor: 1500 },
      { productId: 2, shopId: 20, merchantId: 200, quantity: 1, unitPriceMinor: 3200 },
      { productId: 3, shopId: 10, merchantId: 100, quantity: 1, unitPriceMinor: 700 },
    ]);
    expect(groups).toHaveLength(2);
    expect(groups.find((group) => group.merchantId === 100)).toMatchObject({ subtotalMinor: 3700, items: expect.arrayContaining([expect.objectContaining({ productId: 1 }), expect.objectContaining({ productId: 3 })]) });
    expect(groups.find((group) => group.merchantId === 200)).toMatchObject({ subtotalMinor: 3200 });
  });

  it("does not treat a payment proof as an automatic payment confirmation", () => {
    expect(canSubmitPaymentClaim("awaiting_payment")).toBe(true);
    expect(canReviewPayment("awaiting_payment", "paid")).toBe(false);
    expect(canReviewPayment("payment_under_review", "paid")).toBe(true);
    expect(canReviewPayment("payment_under_review", "rejected")).toBe(true);
  });

  it("requires exactly one payment selection for every merchant group before split checkout", () => {
    expect(hasIndependentMerchantSelections([100, 200], [100, 200])).toBe(true);
    expect(hasIndependentMerchantSelections([100, 200], [100])).toBe(false);
    expect(hasIndependentMerchantSelections([100, 200], [100, 100])).toBe(false);
  });

  it("requires a confirmed payment before non-cancellation fulfilment", () => {
    expect(canAdvanceFulfilment("payment_under_review", "ready")).toBe(false);
    expect(canAdvanceFulfilment("paid", "ready")).toBe(true);
    expect(canAdvanceFulfilment("awaiting_payment", "cancelled")).toBe(true);
  });

  it("returns a safe Arabic reason when an optional market feature is disabled", () => {
    expect(resolveFeatureAvailability({ enabled: false, reasonAr: "الربط الآلي غير معتمد بعد." })).toEqual({ available: false, reasonAr: "الربط الآلي غير معتمد بعد." });
    expect(resolveFeatureAvailability({ enabled: true })).toEqual({ available: true, reasonAr: null });
  });

  it("validates a versioned market policy without coupling it to the Ibb pilot", () => {
    const policy = marketPolicySchema.parse({
      key: "pilot_pricing",
      version: 2,
      value: { subscriptionMinor: 0, commissionBps: 0, centralFundsCustody: false },
      effectiveFrom: null,
    });
    expect(policy.key).toBe("pilot_pricing");
    expect(policy.version).toBe(2);
  });
});
