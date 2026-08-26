import { createClient, type SupabaseClient, type User } from "https://esm.sh/@supabase/supabase-js@2.53.0";
import { ACTION_SPEC_BY_KEY, normalizeActionArguments, redactActionArguments, requireString, requireUuid, type JsonObject } from "./_shared/ai_action_contract.ts";

type Policy = { status?: string; rules?: { max_tool_calls?: number; allowed_action_classes?: string[]; provider_calls_enabled?: boolean } };
type ActionDefinition = { action_key?: string; app_surface?: string; action_class?: string; approval_required?: boolean; enabled?: boolean };
type RunStart = { run_id: string; status: string; scope_type: string; scope_id: string | null; idempotent?: boolean };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-request-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};
const jsonResponse = (body: JsonObject, status = 200) => new Response(JSON.stringify(body), { status, headers: corsHeaders });
const messages: Record<string, string> = {
  AUTH_REQUIRED: "يجب تسجيل الدخول لإعداد إجراء للمراجعة.",
  INVALID_REQUEST: "بيانات إجراء المراجعة غير صالحة.",
  AI_SCOPE_REQUIRED: "يجب تحديد المتجر قبل إعداد الإجراء.",
  AI_SCOPE_FORBIDDEN: "لا يملك حسابك صلاحية الوصول إلى هذا المتجر.",
  AI_ACTION_NOT_FOUND: "إجراء التاجر المطلوب غير متاح.",
  AI_ACTION_DISABLED: "أوقف مالك المنصة هذا الإجراء مؤقتاً.",
  AI_ACTION_ARGUMENTS_INVALID: "لم تكن معاملات الإجراء صالحة.",
  AI_POLICY_DENIED: "هذا الإجراء غير مسموح وفق سياسة المساعد الحالية.",
  AI_APPROVAL_REQUIRED: "تعذر إنشاء طلب المراجعة.",
  AI_RUN_FAILED: "تعذر إنشاء تشغيل آمن للإجراء.",
  INTERNAL_ERROR: "حدث خطأ داخلي آمن. لم يتم تنفيذ أي تغيير.",
};
class SafeError extends Error { constructor(public code: string, public status = 400) { super(code); } }
const objectOrEmpty = (value: unknown): JsonObject => value && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : {};
const sha256 = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))).map((byte) => byte.toString(16).padStart(2, "0")).join("");
const safePolicy = (value: unknown): Policy => {
  const policy = objectOrEmpty(value);
  const rules = objectOrEmpty(policy.rules);
  return {
    status: typeof policy.status === "string" ? policy.status : "implicit_deny",
    rules: {
      max_tool_calls: typeof rules.max_tool_calls === "number" ? Math.max(0, Math.min(20, Math.floor(rules.max_tool_calls))) : 0,
      allowed_action_classes: Array.isArray(rules.allowed_action_classes) ? rules.allowed_action_classes.filter((item: unknown): item is string => typeof item === "string") : [],
      provider_calls_enabled: rules.provider_calls_enabled === true,
    },
  };
};
const rpcObject = async <T>(supabase: SupabaseClient, name: string, args: JsonObject): Promise<T> => {
  const { data, error } = await supabase.rpc(name, args);
  if (error) {
    const signal = `${error.code ?? ""} ${error.message ?? ""}`;
    if (signal.includes("42501") || signal.includes("AI_SHOP_SCOPE_FORBIDDEN") || signal.includes("AI_RUN_FORBIDDEN")) throw new SafeError("AI_SCOPE_FORBIDDEN", 403);
    if (signal.includes("AI_")) throw new SafeError(signal.match(/AI_[A-Z0-9_]+/)?.[0] ?? "INTERNAL_ERROR");
    throw new SafeError("INTERNAL_ERROR", 500);
  }
  return data as T;
};
const authClient = (request: Request) => {
  const token = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new SafeError("AUTH_REQUIRED", 401);
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) throw new SafeError("INTERNAL_ERROR", 500);
  return { token, supabase: createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false }, global: { headers: { Authorization: `Bearer ${token}` } } }) };
};
const safeMessage = (code: string) => messages[code] ?? messages.INTERNAL_ERROR;

