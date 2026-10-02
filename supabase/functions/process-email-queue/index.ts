import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeaders,
  jsonResponse,
  mergeBrand,
  renderTransactionalEmail,
  sendWithResend,
} from "../_shared/email_brand.ts";

type DeliveryRow = {
  id: string;
  user_id: string | null;
  recipient_email: string | null;
  template_slug: string | null;
  title: string | null;
  body: string | null;
  status: string;
  payload: Record<string, unknown> | null;
  attempt_count: number;
};

type OutboxRow = {
  id: string;
  recipient: string;
  template_slug: string;
  title: string;
  body: string;
  payload: Record<string, unknown> | null;
  status: string;
  attempt_count: number;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendKey = Deno.env.get("RESEND_API_KEY");

    if (!resendKey) {
      return jsonResponse(
        { error: "RESEND_API_KEY is not configured", processed: 0 },
        503,
      );
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const drainTicket = await readDrainTicket(req);
    const allowed = await authorizeQueueCaller(
      req,
      supabaseUrl,
      serviceKey,
      admin,
      drainTicket,
    );
    if (!allowed) {
      return jsonResponse({ error: "unauthorized" }, 401);
    }
    const limit = Math.min(
      Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 25), 1),
      100,
    );

    const { data: brandRow } = await admin
      .from("app_settings")
      .select("value")
      .eq("key", "email_brand")
      .maybeSingle();
    const brand = mergeBrand(
      (brandRow?.value as Record<string, unknown> | null) ?? null,
    );
    const from = `${brand.sender_name} <${brand.sender_email}>`;

    const staleBefore = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    await admin
      .from("notification_delivery")
      .update({
        status: "queued",
        updated_at: new Date().toISOString(),
        error_message: "reclaimed_stale_send",
      })
      .eq("channel", "email")
      .eq("status", "sending")
      .lt("updated_at", staleBefore)
      .lt("attempt_count", 3);

    const { data: queued, error: qErr } = await admin
      .from("notification_delivery")
      .select(
        "id,user_id,recipient_email,template_slug,title,body,status,payload,attempt_count",
      )
      .eq("channel", "email")
      .eq("status", "queued")
      .order("created_at", { ascending: true })
      .limit(limit);

    if (qErr) {
      return jsonResponse({ error: "email_queue_read_failed" }, 500);
    }

    const results: Array<Record<string, unknown>> = [];

    for (const row of (queued ?? []) as DeliveryRow[]) {
      const claim = await admin
        .from("notification_delivery")
        .update({
          status: "sending",
          attempt_count: (row.attempt_count ?? 0) + 1,
          updated_at: new Date().toISOString(),
          provider: "resend",
        })
        .eq("id", row.id)
        .eq("status", "queued")
        .select("id")
        .maybeSingle();

      if (!claim.data) {
        results.push({ id: row.id, skipped: true, reason: "already_claimed" });
        continue;
      }

      try {
        const recipient = await resolveRecipient(admin, row);
        if (!recipient) {
          await markFailed(admin, row.id, "missing_recipient_email");
          results.push({ id: row.id, ok: false, error: "missing_recipient_email" });
          continue;
        }

        const variables = extractVariables(row.payload);
        if (!variables.first_name && row.user_id) {
          const name = await resolveFirstName(admin, row.user_id);
          if (name) variables.first_name = name;
        }
        if (!variables.cta_url) {
          variables.cta_url = brand.website_url;
        }

        let subject = row.title || "HD Homes";
        let bodyHtml = row.body || "";
        let textBody = row.body || "";

        if (row.template_slug) {
          const { data: tpl } = await admin
            .from("email_templates")
            .select("subject,body_html,text_body,is_active")
            .eq("slug", row.template_slug)
            .maybeSingle();
          if (tpl?.is_active) {
            subject = tpl.subject || subject;
            bodyHtml = tpl.body_html || bodyHtml;
            textBody = tpl.text_body || textBody;
          }
        }

        const rendered = renderTransactionalEmail({
          subject,
          bodyHtml,
          textBody,
          brand,
          variables,
        });

        let sent = await sendWithResend({
          apiKey: resendKey,
          from,
          to: recipient,
          subject: rendered.subject,
          html: rendered.html,
          text: rendered.text,
          replyTo: brand.reply_to,
        });
        let attempt = (row.attempt_count ?? 0) + 1;
        while (
          !sent.ok &&
          attempt < 3 &&
          (sent.status >= 500 || sent.status === 429)
        ) {
          attempt += 1;
          sent = await sendWithResend({
            apiKey: resendKey,
            from,
            to: recipient,
            subject: rendered.subject,
            html: rendered.html,
            text: rendered.text,
            replyTo: brand.reply_to,
          });
        }

        if (!sent.ok) {
          await markFailed(admin, row.id, sent.error || "send_failed", attempt);
          results.push({ id: row.id, ok: false, retrying: attempt < 3 });
          continue;
        }

        await admin
          .from("notification_delivery")
          .update({
            status: "sent",
            provider: "resend",
            provider_message_id: sent.id ?? null,
            html_body: rendered.html,
            recipient_email: recipient,
            sent_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            error_message: null,
          })
          .eq("id", row.id);

        results.push({ id: row.id, ok: true, provider_message_id: sent.id });
      } catch (err) {
        const attempt = (row.attempt_count ?? 0) + 1;
        await markFailed(admin, row.id, "send_failed", attempt);
        console.error("email delivery failed", row.id, err);
        results.push({ id: row.id, ok: false, retrying: attempt < 3 });
      }
    }

    // Drain website form outbox
    const { data: outbox } = await admin
      .from("website_form_outbox")
      .select(
        "id,recipient,template_slug,title,body,payload,status,attempt_count",
      )
      .eq("status", "queued")
      .order("created_at", { ascending: true })
      .limit(limit);

    for (const row of (outbox ?? []) as OutboxRow[]) {
      const claimed = await admin
        .from("website_form_outbox")
        .update({
          status: "sending",
          attempt_count: (row.attempt_count ?? 0) + 1,
          updated_at: new Date().toISOString(),
          provider: "resend",
        })
        .eq("id", row.id)
        .eq("status", "queued")
        .select("id")
        .maybeSingle();
      if (!claimed.data) {
        results.push({ outbox_id: row.id, skipped: true, reason: "already_claimed" });
        continue;
      }

      try {
        const variables = extractVariables(row.payload);
        if (!variables.cta_url) variables.cta_url = brand.website_url;
        if (!variables.first_name) variables.first_name = "there";

        let subject = row.title;
        let bodyHtml = row.body;
        let textBody = row.body;

        const { data: tpl } = await admin
          .from("email_templates")
          .select("subject,body_html,text_body,is_active")
          .eq("slug", row.template_slug)
          .maybeSingle();
        if (tpl?.is_active) {
          subject = tpl.subject || subject;
          bodyHtml = tpl.body_html || bodyHtml;
          textBody = tpl.text_body || textBody;
        }

        const rendered = renderTransactionalEmail({
          subject,
          bodyHtml,
          textBody,
          brand,
          variables,
        });

        const sent = await sendWithResend({
          apiKey: resendKey,
          from,
          to: row.recipient,
          subject: rendered.subject,
          html: rendered.html,
          text: rendered.text,
          replyTo: brand.reply_to,
        });

        if (!sent.ok) {
          await admin
            .from("website_form_outbox")
            .update({
              status: "failed",
              error_message: sent.error ?? "send_failed",
              updated_at: new Date().toISOString(),
            })
            .eq("id", row.id);
          results.push({
            outbox_id: row.id,
            ok: false,
          });
          continue;
        }

        await admin
          .from("website_form_outbox")
          .update({
            status: "sent",
            provider: "resend",
            provider_message_id: sent.id ?? null,
            sent_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            error_message: null,
          })
          .eq("id", row.id);

        results.push({
          outbox_id: row.id,
          ok: true,
          provider_message_id: sent.id,
        });
      } catch (err) {
        await admin
          .from("website_form_outbox")
          .update({
            status: "failed",
            error_message: String(err),
            updated_at: new Date().toISOString(),
          })
          .eq("id", row.id);
        results.push({ outbox_id: row.id, ok: false });
      }
    }

    return jsonResponse({
      processed: results.length,
      results,
    });
  } catch (err) {
    return jsonResponse({ error: "email_queue_failed" }, 500);
  }
});

