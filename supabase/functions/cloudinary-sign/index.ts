import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  assertMediaUploadAccess,
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

    const body = await req.json();
    const folder = String(body.folder ?? "hdhomes/general/library");
    const resourceType = String(body.resource_type ?? "image");
    const entityType = String(body.entity_type ?? "");
    const entityId = body.entity_id != null ? String(body.entity_id) : "";

    await assertMediaUploadAccess(supabase, {
      entityType,
      entityId,
      folder,
    });

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

    // Non-staff may only write into their avatar folder tree.
    if (!folder.startsWith("hdhomes/")) {
      return new Response(JSON.stringify({ error: "Invalid folder root." }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

    const timestamp = Math.floor(Date.now() / 1000);

    const signParams: Record<string, string | number> = {
      folder,
      timestamp,
    };

    const eager =
      resourceType === "video"
        ? "w_640,h_360,c_fill,f_jpg,q_auto"
        : undefined;
    if (eager) signParams.eager = eager;

    const signature = await buildUploadSignature(signParams, apiSecret);

    return new Response(
      JSON.stringify({
        cloud_name: cloudName,
        api_key: apiKey,
        timestamp,
        signature,
        folder,
        resource_type: resourceType,
        eager,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders() },
      },
    );
  } catch (err) {
    if (err instanceof Response) return err;
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
});
