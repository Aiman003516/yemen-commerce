import { z } from "zod";

/**
 * Shared v1 marketplace vocabulary. Server procedures and web UI import these
 * values directly; the Flutter client mirrors the serialized values in Dart.
 */
export const API_VERSION = "v1" as const;

export const roles = ["customer", "merchant", "admin"] as const;
export type Role = (typeof roles)[number];

export const marketStatuses = ["draft", "active", "paused"] as const;
export type MarketStatus = (typeof marketStatuses)[number];

export const shopStatuses = ["draft", "pending", "approved", "suspended"] as const;
export type ShopStatus = (typeof shopStatuses)[number];

export const productStatuses = ["draft", "active", "archived", "out_of_stock"] as const;
export type ProductStatus = (typeof productStatuses)[number];

export const paymentModes = ["manual", "provider_api"] as const;
export type PaymentMode = (typeof paymentModes)[number];

export const providerVerificationStates = ["manual_only", "pending", "verified"] as const;
export type ProviderVerificationState = (typeof providerVerificationStates)[number];

export const proofRequirements = ["none", "reference", "screenshot", "both"] as const;
export type ProofRequirement = (typeof proofRequirements)[number];

export const paymentStatuses = [
  "awaiting_payment",
  "payment_under_review",
  "paid",
  "rejected",
  "cancelled",
] as const;
export type PaymentStatus = (typeof paymentStatuses)[number];

export const fulfilmentMethods = ["collection", "digital", "seller_arranged"] as const;
export type FulfilmentMethod = (typeof fulfilmentMethods)[number];

export const fulfilmentStatuses = ["pending", "ready", "arranged", "completed", "cancelled"] as const;
export type FulfilmentStatus = (typeof fulfilmentStatuses)[number];

export const capabilityKeys = [
  "manual_payments",
  "payment_proof_upload",
  "digital_delivery",
  "seller_arranged_fulfilment",
  "notifications",
  "provider_api_payments",
  "support_agent",
  "phone_otp_verification",
  "merchant_identity_verification",
] as const;
export type CapabilityKey = (typeof capabilityKeys)[number];

export const phoneVerificationStatuses = ["unverified", "pending", "verified"] as const;
export type PhoneVerificationStatus = (typeof phoneVerificationStatuses)[number];

/** Manual staff-review states only; upload never makes an identity decision automatically. */
export const identityVerificationStatuses = ["draft", "submitted", "under_review", "verified", "rejected", "expired"] as const;
export type IdentityVerificationStatus = (typeof identityVerificationStatuses)[number];

export const identityEvidenceKinds = ["passport", "selfie"] as const;
export type IdentityEvidenceKind = (typeof identityEvidenceKinds)[number];

export const marketConfigSchema = z.object({
  id: z.number().int().positive(),
  governorate: z.string().min(1),
  city: z.string().min(1),
  district: z.string().nullable().optional(),
  serviceArea: z.string().nullable().optional(),
  status: z.enum(marketStatuses),
  currency: z.string().length(3),
  isPilot: z.boolean(),
});
export type MarketConfig = z.infer<typeof marketConfigSchema>;

export const merchantCartGroupSchema = z.object({
  merchantId: z.number().int().positive(),
  shopId: z.number().int().positive(),
  subtotalMinor: z.number().int().nonnegative(),
  feeMinor: z.number().int().nonnegative(),
  taxMinor: z.number().int().nonnegative(),
  totalMinor: z.number().int().nonnegative(),
  currency: z.string().length(3),
  fulfilmentMethods: z.array(z.enum(fulfilmentMethods)),
});
export type MerchantCartGroup = z.infer<typeof merchantCartGroupSchema>;

export const orderPaymentSnapshotSchema = z.object({
  paymentMethodName: z.string().min(1),
  accountHolderName: z.string().min(1),
  receivingIdentifier: z.string().min(1),
  currency: z.string().length(3),
  exactAmountMinor: z.number().int().positive(),
  customerInstructions: z.string().min(1),
  proofRequirement: z.enum(proofRequirements),
  orderReference: z.string().min(1),
});
export type OrderPaymentSnapshot = z.infer<typeof orderPaymentSnapshotSchema>;

export const featureAvailabilitySchema = z.object({
  key: z.enum(capabilityKeys),
  enabled: z.boolean(),
  reasonAr: z.string().nullable().optional(),
});
export type FeatureAvailability = z.infer<typeof featureAvailabilitySchema>;

export const marketPolicySchema = z.object({
  key: z.string().min(1).max(80),
  version: z.number().int().positive(),
  value: z.record(z.string(), z.unknown()),
  effectiveFrom: z.date().nullable().optional(),
});
export type MarketPolicy = z.infer<typeof marketPolicySchema>;

export function minorToDisplay(amountMinor: number, currency = "YER") {
  return new Intl.NumberFormat("ar-YE", {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(amountMinor);
}
