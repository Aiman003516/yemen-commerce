import { describe, expect, it } from "vitest";
import { ACTION_SPEC_BY_KEY, ACTION_TOOL_NAMES, redactActionArguments } from "./ai_action_contract";

describe("AI-3 approval-bound merchant actions", () => {
  it("contains only the fixed merchant action namespace", () => {
    expect(ACTION_TOOL_NAMES.size).toBe(8);
    expect([...ACTION_TOOL_NAMES].every((name) => name.startsWith("merchant."))).toBe(true);
    expect(ACTION_SPEC_BY_KEY.has("merchant.execute_sql")).toBe(false);
  });

  it("rejects unbounded or malformed catalog and inventory arguments", () => {
    const catalog = ACTION_SPEC_BY_KEY.get("merchant.catalog_bulk_save")!;
    expect(catalog.validate({ rows: [{ name: "قهوة", price_minor: 100, stock_quantity: 4 }] })).toBeNull();
    expect(catalog.validate({ rows: Array.from({ length: 51 }, () => ({ name: "x", price_minor: 1, stock_quantity: 0 })) })).not.toBeNull();
    const adjustment = ACTION_SPEC_BY_KEY.get("merchant.inventory_adjustment")!;
    expect(adjustment.validate({ product_id: "not-a-uuid", location_id: "not-a-uuid", quantity_delta: 2, reason: "تصحيح" })).not.toBeNull();
  });

  it("maps an approved adjustment only to the existing RPC and server idempotency key", () => {
    const spec = ACTION_SPEC_BY_KEY.get("merchant.inventory_adjustment")!;
    const args = { product_id: "00000000-0000-4000-8000-000000000001", location_id: "00000000-0000-4000-8000-000000000002", quantity_delta: 2, reason: "جرد" };
    expect(spec.validate(args)).toBeNull();
    const mapped = spec.toRpc("00000000-0000-4000-8000-000000000003", args, "ai3:tool");
    expect(mapped.name).toBe("record_inventory_adjustment");
    expect(mapped.args.p_idempotency_key).toBe("ai3:tool");
    expect(mapped.args.p_shop_id).toBe("00000000-0000-4000-8000-000000000003");
  });

  it("removes private and operational-sensitive identifiers from approval previews", () => {
    const redacted = redactActionArguments({ phone: "700000000", barcode: "123", product_id: "safe", nested: { email: "x@y.invalid", reason: "ok" } }) as Record<string, unknown>;
    expect(redacted).toEqual({ product_id: "safe", nested: { reason: "ok" } });
  });
});
