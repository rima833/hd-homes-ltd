# Investor Portal Hooks (Volume 2 → 3 bridge)

Lightweight public-site entry points into the Investor Portal shell. Full portal modules ship in **Volume 3 — Authentication & User Ecosystem**.

## What ships now

| Surface | Hook |
|---------|------|
| Investment Hub hero | **Investor Portal** CTA → `/investor` |
| Investment Hub closing | `InvestorPortalCtaSection` — portal capabilities + Access / Sign in / Trust |
| Trust Center | Due diligence **Access Investor Portal** + Sign in deep link |
| `/investor/*` shell | `InvestorPortalStubPage` with links back to Investment Hub & Trust |

## Auth behavior

Protected prefixes (`/investor`, `/client`, `/dashboard`) already redirect unauthenticated users to:

```
/login?redirect=<encoded portal path>
```

Public CTAs intentionally hit `/investor` so the existing router redirect handles login return.

## Code map

```
lib/features/investment/presentation/widgets/investor_portal_cta.dart
lib/features/investor/presentation/pages/investor_portal_stub_page.dart
lib/core/router/shell_routes.dart  # investorShellRoute uses stub pages
```

## Not included (Volume 3)

- Auth-gated portfolio / analytics / documents UI
- Live construction & ROI data
- Role-based investor permissions
