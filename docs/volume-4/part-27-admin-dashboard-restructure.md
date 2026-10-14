# Admin Dashboard Restructuring (Master Refactor)

## What changed

The Admin Dashboard sidebar was pruned from a Volume-4 mega-menu into the permanent control-center structure:

- **Dashboard**
- **Website** (Homepage, Hero, Pages, Featured Estates/Properties, Testimonials, Team, FAQ, Blog, Menus, Footer, SEO, Media, Company)
- **Properties** (Estates + PMS property backbone)
- **Clients** → CRM Command Center
- **Investors** → IMP Command Center
- **Sales CRM** → CRM Command Center
- **Construction / Finance / Documents / Marketing / Reports / Analytics / Support**
- **Users** (Staff, Roles, Permissions)
- **Settings / Activity Logs**

## Removed from navigation (and feature packages)

Ops Center (EOC), Procurement, Assets, GRC, EGRC, ECC, EPM, Platform (EDP), Workplace (EDWP), Customer Experience (ECXP), plus HR / Integrations / Security / Sales-as-separate / Notifications / Profile clutter from the primary sidebar.

Reusable domain packages for removed modules were deleted from `lib/features/` after unwiring routes. Database tables remain (no destructive SQL drop in this pass).

## Website CMS

New feature: `lib/features/cms/`

- Supabase-backed editors for homepage sections, hero, pages, featured estates/properties, testimonials, team, FAQ, blog, menus/footer, SEO, media library, banners
- Reports hub with PDF/Excel export via `ExportEngine`
- Settings / company profile editor

## Sync model

Public website, Client Portal, and Investor Portal continue to read the same Supabase tables. Publishing featured estates/properties or construction updates does not require a second write path — admin toggles update the source of truth.

## Verification

```bash
flutter analyze lib/core/router/shell_routes.dart lib/core/navigation lib/features/cms
```

Sign in as staff → `/dashboard` → confirm pruned sidebar and Website › Homepage loads.
