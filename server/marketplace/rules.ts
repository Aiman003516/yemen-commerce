import type { FulfilmentStatus, PaymentStatus } from "../../shared/domain";

export type MerchantCartLine = {
  productId: number;
  shopId: number;
  merchantId: number;
  quantity: number;
  unitPriceMinor: number;
};

export function groupCartLinesByMerchant(lines: MerchantCartLine[]) {
  const groups = new Map<number, MerchantCartLine[]>();
  for (const line of lines) groups.set(line.merchantId, [...(groups.get(line.merchantId) ?? []), line]);
  return Array.from(groups.entries()).map(([merchantId, items]) => ({
    merchantId,
    items,
    subtotalMinor: items.reduce((total, item) => total + item.quantity * item.unitPriceMinor, 0),
  }));
}

export function canSubmitPaymentClaim(status: PaymentStatus) {
  return status === "awaiting_payment";
}

export function canReviewPayment(status: PaymentStatus, next: "paid" | "rejected") {
  return status === "payment_under_review" && (next === "paid" || next === "rejected");
}

export function canAdvanceFulfilment(paymentStatus: PaymentStatus, next: Exclude<FulfilmentStatus, "pending">) {
  return next === "cancelled" || paymentStatus === "paid";
}

export function hasIndependentMerchantSelections(merchantIds: number[], paymentMerchantIds: number[]) {
  const expected = new Set(merchantIds);
  const selected = new Set(paymentMerchantIds);
  return expected.size === merchantIds.length && selected.size === paymentMerchantIds.length && expected.size === selected.size && Array.from(expected).every((id) => selected.has(id));
}

export function resolveFeatureAvailability(input: { enabled: boolean; reasonAr?: string | null }) {
  return input.enabled
    ? { available: true as const, reasonAr: null }
    : { available: false as const, reasonAr: input.reasonAr ?? "هذه الميزة غير مفعّلة في السوق الحالي." };
}
