/**
 * Public (anon/authenticated) signed upload for narrowly-scoped website folders.
 * Does NOT require a user JWT. Still keeps CLOUDINARY_API_SECRET server-side.
 *
 * Allowed folder prefixes only:
 *   hdhomes/general/website/
 *   hdhomes/inspections/
 *   hdhomes/crm/
 */
import {
  buildUploadSignature,
  corsHeaders,
} from "../_shared/cloudinary.ts";

const ALLOWED_PREFIXES = [
  "hdhomes/general/website/",
  "hdhomes/inspections/",
  "hdhomes/crm/",
];

function isAllowedPublicFolder(folder: string): boolean {
  if (folder.length < 8 || folder.length > 180) return false;
  if (!/^hdhomes\/[a-z0-9/_-]+$/i.test(folder)) return false;
  if (folder.includes("..") || folder.includes("//")) return false;
  return ALLOWED_PREFIXES.some(
    (prefix) => folder === prefix.slice(0, -1) || folder.startsWith(prefix),
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
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
    const folder = String(body.folder ?? "hdhomes/general/website/inbox");
    const resourceType = String(body.resource_type ?? "image");

    if (!isAllowedPublicFolder(folder)) {
      return new Response(
        JSON.stringify({
          error: "Folder not allowed for public uploads.",
        }),
        {
          status: 403,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    if (resourceType !== "image" && resourceType !== "video") {
      return new Response(
        JSON.stringify({ error: "Only image and video are allowed." }),
        {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
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
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
});
