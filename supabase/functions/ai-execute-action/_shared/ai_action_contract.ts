export type JsonObject = Record<string, unknown>;

export type ActionSpec = {
  actionKey: string;
  actionClass: "reversible_write" | "high_impact_write";
  description: string;
  parameters: JsonObject;
  validate: (args: JsonObject) => string | null;
  toRpc: (scopeId: string, args: JsonObject, idempotencyKey: string) => { name: string; args: JsonObject };
};

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const ISO_DATETIME_RE = /^\d{4}-\d{2}-\d{2}T[^\s]{1,32}$/;

export const ACTION_TOOL_NAMES = new Set([
  "merchant.catalog_bulk_save",
  "merchant.save_price_list",
  "merchant.save_price_list_item",
  "merchant.save_promotion",
  "merchant.inventory_adjustment",
  "merchant.inventory_transfer",
  "merchant.inventory_count",
  "merchant.open_support_ticket",
]);

export const requireString = (value: unknown, min: number, max: number): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length >= min && normalized.length <= max ? normalized : null;
};

export const requireUuid = (value: unknown, optional = false): string | null => {
  if (optional && value === null) return null;
  if (typeof value !== "string" || !UUID_RE.test(value.trim())) return null;
  return value.trim();
};

export const requireInteger = (value: unknown, min: number, max: number): number | null =>
  typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : null;

const keysOnly = (args: JsonObject, allowed: string[]): string | null =>
  Object.keys(args).some((key) => !allowed.includes(key)) ? "UNKNOWN_ARGUMENT" : null;

const requiredStrings = (args: JsonObject, fields: Array<[string, number, number]>): string | null => {
  for (const [field, min, max] of fields) if (requireString(args[field], min, max) === null) return `INVALID_${field.toUpperCase()}`;
  return null;
};

const optionalStrings = (args: JsonObject, fields: Array<[string, number, number]>): string | null => {
  for (const [field, min, max] of fields) {
    if (args[field] !== undefined && args[field] !== null && requireString(args[field], min, max) === null) return `INVALID_${field.toUpperCase()}`;
  }
  return null;
};

const validateUuidField = (args: JsonObject, field: string, optional = false): string | null => {
  if (args[field] === undefined && optional) return null;
  if (args[field] === null && optional) return null;
  return requireUuid(args[field], optional) ? null : `INVALID_${field.toUpperCase()}`;
};

const validateReason = (args: JsonObject): string | null =>
  requireString(args.reason, 3, 500) ? null : "REASON_REQUIRED";

const validateRows = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["rows", "source_format"]);
  if (keysError) return keysError;
  if (!Array.isArray(args.rows) || args.rows.length < 1 || args.rows.length > 50) return "INVALID_ROWS";
  const sourceFormat = args.source_format === undefined ? "json" : args.source_format;
  if (sourceFormat !== "json" && sourceFormat !== "csv" && sourceFormat !== "xlsx") return "INVALID_SOURCE_FORMAT";
  for (const raw of args.rows) {
    const row = objectOrEmpty(raw);
    if (Object.keys(row).some((key) => !["product_id", "name", "description", "price_minor", "stock_quantity", "status", "barcode"].includes(key))) return "UNKNOWN_ROW_ARGUMENT";
    if (row.product_id !== undefined && row.product_id !== null && !requireUuid(row.product_id)) return "INVALID_PRODUCT_ID";
    if (!requireString(row.name, 2, 160) || !requireInteger(row.price_minor, 1, 2_000_000_000) || !requireInteger(row.stock_quantity, 0, 100_000)) return "INVALID_CATALOG_ROW";
    if (row.description !== undefined && row.description !== null && !requireString(row.description, 1, 2_000)) return "INVALID_DESCRIPTION";
    if (row.barcode !== undefined && row.barcode !== null && !requireString(row.barcode, 3, 128)) return "INVALID_BARCODE";
    if (row.status !== undefined && !["draft", "active", "archived", "out_of_stock"].includes(row.status as string)) return "INVALID_STATUS";
  }
  return null;
};

