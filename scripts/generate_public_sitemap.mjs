#!/usr/bin/env node
/**
 * Appends published property, estate, and blog URLs to a sitemap URL list.
 *
 * Requires (env):
 *   SUPABASE_URL
 *   SUPABASE_ANON_KEY  (read-only published rows via RLS)
 *
 * Optional:
 *   SITE_URL (default https://hdhomesltd.com)
 *
 * Writes: build/sitemap-extra-urls.txt (one absolute URL per line)
 * Run before `dart run tool/generate_seo_artifacts.dart --urls=build/sitemap-extra-urls.txt`
 */

import fs from 'node:fs';
import path from 'node:path';

const siteUrl = (process.env.SITE_URL || 'https://hdhomesltd.com').replace(/\/$/, '');
const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/$/, '');
const anonKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !anonKey) {
  console.error('SUPABASE_URL and SUPABASE_ANON_KEY are required for dynamic sitemap rows.');
  process.exit(1);
}

async function fetchRows(table, select, filters = '') {
  const url = `${supabaseUrl}/rest/v1/${table}?select=${encodeURIComponent(select)}${filters}`;
  const res = await fetch(url, {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
    },
  });
  if (!res.ok) {
    throw new Error(`${table}: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

function propertyPath(row) {
  const slug = (row.slug || '').trim();
  const id = (row.id || '').trim();
  const segment = slug || id;
  return segment ? `${siteUrl}/properties/${segment}` : null;
}

function estatePath(row) {
  const slug = (row.slug || '').trim();
  return slug ? `${siteUrl}/estates/${slug}` : null;
}

function blogPath(row) {
  const slug = (row.slug || '').trim();
  return slug ? `${siteUrl}/blog/${slug}` : null;
}

const urls = new Set();

const properties = await fetchRows(
  'properties',
  'id,slug,updated_at',
  '&is_deleted=eq.false&is_published=eq.true&limit=500',
);
for (const row of properties) {
  const loc = propertyPath(row);
  if (loc) urls.add(loc);
}

const estates = await fetchRows(
  'estates',
  'slug,updated_at',
  '&is_deleted=eq.false&is_published=eq.true&limit=200',
);
for (const row of estates) {
  const loc = estatePath(row);
  if (loc) urls.add(loc);
}

const posts = await fetchRows(
  'blogs',
  'slug,updated_at',
  '&is_deleted=eq.false&status=eq.published&limit=500',
);
for (const row of posts) {
  const loc = blogPath(row);
  if (loc) urls.add(loc);
}

const outDir = path.join(process.cwd(), 'build');
fs.mkdirSync(outDir, { recursive: true });
const outFile = path.join(outDir, 'sitemap-extra-urls.txt');
fs.writeFileSync(outFile, [...urls].sort().join('\n') + (urls.size ? '\n' : ''));
console.log(`Wrote ${urls.size} dynamic URLs to ${outFile}`);
