export type OtpProviderConfiguration = {
  providerKey: string;
  status: "disabled" | "pending_activation" | "active" | "paused";
  deliveryReportsEnabled: boolean;
  rateLimitPerMinute: number;
};

export type OtpAvailability = {
  available: boolean;
  reasonAr: string | null;
  providerKey: string | null;
};

/**
 * Provider adapters are activated only after an approved carrier or aggregator
 * contract exists. No caller may mark a phone verified while this returns false.
 */
export function resolveOtpAvailability(input: { capabilityEnabled: boolean; providers: OtpProviderConfiguration[] }): OtpAvailability {
  if (!input.capabilityEnabled) {
    return { available: false, providerKey: null, reasonAr: "التحقق من ملكية رقم الهاتف غير مفعّل حالياً." };
  }
  const provider = input.providers.find((item) => item.status === "active" && item.rateLimitPerMinute > 0);
  if (!provider) {
    return { available: false, providerKey: null, reasonAr: "لا يوجد مزود رسائل معتمد ومفعّل لهذا السوق." };
  }
  return { available: true, providerKey: provider.providerKey, reasonAr: null };
}
