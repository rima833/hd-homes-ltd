// Shared Cloudinary signing utilities for Supabase Edge Functions.
// API secret is read from Deno.env only — never exposed to clients.

export async function sha1Hex(message: string): Promise<string> {
  const data = new TextEncoder().encode(message);
  const hash = await crypto.subtle.digest("SHA-1", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function cloudinarySign(
  params: Record<string, string | number>,
  apiSecret: string,
): string {
  const sorted = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join("&");
  return sha1Hex(sorted + apiSecret);
}

export async function buildUploadSignature(
  params: Record<string, string | number>,
  apiSecret: string,
): Promise<string> {
  const sorted = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join("&");
  return sha1Hex(sorted + apiSecret);
}

export function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

export async function assertStaffMediaAccess(
  supabase: ReturnType<typeof import("https://esm.sh/@supabase/supabase-js@2").createClient>,
): Promise<void> {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    throw new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }

  const checks = [
    "manage_marketing",
    "marketing.media",
    "marketing.write",
    "marketing.cms",
    "edit_property",
    "manage_construction",
  ];

  for (const perm of checks) {
    const { data, error } = await supabase.rpc("has_permission", {
      permission_slug: perm,
    });
    if (!error && data === true) return;
  }

  const { data: staff, error: staffErr } = await supabase.rpc("is_staff");
  if (!staffErr && staff === true) return;

  throw new Response(JSON.stringify({ error: "Forbidden" }), {
    status: 403,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

/**
 * Staff may upload anywhere.
 * Authenticated users may only upload to their own avatar folder
 * (entity_type=user and entity_id=<auth.uid>).
 */
export async function assertMediaUploadAccess(
  supabase: ReturnType<typeof import("https://esm.sh/@supabase/supabase-js@2").createClient>,
  opts?: { entityType?: string; entityId?: string; folder?: string },
): Promise<{ userId: string; isStaff: boolean }> {
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    throw new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
  const userId = userData.user.id;

  const checks = [
    "manage_marketing",
    "marketing.media",
    "marketing.write",
    "marketing.cms",
    "edit_property",
    "manage_construction",
  ];
  for (const perm of checks) {
    const { data, error } = await supabase.rpc("has_permission", {
      permission_slug: perm,
    });
    if (!error && data === true) return { userId, isStaff: true };
  }
  const { data: staff, error: staffErr } = await supabase.rpc("is_staff");
  if (!staffErr && staff === true) return { userId, isStaff: true };

  const entityType = (opts?.entityType ?? "").toLowerCase();
  const entityId = opts?.entityId ?? "";
  const folder = opts?.folder ?? "";
  const isOwnAvatar =
    entityType === "user" &&
    entityId === userId &&
    (folder.includes(`/users/${userId}/`) || folder.endsWith(`/users/${userId}/avatar`) ||
      folder.includes(`users/${userId}/avatar`));

  if (isOwnAvatar) return { userId, isStaff: false };

  throw new Response(JSON.stringify({ error: "Forbidden" }), {
    status: 403,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}
