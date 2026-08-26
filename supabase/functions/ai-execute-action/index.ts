import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.53.0";
import { ACTION_SPEC_BY_KEY, redactActionArguments, normalizeActionArguments, type JsonObject } from "./_shared/ai_action_contract.ts";

type Run = { run_id: string; app_surface: string; scope_type: string; scope_id: string | null; status: string };
type ActionDefinition = { action_key?: string; app_surface?: string; action_class?: string; approval_required?: boolean; enabled?: boolean };
type ToolCall = { tool_call_id: string; run_id: string; tool_name: string; action_class: string; status: string; arguments_hash: string; approval_required: boolean; result_summary?: JsonObject | null; error_code?: string | null };
type Approval = { approval_id: string; tool_call_id: string; arguments_hash: string; status: string; expires_at?: string };
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-request-id", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json; charset=utf-8" };
const messages: Record<string, string> = {
  AUTH_REQUIRED: "يجب تسجيل الدخول لتنفيذ إجراء تمت الموافقة عليه.",
  INVALID_REQUEST: "بيانات تنفيذ الإجراء غير صالحة.",
  AI_RUN_FORBIDDEN: "لا يمكن الوصول إلى تشغيل المساعد بهذه الجلسة.",
  AI_SCOPE_FORBIDDEN: "لا يملك حسابك صلاحية الوصول إلى هذا المتجر.",
  AI_APPROVAL_FORBIDDEN: "لا توجد موافقة صالحة لهذا الإجراء.",
  AI_APPROVAL_EXPIRED: "انتهت صلاحية الموافقة. أعد إنشاء طلب مراجعة.",
  AI_TOOL_NOT_EXECUTABLE: "هذا الإجراء ليس جاهزاً للتنفيذ.",
  AI_ARGUMENTS_MISMATCH: "تغيرت معاملات الإجراء؛ لم يتم تنفيذ أي تغيير.",
  AI_ACTION_NOT_FOUND: "إجراء التاجر غير متاح.",
  AI_ACTION_DISABLED: "أوقف مالك المنصة هذا الإجراء مؤقتاً.",
  AI_ACTION_FAILED: "تعذر تنفيذ الإجراء. لم يتم تأكيد أي تغيير غير مقصود.",
  INTERNAL_ERROR: "حدث خطأ داخلي آمن. لم يتم تنفيذ أي تغيير.",
};
class SafeError extends Error { constructor(public code: string, public status = 400) { super(code); } }
const objectOrEmpty = (value: unknown): JsonObject => value && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : {};
const sha256 = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))).map((byte) => byte.toString(16).padStart(2, "0")).join("");
const safeResponseValue = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.slice(0, 100).map(safeResponseValue);
  if (!value || typeof value !== "object") return value;
  const out: JsonObject = {};
  for (const [key, child] of Object.entries(value as JsonObject)) {
    if (["user_id", "buyer_user_id", "customer_user_id", "phone", "email", "address", "barcode", "payment_proof", "proof_storage_key", "evidence_storage_key", "raw_payload"].includes(key.toLowerCase())) continue;
    out[key] = safeResponseValue(child);
  }
  return out;
};
const rpc = async <T>(supabase: SupabaseClient, name: string, args: JsonObject): Promise<T> => {
  const { data, error } = await supabase.rpc(name, args);
  if (!error) return data as T;
  const signal = `${error.code ?? ""} ${error.message ?? ""}`;
  if (signal.includes("AI_RUN_FORBIDDEN")) throw new SafeError("AI_RUN_FORBIDDEN", 403);
  if (signal.includes("AI_APPROVAL")) throw new SafeError(signal.match(/AI_APPROVAL_[A-Z0-9_]+/)?.[0] ?? "AI_APPROVAL_FORBIDDEN", 403);
  if (signal.includes("42501") || signal.includes("SHOP_NOT_OWNED")) throw new SafeError("AI_SCOPE_FORBIDDEN", 403);
  throw new SafeError("AI_ACTION_FAILED", 409);
};
const authClient = (request: Request) => {
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new SafeError("AUTH_REQUIRED", 401);
  const url = Deno.env.get("SUPABASE_URL"); const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) throw new SafeError("INTERNAL_ERROR", 500);
  return { token, supabase: createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false }, global: { headers: { Authorization: `Bearer ${token}` } } }) };
};
const safeMessage = (code: string) => messages[code] ?? messages.INTERNAL_ERROR;

