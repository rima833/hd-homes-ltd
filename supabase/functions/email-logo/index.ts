import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Cache-Control": "public, max-age=86400",
};

async function loadLogoB64(): Promise<string> {
  try {
    return (await Deno.readTextFile(new URL("./logo.b64", import.meta.url))).trim();
  } catch {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      throw new Error("logo.b64 missing and no service credentials");
    }
    const admin = createClient(supabaseUrl, serviceKey);
    const { data, error } = await admin
      .from("email_logo_assets")
      .select("b64")
      .eq("id", "hd_homes_logo")
      .maybeSingle();
    if (error || !data?.b64) {
      throw new Error(error?.message ?? "email logo asset not found");
    }
    return data.b64.trim();
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const b64 = await loadLogoB64();
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

  return new Response(bytes, {
    status: 200,
    headers: {
      ...cors,
      "Content-Type": "image/png",
    },
  });
});