const validatePriceList = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["id", "name_ar", "currency", "status", "reason"]);
  return keysError ?? validateUuidField(args, "id", true) ?? requiredStrings(args, [["name_ar", 2, 120], ["currency", 3, 8], ["status", 1, 20]]) ?? (typeof args.status === "string" && ["draft", "active", "archived"].includes(args.status) ? null : "INVALID_STATUS") ?? validateReason(args);
};

const validatePriceListItem = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["id", "price_list_id", "product_id", "variant_id", "unit_price_minor", "min_quantity", "status", "reason"]);
  return keysError ?? validateUuidField(args, "id", true) ?? validateUuidField(args, "price_list_id") ?? validateUuidField(args, "product_id") ?? validateUuidField(args, "variant_id", true) ?? (requireInteger(args.unit_price_minor, 1, 2_000_000_000) ? null : "INVALID_UNIT_PRICE") ?? (requireInteger(args.min_quantity, 1, 1_000_000) ? null : "INVALID_MIN_QUANTITY") ?? (typeof args.status === "string" && ["active", "inactive"].includes(args.status) ? null : "INVALID_STATUS") ?? validateReason(args);
};

const validatePromotion = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["id", "code", "kind", "value_minor", "starts_at", "ends_at", "max_redemptions", "status", "reason"]);
  if (keysError) return keysError;
  return validateUuidField(args, "id", true) ?? requiredStrings(args, [["code", 3, 64], ["kind", 1, 12], ["status", 1, 20]]) ?? (args.kind === "percent" || args.kind === "fixed" ? null : "INVALID_KIND") ?? (requireInteger(args.value_minor, 1, 2_000_000_000) ? null : "INVALID_VALUE") ?? (args.starts_at !== undefined && args.starts_at !== null && requireString(args.starts_at, 20, 80) === null ? "INVALID_START" : null) ?? (args.ends_at !== undefined && args.ends_at !== null && requireString(args.ends_at, 20, 80) === null ? "INVALID_END" : null) ?? (args.max_redemptions !== undefined && args.max_redemptions !== null && !requireInteger(args.max_redemptions, 1, 1_000_000) ? "INVALID_MAX_REDEMPTIONS" : null) ?? (typeof args.status === "string" && ["draft", "active", "paused", "archived"].includes(args.status) ? null : "INVALID_STATUS") ?? validateReason(args);
};

const validateInventoryAdjustment = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["product_id", "location_id", "quantity_delta", "reason"]);
  return keysError ?? validateUuidField(args, "product_id") ?? validateUuidField(args, "location_id") ?? (requireInteger(args.quantity_delta, -100_000, 100_000) && args.quantity_delta !== 0 ? null : "INVALID_QUANTITY_DELTA") ?? validateReason(args);
};

const validateInventoryItems = (value: unknown, max: number, field: string): string | null => {
  if (!Array.isArray(value) || value.length < 1 || value.length > max) return `INVALID_${field.toUpperCase()}`;
  for (const raw of value) {
    const item = objectOrEmpty(raw);
    if (field === "items" && (!requireUuid(item.product_id) || !requireInteger(item.quantity, 1, 100_000))) return "INVALID_INVENTORY_ITEM";
    if (field === "count_items" && (!requireUuid(item.product_id) || !requireInteger(item.counted_quantity, 0, 100_000))) return "INVALID_COUNT_ITEM";
    if (Object.keys(item).some((key) => field === "items" ? !["product_id", "quantity"].includes(key) : !["product_id", "counted_quantity"].includes(key))) return "UNKNOWN_INVENTORY_ITEM_ARGUMENT";
  }
  return null;
};

const validateInventoryTransfer = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["from_location_id", "to_location_id", "items", "reason"]);
  return keysError ?? validateUuidField(args, "from_location_id") ?? validateUuidField(args, "to_location_id") ?? (args.from_location_id === args.to_location_id ? "SAME_LOCATION" : null) ?? validateInventoryItems(args.items, 50, "items") ?? validateReason(args);
};

