import { and, eq } from "drizzle-orm";
import { TRPCError } from "@trpc/server";
import { z } from "zod";
import { merchantOrders, orderStatusHistory, paymentClaims, paymentProofs } from "../../drizzle/schema";
import { protectedProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { requireMerchant, writeAuditEvent } from "../marketplace/access";
import { storagePut } from "../storage";

const proofSchema = z.object({
  base64: z.string().min(1).max(2_800_000),
  mimeType: z.enum(["image/jpeg", "image/png", "image/webp"]),
  originalName: z.string().trim().min(1).max(160),
}).optional();

function unavailable() {
  return new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "قاعدة البيانات غير متاحة حالياً." });
}

export const paymentRouter = router({
  submitClaim: protectedProcedure.input(z.object({ merchantOrderId: z.number().int().positive(), transactionReference: z.string().trim().max(180).optional(), proof: proofSchema })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const [order] = await db.select().from(merchantOrders).where(eq(merchantOrders.id, input.merchantOrderId)).limit(1);
    if (!order || order.customerUserId !== ctx.user.id) throw new TRPCError({ code: "NOT_FOUND", message: "طلب الدفع غير موجود." });
    if (order.paymentStatus !== "awaiting_payment") throw new TRPCError({ code: "BAD_REQUEST", message: "لا يمكن تقديم مطالبة دفع في هذه الحالة." });
    const referenceRequired = order.proofRequirement === "reference" || order.proofRequirement === "both";
    const imageRequired = order.proofRequirement === "screenshot" || order.proofRequirement === "both";
    if (referenceRequired && !input.transactionReference) throw new TRPCError({ code: "BAD_REQUEST", message: "أدخل رقم مرجع التحويل." });
    if (imageRequired && !input.proof) throw new TRPCError({ code: "BAD_REQUEST", message: "أرفق صورة إثبات التحويل." });
    if (!input.transactionReference && !input.proof) throw new TRPCError({ code: "BAD_REQUEST", message: "أدخل مرجع التحويل أو أرفق إثباتاً." });

    await db.insert(paymentClaims).values({ merchantOrderId: order.id, customerUserId: ctx.user.id, transactionReference: input.transactionReference ?? null });
    const [claim] = await db.select().from(paymentClaims).where(and(eq(paymentClaims.merchantOrderId, order.id), eq(paymentClaims.customerUserId, ctx.user.id))).orderBy(paymentClaims.id).limit(1);
    if (!claim) throw unavailable();
    if (input.proof) {
      const bytes = Buffer.from(input.proof.base64.replace(/^data:[^;]+;base64,/, ""), "base64");
      const { key } = await storagePut(`payment-proofs/${order.id}/${input.proof.originalName}`, bytes, input.proof.mimeType);
      await db.insert(paymentProofs).values({ paymentClaimId: claim.id, storageKey: key, mimeType: input.proof.mimeType, originalName: input.proof.originalName });
    }
    await db.update(merchantOrders).set({ paymentStatus: "payment_under_review" }).where(eq(merchantOrders.id, order.id));
    await db.insert(orderStatusHistory).values({ merchantOrderId: order.id, actorUserId: ctx.user.id, eventType: "payment_claim_submitted", previousValue: "awaiting_payment", nextValue: "payment_under_review" });
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "payment.claim_submitted", resourceType: "merchant_order", resourceId: order.id });
    return { paymentStatus: "payment_under_review" as const };
  }),
  reviewClaim: protectedProcedure.input(z.object({ merchantOrderId: z.number().int().positive(), decision: z.enum(["paid", "rejected"]), reason: z.string().trim().max(800).optional() })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const [order] = await db.select().from(merchantOrders).where(eq(merchantOrders.id, input.merchantOrderId)).limit(1);
    if (!order || order.merchantId !== merchant.id) throw new TRPCError({ code: "NOT_FOUND", message: "طلب التاجر غير موجود." });
    if (order.paymentStatus !== "payment_under_review") throw new TRPCError({ code: "BAD_REQUEST", message: "لا توجد مطالبة دفع معلقة للمراجعة." });
    if (input.decision === "rejected" && !input.reason) throw new TRPCError({ code: "BAD_REQUEST", message: "أدخل سبب رفض مطالبة الدفع." });
    await db.update(merchantOrders).set({ paymentStatus: input.decision }).where(eq(merchantOrders.id, order.id));
    await db.update(paymentClaims).set({ reviewedByUserId: ctx.user.id, reviewedAt: new Date(), reviewNote: input.reason ?? null }).where(eq(paymentClaims.merchantOrderId, order.id));
    await db.insert(orderStatusHistory).values({ merchantOrderId: order.id, actorUserId: ctx.user.id, eventType: "payment_reviewed", previousValue: "payment_under_review", nextValue: input.decision, reason: input.reason ?? null });
    await writeAuditEvent({ actorUserId: ctx.user.id, action: `payment.claim_${input.decision}`, resourceType: "merchant_order", resourceId: order.id });
    return { paymentStatus: input.decision };
  }),
});
