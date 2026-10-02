/** Shared HD Homes email branding + HTML render helpers (Edge only). */

export type EmailBrand = {
  logo_url?: string;
  sender_name?: string;
  sender_email?: string;
  reply_to?: string;
  support_email?: string;
  website_url?: string;
  privacy_url?: string;
  terms_url?: string;
  primary_color?: string;
  company_name?: string;
  tagline?: string;
};

export const DEFAULT_EMAIL_BRAND: Required<EmailBrand> = {
  logo_url:
    "https://wbonjdqsifwsawhhxygl.supabase.co/storage/v1/object/public/logos/hd_homes_logo.png",
  sender_name: "HD Homes Limited",
  sender_email: "no-reply@hdhomesltd.com",
  reply_to: "support@hdhomesltd.com",
  support_email: "support@hdhomesltd.com",
  website_url: "https://hdhomesltd.com",
  privacy_url: "https://hdhomesltd.com/trust",
  terms_url: "https://hdhomesltd.com/trust",
  primary_color: "#d6a847",
  company_name: "HD Homes Limited",
  tagline: "Making Quality Housing Accessible",
};

export function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  };
}

export function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** Forces a public site origin. Loopback brand URLs cannot become the mail host. */
export function publicSite(siteUrl: string): string {
  const fallback = DEFAULT_EMAIL_BRAND.website_url.replace(/\/+$/, "");
  const candidate = (siteUrl || fallback).trim().replace(/\/+$/, "");
  try {
    const url = new URL(candidate);
    const host = url.hostname.toLowerCase();
    if (host === "localhost" || host === "127.0.0.1" || host === "::1") {
      return fallback;
    }
    if (url.protocol !== "https:" && url.protocol !== "http:") return fallback;
    return candidate;
  } catch {
    return fallback;
  }
}

/**
 * Resolves an email button link.
 * Localhost and loopback origins are rewritten onto the public site so a
 * debug session cannot mail http://localhost into production inboxes.
 * Relative paths join the public site. Other absolute URLs are left as sent.
 */
export function publicActionUrl(raw: string, siteUrl: string): string {
  const site = publicSite(siteUrl);
  const value = raw.trim();
  if (!value) return site;
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    if (host === "localhost" || host === "127.0.0.1" || host === "::1") {
      const path = url.pathname === "/" ? "" : url.pathname;
      return `${site}${path}${url.search}${url.hash}`;
    }
    return value;
  } catch {
    if (value.startsWith("/")) return `${site}${value}`;
    return value;
  }
}

export function normalizeEmailVariables(
  variables: Record<string, unknown>,
  brand: Required<EmailBrand>,
): Record<string, string> {
  const name = String(variables.recipient_name || variables.first_name || "there").trim() || "there";
  const action = publicActionUrl(
    String(variables.action_url || variables.cta_url || brand.website_url),
    brand.website_url,
  );
  const out: Record<string, string> = {};
  for (const [key, raw] of Object.entries(variables)) {
    if (raw == null) continue;
    const value = String(raw);
    if (
      (key === "cta_url" || key === "action_url" || key === "meeting_url") &&
      value.trim()
    ) {
      out[key] = publicActionUrl(value, brand.website_url);
    } else {
      out[key] = value;
    }
  }
  out.recipient_name = name;
  out.first_name = String(variables.first_name || name);
  out.action_url = action;
  out.cta_url = action;
  out.brand_logo_url = brand.logo_url;
  return out;
}

export function replaceVariables(
  template: string,
  variables: Record<string, unknown>,
): string {
  let out = template;
  for (const [key, raw] of Object.entries(variables)) {
    const value = raw == null ? "" : String(raw);
    out = out.replaceAll(`{{${key}}}`, value);
  }
  // Leave unknown tokens empty for cleaner mail.
  out = out.replaceAll(/\{\{[a-zA-Z0-9_]+\}\}/g, "");
  return out;
}

export function mergeBrand(raw: Record<string, unknown> | null): Required<EmailBrand> {
  const src = raw ?? {};
  return {
    logo_url: String(src.logo_url || DEFAULT_EMAIL_BRAND.logo_url),
    sender_name: String(src.sender_name ?? DEFAULT_EMAIL_BRAND.sender_name),
    sender_email: String(src.sender_email ?? DEFAULT_EMAIL_BRAND.sender_email),
    reply_to: String(src.reply_to ?? DEFAULT_EMAIL_BRAND.reply_to),
    support_email: String(src.support_email ?? DEFAULT_EMAIL_BRAND.support_email),
    website_url: publicSite(String(src.website_url ?? DEFAULT_EMAIL_BRAND.website_url)),
    privacy_url: publicActionUrl(
      String(src.privacy_url ?? DEFAULT_EMAIL_BRAND.privacy_url),
      DEFAULT_EMAIL_BRAND.website_url,
    ),
    terms_url: publicActionUrl(
      String(src.terms_url ?? DEFAULT_EMAIL_BRAND.terms_url),
      DEFAULT_EMAIL_BRAND.website_url,
    ),
    primary_color: String(src.primary_color ?? DEFAULT_EMAIL_BRAND.primary_color),
    company_name: String(src.company_name ?? DEFAULT_EMAIL_BRAND.company_name),
    tagline: String(src.tagline ?? DEFAULT_EMAIL_BRAND.tagline),
  };
}

