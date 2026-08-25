import { and, desc, eq, inArray } from "drizzle-orm";
import { TRPCError } from "@trpc/server";
import { z } from "zod";
import { merchantOrders, merchants, paymentMethods, products, shopFulfilmentMethods, shops, userRoles } from "../../drizzle/schema";
import { protectedProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { getActiveMarket, requireMerchant, writeAuditEvent } from "../marketplace/access";

const paymentSchema = z.object({
  name: z.string().trim().min(2).max(120),
  accountHolderName: z.string().trim().min(2).max(160),
  receivingIdentifier: z.string().trim().min(3).max(220),
  customerInstructions: z.string().trim().min(10).max(2000),
  proofRequirement: z.enum(["none", "reference", "screenshot", "both"]),
});

function unavailable() { return new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "قاعدة البيانات غير متاحة حالياً." }); }

export const merchantRouter = router({
  mine: protectedProcedure.query(async ({ ctx }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const [merchant] = await db.select().from(merchants).where(eq(merchants.ownerUserId, ctx.user.id)).limit(1);
    if (!merchant) return { merchant: null, shops: [], products: [], paymentMethods: [], orders: [] };
    const merchantShops = await db.select().from(shops).where(eq(shops.merchantId, merchant.id));
    const shopIds = merchantShops.map((shop) => shop.id);
    const merchantProducts = shopIds.length ? await db.select().from(products).where(inArray(products.shopId, shopIds)) : [];
    const methods = await db.select().from(paymentMethods).where(eq(paymentMethods.merchantId, merchant.id));
    const orders = await db.select().from(merchantOrders).where(eq(merchantOrders.merchantId, merchant.id)).orderBy(desc(merchantOrders.createdAt));
    return { merchant, shops: merchantShops, products: merchantProducts, paymentMethods: methods, orders };
  }),
  submitApplication: protectedProcedure.input(z.object({ phone: z.string().trim().min(7).max(32), ownerName: z.string().trim().min(3).max(160), marketId: z.number().int().positive().optional() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const [existing] = await db.select().from(merchants).where(eq(merchants.ownerUserId, ctx.user.id)).limit(1);
    if (existing) throw new TRPCError({ code: "CONFLICT", message: "لديك طلب تاجر أو حساب تاجر قائم." });
    const market = await getActiveMarket(input.marketId);
    await db.insert(merchants).values({ ownerUserId: ctx.user.id, marketId: market.id, phone: input.phone, ownerName: input.ownerName, verificationStatus: "pending" });
    const [merchant] = await db.select().from(merchants).where(eq(merchants.ownerUserId, ctx.user.id)).limit(1);
    if (!merchant) throw unavailable();
    await db.insert(userRoles).values({ userId: ctx.user.id, role: "merchant", marketId: market.id });
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "merchant.application_created", resourceType: "merchant", resourceId: merchant.id, metadata: { marketId: market.id } });
    return merchant;
  }),
  createShop: protectedProcedure.input(z.object({ name: z.string().trim().min(3).max(160), slug: z.string().trim().regex(/^[a-z0-9-]+$/).min(3).max(180), description: z.string().trim().max(2000).optional(), areaLabel: z.string().trim().max(160).optional(), accentColor: z.string().regex(/^#[0-9a-fA-F]{6}$/).optional() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    await db.insert(shops).values({ merchantId: merchant.id, marketId: merchant.marketId, name: input.name, slug: input.slug, description: input.description ?? null, areaLabel: input.areaLabel ?? null, accentColor: input.accentColor ?? "#006A63", status: "pending" });
    const [shop] = await db.select().from(shops).where(eq(shops.slug, input.slug)).limit(1);
    if (!shop) throw unavailable();
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "shop.submitted", resourceType: "shop", resourceId: shop.id });
    return shop;
  }),
  saveProduct: protectedProcedure.input(z.object({ id: z.number().int().positive().optional(), shopId: z.number().int().positive(), categoryId: z.number().int().positive().optional(), name: z.string().trim().min(2).max(180), description: z.string().trim().max(3000).optional(), priceMinor: z.number().int().positive(), stockQuantity: z.number().int().min(0).max(100000), status: z.enum(["draft", "active", "archived", "out_of_stock"]) })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const [shop] = await db.select().from(shops).where(and(eq(shops.id, input.shopId), eq(shops.merchantId, merchant.id))).limit(1);
    if (!shop) throw new TRPCError({ code: "NOT_FOUND", message: "متجر التاجر غير موجود." });
    const values = { shopId: shop.id, categoryId: input.categoryId ?? null, name: input.name, description: input.description ?? null, priceMinor: input.priceMinor, stockQuantity: input.stockQuantity, status: input.stockQuantity === 0 && input.status === "active" ? "out_of_stock" as const : input.status };
    if (input.id) {
      const [existing] = await db.select().from(products).where(and(eq(products.id, input.id), eq(products.shopId, shop.id))).limit(1);
      if (!existing) throw new TRPCError({ code: "NOT_FOUND", message: "المنتج غير موجود ضمن متجرك." });
      await db.update(products).set(values).where(eq(products.id, existing.id));
      return { id: existing.id, updated: true };
    }
    await db.insert(products).values(values);
    return { created: true };
  }),
  savePaymentMethod: protectedProcedure.input(paymentSchema.extend({ id: z.number().int().positive().optional() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const values = { merchantId: merchant.id, name: input.name, accountHolderName: input.accountHolderName, receivingIdentifier: input.receivingIdentifier, customerInstructions: input.customerInstructions, proofRequirement: input.proofRequirement, mode: "manual" as const, providerVerification: "manual_only" as const, isActive: true };
    if (input.id) {
      const [existing] = await db.select().from(paymentMethods).where(and(eq(paymentMethods.id, input.id), eq(paymentMethods.merchantId, merchant.id))).limit(1);
      if (!existing) throw new TRPCError({ code: "NOT_FOUND", message: "طريقة الدفع غير موجودة ضمن حساب التاجر." });
      await db.update(paymentMethods).set(values).where(eq(paymentMethods.id, existing.id));
      return { id: existing.id, updated: true };
    }
    await db.insert(paymentMethods).values(values);
    return { created: true };
  }),
  setFulfilment: protectedProcedure.input(z.object({ shopId: z.number().int().positive(), method: z.enum(["collection", "digital", "seller_arranged"]), instructions: z.string().trim().max(2000).optional(), isActive: z.boolean() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const [shop] = await db.select().from(shops).where(and(eq(shops.id, input.shopId), eq(shops.merchantId, merchant.id))).limit(1);
    if (!shop) throw new TRPCError({ code: "NOT_FOUND", message: "متجر التاجر غير موجود." });
    const [existing] = await db.select().from(shopFulfilmentMethods).where(and(eq(shopFulfilmentMethods.shopId, shop.id), eq(shopFulfilmentMethods.method, input.method))).limit(1);
    if (existing) await db.update(shopFulfilmentMethods).set({ instructions: input.instructions ?? null, isActive: input.isActive }).where(eq(shopFulfilmentMethods.id, existing.id));
    else await db.insert(shopFulfilmentMethods).values({ shopId: shop.id, method: input.method, instructions: input.instructions ?? null, isActive: input.isActive });
    return { success: true };
  }),
  updateFulfilment: protectedProcedure.input(z.object({ merchantOrderId: z.number().int().positive(), fulfilmentStatus: z.enum(["ready", "arranged", "completed", "cancelled"]), reason: z.string().trim().max(800).optional() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const [order] = await db.select().from(merchantOrders).where(and(eq(merchantOrders.id, input.merchantOrderId), eq(merchantOrders.merchantId, merchant.id))).limit(1);
    if (!order) throw new TRPCError({ code: "NOT_FOUND", message: "طلب التاجر غير موجود." });
    if (input.fulfilmentStatus !== "cancelled" && order.paymentStatus !== "paid") throw new TRPCError({ code: "BAD_REQUEST", message: "لا يمكن بدء التنفيذ قبل تأكيد استلام الدفع." });
    await db.update(merchantOrders).set({ fulfilmentStatus: input.fulfilmentStatus }).where(eq(merchantOrders.id, order.id));
    await writeAuditEvent({ actorUserId: ctx.user.id, action: `fulfilment.${input.fulfilmentStatus}`, resourceType: "merchant_order", resourceId: order.id, metadata: { reason: input.reason } });
    return { fulfilmentStatus: input.fulfilmentStatus };
  }),
});