const validateInventoryCount = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["location_id", "items", "reason"]);
  return keysError ?? validateUuidField(args, "location_id") ?? validateInventoryItems(args.items, 100, "count_items") ?? validateReason(args);
};

const validateSupportTicket = (args: JsonObject): string | null => {
  const keysError = keysOnly(args, ["category", "subject", "description", "priority", "merchant_order_id"]);
  if (keysError) return keysError;
  return requiredStrings(args, [["category", 2, 32], ["subject", 3, 160], ["description", 3, 4_000]]) ?? (args.priority === undefined || ["low", "normal", "high", "urgent"].includes(args.priority as string) ? null : "INVALID_PRIORITY") ?? validateUuidField(args, "merchant_order_id", true);
};

export const objectOrEmpty = (value: unknown): JsonObject =>
  value && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : {};

export const redactActionArguments = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(redactActionArguments);
  if (!value || typeof value !== "object") return value;
  const result: JsonObject = {};
  for (const [key, child] of Object.entries(value as JsonObject)) {
    if (["user_id", "buyer_user_id", "customer_user_id", "phone", "email", "address", "barcode"].includes(key.toLowerCase())) continue;
    result[key] = redactActionArguments(child);
  }
  return result;
};

const action = (actionKey: string, description: string, parameters: JsonObject, validate: (args: JsonObject) => string | null, toRpc: ActionSpec["toRpc"]): ActionSpec => ({ actionKey, actionClass: "reversible_write", description, parameters, validate, toRpc });

