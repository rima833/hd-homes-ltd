/**
 * DISABLED after one-shot legacy migration.
 * Intentionally returns 410 so the temporary open importer cannot be reused.
 */
import { corsHeaders } from "../_shared/cloudinary.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  return new Response(
    JSON.stringify({
      error: "cloudinary-import-legacy has been disabled after migration.",
    }),
    {
      status: 410,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    },
  );
});