export function wrapEmailHtml(
  contentHtml: string,
  brand: Required<EmailBrand>,
): string {
  const gold = escapeHtml(brand.primary_color || "#d6a847");
  const logo = brand.logo_url
    ? `<img src="${escapeHtml(brand.logo_url)}" alt="HD Homes Limited" width="95" style="display:block;max-width:95px;height:auto;margin:0 auto;border:0;outline:none;" />`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${escapeHtml(brand.company_name)}</title>
  <style>
    @media only screen and (max-width: 600px) {
      .email-wrapper { padding: 20px 12px !important; }
      .email-card { width: 100% !important; border-radius: 12px !important; }
      .content { padding: 32px 24px !important; }
      .heading { font-size: 26px !important; }
      .button { width: 100% !important; box-sizing: border-box !important; }
    }
  </style>
</head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;color:#1a1a1a;">
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f3f4f6;">
  <tr>
    <td align="center" class="email-wrapper" style="padding:45px 16px;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" class="email-card" style="max-width:620px;background:#ffffff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">
        <tr>
          <td align="center" style="background:#111111;padding:32px 25px 28px;">
            ${logo}
            <p style="margin:14px 0 0;font-size:11px;letter-spacing:2.5px;color:${gold};font-weight:bold;">HD HOMES LIMITED</p>
          </td>
        </tr>
        <tr>
          <td style="height:4px;background:${gold};font-size:0;line-height:0;">&nbsp;</td>
        </tr>
        <tr>
          <td class="content" style="padding:48px 50px 42px;">
            ${contentHtml}
          </td>
        </tr>
        <tr>
          <td style="padding:0 50px;"><div style="height:1px;background:#eeeeee;"></div></td>
        </tr>
        <tr>
          <td align="center" style="padding:30px 30px 34px;background:#ffffff;">
            <p style="margin:0 0 8px;font-size:14px;font-weight:bold;color:#222222;">${escapeHtml(brand.company_name)}</p>
            <p style="margin:0 0 18px;font-size:12px;line-height:1.6;color:#8a8a8a;">${escapeHtml(brand.tagline)}</p>
            <p style="margin:0 0 10px;font-size:12px;line-height:1.6;color:#8a8a8a;">
              <a href="${escapeHtml(brand.website_url)}" style="color:#8a8a8a;text-decoration:underline;">Website</a>
              &nbsp;&middot;&nbsp;
              <a href="mailto:${escapeHtml(brand.support_email)}" style="color:#8a8a8a;text-decoration:underline;">Support</a>
              &nbsp;&middot;&nbsp;
              <a href="${escapeHtml(brand.privacy_url)}" style="color:#8a8a8a;text-decoration:underline;">Privacy</a>
              &nbsp;&middot;&nbsp;
              <a href="${escapeHtml(brand.terms_url)}" style="color:#8a8a8a;text-decoration:underline;">Terms</a>
            </p>
            <p style="margin:0;font-size:11px;line-height:1.6;color:#a0a0a0;">This is an automated message from HD Homes Limited. Please do not reply directly to this email.</p>
            <p style="margin:14px 0 0;font-size:11px;color:#b0b0b0;">&copy; HD Homes Limited. All rights reserved.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`;
}

export function renderTransactionalEmail(opts: {
  subject: string;
  bodyHtml: string;
  textBody?: string | null;
  brand: Required<EmailBrand>;
  variables: Record<string, unknown>;
}): { subject: string; html: string; text: string } {
  const variables = normalizeEmailVariables(opts.variables, opts.brand);
  const subject = replaceVariables(opts.subject, variables);
  const content = replaceVariables(opts.bodyHtml || "", variables);
  const html = wrapEmailHtml(content, opts.brand);
  const text = replaceVariables(
    opts.textBody || stripTags(content) || subject,
    variables,
  );
  return { subject, html, text };
}

function stripTags(html: string): string {
  return html.replaceAll(/<[^>]+>/g, " ").replaceAll(/\s+/g, " ").trim();
}

export type ResendSendResult = {
  ok: boolean;
  id?: string;
  error?: string;
  status: number;
};

export async function sendWithResend(opts: {
  apiKey: string;
  from: string;
  to: string;
  subject: string;
  html: string;
  text?: string;
  replyTo?: string;
}): Promise<ResendSendResult> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${opts.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: opts.from,
      to: [opts.to],
      subject: opts.subject,
      html: opts.html,
      text: opts.text,
      reply_to: opts.replyTo || undefined,
    }),
  });

  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message =
      typeof payload?.message === "string"
        ? payload.message
        : typeof payload?.error === "string"
          ? payload.error
          : `Resend error (${res.status})`;
    return { ok: false, status: res.status, error: message };
  }

  return {
    ok: true,
    status: res.status,
    id: typeof payload?.id === "string" ? payload.id : undefined,
  };
}
