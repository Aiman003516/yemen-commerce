import { createClient } from "https://esm.sh/@supabase/supabase-js@2.53.0";

type JsonObject = Record<string, unknown>;
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "content-type, x-ai-worker-key", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json; charset=utf-8" };
const WORKFLOW_KEYS = new Set(["evaluation.batch", "knowledge.refresh", "merchant.alert_summary"]);
const json = (value: JsonObject, status = 200) => new Response(JSON.stringify(value), { status, headers: corsHeaders });
const requiredString = (value: unknown, min: number, max: number) => typeof value === "string" && value.trim().length >= min && value.trim().length <= max ? value.trim() : null;

const internalClient = () => {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const workerKey = Deno.env.get("AI_WORKER_KEY");
  if (!url || !serviceKey || !workerKey) throw new Error("worker_not_configured");
  return { workerKey, client: createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } }) };
};
const rpc = async (client: ReturnType<typeof internalClient>["client"], name: string, args: JsonObject) => {
  const { data, error } = await client.rpc(name, args);
  if (error) throw new Error(name);
  return data;
};

const run = async (request: Request): Promise<Response> => {
  const { workerKey, client } = internalClient();
  if (request.headers.get("x-ai-worker-key") !== workerKey) return json({ code: "WORKER_UNAUTHORIZED", message: "الوصول الداخلي غير مصرح." }, 401);
  let body: JsonObject;
  try { body = JSON.parse(await request.text()) as JsonObject; } catch { return json({ code: "INVALID_REQUEST", message: "الطلب غير صالح." }, 400); }
  const operation = requiredString(body.operation, 4, 20);
  if (operation === "claim") {
    const workerId = requiredString(body.worker_id, 8, 120);
    if (!workerId) return json({ code: "INVALID_WORKER", message: "معرّف العامل غير صالح." }, 400);
    const item = await rpc(client, "ai_claim_workflow", { p_worker_id: workerId, p_lease_seconds: typeof body.lease_seconds === "number" ? Math.min(900, Math.max(30, Math.floor(body.lease_seconds))) : 120 });
    if (!item) return json({ workflow: null, status: "empty" });
    const workflow = item as JsonObject;
    if (typeof workflow.workflow_key !== "string" || !WORKFLOW_KEYS.has(workflow.workflow_key)) {
      if (typeof workflow.workflow_id === "string" && typeof workflow.lease_token_hash === "string") {
        await rpc(client, "ai_complete_workflow", { p_workflow_id: workflow.workflow_id, p_lease_token_hash: workflow.lease_token_hash, p_status: "failed", p_error_code: "AI_WORKFLOW_KEY_DENIED" });
      }
      return json({ code: "AI_WORKFLOW_KEY_DENIED", message: "نوع سير العمل غير مسموح." }, 403);
    }
    return json({ workflow: { workflow_id: workflow.workflow_id, run_id: workflow.run_id, workflow_key: workflow.workflow_key, app_surface: workflow.app_surface, scope_type: workflow.scope_type, scope_id: workflow.scope_id, payload_redacted: workflow.payload_redacted, attempts: workflow.attempts, max_attempts: workflow.max_attempts }, lease_token_hash: workflow.lease_token_hash, status: "claimed" }, 200);
  }
  if (operation === "complete") {
    const workflowId = requiredString(body.workflow_id, 36, 80);
    const leaseTokenHash = requiredString(body.lease_token_hash, 16, 128);
    const status = requiredString(body.status, 4, 12);
    if (!workflowId || !leaseTokenHash || !status || !["queued", "succeeded", "failed", "cancelled", "expired"].includes(status)) return json({ code: "INVALID_COMPLETION", message: "بيانات إكمال سير العمل غير صالحة." }, 400);
    const result = await rpc(client, "ai_complete_workflow", { p_workflow_id: workflowId, p_lease_token_hash: leaseTokenHash, p_status: status, p_error_code: typeof body.error_code === "string" ? body.error_code.slice(0, 80) : null, p_next_run_at: typeof body.next_run_at === "string" ? body.next_run_at : null });
    return json({ workflow: result, status: "completed" });
  }
  return json({ code: "INVALID_OPERATION", message: "نوع العملية غير متاح." }, 400);
};
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ code: "METHOD_NOT_ALLOWED", message: "الطريقة غير مسموحة." }, 405);
  try { return await run(request); } catch { return json({ code: "AI_WORKER_UNAVAILABLE", message: "عامل سير العمل غير مفعّل حالياً." }, 503); }
});
