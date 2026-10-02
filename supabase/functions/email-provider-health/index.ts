import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse, mergeBrand } from "../_shared/email_brand.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const authHeader = req.headers.get("Authorization") ?? "";

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const admin = createClient(supabaseUrl, serviceKey);

    const {
      data: { user },
    } = await userClient.auth.getUser();

    // Allow service-role cron pings without a user, but never echo secrets.
    const isService =
      authHeader.includes(serviceKey) ||
      req.headers.get("x-email-health-cron") === "1";

    if (!isService) {
      if (!user) return jsonResponse({ error: "authentication_required" }, 401);
      const { data: allowed } = await admin.rpc("has_permission", {
        permission_slug: "manage_settings",
        target_user_id: user.id,
      });
      const { data: isSuper } = await admin.rpc("has_role", {
        role_slug: "super_admin",
        target_user_id: user.id,
      });
      if (!allowed && !isSuper) {
        return jsonResponse({ error: "permission_denied" }, 403);
      }
    }

    const keyPresent = Boolean(resendKey && resendKey.trim().length > 10);
    let domainsOk: boolean | null = null;
    let domainError: string | null = null;

    if (keyPresent) {
      try {
        const res = await fetch("https://api.resend.com/domains", {
          headers: { Authorization: `Bearer ${resendKey}` },
        });
        domainsOk = res.ok;
        if (!res.ok) {
          const payload = await res.json().catch(() => ({}));
          domainError =
            typeof payload?.message === "string"
              ? payload.message
              : `domains_http_${res.status}`;
        }
      } catch (err) {
        domainsOk = false;
        domainError = String(err);
      }
    }

    const configured = keyPresent && domainsOk !== false;

    const { data: integrationsRow } = await admin
      .from("app_settings")
      .select("value")
      .eq("key", "integrations")
      .maybeSingle();

    const current =
      (integrationsRow?.value as Record<string, unknown> | null) ?? {};
    const emailCfg =
      (current.email as Record<string, unknown> | undefined) ?? {};

    const nextEmail = {
      ...emailCfg,
      configured,
      provider: "resend",
      notes: configured
        ? "Resend Edge worker healthy"
        : keyPresent
          ? "Resend key present but domain check failed"
          : "Set RESEND_API_KEY Edge secret and verify sending domain",
      last_health_check_at: new Date().toISOString(),
    };

    await admin
      .from("app_settings")
      .update({
        value: { ...current, email: nextEmail },
        updated_at: new Date().toISOString(),
      })
      .eq("key", "integrations");

    const { data: brandRow } = await admin
      .from("app_settings")
      .select("value")
      .eq("key", "email_brand")
      .maybeSingle();
    const brand = mergeBrand(
      (brandRow?.value as Record<string, unknown> | null) ?? null,
    );

    return jsonResponse({
      ok: true,
      configured,
      provider: "resend",
      api_key_present: keyPresent,
      domains_ok: domainsOk,
      domain_error: domainError,
      sender_email: brand.sender_email,
      sender_name: brand.sender_name,
      // Never return the API key.
    });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
