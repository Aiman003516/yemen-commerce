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

  it("rejects non-admin access before any evidence query or signed-url generation", async () => {
    await expect(callerFor({ id: 44, role: "customer" }).adminEvidenceAccess({ identityCaseId: 701 })).rejects.toMatchObject({ code: "FORBIDDEN" });
    expect(mocks.getDb).not.toHaveBeenCalled();
  });

  it("requires a documented manual decision and fails safely when the database is unavailable", async () => {
    await expect(callerFor({ id: 7, role: "admin" }).review({ identityCaseId: 701, decision: "verified", note: " " })).rejects.toMatchObject({ code: "BAD_REQUEST" });
    mocks.getDb.mockResolvedValue(null);
    await expect(callerFor({ id: 44, role: "customer" }).mine()).rejects.toMatchObject({ code: "INTERNAL_SERVER_ERROR" });
  });
});
