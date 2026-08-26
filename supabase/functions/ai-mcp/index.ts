import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.53.0";

type JsonObject = Record<string, unknown>;
type McpRequest = { jsonrpc?: string; id?: string | number | null; method?: string; params?: JsonObject };
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-ai-client-id, x-ai-redirect-uri", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json; charset=utf-8" };
const tools = [
  { name: "merchant.catalog.read", description: "Read a bounded owned merchant catalog projection.", inputSchema: { type: "object", properties: { scope_id: { type: "string" }, query: { type: "string", maxLength: 120 }, limit: { type: "integer", minimum: 1, maximum: 40 }, offset: { type: "integer", minimum: 0, maximum: 10000 } }, required: ["scope_id"], additionalProperties: false } },
  { name: "merchant.orders.read", description: "Read a bounded owned merchant order workbench projection.", inputSchema: { type: "object", properties: { scope_id: { type: "string" }, limit: { type: "integer", minimum: 1, maximum: 50 }, offset: { type: "integer", minimum: 0, maximum: 10000 } }, required: ["scope_id"], additionalProperties: false } },
  { name: "merchant.analytics.read", description: "Read an owned merchant daily rollup range.", inputSchema: { type: "object", properties: { scope_id: { type: "string" }, from: { type: "string", maxLength: 10 }, to: { type: "string", maxLength: 10 }, limit: { type: "integer", minimum: 1, maximum: 30 }, offset: { type: "integer", minimum: 0, maximum: 10000 } }, required: ["scope_id", "from", "to"], additionalProperties: false } },
];
const objectOrEmpty = (value: unknown): JsonObject => value && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : {};
const requireUuid = (value: unknown) => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value.trim());
const requireInt = (value: unknown, min: number, max: number, fallback: number) => typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : fallback;
class SafeError extends Error { constructor(public code: string, public status = 400) { super(code); } }
const rpcRows = async (supabase: SupabaseClient, name: string, args: JsonObject) => {
  const { data, error } = await supabase.rpc(name, args);
  if (!error) return Array.isArray(data) ? data.slice(0, 100) : [];
  const signal = `${error.code ?? ""} ${error.message ?? ""}`;
  if (signal.includes("42501") || signal.includes("SHOP_NOT_OWNED") || signal.includes("AI_SHOP_SCOPE_FORBIDDEN")) throw new SafeError("SCOPE_FORBIDDEN", 403);
  throw new SafeError("TOOL_FAILED", 409);
};
const safeValue = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.slice(0, 100).map(safeValue);
  if (!value || typeof value !== "object") return value;
  const result: JsonObject = {};
  for (const [key, child] of Object.entries(value as JsonObject)) {
    if (["user_id", "buyer_user_id", "customer_user_id", "merchant_id", "phone", "email", "address", "barcode", "payment_proof", "proof_storage_key", "evidence_storage_key", "raw_payload"].includes(key.toLowerCase())) continue;
    result[key] = safeValue(child);
  }
  return result;
};
const response = (id: string | number | null | undefined, result: JsonObject, status = 200) => new Response(JSON.stringify({ jsonrpc: "2.0", id: id ?? null, result }), { status, headers: corsHeaders });
const errorResponse = (id: string | number | null | undefined, code: number, message: string, status = 400) => new Response(JSON.stringify({ jsonrpc: "2.0", id: id ?? null, error: { code, message } }), { status, headers: corsHeaders });