const execute = async (request: Request): Promise<Response> => {
  const { token, supabase } = authClient(request);
  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  if (authError || !authData.user) throw new SafeError("AUTH_REQUIRED", 401);
  let body: JsonObject;
  try { body = objectOrEmpty(await request.json()); } catch { throw new SafeError("INVALID_REQUEST"); }
  const runId = typeof body.run_id === "string" ? body.run_id.trim() : "";
  const toolCallId = typeof body.tool_call_id === "string" ? body.tool_call_id.trim() : "";
  const approvalId = typeof body.approval_id === "string" ? body.approval_id.trim() : "";
  const suppliedArgs = body.arguments === undefined ? null : normalizeActionArguments(body.arguments);
  if (!runId || !toolCallId || !approvalId || (body.arguments !== undefined && !suppliedArgs)) throw new SafeError("INVALID_REQUEST");
  const run = await rpc<Run>(supabase, "ai_get_run", { p_run_id: runId });
  if (run.app_surface !== "merchant" || run.scope_type !== "shop" || !run.scope_id) throw new SafeError("AI_SCOPE_FORBIDDEN", 403);
  const calls = await rpc<ToolCall[]>(supabase, "ai_list_run_tool_calls", { p_run_id: runId });
  const call = (Array.isArray(calls) ? calls : []).find((item) => item.tool_call_id === toolCallId);
  if (!call || call.run_id !== runId) throw new SafeError("AI_RUN_FORBIDDEN", 403);
  if (call.status === "succeeded") return new Response(JSON.stringify({ run_id: runId, tool_call_id: toolCallId, status: "succeeded", idempotent: true, result: safeResponseValue(call.result_summary ?? {}), locale: "ar" }), { status: 200, headers: corsHeaders });
  if (call.status !== "approved" || !call.approval_required) throw new SafeError("AI_TOOL_NOT_EXECUTABLE", 409);
  const approvals = await rpc<Approval[]>(supabase, "ai_list_my_approvals", { p_status: "approved" });
  const approval = (Array.isArray(approvals) ? approvals : []).find((item) => item.approval_id === approvalId && item.tool_call_id === toolCallId);
  if (!approval || approval.status !== "approved") throw new SafeError("AI_APPROVAL_FORBIDDEN", 403);
  if (approval.expires_at && Date.parse(approval.expires_at) <= Date.now()) throw new SafeError("AI_APPROVAL_EXPIRED", 409);
  const payload = await rpc<JsonObject>(supabase, "ai_get_action_payload", { p_tool_call_id: toolCallId });
  const args = normalizeActionArguments(payload);
  if (!args) throw new SafeError("AI_ACTION_FAILED", 409);
  const argumentsHash = await sha256(JSON.stringify(args));
  if (argumentsHash !== call.arguments_hash || argumentsHash !== approval.arguments_hash) throw new SafeError("AI_ARGUMENTS_MISMATCH", 409);
  if (suppliedArgs && await sha256(JSON.stringify(suppliedArgs)) !== argumentsHash) throw new SafeError("AI_ARGUMENTS_MISMATCH", 409);
  const spec = ACTION_SPEC_BY_KEY.get(call.tool_name);
  if (!spec || spec.actionClass !== "reversible_write") throw new SafeError("AI_ACTION_NOT_FOUND");
  const definition = await rpc<ActionDefinition | null>(supabase, "ai_get_action_definition", { p_action_key: call.tool_name });
  if (!definition || definition.action_key !== call.tool_name || definition.app_surface !== "merchant" || definition.action_class !== spec.actionClass) throw new SafeError("AI_ACTION_NOT_FOUND");
  if (definition.enabled !== true || definition.approval_required !== true) throw new SafeError("AI_ACTION_DISABLED", 409);
  const validationError = spec.validate(args);
  if (validationError) throw new SafeError("AI_ARGUMENTS_MISMATCH", 409);
  await rpc(supabase, "ai_transition_tool_call", { p_tool_call_id: toolCallId, p_status: "running", p_result_summary: null, p_error_code: null });
  try {
    const mapped = spec.toRpc(run.scope_id, args, `ai3:${toolCallId}`);
    const result = await rpc<unknown>(supabase, mapped.name, mapped.args);
    const summary = { row_count: Array.isArray(result) ? result.length : 1, action_key: call.tool_name, idempotent: objectOrEmpty(result).idempotent === true };
    await rpc(supabase, "ai_transition_tool_call", { p_tool_call_id: toolCallId, p_status: "succeeded", p_result_summary: summary, p_error_code: null });
    await rpc(supabase, "ai_finish_run", { p_run_id: runId, p_status: "succeeded", p_output_hash: await sha256(JSON.stringify(summary)) });
    return new Response(JSON.stringify({ run_id: runId, tool_call_id: toolCallId, action_key: call.tool_name, status: "succeeded", idempotent: summary.idempotent, result: safeResponseValue(result), locale: "ar" }), { status: 200, headers: corsHeaders });
  } catch (error) {
    try { await rpc(supabase, "ai_transition_tool_call", { p_tool_call_id: toolCallId, p_status: "failed", p_result_summary: null, p_error_code: "AI_ACTION_FAILED" }); } catch { /* keep safe failure */ }
    try { await rpc(supabase, "ai_finish_run", { p_run_id: runId, p_status: "failed", p_output_hash: null }); } catch { /* keep safe failure */ }
    if (error instanceof SafeError && error.code === "AI_SCOPE_FORBIDDEN") throw error;
    throw new SafeError("AI_ACTION_FAILED", 409);
  }
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return new Response(JSON.stringify({ code: "METHOD_NOT_ALLOWED", message: "الطريقة غير مسموحة." }), { status: 405, headers: corsHeaders });
  try { return await execute(request); } catch (error) {
    const safe = error instanceof SafeError ? error : new SafeError("INTERNAL_ERROR", 500);
    return new Response(JSON.stringify({ code: safe.code, message: safeMessage(safe.code) }), { status: safe.status, headers: corsHeaders });
  }
});
