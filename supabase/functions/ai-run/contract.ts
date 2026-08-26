export type JsonObject = Record<string, unknown>;

export const READONLY_TOOL_NAMES = new Set([
  "customer.list_own_quotes",
  "merchant.order_workbench",
  "merchant.daily_rollups",
  "merchant.price_lists",
  "developer.provider_readiness",
  "developer.effective_policies",
]);

export const DENIED_ACTION_CLASSES = new Set([
  "draft",
  "reversible_write",
  "high_impact_write",
  "external_side_effect",
  "sensitive_read",
]);

export const MAX_INPUT_CHARS = 4_000;
export const MAX_TOOL_RESULT_CHARS = 6_000;

export const requireString = (value: unknown, max: number): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 && normalized.length <= max ? normalized : null;
};

export const requireInteger = (value: unknown, min: number, max: number): number | null => {
  if (typeof value !== "number" || !Number.isInteger(value)) return null;
  return value >= min && value <= max ? value : null;
};

export const objectOrEmpty = (value: unknown): JsonObject => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as JsonObject;
};

export const validateNoArgs = (args: JsonObject): string | null =>
  Object.keys(args).length === 0 ? null : "NO_ARGUMENTS_ALLOWED";

export const validateMerchantArgs = (args: JsonObject): string | null => {
  const keys = Object.keys(args);
  if (keys.some((key) => !["limit", "offset", "query", "fulfilment_status", "payment_status", "cod_status", "from", "to"].includes(key))) return "UNKNOWN_ARGUMENT";
  if (args.limit !== undefined && requireInteger(args.limit, 1, 50) === null) return "INVALID_LIMIT";
  if (args.offset !== undefined && requireInteger(args.offset, 0, 10_000) === null) return "INVALID_OFFSET";
  for (const key of ["query", "fulfilment_status", "payment_status", "cod_status", "from", "to"]) {
    if (args[key] !== undefined && requireString(args[key], 120) === null) return "INVALID_FILTER";
  }
  return null;
};

export const validateRollupArgs = (args: JsonObject): string | null => {
  const keys = Object.keys(args);
  if (keys.some((key) => !["from", "to", "limit", "offset"].includes(key))) return "UNKNOWN_ARGUMENT";
  for (const key of ["from", "to"]) {
    if (requireString(args[key], 10) === null) return "INVALID_DATE";
  }
  if (args.limit !== undefined && requireInteger(args.limit, 1, 30) === null) return "INVALID_LIMIT";
  if (args.offset !== undefined && requireInteger(args.offset, 0, 10_000) === null) return "INVALID_OFFSET";
  return null;
};

export const parseJsonObject = (value: string): JsonObject | null => {
  try {
    const parsed: unknown = JSON.parse(value);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    return parsed as JsonObject;
  } catch {
    return null;
  }
};

const REDACTED_KEYS = new Set([
  "buyer_user_id", "customer_user_id", "user_id", "merchant_id", "contact_phone", "phone", "email", "address",
  "identity", "identity_document", "payment_proof", "proof_storage_key", "evidence_storage_key", "raw_payload",
]);

export const redactToolResult = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(redactToolResult);
  if (!value || typeof value !== "object") return value;
  const result: JsonObject = {};
  for (const [key, child] of Object.entries(value as JsonObject)) {
    if (REDACTED_KEYS.has(key.toLowerCase())) continue;
    result[key] = redactToolResult(child);
  }
  return result;
};

export type Policy = {
  status: string;
  version?: number | null;
  rules?: {
    max_tool_calls?: number;
    allowed_action_classes?: string[];
    provider_calls_enabled?: boolean;
    [key: string]: unknown;
  };
};

export const safePolicy = (value: unknown): Policy => {
  const policy = objectOrEmpty(value) as Policy;
  const rules = objectOrEmpty(policy.rules);
  return {
    status: typeof policy.status === "string" ? policy.status : "implicit_deny",
    version: typeof policy.version === "number" ? policy.version : null,
    rules: {
      max_tool_calls: typeof rules.max_tool_calls === "number" ? Math.max(0, Math.min(20, Math.floor(rules.max_tool_calls))) : 0,
      allowed_action_classes: Array.isArray(rules.allowed_action_classes) ? rules.allowed_action_classes.filter((item): item is string => typeof item === "string") : [],
      provider_calls_enabled: rules.provider_calls_enabled === true,
    },
  };
};
