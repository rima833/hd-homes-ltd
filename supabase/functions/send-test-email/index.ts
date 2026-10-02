import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeaders,
  jsonResponse,
  mergeBrand,
  renderTransactionalEmail,
  sendWithResend,
} from "../_shared/email_brand.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendKey = Deno.env.get("RESEND_API_KEY");
    const authHeader = req.headers.get("Authorization") ?? "";

    if (!resendKey) {
      return jsonResponse({ error: "RESEND_API_KEY is not configured" }, 503);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const admin = createClient(supabaseUrl, serviceKey);

    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return jsonResponse({ error: "authentication_required" }, 401);
    }

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

    const body = await req.json();
    const to = String(body.to ?? body.recipient_email ?? "").trim().toLowerCase();
    const templateSlug = String(body.template_slug ?? "welcome").trim();
    const variables =
      body.variables && typeof body.variables === "object"
        ? (body.variables as Record<string, unknown>)
        : {};

    if (!to.includes("@")) {
      return jsonResponse({ error: "invalid_recipient" }, 400);
    }

    const { data: brandRow } = await admin
      .from("app_settings")
      .select("value")
      .eq("key", "email_brand")
      .maybeSingle();
    const brand = mergeBrand(
      (brandRow?.value as Record<string, unknown> | null) ?? null,
    );

    const { data: tpl, error: tplErr } = await admin
      .from("email_templates")
      .select("slug,subject,body_html,text_body,is_active")
      .eq("slug", templateSlug)
      .maybeSingle();

    if (tplErr || !tpl || !tpl.is_active) {
      return jsonResponse({ error: "template_not_found" }, 404);
    }

    if (!variables.first_name) variables.first_name = "there";
    if (!variables.cta_url) variables.cta_url = brand.website_url;

    const rendered = renderTransactionalEmail({
      subject: tpl.subject,
      bodyHtml: tpl.body_html || "",
      textBody: tpl.text_body,
      brand,
      variables,
    });

    const { data: delivery, error: insertErr } = await admin
      .from("notification_delivery")
      .insert({
        user_id: user.id,
        channel: "email",
        title: rendered.subject,
        body: rendered.text,
        status: "sending",
        recipient_email: to,
        template_slug: tpl.slug,
        provider: "resend",
        html_body: rendered.html,
        payload: {
          test: true,
          variables,
          requested_by: user.id,
        },
        attempt_count: 1,
      })
      .select("id")
      .single();

    if (insertErr) {
      return jsonResponse({ error: insertErr.message }, 500);
    }

    const from = `${brand.sender_name} <${brand.sender_email}>`;
    const sent = await sendWithResend({
      apiKey: resendKey,
      from,
      to,
      subject: rendered.subject,
      html: rendered.html,
      text: rendered.text,
      replyTo: brand.reply_to,
    });

    if (!sent.ok) {
      await admin
        .from("notification_delivery")
        .update({
          status: "failed",
          error_message: sent.error ?? "send_failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", delivery.id);
      return jsonResponse(
        { error: sent.error ?? "send_failed", delivery_id: delivery.id },
        502,
      );
    }

    await admin
      .from("notification_delivery")
      .update({
        status: "sent",
        provider_message_id: sent.id ?? null,
        sent_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        error_message: null,
      })
      .eq("id", delivery.id);

    return jsonResponse({
      ok: true,
      delivery_id: delivery.id,
      provider_message_id: sent.id,
      template_slug: tpl.slug,
      to,
    });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