function secretsMatch(provided: string, expected: string): boolean {
  if (!expected || provided.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= provided.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return diff === 0;
}

/** Reads a one-time drain ticket. The body is ignored for every other field. */
async function readDrainTicket(req: Request): Promise<string> {
  if (req.method === "GET" || req.method === "HEAD") return "";
  try {
    const parsed = await req.json();
    const ticket = parsed?.drain_ticket;
    return typeof ticket === "string" ? ticket : "";
  } catch {
    return "";
  }
}

/**
 * Cron inserts a one-time ticket and posts it here.
 * A scheduler may also present x-queue-secret.
 * A signed-in super admin or admin may present their user JWT.
 */
async function authorizeQueueCaller(
  req: Request,
  supabaseUrl: string,
  serviceKey: string,
  admin: ReturnType<typeof createClient>,
  drainTicket: string,
): Promise<boolean> {
  if (/^[a-f0-9]{64}$/.test(drainTicket)) {
    const { data } = await admin
      .from("email_queue_drain_tickets")
      .update({ used_at: new Date().toISOString() })
      .eq("nonce", drainTicket)
      .is("used_at", null)
      .gt("expires_at", new Date().toISOString())
      .select("id")
      .maybeSingle();
    if (data?.id) return true;
  }

  const queueSecret = Deno.env.get("EMAIL_QUEUE_SECRET") ?? "";
  const provided = req.headers.get("x-queue-secret") ?? "";
  if (secretsMatch(provided, queueSecret)) return true;

  const header = req.headers.get("Authorization") ?? "";
  const bearer = header.toLowerCase().startsWith("bearer ")
    ? header.slice(7).trim()
    : "";
  if (!bearer || secretsMatch(bearer, serviceKey)) {
    // Service-role bearer is allowed for a database scheduler. An empty
    // bearer is not. Do not treat the anon key as authorization.
    return bearer.length > 0 && secretsMatch(bearer, serviceKey);
  }

  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!anonKey || secretsMatch(bearer, anonKey)) return false;

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${bearer}` } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const userId = userData.user?.id;
  if (!userId) return false;

  const { data: isSuper } = await admin.rpc("has_role", {
    role_slug: "super_admin",
    target_user_id: userId,
  });
  if (isSuper === true) return true;
  const { data: isAdmin } = await admin.rpc("has_role", {
    role_slug: "admin",
    target_user_id: userId,
  });
  return isAdmin === true;
}

function extractVariables(
  payload: Record<string, unknown> | null,
): Record<string, unknown> {
  if (!payload) return {};
  const vars = payload.variables;
  if (vars && typeof vars === "object" && !Array.isArray(vars)) {
    return { ...(vars as Record<string, unknown>) };
  }
  return { ...payload };
}

async function resolveRecipient(
  admin: ReturnType<typeof createClient>,
  row: DeliveryRow,
): Promise<string | null> {
  if (row.recipient_email && row.recipient_email.includes("@")) {
    return row.recipient_email.trim().toLowerCase();
  }
  if (!row.user_id) return null;
  const { data } = await admin
    .from("profiles")
    .select("email")
    .eq("id", row.user_id)
    .maybeSingle();
  const email = data?.email;
  return typeof email === "string" && email.includes("@")
    ? email.trim().toLowerCase()
    : null;
}

async function resolveFirstName(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<string | null> {
  const { data } = await admin
    .from("profiles")
    .select("first_name")
    .eq("id", userId)
    .maybeSingle();
  const name = data?.first_name;
  return typeof name === "string" && name.trim() ? name.trim() : null;
}

async function markFailed(
  admin: ReturnType<typeof createClient>,
  id: string,
  error: string,
  attempt = 3,
) {
  const retry = attempt < 3;
  await admin
    .from("notification_delivery")
    .update({
      status: retry ? "queued" : "failed",
      attempt_count: attempt,
      error_message: error.slice(0, 1000),
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
}