export const ACTION_SPECS: ActionSpec[] = [
  action("merchant.catalog_bulk_save", "Apply a bounded idempotent catalog batch after the merchant reviews it.", { type: "object", properties: { rows: { type: "array", maxItems: 50 }, source_format: { type: "string", enum: ["json", "csv", "xlsx"] } }, required: ["rows"], additionalProperties: false }, validateRows, (shopId, args, key) => ({ name: "bulk_save_products", args: { p_shop_id: shopId, p_rows: args.rows, p_idempotency_key: key, p_source_format: args.source_format ?? "json" } })),
  action("merchant.save_price_list", "Create or update an owned wholesale price list after explicit merchant approval.", { type: "object", properties: { id: { type: ["string", "null"] }, name_ar: { type: "string", minLength: 2, maxLength: 120 }, currency: { type: "string", minLength: 3, maxLength: 8 }, status: { type: "string", enum: ["draft", "active", "archived"] }, reason: { type: "string", minLength: 3, maxLength: 500 } }, required: ["name_ar", "currency", "status", "reason"], additionalProperties: false }, validatePriceList, (shopId, args) => ({ name: "save_wholesale_price_list", args: { p_id: args.id ?? null, p_shop_id: shopId, p_name_ar: args.name_ar, p_currency: args.currency, p_status: args.status, p_reason: args.reason } })),
  action("merchant.save_price_list_item", "Create or update an owned wholesale price-list line after explicit merchant approval.", { type: "object", properties: { id: { type: ["string", "null"] }, price_list_id: { type: "string" }, product_id: { type: "string" }, variant_id: { type: ["string", "null"] }, unit_price_minor: { type: "integer", minimum: 1, maximum: 2000000000 }, min_quantity: { type: "integer", minimum: 1, maximum: 1000000 }, status: { type: "string", enum: ["active", "inactive"] }, reason: { type: "string", minLength: 3, maxLength: 500 } }, required: ["price_list_id", "product_id", "unit_price_minor", "min_quantity", "status", "reason"], additionalProperties: false }, validatePriceListItem, (_shopId, args) => ({ name: "save_wholesale_price_list_item", args: { p_id: args.id ?? null, p_price_list_id: args.price_list_id, p_product_id: args.product_id, p_variant_id: args.variant_id ?? null, p_unit_price_minor: args.unit_price_minor, p_min_quantity: args.min_quantity, p_status: args.status, p_reason: args.reason } })),
  action("merchant.save_promotion", "Create or update an owned promotion after explicit merchant approval.", { type: "object", properties: { id: { type: ["string", "null"] }, code: { type: "string", minLength: 3, maxLength: 64 }, kind: { type: "string", enum: ["percent", "fixed"] }, value_minor: { type: "integer", minimum: 1, maximum: 2000000000 }, starts_at: { type: ["string", "null"] }, ends_at: { type: ["string", "null"] }, max_redemptions: { type: ["integer", "null"], minimum: 1, maximum: 1000000 }, status: { type: "string", enum: ["draft", "active", "paused", "archived"] }, reason: { type: "string", minLength: 3, maxLength: 500 } }, required: ["code", "kind", "value_minor", "status", "reason"], additionalProperties: false }, validatePromotion, (shopId, args) => ({ name: "save_merchant_promotion", args: { p_id: args.id ?? null, p_shop_id: shopId, p_code: args.code, p_kind: args.kind, p_value_minor: args.value_minor, p_starts_at: args.starts_at ?? null, p_ends_at: args.ends_at ?? null, p_max_redemptions: args.max_redemptions ?? null, p_status: args.status, p_reason: args.reason } })),
  action("merchant.inventory_adjustment", "Record one idempotent owned-shop inventory adjustment after explicit merchant approval.", { type: "object", properties: { product_id: { type: "string" }, location_id: { type: "string" }, quantity_delta: { type: "integer", minimum: -100000, maximum: 100000 }, reason: { type: "string", minLength: 3, maxLength: 500 } }, required: ["product_id", "location_id", "quantity_delta", "reason"], additionalProperties: false }, validateInventoryAdjustment, (shopId, args, key) => ({ name: "record_inventory_adjustment", args: { p_shop_id: shopId, p_product_id: args.product_id, p_location_id: args.location_id, p_quantity_delta: args.quantity_delta, p_reason: args.reason, p_idempotency_key: key } })),
  action("merchant.inventory_transfer", "Complete a bounded owned-shop inventory transfer after explicit merchant approval.", { type: "object", properties: { from_location_id: { type: "string" }, to_location_id: { type: "string" }, items: { type: "array", maxItems: 50 }, reason: { type: "string", minLength: 3, maxLength: 500 } }, required: ["from_location_id", "to_location_id", "items", "reason"], additionalProperties: false }, validateInventoryTransfer, (shopId, args, key) => ({ name: "complete_inventory_transfer", args: { p_shop_id: shopId, p_from_location_id: args.from_location_id, p_to_location_id: args.to_location_id, p_items: args.items, p_reason: args.reason, p_idempotency_key: key } })),
  action("merchant.inventory_count", "Apply a bounded owned-shop inventory count after explicit merchant approval.", { type: "object", properties: { location_id: { type: "string" }, items: { type: "array", maxItems: 100 }, reason: { type: "string", minLength: 3, maxLength: 500 } }, required: ["location_id", "items", "reason"], additionalProperties: false }, validateInventoryCount, (shopId, args, key) => ({ name: "apply_inventory_count", args: { p_shop_id: shopId, p_location_id: args.location_id, p_items: args.items, p_reason: args.reason, p_idempotency_key: key } })),
  action("merchant.open_support_ticket", "Open a merchant support ticket after explicit merchant approval.", { type: "object", properties: { category: { type: "string", minLength: 2, maxLength: 32 }, subject: { type: "string", minLength: 3, maxLength: 160 }, description: { type: "string", minLength: 3, maxLength: 4000 }, priority: { type: "string", enum: ["low", "normal", "high", "urgent"] }, merchant_order_id: { type: ["string", "null"] } }, required: ["category", "subject", "description"], additionalProperties: false }, validateSupportTicket, (_shopId, args) => ({ name: "open_support_ticket", args: { p_category: args.category, p_subject: args.subject, p_description: args.description, p_priority: args.priority ?? "normal", p_merchant_order_id: args.merchant_order_id ?? null } })),
];

export const ACTION_SPEC_BY_KEY = new Map(ACTION_SPECS.map((spec) => [spec.actionKey, spec]));

export const normalizeActionArguments = (value: unknown): JsonObject | null => {
  const args = objectOrEmpty(value);
  return Object.keys(args).length === 0 && value !== undefined ? null : args;
};
