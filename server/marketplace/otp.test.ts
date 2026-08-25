import { describe, expect, it } from "vitest";
import { resolveOtpAvailability } from "./otp";

describe("deferred carrier OTP availability", () => {
  it("keeps collected phone numbers unverified while the market capability is disabled", () => {
    expect(resolveOtpAvailability({ capabilityEnabled: false, providers: [{ providerKey: "yemen-mobile", status: "active", deliveryReportsEnabled: true, rateLimitPerMinute: 30 }] }))
      .toMatchObject({ available: false, providerKey: null });
  });

  it("requires an active, rate-limited provider before verification can start", () => {
    expect(resolveOtpAvailability({ capabilityEnabled: true, providers: [{ providerKey: "sabafon", status: "pending_activation", deliveryReportsEnabled: false, rateLimitPerMinute: 0 }] }))
      .toMatchObject({ available: false });
    expect(resolveOtpAvailability({ capabilityEnabled: true, providers: [{ providerKey: "you", status: "active", deliveryReportsEnabled: true, rateLimitPerMinute: 20 }] }))
      .toEqual({ available: true, providerKey: "you", reasonAr: null });
  });
});
