/**
 * Staff-only batch migration: pull legacy image/video URLs into Cloudinary.
 * Covers property/blog/estate galleries plus website marketing surfaces
 * (heroes, banners, partners, testimonials, landing heroes).
 * Uses service role for DB writes. Does NOT delete source Storage/Unsplash files.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  assertStaffMediaAccess,
  buildUploadSignature,
  corsHeaders,
} from "../_shared/cloudinary.ts";

type MigrateTarget = {
  kind:
    | "property_image"
    | "blog_cover"
    | "estate_image"
    | "hero_background"
    | "hero_video"
    | "banner"
    | "partner"
    | "testimonial"
    | "landing_hero";
  id: string;
  entityId: string;
  sourceUrl: string;
  mediaId: string | null;
  folder: string;
  resourceType: "image" | "video";
  isCover?: boolean;
  /** For hero_video: content jsonb patch key */
  contentKey?: string;
};

async function uploadUrlToCloudinary(opts: {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
  sourceUrl: string;
  folder: string;
  resourceType: "image" | "video";
}) {
  const timestamp = Math.floor(Date.now() / 1000);
  const signParams: Record<string, string | number> = {
    folder: opts.folder,
    timestamp,
  };
  const signature = await buildUploadSignature(signParams, opts.apiSecret);
  const form = new FormData();
  form.append("file", opts.sourceUrl);
  form.append("api_key", opts.apiKey);
  form.append("timestamp", String(timestamp));
  form.append("signature", signature);
  form.append("folder", opts.folder);

  const uploadRes = await fetch(
    `https://api.cloudinary.com/v1_1/${opts.cloudName}/${opts.resourceType}/upload`,
    { method: "POST", body: form },
  );
  const uploaded = await uploadRes.json();
  if (!uploadRes.ok) {
    throw new Error(
      `Cloudinary upload failed: ${JSON.stringify(uploaded)}`,
    );
  }
  const secureUrl = String(uploaded.secure_url ?? "");
  const thumbnailUrl = opts.resourceType === "video"
    ? secureUrl.replace(
      "/video/upload/",
      "/video/upload/so_0,w_640,h_360,c_fill,f_jpg,q_auto/",
    )
    : secureUrl.replace(
      "/image/upload/",
      "/image/upload/c_fill,w_400,h_400,f_auto,q_auto/",
    );
  return {
    cloudinary_public_id: String(uploaded.public_id ?? ""),
    cloudinary_asset_id: uploaded.asset_id ?? null,
    secure_url: secureUrl,
    file_url: secureUrl,
    thumbnail_url: thumbnailUrl,
    resource_type: String(uploaded.resource_type ?? opts.resourceType),
    format: uploaded.format ?? null,
    width: uploaded.width ?? null,
    height: uploaded.height ?? null,
    duration: uploaded.duration ?? null,
    file_size: uploaded.bytes ?? null,
    folder: opts.folder,
    storage_provider: "cloudinary",
  };
}

