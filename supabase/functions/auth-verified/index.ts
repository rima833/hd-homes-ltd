/**
 * Legacy bridge for Auth email redirects that still point at this function.
 *
 * Do not serve HTML/SVG here — Supabase blocks HTML on *.supabase.co and iOS
 * Safari downloads SVG. Always 302 to the live website. Email confirmation
 * already completed on /auth/v1/verify before this redirect.
 */
Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey",
      },
    });
  }

  const incoming = new URL(req.url);
  const target = new URL("https://hdhomesltd.com/");
  incoming.searchParams.forEach((value, key) => {
    target.searchParams.set(key, value);
  });
  target.searchParams.set("hd_auth", "verified");

  return new Response(null, {
    status: 302,
    headers: {
      Location: target.toString(),
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
    },
  });
});