const execute = async (request: Request): Promise<Response> => {
  const { token, supabase } = authClient(request);
  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  if (authError || !authData.user) throw new SafeError("AUTH_REQUIRED", 401);
  const user: User = authData.user;
  let body: JsonObject;
  try { body = objectOrEmpty(await request.json()); } catch { throw new SafeError("INVALID_REQUEST"); }
  if (body.app_surface !== undefined && body.app_surface !== "merchant") throw new SafeError("AI_SCOPE_FORBIDDEN", 403);
  if (body.scope_type !== undefined && body.scope_type !== "shop") throw new SafeError("AI_SCOPE_REQUIRED");
  const shopId = requireUuid(body.scope_id);
  const actionKey = requireString(body.action_key, 3, 80);
  const idempotencyKey = requireString(body.idempotency_key, 8, 200);
  const args = normalizeActionArguments(body.arguments);
  if (!shopId || !actionKey || !idempotencyKey || !args) throw new SafeError("INVALID_REQUEST");
  const spec = ACTION_SPEC_BY_KEY.get(actionKey);
  if (!spec) throw new SafeError("AI_ACTION_NOT_FOUND");
  const definition = await rpcObject<ActionDefinition | null>(supabase, "ai_get_action_definition", { p_action_key: actionKey });
  if (!definition || definition.action_key !== actionKey || definition.app_surface !== "merchant" || definition.action_class !== spec.actionClass) throw new SafeError("AI_ACTION_NOT_FOUND");
  if (definition.enabled !== true || definition.approval_required !== true) throw new SafeError("AI_ACTION_DISABLED", 409);
  const validationError = spec.validate(args);
  if (validationError) throw new SafeError("AI_ACTION_ARGUMENTS_INVALID");
  const requestHash = await sha256(JSON.stringify({ app_surface: "merchant", scope_type: "shop", scope_id: shopId, action_key: actionKey, arguments: args }));
  const start = await rpcObject<RunStart>(supabase, "ai_start_run", {
    p_app_surface: "merchant",
    p_scope_type: "shop",
    p_scope_id: shopId,
    p_intent_key: "merchant.reviewable_action",
    p_request_hash: requestHash,
    p_requested_locale: "ar",
    p_idempotency_key: idempotencyKey,
    p_metadata: { engine_version: "ai3-action-proposal-2026-08-26", action_key: actionKey, actor_user_id_hash: await sha256(user.id) },
  });
  if (start.idempotent) return jsonResponse({ run_id: start.run_id, status: start.status, idempotent: true, locale: "ar" }, start.status === "waiting_approval" ? 202 : 200);
  let completed = false;
  try {
    const policy = safePolicy(await rpcObject<Policy>(supabase, "ai_get_effective_policy", { p_app_surface: "merchant", p_tool_name: actionKey }));
    if (policy.status === "implicit_deny" || !policy.rules?.allowed_action_classes?.includes("read") || !policy.rules.allowed_action_classes.includes(spec.actionClass) || (policy.rules.max_tool_calls ?? 0) < 1) {
      throw new SafeError("AI_POLICY_DENIED", 403);
    }
    const proposed = await rpcObject<{ tool_call_id: string; status: string }>(supabase, "ai_propose_action_tool_call", {
      p_run_id: start.run_id,
      p_sequence_no: 1,
      p_tool_name: actionKey,
      p_action_class: spec.actionClass,
      p_arguments_hash: await sha256(JSON.stringify(args)),
      p_arguments_redacted: redactActionArguments(args),
      p_arguments_payload: args,
      p_required_capability: null,
      p_approval_required: true,
      p_policy_decision: "needs_approval",
      p_idempotency_key: `${start.run_id}:proposal`,
    });
    if (!proposed.tool_call_id || proposed.status !== "awaiting_approval") throw new SafeError("AI_APPROVAL_REQUIRED", 500);
    const approval = await rpcObject<{ approval_id: string; expires_at: string }>(supabase, "ai_request_approval", { p_tool_call_id: proposed.tool_call_id, p_expires_in_seconds: 900 });
    return jsonResponse({ run_id: start.run_id, tool_call_id: proposed.tool_call_id, approval_id: approval.approval_id, action_key: actionKey, status: "awaiting_approval", arguments: redactActionArguments(args), expires_at: approval.expires_at, locale: "ar" }, 202);
  } catch (error) {
    if (!completed) { try { await rpcObject(supabase, "ai_finish_run", { p_run_id: start.run_id, p_status: "failed", p_output_hash: null }); } catch { /* preserve safe error */ } }
    throw error;
  }
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ code: "METHOD_NOT_ALLOWED", message: "الطريقة غير مسموحة." }, 405);
  try { return await execute(request); } catch (error) {
    const safe = error instanceof SafeError ? error : new SafeError("INTERNAL_ERROR", 500);
    return jsonResponse({ code: safe.code, message: safeMessage(safe.code) }, safe.status);
  }
});
