import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  assertStaffMediaAccess,
  buildUploadSignature,
  corsHeaders,
} from "../_shared/cloudinary.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    await assertStaffMediaAccess(supabase);

    const cloudName = Deno.env.get("CLOUDINARY_CLOUD_NAME");
    const apiKey = Deno.env.get("CLOUDINARY_API_KEY");
    const apiSecret = Deno.env.get("CLOUDINARY_API_SECRET");

    if (!cloudName || !apiKey || !apiSecret) {
      return new Response(
        JSON.stringify({ error: "Cloudinary is not configured server-side." }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const body = await req.json();
    const publicId = String(body.public_id ?? "");
    const resourceType = String(body.resource_type ?? "image");

    if (!publicId) {
      return new Response(JSON.stringify({ error: "public_id required" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const signParams: Record<string, string | number> = {
      public_id: publicId,
      timestamp,
    };
    const signature = await buildUploadSignature(signParams, apiSecret);

    const form = new URLSearchParams({
      public_id: publicId,
      api_key: apiKey,
      timestamp: String(timestamp),
      signature,
    });

    const destroyUrl =
      `https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/destroy`;
    const destroyRes = await fetch(destroyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    });
    const destroyBody = await destroyRes.text();

    if (!destroyRes.ok) {
      return new Response(
        JSON.stringify({
          error: "Cloudinary destroy failed",
          detail: destroyBody,
        }),
        {
          status: destroyRes.status,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    return new Response(JSON.stringify({ ok: true, result: destroyBody }), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  } catch (err) {
    if (err instanceof Response) return err;
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
});