const execute = async (request: Request): Promise<Response> => {
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new SafeError("AUTH_REQUIRED", 401);
  const clientId = request.headers.get("x-ai-client-id")?.trim() ?? "";
  const redirectUri = request.headers.get("x-ai-redirect-uri")?.trim() ?? "";
  if (!clientId || !redirectUri) throw new SafeError("CONSENT_REQUIRED", 403);
  const url = Deno.env.get("SUPABASE_URL"); const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) throw new SafeError("INTERNAL_ERROR", 500);
  const supabase = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false }, global: { headers: { Authorization: `Bearer ${token}` } } });
  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  if (authError || !authData.user) throw new SafeError("AUTH_REQUIRED", 401);
  const externalEnabled = await supabase.rpc("ai_external_agent_gate", {});
  if (externalEnabled.error || externalEnabled.data !== true) throw new SafeError("EXTERNAL_AGENT_DISABLED", 403);
  await supabase.rpc("ai_check_external_consent", { p_client_id: clientId, p_redirect_uri: redirectUri }).then(({ error }) => { if (error) throw new SafeError("CONSENT_REQUIRED", 403); });
  const { data: quota, error: quotaError } = await supabase.rpc("ai_consume_external_quota", { p_client_id: clientId, p_redirect_uri: redirectUri });
  if (quotaError) {
    const signal = `${quotaError.code ?? ""} ${quotaError.message ?? ""}`;
    if (signal.includes("AI_EXTERNAL_CONSENT")) throw new SafeError("CONSENT_REQUIRED", 403);
    throw new SafeError("TOOL_FAILED", 409);
  }
  if (objectOrEmpty(quota).allowed !== true) throw new SafeError("EXTERNAL_QUOTA_EXCEEDED", 429);
  let body: McpRequest;
  try { body = objectOrEmpty(await request.json()) as McpRequest; } catch { throw new SafeError("INVALID_REQUEST"); }
  if (body.jsonrpc !== "2.0" || !body.method) throw new SafeError("INVALID_REQUEST");
  if (body.method === "initialize") return response(body.id, { protocolVersion: "2025-06-18", capabilities: { tools: { listChanged: false } }, serverInfo: { name: "yemen-commerce-ai", version: "ai6-readonly-2026-08-26" } });
  if (body.method === "notifications/initialized") return new Response(null, { status: 204, headers: corsHeaders });
  if (body.method === "tools/list") return response(body.id, { tools });
  if (body.method !== "tools/call") throw new SafeError("METHOD_NOT_FOUND");
  const params = objectOrEmpty(body.params);
  const toolName = typeof params.name === "string" ? params.name : "";
  const args = objectOrEmpty(params.arguments);
  if (!tools.some((tool) => tool.name === toolName)) throw new SafeError("TOOL_NOT_FOUND");
  const scopeId = args.scope_id;
  if (!requireUuid(scopeId)) throw new SafeError("SCOPE_REQUIRED", 400);
  let result: unknown;
  if (toolName === "merchant.catalog.read") result = await rpcRows(supabase, "merchant_ai_catalog", { p_shop_id: scopeId, p_query: typeof args.query === "string" ? args.query.trim().slice(0, 120) || null : null, p_limit: requireInt(args.limit, 1, 40, 20), p_offset: requireInt(args.offset, 0, 10000, 0) });
  else if (toolName === "merchant.orders.read") result = await rpcRows(supabase, "merchant_order_workbench", { p_shop_id: scopeId, p_fulfilment_status: null, p_payment_status: null, p_cod_status: null, p_query: null, p_limit: requireInt(args.limit, 1, 50, 20), p_offset: requireInt(args.offset, 0, 10000, 0) });
  else result = await rpcRows(supabase, "merchant_daily_rollups", { p_shop_id: scopeId, p_from: args.from, p_to: args.to, p_limit: requireInt(args.limit, 1, 30, 14), p_offset: requireInt(args.offset, 0, 10000, 0) });
  return response(body.id, { content: [{ type: "text", text: JSON.stringify(safeValue(result)) }], isError: false });
};
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return errorResponse(null, -32600, "الطريقة غير مسموحة.", 405);
  try { return await execute(request); } catch (error) {
    if (error instanceof SafeError) {
      const map: Record<string, [number, string]> = { AUTH_REQUIRED: [-32001, "يجب تسجيل الدخول."], CONSENT_REQUIRED: [-32003, "يجب منح موافقة صريحة لهذا العميل."], EXTERNAL_AGENT_DISABLED: [-32004, "الوصول الخارجي غير مفعّل وفق سياسة المنصة."], EXTERNAL_QUOTA_EXCEEDED: [-32008, "تم بلوغ حد الاستخدام اليومي لهذا العميل."], SCOPE_FORBIDDEN: [-32005, "لا يملك العميل صلاحية هذا النطاق."], TOOL_NOT_FOUND: [-32602, "الأداة غير متاحة."], METHOD_NOT_FOUND: [-32601, "الطريقة غير متاحة."], SCOPE_REQUIRED: [-32602, "يجب تحديد نطاق المتجر."], TOOL_FAILED: [-32010, "تعذر تنفيذ القراءة الآمنة."], INVALID_REQUEST: [-32600, "الطلب غير صالح."], INTERNAL_ERROR: [-32603, "حدث خطأ داخلي آمن."], };
      const [rpcCode, message] = map[error.code] ?? [-32603, "حدث خطأ داخلي آمن."];
      return errorResponse(null, rpcCode, message, error.status);
    }
    return errorResponse(null, -32603, "حدث خطأ داخلي آمن.", 500);
  }
});
