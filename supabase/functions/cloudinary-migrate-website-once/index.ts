/**
 * DISABLED after one-shot website Cloudinary migration.
 */
import { corsHeaders } from "../_shared/cloudinary.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  return new Response(
    JSON.stringify({
      error: "cloudinary-migrate-website-once has been disabled after migration.",
    }),
    {
      status: 410,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    },
  );
});
