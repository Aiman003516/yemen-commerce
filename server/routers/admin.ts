import { desc, eq } from "drizzle-orm";
import { TRPCError } from "@trpc/server";
import { z } from "zod";
import { auditEvents, capabilities, categories, marketCapabilities, merchants, reports, shops } from "../../drizzle/schema";
import { protectedProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { ensureIbbMarket, requireAdmin, writeAuditEvent } from "../marketplace/access";

function unavailable() { return new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "قاعدة البيانات غير متاحة حالياً." }); }

export const adminRouter = router({
  overview: protectedProcedure.query(async ({ ctx }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    const market = await ensureIbbMarket();
    const [pendingMerchants, pendingShops, openReports, recentAudit] = await Promise.all([
      db.select().from(merchants).where(eq(merchants.verificationStatus, "pending")),
      db.select().from(shops).where(eq(shops.status, "pending")),
      db.select().from(reports).where(eq(reports.status, "open")),
      db.select().from(auditEvents).orderBy(desc(auditEvents.createdAt)).limit(60),
    ]);
    return { market, pendingMerchants, pendingShops, openReports, recentAudit };
  }),
  approveMerchant: protectedProcedure.input(z.object({ merchantId: z.number().int().positive(), approved: z.boolean() })).mutation(async ({ ctx, input }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    await db.update(merchants).set({ verificationStatus: input.approved ? "verified" : "rejected" }).where(eq(merchants.id, input.merchantId));
    await writeAuditEvent({ actorUserId: ctx.user.id, action: input.approved ? "merchant.verified" : "merchant.rejected", resourceType: "merchant", resourceId: input.merchantId });
    return { success: true };
  }),
  approveShop: protectedProcedure.input(z.object({ shopId: z.number().int().positive(), approved: z.boolean() })).mutation(async ({ ctx, input }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    await db.update(shops).set({ status: input.approved ? "approved" : "suspended" }).where(eq(shops.id, input.shopId));
    await writeAuditEvent({ actorUserId: ctx.user.id, action: input.approved ? "shop.approved" : "shop.suspended", resourceType: "shop", resourceId: input.shopId });
    return { success: true };
  }),
  saveCategory: protectedProcedure.input(z.object({ nameAr: z.string().trim().min(2).max(120), nameEn: z.string().trim().max(120).optional(), slug: z.string().trim().regex(/^[a-z0-9-]+$/).min(2).max(140) })).mutation(async ({ ctx, input }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    const market = await ensureIbbMarket();
    await db.insert(categories).values({ marketId: market.id, nameAr: input.nameAr, nameEn: input.nameEn ?? null, slug: input.slug });
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "category.created", resourceType: "category", metadata: { slug: input.slug } });
    return { success: true };
  }),
  setCapability: protectedProcedure.input(z.object({ capabilityId: z.number().int().positive(), enabled: z.boolean(), reasonAr: z.string().trim().max(280).optional() })).mutation(async ({ ctx, input }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    const market = await ensureIbbMarket();
    const [capability] = await db.select().from(capabilities).where(eq(capabilities.id, input.capabilityId)).limit(1);
    if (!capability) throw new TRPCError({ code: "NOT_FOUND", message: "القدرة المطلوبة غير موجودة." });
    const [existing] = await db.select().from(marketCapabilities).where(eq(marketCapabilities.capabilityId, capability.id)).limit(1);
    if (existing) await db.update(marketCapabilities).set({ enabled: input.enabled, reasonAr: input.reasonAr ?? null }).where(eq(marketCapabilities.id, existing.id));
    else await db.insert(marketCapabilities).values({ marketId: market.id, capabilityId: capability.id, enabled: input.enabled, reasonAr: input.reasonAr ?? null });
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "capability.updated", resourceType: "capability", resourceId: capability.id, metadata: { enabled: input.enabled } });
    return { success: true };
  }),
});
