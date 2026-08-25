import { beforeEach, describe, expect, it, vi } from "vitest";
import { TRPCError } from "@trpc/server";

const mocks = vi.hoisted(() => ({
  getDb: vi.fn(),
  requireAdmin: vi.fn(),
  requireMerchant: vi.fn(),
  writeAuditEvent: vi.fn(),
}));

vi.mock("../db", () => ({ getDb: mocks.getDb }));
vi.mock("../marketplace/access", () => ({
  requireAdmin: mocks.requireAdmin,
  requireMerchant: mocks.requireMerchant,
  writeAuditEvent: mocks.writeAuditEvent,
}));
vi.mock("../storage", () => ({ storageGetSignedUrl: vi.fn(), storagePut: vi.fn() }));

import { identityRouter } from "./identity";

const callerFor = (user: { id: number; role: string }) => identityRouter.createCaller({ user } as any);

describe("identity router authorization boundaries", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.requireAdmin.mockImplementation(async (user) => {
      if (user.role !== "admin") throw new TRPCError({ code: "FORBIDDEN" });
    });
  });

  it("resolves identity evidence only from the authenticated merchant owner, never a caller-supplied merchant id", async () => {
    const caseRow = { id: 701, merchantId: 91, status: "submitted" };
    const firstQuery = { from: () => ({ where: () => ({ limit: async () => [caseRow] }) }) };
    const secondQuery = { from: () => ({ where: async () => [{ kind: "passport" }, { kind: "selfie" }] }) };
    mocks.getDb.mockResolvedValue({ select: vi.fn().mockReturnValueOnce(firstQuery).mockReturnValueOnce(secondQuery) });
    mocks.requireMerchant.mockResolvedValue({ id: 91 });

    const result = await callerFor({ id: 44, role: "customer" }).mine();

    expect(mocks.requireMerchant).toHaveBeenCalledWith(44);
    expect(result.identityCase?.merchantId).toBe(91);
    expect(result.evidenceKinds).toEqual(["passport", "selfie"]);
  });

  it("does not leak a different merchant case when a caller attempts to supply another merchant identifier", async () => {
    const ownCase = { id: 702, merchantId: 88, status: "submitted" };
    const firstQuery = { from: () => ({ where: () => ({ limit: async () => [ownCase] }) }) };
    const secondQuery = { from: () => ({ where: async () => [{ kind: "passport" }] }) };
    mocks.getDb.mockResolvedValue({ select: vi.fn().mockReturnValueOnce(firstQuery).mockReturnValueOnce(secondQuery) });
    mocks.requireMerchant.mockResolvedValue({ id: 88 });

    const result = await (callerFor({ id: 88, role: "merchant" }).mine as any)({ merchantId: 91, identityCaseId: 701 });

    expect(mocks.requireMerchant).toHaveBeenCalledWith(88);
    expect(result.identityCase?.id).toBe(702);
    expect(result.identityCase?.merchantId).toBe(88);
    expect(result.evidenceKinds).toEqual(["passport"]);
  });

  it("rejects non-admin access before any evidence query or signed-url generation", async () => {
    await expect(callerFor({ id: 44, role: "customer" }).adminEvidenceAccess({ identityCaseId: 701 })).rejects.toMatchObject({ code: "FORBIDDEN" });
    expect(mocks.getDb).not.toHaveBeenCalled();
  });

  it("denies a merchant-role caller the administrator-only evidence route before any document lookup", async () => {
    await expect(callerFor({ id: 88, role: "merchant" }).adminEvidenceAccess({ identityCaseId: 701 })).rejects.toMatchObject({ code: "FORBIDDEN" });
    expect(mocks.getDb).not.toHaveBeenCalled();
  });

  it("does not query or disclose another merchant case when merchant ownership resolution is denied", async () => {
    const select = vi.fn();
    mocks.getDb.mockResolvedValue({ select });
    mocks.requireMerchant.mockRejectedValue(new TRPCError({ code: "FORBIDDEN" }));

    await expect(callerFor({ id: 88, role: "merchant" }).mine()).rejects.toMatchObject({ code: "FORBIDDEN" });

    expect(select).not.toHaveBeenCalled();
  });

  it("requires a documented manual decision and fails safely when the database is unavailable", async () => {
    await expect(callerFor({ id: 7, role: "admin" }).review({ identityCaseId: 701, decision: "verified", note: " " })).rejects.toMatchObject({ code: "BAD_REQUEST" });
    mocks.getDb.mockResolvedValue(null);
    await expect(callerFor({ id: 44, role: "customer" }).mine()).rejects.toMatchObject({ code: "INTERNAL_SERVER_ERROR" });
  });
});
