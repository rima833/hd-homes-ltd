# Volume 3 — Authentication & User Ecosystem

Enterprise identity platform for **HD Homes Ltd**. Volume 3 builds on Volume 1 architecture and Volume 2 public website.

## Parts

| Part | Document | Status |
|------|----------|--------|
| 1 | [Authentication Architecture & Identity Management](./part-01-authentication-architecture.md) | Phase 1 implemented · migration applied |
| 2 | [Registration & Account Creation](./part-02-registration-account-creation.md) | Phase 1 complete (SQL applied) |
| 3 | [Login & Secure Authentication](./part-03-login-secure-authentication.md) | Phase 1 complete (SQL applied) |
| 4 | [Email & Phone Verification](./part-04-email-phone-verification.md) | Phase 1 complete (SQL applied) |
| 5 | [Password Recovery & Account Security](./part-05-password-recovery-account-security.md) | Phase 1 complete (SQL applied) |
| 6 | [Multi-Factor Authentication (MFA)](./part-06-multi-factor-authentication.md) | Phase 1 complete (SQL applied) |
| 7 | [User Profiles & Account Management](./part-07-user-profiles-account-management.md) | Phase 1 complete (SQL applied) |
| 8 | [KYC & Identity Verification](./part-08-kyc-identity-verification.md) | Phase 1 complete (SQL applied) |
| 9 | [Notification & Communication Center](./part-09-notification-communication-center.md) | Phase 1 complete (SQL applied) |
| 10 | [Activity Logs, Audit Trails & System Monitoring](./part-10-activity-audit-observability.md) | Phase 1 complete (SQL applied) |
| 11 | [Organization, Teams & Staff Management](./part-11-organization-teams-staff.md) | Phase 1 complete (SQL applied) |
| 12 | [RBAC & Permission Engine](./part-12-rbac-permission-engine.md) | Phase 1 complete (SQL applied) |
| 13 | [User Preferences & Personalization Engine](./part-13-user-preferences-personalization.md) | Phase 1 complete (SQL applied) |
| 14 | [Enterprise Search & Global Command Center](./part-14-enterprise-search-command-center.md) | Phase 1 complete (SQL applied) |
| 15 | [AI Workspace & Digital Assistant Foundation](./part-15-ai-workspace-digital-assistant.md) | Phase 1 complete (SQL applied) |

**Volume 3 complete.** Volume 4 (Admin Dashboard & Business Management) can start when ready.

## Implementation rules

- Supabase Auth is the identity provider; business data lives in PostgreSQL (`profiles`, RBAC).
- Never put authorization data in mutable `user_metadata`.
- Never bypass RLS from Flutter.
- Do **not** apply new migrations until approved.
- All outbound messaging must go through the Communication Engine (Part 9).
- All audit / activity events must go through the Audit Service / Event Bus (Part 10).
- Staff structure (departments, teams, employees) lives in the Organization platform (Part 11).
- Authorization must go through the Permission / Policy Engine (Part 12) — never hardcode grants in features.
- User experience customization must go through the Preference / Personalization Engine (Part 13).
- Platform-wide find / navigate / command actions must go through the Enterprise Search & Command Center (Part 14).
- AI assistance must go through the AI Gateway (Part 15) — never call providers from feature modules.
