import { describe, expect, it } from "vitest";
import {
  DENIED_ACTION_CLASSES,
  READONLY_TOOL_NAMES,
  objectOrEmpty,
  parseDraftEnvelope,
  parseJsonObject,
  redactToolResult,
  requireInteger,
  requireString,
  safePolicy,
  validateCatalogArgs,
  validateCodArgs,
  validateMerchantArgs,
  validateNoArgs,
  validatePosArgs,
  validateRollupArgs,
} from "../contract";

describe("AI-1 read-only dispatcher contracts", () => {
  it("keeps the registry namespaced and free of dangerous actions", () => {
    expect(READONLY_TOOL_NAMES.size).toBe(11);
    expect([...READONLY_TOOL_NAMES].every((name) => name.includes("."))).toBe(true);
    expect([...DENIED_ACTION_CLASSES]).not.toContain("read");
  });

  it("rejects unknown, oversized, and unbounded arguments", () => {
    expect(requireString("  عربي  ", 20)).toBe("عربي");
    expect(requireString("", 20)).toBeNull();
    expect(requireString("x".repeat(21), 20)).toBeNull();
    expect(requireInteger(4, 1, 4)).toBe(4);
    expect(requireInteger(4.5, 1, 10)).toBeNull();
    expect(validateNoArgs({})).toBeNull();
    expect(validateNoArgs({ sql: "select 1" })).not.toBeNull();
    expect(validateMerchantArgs({ limit: 50, offset: 0 })).toBeNull();
    expect(validateMerchantArgs({ limit: 51 })).not.toBeNull();
    expect(validateMerchantArgs({ rpc_name: "save_product" })).not.toBeNull();
    expect(validateRollupArgs({ from: "2026-08-01", to: "2026-08-26", limit: 30 })).toBeNull();
    expect(validateRollupArgs({ from: "2026-08-01", to: "2026-08-26", limit: 31 })).not.toBeNull();
    expect(validateCatalogArgs({ query: "قهوة", limit: 40, offset: 0 })).toBeNull();
    expect(validateCatalogArgs({ url: "https://unsafe.invalid" })).not.toBeNull();
    expect(validateCodArgs({ business_date: "2026-08-26", limit: 30 })).toBeNull();
    expect(validateCodArgs({ business_date: "2026-08-26", limit: 31 })).not.toBeNull();
    expect(validatePosArgs({ from: "2026-08-01T00:00:00Z", to: "2026-08-26T00:00:00Z" })).toBeNull();
    expect(validatePosArgs({ from: "yesterday" })).not.toBeNull();
  });

  it("accepts only JSON objects as provider tool arguments", () => {
    expect(parseJsonObject('{"limit":1}')?.limit).toBe(1);
    expect(parseJsonObject("[]")).toBeNull();
    expect(parseJsonObject("not json")).toBeNull();
  });

  it("redacts identity, contact, evidence, and raw payload fields recursively", () => {
    const value = redactToolResult({
      id: "safe",
      buyer_user_id: "secret-user",
      customer: { phone: "+967000000", email: "private@example.invalid" },
      evidence: { proof_storage_key: "private/path" },
      rows: [{ merchant_id: "secret-merchant", amount_minor: 100 }],
    }) as Record<string, unknown>;
    expect(value.id).toBe("safe");
    expect(value).not.toHaveProperty("buyer_user_id");
    expect(value).not.toHaveProperty("customer.phone");
    expect(value).not.toHaveProperty("customer.email");
    expect(value).not.toHaveProperty("evidence.proof_storage_key");
    expect(value).not.toHaveProperty("rows.0.merchant_id");
  });

  it("fails closed and caps policy budgets", () => {
    const implicit = safePolicy({ status: "implicit_deny", rules: { allowed_action_classes: ["read"], max_tool_calls: 999, provider_calls_enabled: true } });
    expect(implicit.status).toBe("implicit_deny");
    expect(implicit.rules?.max_tool_calls).toBe(20);
    const malformed = safePolicy({ rules: { allowed_action_classes: "read", max_tool_calls: "999" } });
    expect(malformed.status).toBe("implicit_deny");
    expect(malformed.rules?.max_tool_calls).toBe(0);
    expect(Object.keys(objectOrEmpty([]))).toHaveLength(0);
  });

  it("accepts only a bounded structured draft envelope", () => {
    const valid = parseDraftEnvelope(JSON.stringify({
      summary: "مسودة وصف جاهزة للمراجعة.",
      drafts: [{
        kind: "product_description",
        title: "وصف المنتج",
        content: "وصف عربي قصير.",
        language: "ar",
        source_product_id: "product-1",
      }],
    }));
    expect(valid?.drafts).toHaveLength(1);
    expect(parseDraftEnvelope(JSON.stringify({ summary: "x", drafts: [{ kind: "reversible_write", title: "x", content: "x", language: "ar", source_product_id: null }] }))).toBeNull();
    expect(parseDraftEnvelope(JSON.stringify({ summary: "x", drafts: Array.from({ length: 7 }, () => ({ kind: "quote_note", title: "x", content: "x", language: "ar", source_product_id: null })) }))).toBeNull();
  });

  it("keeps customer, merchant, and developer tool namespaces separated", () => {
    expect([...READONLY_TOOL_NAMES].filter((name) => name.startsWith("customer.")).length).toBe(1);
    expect([...READONLY_TOOL_NAMES].filter((name) => name.startsWith("merchant.")).length).toBe(8);
    expect([...READONLY_TOOL_NAMES].filter((name) => name.startsWith("developer.")).length).toBe(2);
  });
});
