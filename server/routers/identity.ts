import { and, eq } from "drizzle-orm";
import { TRPCError } from "@trpc/server";
import { z } from "zod";
import { identityEvidence, identityVerificationCases } from "../../drizzle/schema";
import { protectedProcedure, router } from "../_core/trpc";
import { getDb } from "../db";
import { requireAdmin, requireMerchant, writeAuditEvent } from "../marketplace/access";
import { identityStatusAfterSubmission, mayDecideManualIdentityReview, mayStartManualIdentityReview } from "../marketplace/identity";
import { storageGetSignedUrl, storagePut } from "../storage";

const imageSchema = z.object({
  base64: z.string().min(64).max(5_600_000),
  mimeType: z.enum(["image/jpeg", "image/png", "image/webp"]),
  originalName: z.string().trim().min(1).max(180),
});

function unavailable() { return new TRPCError({ code: "INTERNAL_SERVER_ERROR", message: "قاعدة البيانات غير متاحة حالياً." }); }

export const identityRouter = router({
  mine: protectedProcedure.query(async ({ ctx }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const [identityCase] = await db.select().from(identityVerificationCases).where(eq(identityVerificationCases.merchantId, merchant.id)).limit(1);
    if (!identityCase) return { identityCase: null, evidenceKinds: [] as string[] };
    const evidence = await db.select({ kind: identityEvidence.kind }).from(identityEvidence).where(eq(identityEvidence.identityCaseId, identityCase.id));
    return { identityCase, evidenceKinds: evidence.map((item) => item.kind) };
  }),
  submit: protectedProcedure.input(z.object({ consent: z.literal(true), passport: imageSchema, selfie: imageSchema })).mutation(async ({ ctx, input }) => {
    const db = await getDb();
    if (!db) throw unavailable();
    const merchant = await requireMerchant(ctx.user.id);
    const now = new Date();
    let [identityCase] = await db.select().from(identityVerificationCases).where(eq(identityVerificationCases.merchantId, merchant.id)).limit(1);
    if (!identityCase) {
      await db.insert(identityVerificationCases).values({ merchantId: merchant.id, submittedByUserId: ctx.user.id, consentAt: now, status: "submitted", retentionUntil: new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000) });
      [identityCase] = await db.select().from(identityVerificationCases).where(eq(identityVerificationCases.merchantId, merchant.id)).limit(1);
    } else {
      await db.update(identityVerificationCases).set({ consentAt: now, status: identityStatusAfterSubmission(identityCase.status), reviewedByUserId: null, reviewedAt: null, decisionNote: null }).where(eq(identityVerificationCases.id, identityCase.id));
    }
    if (!identityCase) throw unavailable();
    for (const [kind, image] of [["passport", input.passport], ["selfie", input.selfie]] as const) {
      const bytes = Buffer.from(image.base64.replace(/^data:[^;]+;base64,/, ""), "base64");
      const { key } = await storagePut(`restricted-identity/${merchant.id}/${kind}-${Date.now()}`, bytes, image.mimeType);
      const [existing] = await db.select().from(identityEvidence).where(and(eq(identityEvidence.identityCaseId, identityCase.id), eq(identityEvidence.kind, kind))).limit(1);
      const values = { identityCaseId: identityCase.id, kind, storageKey: key, mimeType: image.mimeType, originalName: image.originalName };
      if (existing) await db.update(identityEvidence).set(values).where(eq(identityEvidence.id, existing.id));
      else await db.insert(identityEvidence).values(values);
    }
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "identity.submitted", resourceType: "identity_case", resourceId: identityCase.id, metadata: { automatedBiometricMatching: false } });
    return { status: "submitted" as const };
  }),
  adminQueue: protectedProcedure.query(async ({ ctx }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    return db.select().from(identityVerificationCases).where(eq(identityVerificationCases.status, "submitted"));
  }),
  adminEvidenceAccess: protectedProcedure.input(z.object({ identityCaseId: z.number().int().positive() })).query(async ({ ctx, input }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    const [identityCase] = await db.select().from(identityVerificationCases).where(eq(identityVerificationCases.id, input.identityCaseId)).limit(1);
    if (!identityCase) throw new TRPCError({ code: "NOT_FOUND", message: "الوثائق غير متاحة." });
    if (mayStartManualIdentityReview(identityCase.status)) {
      await db.update(identityVerificationCases).set({ status: "under_review" }).where(eq(identityVerificationCases.id, identityCase.id));
    }
    const evidence = await db.select().from(identityEvidence).where(eq(identityEvidence.identityCaseId, input.identityCaseId));
    await writeAuditEvent({ actorUserId: ctx.user.id, action: "identity.evidence_accessed", resourceType: "identity_case", resourceId: input.identityCaseId, metadata: { evidenceCount: evidence.length } });
    return Promise.all(evidence.map(async (item) => ({ kind: item.kind, mimeType: item.mimeType, originalName: item.originalName, signedUrl: await storageGetSignedUrl(item.storageKey) })));
  }),
  review: protectedProcedure.input(z.object({ identityCaseId: z.number().int().positive(), decision: z.enum(["verified", "rejected"]), note: z.string().trim().min(3).max(1000) })).mutation(async ({ ctx, input }) => {
    await requireAdmin(ctx.user);
    const db = await getDb();
    if (!db) throw unavailable();
    const [identityCase] = await db.select().from(identityVerificationCases).where(eq(identityVerificationCases.id, input.identityCaseId)).limit(1);
    if (!identityCase || !mayDecideManualIdentityReview(identityCase.status, input.note)) throw new TRPCError({ code: "NOT_FOUND", message: "حالة التحقق غير متاحة للمراجعة." });
    await db.update(identityVerificationCases).set({ status: input.decision, reviewedByUserId: ctx.user.id, reviewedAt: new Date(), decisionNote: input.note }).where(eq(identityVerificationCases.id, identityCase.id));
    await writeAuditEvent({ actorUserId: ctx.user.id, action: `identity.${input.decision}`, resourceType: "identity_case", resourceId: identityCase.id, metadata: { automatedBiometricMatching: false } });
    return { status: input.decision };
  }),
});
