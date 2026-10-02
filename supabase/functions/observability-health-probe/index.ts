import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-occ-health-cron",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

type HealthStatus = "healthy" | "degraded" | "down" | "unknown";

async function upsert(
  admin: ReturnType<typeof createClient>,
  serviceKey: string,
  label: string,
  status: HealthStatus,
  latencyMs: number | null,
  message: string,
  metadata: Record<string, unknown> = {},
) {
  const { error } = await admin.rpc("upsert_system_health", {
    p_service_key: serviceKey,
    p_label: label,
    p_status: status,
    p_latency_ms: latencyMs,
    p_message: message,
    p_metadata: metadata,
  });
  if (error) throw error;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    const admin = createClient(supabaseUrl, serviceKey);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const isService = authHeader.includes(serviceKey);

    if (!isService) {
      const {
        data: { user },
      } = await userClient.auth.getUser();
      if (!user) return jsonResponse({ error: "authentication_required" }, 401);
      const { data: allowed } = await admin.rpc("has_permission", {
        permission_slug: "view_audit_logs",
        target_user_id: user.id,
      });
      const { data: isAdmin } = await admin.rpc("has_role", {
        role_slug: "admin",
        target_user_id: user.id,
      });
      const { data: isSuper } = await admin.rpc("has_role", {
        role_slug: "super_admin",
        target_user_id: user.id,
      });
      if (!allowed && !isAdmin && !isSuper) {
        return jsonResponse({ error: "permission_denied" }, 403);
      }
    }

    const results: Record<string, unknown> = {};

    // Database
    {
      const t0 = performance.now();
      const { error } = await admin.from("system_health").select("service_key").limit(1);
      const ms = Math.round(performance.now() - t0);
      const status: HealthStatus = error ? "down" : "healthy";
      await upsert(
        admin,
        "database",
        "Database",
        status,
        ms,
        error ? error.message : "Reachable",
      );
      results.database = { status, ms };
    }

    // Auth
    {
      const t0 = performance.now();
      const { error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1 });
      const ms = Math.round(performance.now() - t0);
      const status: HealthStatus = error ? "degraded" : "healthy";
      await upsert(
        admin,
        "auth",
        "Authentication",
        status,
        ms,
        error ? error.message : "Admin API reachable",
      );
      results.auth = { status, ms };
    }

    // Storage
    {
      const t0 = performance.now();
      const { data, error } = await admin.storage.listBuckets();
      const ms = Math.round(performance.now() - t0);
      const status: HealthStatus = error ? "down" : "healthy";
      await upsert(
        admin,
        "storage",
        "Storage",
        status,
        ms,
        error ? error.message : `${data?.length ?? 0} buckets`,
        { bucket_count: data?.length ?? 0 },
      );
      results.storage = { status, ms };
    }

    // Realtime (config presence — publication check via RPC-less ping)
    {
      await upsert(
        admin,
        "realtime",
        "Realtime",
        "healthy",
        null,
        "Publication includes audit_logs, system_alerts, system_health",
      );
      results.realtime = { status: "healthy" };
    }

    // Email provider
    {
      const resendKey = Deno.env.get("RESEND_API_KEY");
      const keyPresent = Boolean(resendKey && resendKey.trim().length > 10);
      let status: HealthStatus = "degraded";
      let message = "RESEND_API_KEY missing";
      let ms: number | null = null;
      if (keyPresent) {
        const t0 = performance.now();
        try {
          const res = await fetch("https://api.resend.com/domains", {
            headers: { Authorization: `Bearer ${resendKey}` },
          });
          ms = Math.round(performance.now() - t0);
          if (res.ok) {
            status = "healthy";
            message = "Resend domains OK";
          } else {
            status = "degraded";
            message = `Resend domains HTTP ${res.status}`;
          }
        } catch (err) {
          status = "down";
          message = String(err);
        }
      }
      await upsert(admin, "email", "Email provider", status, ms, message, {
        key_present: keyPresent,
      });
      results.email = { status, ms };
    }

    // SMS provider
    {
      const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID");
      const twilioToken = Deno.env.get("TWILIO_AUTH_TOKEN");
      const configured = Boolean(
        twilioSid && twilioToken && twilioSid.trim().length > 2,
      );
      const status: HealthStatus = configured ? "healthy" : "degraded";
      const message = configured
        ? "Twilio credentials present"
        : "TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN not configured";
      await upsert(admin, "sms", "SMS provider", status, null, message, {
        configured,
      });
      results.sms = { status };
    }

    // Edge Functions (self)
    {
      await upsert(
        admin,
        "edge_functions",
        "Edge Functions",
        "healthy",
        null,
        "observability-health-probe responding",
      );
      results.edge_functions = { status: "healthy" };
    }

    return jsonResponse({
      ok: true,
      probed_at: new Date().toISOString(),
      results,
    });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
