import { and, eq } from "drizzle-orm";
import { TRPCError } from "@trpc/server";
import { auditEvents, capabilities, marketCapabilities, marketPolicyVersions, markets, merchants, userRoles } from "../../drizzle/schema";
import { getDb } from "../db";
import type { CapabilityKey, Role } from "../../shared/domain";
import { resolveActivePolicies } from "./policies";

const IBB_DEFAULT = {
  governorate: "إب",
  city: "إب",
  status: "active" as const,
  currency: "YER",
  isPilot: true,
};

const DEFAULT_CAPABILITIES: Array<{ key: CapabilityKey; enabled: boolean; reasonAr?: string }> = [
  { key: "manual_payments", enabled: true },
  { key: "payment_proof_upload", enabled: true },
  { key: "digital_delivery", enabled: true },
  { key: "seller_arranged_fulfilment", enabled: true },
  { key: "notifications", enabled: false, reasonAr: "سيتم تفعيل الإشعارات في مرحلة لاحقة." },
  { key: "provider_api_payments", enabled: false, reasonAr: "تظل عمليات الدفع يدوية حتى اعتماد مزود الدفع رسمياً." },
  { key: "support_agent", enabled: false, reasonAr: "دور الدعم محدود ومؤجل في مرحلة الإطلاق." },
  { key: "phone_otp_verification", enabled: false, reasonAr: "سيُفعّل التحقق من ملكية الهاتف بعد اعتماد مزود رسائل مناسب." },
];

const DEFAULT_POLICIES = [
  { key: "pilot_pricing", value: { subscriptionMinor: 0, commissionBps: 0, centralFundsCustody: false } },
  { key: "merchant_verification", value: { approvalRequired: true, phoneRequired: true, locationRequired: true } },
  { key: "fulfilment", value: { enabledMethods: ["collection", "digital", "seller_arranged"], platformManagedShipping: false } },
];

function databaseUnavailable() {
  return new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "قاعدة البيانات غير متاحة حالياً." });
}

/** Creates only the required live Ibb market configuration; no mock shops, products, reviews, or orders are created. */
export async function ensureIbbMarket() {
  const db = await getDb();
  if (!db) throw databaseUnavailable();

  let [market] = await db.select().from(markets).where(and(eq(markets.governorate, IBB_DEFAULT.governorate), eq(markets.city, IBB_DEFAULT.city))).limit(1);
  if (!market) {
    await db.insert(markets).values(IBB_DEFAULT);
    [market] = await db.select().from(markets).where(and(eq(markets.governorate, IBB_DEFAULT.governorate), eq(markets.city, IBB_DEFAULT.city))).limit(1);
  }
  if (!market) throw databaseUnavailable();

  for (const capability of DEFAULT_CAPABILITIES) {
    let [existing] = await db.select().from(capabilities).where(eq(capabilities.key, capability.key)).limit(1);
    if (!existing) {
      await db.insert(capabilities).values({ key: capability.key, defaultEnabled: capability.enabled });
      [existing] = await db.select().from(capabilities).where(eq(capabilities.key, capability.key)).limit(1);
    }
    if (!existing) continue;
    const [override] = await db.select().from(marketCapabilities).where(and(eq(marketCapabilities.marketId, market.id), eq(marketCapabilities.capabilityId, existing.id))).limit(1);
    if (!override) {
      await db.insert(marketCapabilities).values({ marketId: market.id, capabilityId: existing.id, enabled: capability.enabled, reasonAr: capability.reasonAr ?? null });
    }
  }

  for (const policy of DEFAULT_POLICIES) {
    const [existing] = await db.select().from(marketPolicyVersions).where(and(eq(marketPolicyVersions.marketId, market.id), eq(marketPolicyVersions.key, policy.key), eq(marketPolicyVersions.version, 1))).limit(1);
    if (!existing) await db.insert(marketPolicyVersions).values({ marketId: market.id, key: policy.key, version: 1, valueJson: JSON.stringify(policy.value), isActive: true });
  }

  return market;
}

export async function getMarketCapabilities(marketId: number) {
  const db = await getDb();
  if (!db) throw databaseUnavailable();
  return db.select({ key: capabilities.key, enabled: marketCapabilities.enabled, reasonAr: marketCapabilities.reasonAr })
    .from(marketCapabilities)
    .innerJoin(capabilities, eq(marketCapabilities.capabilityId, capabilities.id))
    .where(eq(marketCapabilities.marketId, marketId));
}

export async function getActiveMarket(marketId?: number) {
  const db = await getDb();
  if (!db) throw databaseUnavailable();
  if (!marketId) return ensureIbbMarket();
  const [market] = await db.select().from(markets).where(and(eq(markets.id, marketId), eq(markets.status, "active"))).limit(1);
  if (!market) throw new TRPCError({ code: "NOT_FOUND", message: "السوق المطلوب غير متاح حالياً." });
  return market;
}

export async function getActiveMarketPolicies(marketId: number) {
  const db = await getDb();
  if (!db) throw databaseUnavailable();
  const rows = await db.select().from(marketPolicyVersions).where(eq(marketPolicyVersions.marketId, marketId));
  return resolveActivePolicies(rows);
}

export async function getUserRoles(userId: number): Promise<Role[]> {
  const db = await getDb();
  if (!db) throw databaseUnavailable();
  const rows = await db.select({ role: userRoles.role }).from(userRoles).where(eq(userRoles.userId, userId));
  return rows.map((row) => row.role as Role);
}

export async function requireAdmin(user: { id: number; role: string }) {
  if (user.role === "admin") return;
  const roles = await getUserRoles(user.id);
  if (!roles.includes("admin")) throw new TRPCError({ code: "FORBIDDEN", message: "هذه العملية متاحة للإدارة فقط." });
}

/** A merchant context is always resolved from the authenticated owner, never from client-supplied IDs. */
export async function requireMerchant(userId: number) {
  const db = await getDb();
  if (!db) throw databaseUnavailable();
  const [merchant] = await db.select().from(merchants).where(eq(merchants.ownerUserId, userId)).limit(1);
  if (!merchant) throw new TRPCError({ code: "FORBIDDEN", message: "حساب التاجر غير مهيأ لهذا المستخدم." });
  return merchant;
}

export async function writeAuditEvent(input: {
  actorUserId?: number;
  action: string;
  resourceType: string;
  resourceId?: string | number;
  metadata?: Record<string, unknown>;
}) {
  const db = await getDb();
  if (!db) throw databaseUnavailable();
  await db.insert(auditEvents).values({
    actorUserId: input.actorUserId ?? null,
    action: input.action,
    resourceType: input.resourceType,
    resourceId: input.resourceId === undefined ? null : String(input.resourceId),
    metadataJson: input.metadata ? JSON.stringify(input.metadata) : null,
  });
}
