/**
 * Staff-only: pull a remote image/video URL into Cloudinary and return asset metadata.
 * Does NOT delete the source. Client must update Supabase media rows after success.
 */
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
    const sourceUrl = String(body.source_url ?? "").trim();
    const folder = String(body.folder ?? "hdhomes/general/library");
    const resourceType = String(body.resource_type ?? "image");
    const mediaId = body.media_id != null ? String(body.media_id) : null;

    if (!sourceUrl || !/^https?:\/\//i.test(sourceUrl)) {
      return new Response(JSON.stringify({ error: "Valid source_url required." }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

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
    const signature = await buildUploadSignature(signParams, apiSecret);

    const form = new FormData();
    form.append("file", sourceUrl);
    form.append("api_key", apiKey);
    form.append("timestamp", String(timestamp));
    form.append("signature", signature);
    form.append("folder", folder);

    const uploadRes = await fetch(
      `https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/upload`,
      { method: "POST", body: form },
    );
    const uploaded = await uploadRes.json();

    if (!uploadRes.ok) {
      return new Response(
        JSON.stringify({
          error: "Cloudinary upload failed",
          detail: uploaded,
        }),
        {
          status: uploadRes.status,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const secureUrl = String(uploaded.secure_url ?? "");
    const publicId = String(uploaded.public_id ?? "");
    const thumbnailUrl =
      resourceType === "video"
        ? secureUrl.replace("/video/upload/", "/video/upload/so_0,w_640,h_360,c_fill,f_jpg,q_auto/")
        : secureUrl.replace(
          "/image/upload/",
          "/image/upload/c_fill,w_400,h_400,f_auto,q_auto/",
        );

    const payload = {
      cloudinary_public_id: publicId,
      cloudinary_asset_id: uploaded.asset_id ?? null,
      secure_url: secureUrl,
      file_url: secureUrl,
      thumbnail_url: thumbnailUrl,
      resource_type: String(uploaded.resource_type ?? resourceType),
      format: uploaded.format ?? null,
      width: uploaded.width ?? null,
      height: uploaded.height ?? null,
      duration: uploaded.duration ?? null,
      file_size: uploaded.bytes ?? null,
      folder,
      storage_provider: "cloudinary",
      updated_at: new Date().toISOString(),
      migration_source_url: sourceUrl,
    };

    if (mediaId) {
      const { error: updErr } = await supabase
        .from("media")
        .update({
          cloudinary_public_id: payload.cloudinary_public_id,
          cloudinary_asset_id: payload.cloudinary_asset_id,
          secure_url: payload.secure_url,
          file_url: payload.file_url,
          thumbnail_url: payload.thumbnail_url,
          resource_type: payload.resource_type,
          format: payload.format,
          width: payload.width,
          height: payload.height,
          duration: payload.duration,
          file_size: payload.file_size,
          folder: payload.folder,
          storage_provider: "cloudinary",
          updated_at: payload.updated_at,
        })
        .eq("id", mediaId);
      if (updErr) {
        return new Response(
          JSON.stringify({
            error: "Cloudinary upload succeeded but media row update failed",
            detail: updErr.message,
            uploaded: payload,
          }),
          {
            status: 500,
            headers: { "Content-Type": "application/json", ...corsHeaders() },
          },
        );
      }
    }

    return new Response(JSON.stringify({ ok: true, ...payload, media_id: mediaId }), {
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