function isCloudinary(url: string): boolean {
  return url.includes("res.cloudinary.com");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization") ?? "";

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    await assertStaffMediaAccess(userClient);

    if (!serviceKey) {
      return new Response(
        JSON.stringify({ error: "Service role key not configured." }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

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

    const admin = createClient(supabaseUrl, serviceKey);
    const body = await req.json().catch(() => ({}));
    const limit = Math.min(Number(body.limit ?? 40), 100);

    const targets: MigrateTarget[] = [];

    const { data: propertyRows } = await admin
      .from("property_images")
      .select("id, property_id, url, media_id, is_cover")
      .eq("is_deleted", false)
      .limit(limit);

    for (const row of propertyRows ?? []) {
      const url = String(row.url ?? "").trim();
      if (!url || isCloudinary(url)) continue;
      const propertyId = String(row.property_id ?? "");
      if (!propertyId) continue;
      targets.push({
        kind: "property_image",
        id: String(row.id),
        entityId: propertyId,
        sourceUrl: url,
        mediaId: row.media_id ? String(row.media_id) : null,
        folder: `hdhomes/properties/${propertyId}/gallery`,
        resourceType: "image",
        isCover: row.is_cover === true,
      });
    }

    const { data: blogRows } = await admin
      .from("blogs")
      .select("id, cover_image_url, media_id")
      .eq("is_deleted", false)
      .not("cover_image_url", "is", null)
      .limit(limit);

    for (const row of blogRows ?? []) {
      const url = String(row.cover_image_url ?? "").trim();
      if (!url || isCloudinary(url)) continue;
      const blogId = String(row.id ?? "");
      if (!blogId) continue;
      targets.push({
        kind: "blog_cover",
        id: blogId,
        entityId: blogId,
        sourceUrl: url,
        mediaId: row.media_id ? String(row.media_id) : null,
        folder: `hdhomes/blog/${blogId}/featured`,
        resourceType: "image",
      });
    }

    const { data: estateRows } = await admin
      .from("estate_images")
      .select("id, estate_id, url, media_id, is_cover")
      .eq("is_deleted", false)
      .limit(limit);

    for (const row of estateRows ?? []) {
      const url = String(row.url ?? "").trim();
      if (!url || isCloudinary(url)) continue;
      const estateId = String(row.estate_id ?? "");
      if (!estateId) continue;
      targets.push({
        kind: "estate_image",
        id: String(row.id),
        entityId: estateId,
        sourceUrl: url,
        mediaId: row.media_id ? String(row.media_id) : null,
        folder: `hdhomes/developments/${estateId}/gallery`,
        resourceType: "image",
        isCover: row.is_cover === true,
      });
    }

    const { data: heroRows } = await admin
      .from("hero_sections")
      .select("id, page_key, background_url, content")
      .eq("is_deleted", false)
      .limit(limit);

    for (const row of heroRows ?? []) {
      const id = String(row.id ?? "");
      const pageKey = String(row.page_key ?? "homepage");
      if (!id) continue;
      const bg = String(row.background_url ?? "").trim();
      if (bg && !isCloudinary(bg)) {
        targets.push({
          kind: "hero_background",
          id,
          entityId: pageKey,
          sourceUrl: bg,
          mediaId: null,
          folder: `hdhomes/marketing/hero/${pageKey}`,
          resourceType: "image",
        });
      }
      const content = (row.content ?? {}) as Record<string, unknown>;
      const videoKey = content.video_url != null
        ? "video_url"
        : content.videoUrl != null
        ? "videoUrl"
        : "video_url";
      const video = String(content[videoKey] ?? "").trim();
      if (video && !isCloudinary(video)) {
        targets.push({
          kind: "hero_video",
          id,
          entityId: pageKey,
          sourceUrl: video,
          mediaId: null,
          folder: `hdhomes/marketing/hero/${pageKey}`,
          resourceType: "video",
          contentKey: videoKey,
        });
      }
    }

    const { data: bannerRows } = await admin
      .from("banners")
      .select("id, image_url")
      .eq("is_deleted", false)
      .not("image_url", "is", null)
      .limit(limit);

    for (const row of bannerRows ?? []) {
      const url = String(row.image_url ?? "").trim();
      const id = String(row.id ?? "");
      if (!id || !url || isCloudinary(url)) continue;
      targets.push({
        kind: "banner",
        id,
        entityId: id,
        sourceUrl: url,
        mediaId: null,
        folder: "hdhomes/marketing/banners",
        resourceType: "image",
      });
    }

    const { data: partnerRows } = await admin
      .from("partners")
      .select("id, logo_url, media_id")
      .eq("is_deleted", false)
      .not("logo_url", "is", null)
      .limit(limit);

    for (const row of partnerRows ?? []) {
      const url = String(row.logo_url ?? "").trim();
      const id = String(row.id ?? "");
      if (!id || !url || isCloudinary(url)) continue;
      targets.push({
        kind: "partner",
        id,
        entityId: id,
        sourceUrl: url,
        mediaId: row.media_id ? String(row.media_id) : null,
        folder: "hdhomes/marketing/partners",
        resourceType: "image",
      });
    }

    const { data: testimonialRows } = await admin
      .from("testimonials")
      .select("id, avatar_url")
      .eq("is_deleted", false)
      .not("avatar_url", "is", null)
      .limit(limit);

    for (const row of testimonialRows ?? []) {
      const url = String(row.avatar_url ?? "").trim();
      const id = String(row.id ?? "");
      if (!id || !url || isCloudinary(url)) continue;
      targets.push({
        kind: "testimonial",
        id,
        entityId: id,
        sourceUrl: url,
        mediaId: null,
        folder: "hdhomes/marketing/testimonials",
        resourceType: "image",
      });
    }

    const { data: landingRows } = await admin
      .from("landing_pages")
      .select("id, hero_image_url")
      .not("hero_image_url", "is", null)
      .limit(limit);

    for (const row of landingRows ?? []) {
      const url = String(row.hero_image_url ?? "").trim();
      const id = String(row.id ?? "");
      if (!id || !url || isCloudinary(url)) continue;
      targets.push({
        kind: "landing_hero",
        id,
        entityId: id,
        sourceUrl: url,
        mediaId: null,
        folder: "hdhomes/marketing/landing",
        resourceType: "image",
      });
    }

    let migrated = 0;
    let failed = 0;
    const errors: Array<{ id: string; kind: string; error: string }> = [];

    for (const target of targets) {
      try {
        const uploaded = await uploadUrlToCloudinary({
          cloudName,
          apiKey,
          apiSecret,
          sourceUrl: target.sourceUrl,
          folder: target.folder,
          resourceType: target.resourceType,
        });

        let mediaId = target.mediaId;
        const entityType = target.kind === "blog_cover"
          ? "blog"
          : target.kind === "estate_image"
          ? "estate"
          : target.kind === "property_image"
          ? "property"
          : "marketing";

        if (mediaId) {
          const { error } = await admin.from("media").update({
            ...uploaded,
            updated_at: new Date().toISOString(),
          }).eq("id", mediaId);
          if (error) throw error;
        } else {
          const { data: created, error } = await admin
            .from("media")
            .insert({
              title: `Migrated ${target.kind}`,
              file_type: target.resourceType,
              entity_type: entityType,
              entity_id: target.entityId,
              is_published: true,
              is_active: true,
              is_cover: target.isCover === true,
              is_primary: target.isCover === true,
              ...uploaded,
            })
            .select("id")
            .single();
          if (error) throw error;
          mediaId = String(created.id);
        }

        if (target.kind === "property_image") {
          const { error } = await admin.from("property_images").update({
            url: uploaded.secure_url,
            media_id: mediaId,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "blog_cover") {
          const { error } = await admin.from("blogs").update({
            cover_image_url: uploaded.secure_url,
            media_id: mediaId,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "estate_image") {
          const { error } = await admin.from("estate_images").update({
            url: uploaded.secure_url,
            media_id: mediaId,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "hero_background") {
          const { error } = await admin.from("hero_sections").update({
            background_url: uploaded.secure_url,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "hero_video") {
          const { data: hero } = await admin
            .from("hero_sections")
            .select("content")
            .eq("id", target.id)
            .maybeSingle();
          const content = {
            ...((hero?.content ?? {}) as Record<string, unknown>),
          };
          content.video_url = uploaded.secure_url;
          delete content.videoUrl;
          const { error } = await admin.from("hero_sections").update({
            content,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "banner") {
          const { error } = await admin.from("banners").update({
            image_url: uploaded.secure_url,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "partner") {
          const { error } = await admin.from("partners").update({
            logo_url: uploaded.secure_url,
            media_id: mediaId,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "testimonial") {
          const { error } = await admin.from("testimonials").update({
            avatar_url: uploaded.secure_url,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        } else if (target.kind === "landing_hero") {
          const { error } = await admin.from("landing_pages").update({
            hero_image_url: uploaded.secure_url,
            updated_at: new Date().toISOString(),
          }).eq("id", target.id);
          if (error) throw error;
        }

        migrated++;
      } catch (e) {
        failed++;
        errors.push({
          id: target.id,
          kind: target.kind,
          error: String(e),
        });
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        scanned: targets.length,
        migrated,
        failed,
        errors: errors.slice(0, 10),
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
