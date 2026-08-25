import { describe, expect, it } from "vitest";
import { policyOrFallback, resolveActivePolicies } from "./policies";

describe("market policy resolution", () => {
  const now = new Date("2026-08-25T00:00:00.000Z");

  it("selects the latest active effective version for each policy key", () => {
    const policies = resolveActivePolicies([
      { key: "pricing", version: 1, valueJson: '{"commissionBps":0}', isActive: true, effectiveFrom: null },
      { key: "pricing", version: 2, valueJson: '{"commissionBps":250}', isActive: true, effectiveFrom: new Date("2026-08-01T00:00:00.000Z") },
      { key: "fulfilment", version: 1, valueJson: '{"collection":true}', isActive: true, effectiveFrom: null },
    ], now);
    expect(policyOrFallback(policies, "pricing", {})).toEqual({ commissionBps: 250 });
    expect(policyOrFallback(policies, "fulfilment", {})).toEqual({ collection: true });
  });

  it("excludes inactive and future policies and returns a safe fallback when none is available", () => {
    const policies = resolveActivePolicies([
      { key: "payments", version: 1, valueJson: '{"providerApi":true}', isActive: false, effectiveFrom: null },
      { key: "payments", version: 2, valueJson: '{"providerApi":true}', isActive: true, effectiveFrom: new Date("2026-09-01T00:00:00.000Z") },
    ], now);
    expect(policies).toEqual([]);
    expect(policyOrFallback(policies, "payments", { providerApi: false })).toEqual({ providerApi: false });
  });
});
