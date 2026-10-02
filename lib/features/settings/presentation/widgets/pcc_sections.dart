import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/auth/policies/admin_access_policy.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/core/config/cloudinary_config.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/presentation/pages/payment_verification_page.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_ops_panels.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_health.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:hdhomesproject/features/settings/presentation/widgets/pcc_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

class PccOverviewSection extends ConsumerWidget {
  const PccOverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(platformHealthProvider);
    final auditsAsync = ref.watch(recentSettingsAuditsProvider);
    final fmt = DateFormat('dd MMM yyyy · HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PccPanel(
          title: 'Platform health',
          subtitle:
              'Statuses are computed from live Supabase signals — never invented.',
          trailing: IconButton(
            tooltip: 'Refresh health',
            onPressed: () => ref.invalidate(platformHealthProvider),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            color: AdminDeskColors.muted,
          ),
          child: healthAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AdminDeskColors.gold),
              ),
            ),
            error: (e, _) => Text(
              '$e',
              style: const TextStyle(color: AdminDeskColors.red),
            ),
            data: (snapshot) {
              final checks = snapshot.checks.values.toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final check in checks)
                        _HealthChip(check: check),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Checked ${fmt.format(snapshot.checkedAt.toLocal())}',
                    style: const TextStyle(
                      color: AdminDeskColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (snapshot.lastSettingsUpdateAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last settings update ${fmt.format(snapshot.lastSettingsUpdateAt!.toLocal())}'
                      '${snapshot.lastSettingsUpdateBy != null && snapshot.lastSettingsUpdateBy!.isNotEmpty ? ' · ${snapshot.lastSettingsUpdateBy}' : ''}',
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (snapshot.issues.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Attention',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final issue in snapshot.issues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${issue.label}: ${issue.notes ?? issue.status.label}',
                          style: TextStyle(
                            color: pccStatusColor(issue.status),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        PccPanel(
          title: 'Recent settings audit',
          subtitle: 'Writes via upsert_app_setting are logged to audit_logs.',
          child: auditsAsync.when(
            loading: () => const LinearProgressIndicator(
              color: AdminDeskColors.gold,
              backgroundColor: AdminDeskColors.elevated,
            ),
            error: (e, _) => Text(
              '$e',
              style: const TextStyle(color: AdminDeskColors.red),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Text(
                  'No settings audit events yet. Save a setting to create the first trail.',
                  style: TextStyle(color: AdminDeskColors.muted, fontSize: 13),
                );
              }
              return Column(
                children: [
                  for (final row in rows.take(8))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminDeskColors.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminDeskColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.history,
                            size: 14,
                            color: AdminDeskColors.gold,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${row['action'] ?? 'settings.update'} · ${row['entity_id'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _fmtAuditTime(row['created_at'], fmt),
                            style: const TextStyle(
                              color: AdminDeskColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmtAuditTime(Object? raw, DateFormat fmt) {
    final dt = DateTime.tryParse('$raw');
    if (dt == null) return '';
    return fmt.format(dt.toLocal());
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.check});
  final PlatformHealthCheck check;

  @override
  Widget build(BuildContext context) {
    final color = pccStatusColor(check.status);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminDeskColors.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            check.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            check.status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          if ((check.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              check.notes!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PccBusinessSection extends StatelessWidget {
  const PccBusinessSection({
    super.key,
    required this.draft,
    required this.formSeed,
    required this.onPatch,
  });

  final PlatformSettingsBundle draft;
  final int formSeed;
  final void Function({Map<String, dynamic>? company}) onPatch;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> next(String key, String value) => {
          ...draft.company,
          key: value,
        };
    return PccPanel(
      title: 'Business profile',
      subtitle: 'Legal identity shown across the public site and portals.',
      child:  _FieldGrid(
        children: [
          PccField(
            label: 'Company name',
            value: draft.companyName,
            seed: formSeed,
            onChanged: (v) => onPatch(company: next('name', v)),
          ),
          PccField(
            label: 'Legal name',
            value: draft.legalName,
            seed: formSeed,
            onChanged: (v) => onPatch(company: next('legal_name', v)),
          ),
          PccField(
            label: 'Tagline',
            value: draft.tagline,
            seed: formSeed,
            onChanged: (v) => onPatch(company: next('tagline', v)),
          ),
          PccField(
            label: 'Registration number',
            value: draft.registrationNumber,
            seed: formSeed,
            onChanged: (v) => onPatch(company: next('registration_number', v)),
          ),
          PccField(
            label: 'Country',
            value: draft.country,
            seed: formSeed,
            onChanged: (v) => onPatch(company: next('country', v)),
          ),
          PccField(
            label: 'Timezone',
            value: draft.timezone,
            seed: formSeed,
            onChanged: (v) => onPatch(company: next('timezone', v)),
          ),
        ],
      ),
    );
  }
}

class PccContactSection extends StatelessWidget {
  const PccContactSection({
    super.key,
    required this.draft,
    required this.formSeed,
    required this.onPatch,
  });

  final PlatformSettingsBundle draft;
  final int formSeed;
  final void Function({Map<String, dynamic>? contact}) onPatch;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> next(String key, String value) => {
          ...draft.contact,
          key: value,
        };
    return PccPanel(
      title: 'Contact channels',
      subtitle: 'Public phone, WhatsApp, email, address, and support hours.',
      child:  _FieldGrid(
        children: [
          PccField(
            label: 'Support email',
            value: draft.supportEmail,
            seed: formSeed,
            onChanged: (v) => onPatch(contact: next('email', v)),
          ),
          PccField(
            label: 'Phone',
            value: draft.supportPhone,
            seed: formSeed,
            onChanged: (v) => onPatch(contact: next('phone', v)),
          ),
          PccField(
            label: 'WhatsApp',
            value: draft.supportWhatsapp,
            seed: formSeed,
            onChanged: (v) => onPatch(contact: next('whatsapp', v)),
          ),
          PccField(
            label: 'Address',
            value: draft.officeAddress,
            seed: formSeed,
            onChanged: (v) => onPatch(contact: next('address', v)),
          ),
          PccField(
            label: 'Support hours',
            value: draft.supportHours,
            seed: formSeed,
            onChanged: (v) => onPatch(contact: next('support_hours', v)),
          ),
        ],
      ),
    );
  }
}

class PccBrandSocialSection extends StatelessWidget {
  const PccBrandSocialSection({
    super.key,
    required this.draft,
    required this.formSeed,
    required this.onPatch,
  });

  final PlatformSettingsBundle draft;
  final int formSeed;
  final void Function({
    Map<String, dynamic>? theme,
    Map<String, dynamic>? social,
  }) onPatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PccPanel(
          title: 'Brand colors',
          subtitle:
              'Reference hex values for Control Center consumers. Full theme application lands in later phases.',
          child:  _FieldGrid(
            children: [
              PccField(
                label: 'Primary',
                value: draft.brandPrimary,
                seed: formSeed,
                hint: '#B48743',
                onChanged: (v) => onPatch(
                  theme: {...draft.theme, 'primary': v},
                ),
              ),
              PccField(
                label: 'Accent',
                value: draft.brandAccent,
                seed: formSeed,
                hint: '#D4A34E',
                onChanged: (v) => onPatch(
                  theme: {...draft.theme, 'accent': v},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PccPanel(
          title: 'Social profiles',
          subtitle: 'Public social URLs used by the footer and contact surfaces.',
          child:  _FieldGrid(
            children: [
              PccField(
                label: 'Facebook',
                value: draft.facebookUrl,
                seed: formSeed,
                onChanged: (v) => onPatch(
                  social: {...draft.social, 'facebook_url': v},
                ),
              ),
              PccField(
                label: 'Instagram',
                value: draft.instagramUrl,
                seed: formSeed,
                onChanged: (v) => onPatch(
                  social: {...draft.social, 'instagram_url': v},
                ),
              ),
              PccField(
                label: 'Twitter / X',
                value: draft.twitterUrl,
                seed: formSeed,
                onChanged: (v) => onPatch(
                  social: {...draft.social, 'twitter_url': v},
                ),
              ),
              PccField(
                label: 'LinkedIn',
                value: draft.linkedinUrl,
                seed: formSeed,
                onChanged: (v) => onPatch(
                  social: {...draft.social, 'linkedin_url': v},
                ),
              ),
              PccField(
                label: 'YouTube',
                value: draft.youtubeUrl,
                seed: formSeed,
                onChanged: (v) => onPatch(
                  social: {...draft.social, 'youtube_url': v},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PccSeoSection extends StatelessWidget {
  const PccSeoSection({
    super.key,
    required this.draft,
    required this.formSeed,
    required this.onPatch,
  });

  final PlatformSettingsBundle draft;
  final int formSeed;
  final void Function({Map<String, dynamic>? seo}) onPatch;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> next(String key, String value) => {
          ...draft.seo,
          key: value,
        };
    return PccPanel(
      title: 'SEO defaults',
      subtitle:
          'Fallback title, description, site URL, and OG image when path-level CMS SEO is empty.',
      child:  _FieldGrid(
        children: [
          PccField(
            label: 'Default title',
            value: draft.seoTitle,
            seed: formSeed,
            onChanged: (v) => onPatch(seo: next('default_title', v)),
          ),
          PccField(
            label: 'Default description',
            value: draft.seoDescription,
            seed: formSeed,
            maxLines: 3,
            onChanged: (v) => onPatch(seo: next('default_description', v)),
          ),
          PccField(
            label: 'Site URL',
            value: draft.siteUrl,
            seed: formSeed,
            hint: 'https://hdhomes.ng',
            onChanged: (v) => onPatch(seo: next('site_url', v)),
          ),
          PccField(
            label: 'OG image URL',
            value: draft.ogImageUrl,
            seed: formSeed,
            onChanged: (v) => onPatch(seo: next('og_image_url', v)),
          ),
          PccField(
            label: 'Twitter handle',
            value: draft.twitterHandle,
            seed: formSeed,
            onChanged: (v) => onPatch(seo: next('twitter_handle', v)),
          ),
        ],
      ),
    );
  }
}

class PccWebsiteSection extends StatelessWidget {
  const PccWebsiteSection({
    super.key,
    required this.draft,
    required this.formSeed,
    required this.onPatch,
  });

  final PlatformSettingsBundle draft;
  final int formSeed;
  final void Function({
    Map<String, dynamic>? websiteFeatures,
    Map<String, dynamic>? maintenance,
  }) onPatch;

  @override
  Widget build(BuildContext context) {
    void setFeature(String key, bool value) {
      onPatch(websiteFeatures: {...draft.websiteFeatures, key: value});
    }

    void setMaintenance(String key, Object value) {
      onPatch(maintenance: {...draft.maintenance, key: value});
    }

    return Column(
      children: [
        PccPanel(
          title: 'Website feature flags',
          subtitle:
              'These toggles gate live public surfaces (FABs, calculators, newsletter, blog).',
          child: Column(
            children: [
              PccToggle(
                title: 'WhatsApp FAB',
                subtitle: 'Floating WhatsApp action on public pages.',
                value: draft.showWhatsappFab,
                onChanged: (v) => setFeature('show_whatsapp_fab', v),
              ),
              PccToggle(
                title: 'Live chat FAB',
                subtitle: 'Floating live-chat entry point.',
                value: draft.showLiveChatFab,
                onChanged: (v) => setFeature('show_live_chat_fab', v),
              ),
              PccToggle(
                title: 'Call FAB (mobile)',
                subtitle: 'Mobile call shortcut.',
                value: draft.showCallFabMobile,
                onChanged: (v) => setFeature('show_call_fab_mobile', v),
              ),
              PccToggle(
                title: 'Book FAB (mobile)',
                subtitle: 'Mobile book-inspection shortcut.',
                value: draft.showBookFabMobile,
                onChanged: (v) => setFeature('show_book_fab_mobile', v),
              ),
              PccToggle(
                title: 'Payment calculator',
                subtitle: 'Public payment plan calculator.',
                value: draft.enablePaymentCalculator,
                onChanged: (v) => setFeature('enable_payment_calculator', v),
              ),
              PccToggle(
                title: 'ROI calculator',
                subtitle: 'Public investment ROI calculator.',
                value: draft.enableRoiCalculator,
                onChanged: (v) => setFeature('enable_roi_calculator', v),
              ),
              PccToggle(
                title: 'Public search',
                subtitle: 'Site search overlay availability.',
                value: draft.enablePublicSearch,
                onChanged: (v) => setFeature('enable_public_search', v),
              ),
              PccToggle(
                title: 'Newsletter',
                subtitle: 'Homepage newsletter signup band.',
                value: draft.enableNewsletter,
                onChanged: (v) => setFeature('enable_newsletter', v),
              ),
              PccToggle(
                title: 'Blog in header',
                subtitle: 'Show Blog in the public header navigation.',
                value: draft.enableBlog,
                onChanged: (v) => setFeature('enable_blog', v),
              ),
              PccToggle(
                title: 'Testimonials',
                subtitle: 'Published quotes on the homepage and every other public page.',
                value: draft.enableTestimonials,
                onChanged: (v) => setFeature('enable_testimonials', v),
              ),
              PccToggle(
                title: 'Partners',
                subtitle: 'Homepage partners / affiliations section.',
                value: draft.enablePartners,
                onChanged: (v) => setFeature('enable_partners', v),
              ),
              PccToggle(
                title: 'FAQ hub',
                subtitle: 'Published questions on the homepage and every other public page.',
                value: draft.enableFaq,
                onChanged: (v) => setFeature('enable_faq', v),
              ),
              PccToggle(
                title: 'Featured properties',
                subtitle: 'Homepage featured property listings.',
                value: draft.enableFeaturedProperties,
                onChanged: (v) => setFeature('enable_featured_properties', v),
              ),
              PccToggle(
                title: 'Property / estate listings',
                subtitle: 'Properties nav and featured estates.',
                value: draft.enablePropertyListings,
                onChanged: (v) => setFeature('enable_property_listings', v),
              ),
              PccToggle(
                title: 'Investment section',
                subtitle: 'Investment nav, CTA, and related surfaces.',
                value: draft.enableInvestmentSection,
                onChanged: (v) => setFeature('enable_investment_section', v),
              ),
              PccToggle(
                title: 'Construction updates',
                subtitle: 'Construction hub entry in public navigation.',
                value: draft.enableConstructionUpdates,
                onChanged: (v) => setFeature('enable_construction_updates', v),
              ),
              PccToggle(
                title: 'Contact forms',
                subtitle: 'Public contact hub and lead capture forms.',
                value: draft.enableContactForms,
                onChanged: (v) => setFeature('enable_contact_forms', v),
              ),
              PccToggle(
                title: 'Client portal entry',
                subtitle: 'Client login / portal links on public surfaces.',
                value: draft.enableClientPortalEntry,
                onChanged: (v) => setFeature('enable_client_portal_entry', v),
              ),
              PccToggle(
                title: 'Investor portal entry',
                subtitle: 'Investor login / portal links on public surfaces.',
                value: draft.enableInvestorPortalEntry,
                onChanged: (v) =>
                    setFeature('enable_investor_portal_entry', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PccPanel(
          title: 'Maintenance & banners',
          subtitle: 'Full-page maintenance lock and optional public banner.',
          child: Column(
            children: [
              PccToggle(
                title: 'Maintenance mode',
                subtitle: 'Locks the public site for non-staff visitors.',
                value: draft.maintenanceEnabled,
                onChanged: (v) => setMaintenance('enabled', v),
              ),
              PccToggle(
                title: 'Allow admin bypass',
                subtitle: 'Signed-in staff can still browse while locked.',
                value: draft.allowAdminBypass,
                onChanged: (v) => setMaintenance('allow_admin_bypass', v),
              ),
              PccToggle(
                title: 'Show announcement banner',
                subtitle: 'Uses the banner message below on the public shell.',
                value: draft.showMaintenanceBanner,
                onChanged: (v) => setMaintenance('show_banner', v),
              ),
              const SizedBox(height: 8),
              _FieldGrid(
                children: [
                  PccField(
                    label: 'Maintenance title',
                    value: draft.maintenanceTitle,
                    seed: formSeed,
                    onChanged: (v) => setMaintenance('title', v),
                  ),
                  PccField(
                    label: 'Maintenance message',
                    value: draft.maintenanceMessage,
                    seed: formSeed,
                    maxLines: 3,
                    onChanged: (v) => setMaintenance('message', v),
                  ),
                  PccField(
                    label: 'Banner message',
                    value: draft.bannerMessage,
                    seed: formSeed,
                    maxLines: 2,
                    onChanged: (v) => setMaintenance('banner_message', v),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PccPortalSection extends StatelessWidget {
  const PccPortalSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.portalKey,
    required this.draft,
    required this.onPatch,
    required this.keys,
  });

  final String title;
  final String subtitle;
  final String portalKey;
  final PlatformSettingsBundle draft;
  final void Function({Map<String, dynamic>? portalFeatures}) onPatch;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final portal = Map<String, dynamic>.from(
      portalKey == 'client' ? draft.clientPortal : draft.investorPortal,
    );

    bool flag(String key) {
      final v = portal[key];
      if (v is bool) return v;
      return true;
    }

    void setFlag(String key, bool value) {
      final nextPortal = {...portal, key: value};
      onPatch(
        portalFeatures: {
          ...draft.portalFeatures,
          portalKey: nextPortal,
        },
      );
    }

    return PccPanel(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          for (final key in keys)
            PccToggle(
              title: _labelFor(key),
              subtitle: key,
              value: flag(key),
              onChanged: (v) => setFlag(key, v),
            ),
          const SizedBox(height: 8),
          PccField(
            label: 'Welcome message',
            value: '${portal['welcome_message'] ?? ''}',
            seed: portal.hashCode,
            maxLines: 2,
            onChanged: (v) {
              onPatch(
                portalFeatures: {
                  ...draft.portalFeatures,
                  portalKey: {...portal, 'welcome_message': v},
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _labelFor(String key) {
    if (key == 'enabled') return 'Portal enabled';
    return key
        .replaceAll('show_', '')
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }
}

class PccIntegrationsSection extends StatelessWidget {
  const PccIntegrationsSection({
    super.key,
    required this.draft,
    required this.onPatch,
  });

  final PlatformSettingsBundle draft;
  final void Function({Map<String, dynamic>? integrations}) onPatch;

  @override
  Widget build(BuildContext context) {
    final entries = draft.integrations.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return PccPanel(
      title: 'Integration registry',
      subtitle:
          'Status only — no secrets. Secrets remain in Edge Functions / Supabase config.',
      child: entries.isEmpty
          ? const Text(
              'No integration registry rows loaded yet.',
              style: TextStyle(color: AdminDeskColors.muted),
            )
          : Column(
              children: [
                for (final entry in entries)
                  Builder(
                    builder: (context) {
                      final map = entry.value is Map
                          ? Map<String, dynamic>.from(entry.value as Map)
                          : <String, dynamic>{};
                      final configured = map['configured'] == true;
                      final notes = '${map['notes'] ?? ''}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminDeskColors.elevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminDeskColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              configured
                                  ? LucideIcons.checkCircle2
                                  : LucideIcons.circleDashed,
                              size: 18,
                              color: configured
                                  ? AdminDeskColors.green
                                  : AdminDeskColors.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (notes.isNotEmpty)
                                    Text(
                                      notes,
                                      style: const TextStyle(
                                        color: AdminDeskColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: configured,
                              activeThumbColor: AdminDeskColors.gold,
                              onChanged: (v) {
                                onPatch(
                                  integrations: {
                                    ...draft.integrations,
                                    entry.key: {
                                      ...map,
                                      'configured': v,
                                    },
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class PccDeepLinksSection extends StatelessWidget {
  const PccDeepLinksSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.links,
  });

  final String title;
  final String subtitle;
  final List<(String, String, IconData, String)> links;

  @override
  Widget build(BuildContext context) {
    return PccPanel(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          for (final link in links)
            PccDeepLinkCard(
              title: link.$1,
              description: link.$2,
              icon: link.$3,
              actionLabel: 'Open',
              onOpen: () => context.go(link.$4),
            ),
        ],
      ),
    );
  }
}

/// Embeds live FAPMS payment policy + receiving accounts (no duplicate rails).
class PccFinanceSection extends ConsumerWidget {
  const PccFinanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fapmsRealtimeProvider);
    final snapAsync = ref.watch(fapmsSnapshotProvider);

    return PermissionGateAny(
      permissions: AdminAccessPolicy.finance,
      fallback: PccPanel(
        title: 'Finance & payments',
        subtitle:
            'Payment rails stay in FAPMS. You need finance or manage_payments access.',
        child: const Text(
          'You do not have permission to view finance settings.',
          style: TextStyle(color: AdminDeskColors.muted),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PccPanel(
            title: 'Finance & payments',
            subtitle:
                'Live FAPMS settings — same payment_settings and receiving accounts used by Client / Investor portals.',
            trailing: TextButton.icon(
              onPressed: () {
                ref.invalidate(fapmsSnapshotProvider);
                ref.read(fapmsControllerProvider.notifier).refresh();
              },
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Refresh'),
            ),
            child: Column(
              children: [
                PccDeepLinkCard(
                  title: 'Finance desk',
                  description:
                      'Verification queues, installments, banking, commissions, and investor transfers.',
                  icon: LucideIcons.wallet,
                  actionLabel: 'Open',
                  onOpen: () => context.go(RoutePaths.dashboardFinance),
                ),
                PccDeepLinkCard(
                  title: 'Payment calculator CMS',
                  description:
                      'Public calculator copy and plan presentation.',
                  icon: LucideIcons.calculator,
                  actionLabel: 'Open',
                  onOpen: () =>
                      context.go(RoutePaths.dashboardWebsitePaymentCalculator),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          snapAsync.when(
            loading: () => const PccPanel(
              title: 'Client payment policy',
              subtitle: 'Loading FAPMS payment_settings…',
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AdminDeskColors.gold),
                ),
              ),
            ),
            error: (e, _) => PccPanel(
              title: 'Client payment policy',
              subtitle: 'Could not load FAPMS settings.',
              child: Text(
                '$e',
                style: const TextStyle(color: AdminDeskColors.red),
              ),
            ),
            data: (snap) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snap.loadWarnings.isNotEmpty) ...[
                  PccPanel(
                    title: 'Load notes',
                    subtitle: 'Non-blocking FAPMS load signals.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in snap.loadWarnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              w,
                              style: const TextStyle(
                                color: AdminDeskColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FinancePaymentSettingsCard(settings: snap.paymentSettings),
                const SizedBox(height: 16),
                PccPanel(
                  title: 'Receiving accounts & client rails',
                  subtitle:
                      'Company bank accounts shown to clients, payment methods, and late-fee rules.',
                  child: const ClientPaymentsSettingsPanel(),
                ),
                const SizedBox(height: 16),
                _PccBankAccountsSummary(accounts: snap.bankAccounts),
                const SizedBox(height: 16),
                _PccFinanceQueueSummary(snap: snap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PccBankAccountsSummary extends StatelessWidget {
  const _PccBankAccountsSummary({required this.accounts});

  final List<FapmsBankAccount> accounts;

  @override
  Widget build(BuildContext context) {
    return PccPanel(
      title: 'Treasury bank accounts',
      subtitle:
          'Balances from FAPMS bank_accounts. Manage movements in the Finance desk Banking tab.',
      trailing: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardFinance),
        child: const Text('Open Banking'),
      ),
      child: accounts.isEmpty
          ? const Text(
              'No bank accounts configured in Supabase.',
              style: TextStyle(color: AdminDeskColors.muted),
            )
          : Column(
              children: [
                for (final a in accounts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      LucideIcons.landmark,
                      color: a.isActive
                          ? AdminDeskColors.gold
                          : AdminDeskColors.muted,
                      size: 20,
                    ),
                    title: Text(
                      a.accountName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (a.bankName.isNotEmpty) a.bankName,
                        if (a.accountNumberMasked != null)
                          a.accountNumberMasked!,
                        if (!a.isActive) 'inactive',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      a.balanceDisplay,
                      style: const TextStyle(
                        color: AdminDeskColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PccFinanceQueueSummary extends StatelessWidget {
  const _PccFinanceQueueSummary({required this.snap});

  final FapmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return PccPanel(
      title: 'Verification queues',
      subtitle: 'Live counts from FAPMS — open Finance to process.',
      child: Row(
        children: [
          Expanded(
            child: _QueueStat(
              label: 'Client proofs',
              value: '${snap.pendingClientVerifications}',
              icon: LucideIcons.badgeCheck,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QueueStat(
              label: 'Investor transfers',
              value: '${snap.pendingInvestorIntents}',
              icon: LucideIcons.arrowLeftRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueStat extends StatelessWidget {
  const _QueueStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminDeskColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminDeskColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin ops wrappers — live summaries + Support settings, desks remain SoR.
class PccOpsModulesSection extends ConsumerWidget {
  const PccOpsModulesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PccPanel(
          title: 'Operations modules',
          subtitle:
              'Desks stay the system of record. Control Center surfaces thin config and live counts — no duplicate CRM/CPMS/Marketing apps.',
          trailing: TextButton.icon(
            onPressed: () {
              ref.invalidate(supportConfigurationProvider);
              ref.invalidate(crmSnapshotProvider);
              ref.invalidate(cpmsSnapshotProvider);
              ref.invalidate(dxpSnapshotProvider);
              ref.invalidate(cshopSnapshotProvider);
            },
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Refresh'),
          ),
          child: Column(
            children: [
              PccDeepLinkCard(
                title: 'Sales CRM',
                description: 'Leads, pipeline board, and client workflows.',
                icon: LucideIcons.contact,
                actionLabel: 'Open',
                onOpen: () => context.go(RoutePaths.dashboardCrm),
              ),
              PccDeepLinkCard(
                title: 'Construction (CPMS)',
                description: 'Projects, milestones, procurement, and site ops.',
                icon: LucideIcons.hardHat,
                actionLabel: 'Open',
                onOpen: () => context.go(RoutePaths.dashboardConstruction),
              ),
              PccDeepLinkCard(
                title: 'Public construction CMS',
                description: 'Website construction updates and progress copy.',
                icon: LucideIcons.newspaper,
                actionLabel: 'Open',
                onOpen: () =>
                    context.go(RoutePaths.dashboardWebsiteConstruction),
              ),
              PccDeepLinkCard(
                title: 'Marketing (DXP)',
                description: 'Campaigns, landing pages, and growth surfaces.',
                icon: LucideIcons.megaphone,
                actionLabel: 'Open',
                onOpen: () => context.go(RoutePaths.dashboardMarketing),
              ),
              PccDeepLinkCard(
                title: 'Support desk',
                description: 'Tickets, channels, SLA, and agent workspace.',
                icon: LucideIcons.headphones,
                actionLabel: 'Open',
                onOpen: () => context.go(RoutePaths.dashboardSupport),
              ),
              PccDeepLinkCard(
                title: 'Live chat',
                description: 'Realtime visitor and portal chat console.',
                icon: LucideIcons.messageCircle,
                actionLabel: 'Open',
                onOpen: () => context.go(RoutePaths.dashboardLiveChat),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _PccSupportSettingsCard(),
        const SizedBox(height: 16),
        const _PccCrmSummaryCard(),
        const SizedBox(height: 16),
        const _PccConstructionSummaryCard(),
        const SizedBox(height: 16),
        const _PccMarketingSummaryCard(),
      ],
    );
  }
}

class _PccSupportSettingsCard extends ConsumerStatefulWidget {
  const _PccSupportSettingsCard();

  @override
  ConsumerState<_PccSupportSettingsCard> createState() =>
      _PccSupportSettingsCardState();
}

class _PccSupportSettingsCardState
    extends ConsumerState<_PccSupportSettingsCard> {
  SupportSettings? _draft;
  String? _baselineId;
  int _seed = 0;
  bool _saving = false;
  String? _error;
  String? _notice;

  Future<void> _persist(SupportSettings next) async {
    final repo = ref.read(supportRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final saved = await repo.updateSettings(next);
      ref.invalidate(supportConfigurationProvider);
      setState(() {
        _draft = saved;
        _baselineId = saved.id;
        _seed++;
        _saving = false;
        _notice = 'Support settings saved.';
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = userFacingError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportConfigurationProvider);

    return PermissionGateAny(
      permissions: [
        ...AdminAccessPolicy.support,
        ...AdminAccessPolicy.communications,
      ],
      fallback: const PccPanel(
        title: 'Support settings',
        subtitle: 'Requires support or communications access.',
        child: Text(
          'You do not have permission to edit support_settings.',
          style: TextStyle(color: AdminDeskColors.muted),
        ),
      ),
      child: async.when(
        loading: () => const PccPanel(
          title: 'Support settings',
          subtitle: 'Loading support_settings…',
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AdminDeskColors.gold),
            ),
          ),
        ),
        error: (e, _) => PccPanel(
          title: 'Support settings',
          subtitle: 'Could not load support_settings.',
          child: Text(userFacingError(e), style: const TextStyle(color: AdminDeskColors.red)),
        ),
        data: (snap) {
          if (snap == null) {
            return const PccPanel(
              title: 'Support settings',
              subtitle: 'Supabase is not configured.',
              child: Text(
                'Connect Supabase to manage welcome and offline messages.',
                style: TextStyle(color: AdminDeskColors.muted),
              ),
            );
          }
          final base = snap.settings;
          if (_draft == null || _baselineId != base.id) {
            _draft = base;
            _baselineId = base.id;
          }
          final draft = _draft ?? base;
          final dirty = draft.welcomeMessage != base.welcomeMessage ||
              draft.offlineMessage != base.offlineMessage ||
              draft.timezone != base.timezone ||
              draft.businessHoursEnabled != base.businessHoursEnabled ||
              draft.offlineTicketEnabled != base.offlineTicketEnabled ||
              draft.autoAssignmentEnabled != base.autoAssignmentEnabled;
          return PccPanel(
            title: 'Support settings',
            subtitle:
                'Live support_settings — welcome/offline copy and channel toggles used by the Support desk.',
            trailing: TextButton(
              onPressed: () => context.go(RoutePaths.dashboardSupport),
              child: const Text('Open Support'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AdminDeskColors.red),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _notice!,
                      style: const TextStyle(color: AdminDeskColors.green),
                    ),
                  ),
                PccField(
                  label: 'Timezone',
                  value: draft.timezone,
                  seed: _seed,
                  onChanged: (v) =>
                      setState(() => _draft = draft.copyWith(timezone: v)),
                ),
                const SizedBox(height: 12),
                PccField(
                  label: 'Welcome message',
                  value: draft.welcomeMessage,
                  seed: _seed,
                  maxLines: 3,
                  onChanged: (v) => setState(
                    () => _draft = draft.copyWith(welcomeMessage: v),
                  ),
                ),
                const SizedBox(height: 12),
                PccField(
                  label: 'Offline message',
                  value: draft.offlineMessage,
                  seed: _seed,
                  maxLines: 3,
                  onChanged: (v) => setState(
                    () => _draft = draft.copyWith(offlineMessage: v),
                  ),
                ),
                const SizedBox(height: 8),
                PccToggle(
                  title: 'Business hours enabled',
                  subtitle: 'Respect support_operating_hours when online.',
                  value: draft.businessHoursEnabled,
                  onChanged: (v) {
                    final next = draft.copyWith(businessHoursEnabled: v);
                    setState(() => _draft = next);
                    unawaited(_persist(next));
                  },
                ),
                PccToggle(
                  title: 'Offline ticket capture',
                  subtitle: 'Allow ticket creation while support is offline.',
                  value: draft.offlineTicketEnabled,
                  onChanged: (v) {
                    final next = draft.copyWith(offlineTicketEnabled: v);
                    setState(() => _draft = next);
                    unawaited(_persist(next));
                  },
                ),
                PccToggle(
                  title: 'Auto-assignment',
                  subtitle: 'Apply support_assignment_rules to new tickets.',
                  value: draft.autoAssignmentEnabled,
                  onChanged: (v) {
                    final next = draft.copyWith(autoAssignmentEnabled: v);
                    setState(() => _draft = next);
                    unawaited(_persist(next));
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${snap.hours.length} operating-hour rows · '
                  '${snap.holidays.length} holidays · '
                  '${snap.quickReplies.length} quick replies · '
                  '${snap.assignmentRules.length} assignment rules',
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: !dirty || _saving
                        ? null
                        : () => unawaited(_persist(draft)),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.save, size: 16),
                    label: Text(_saving ? 'Saving…' : 'Save messages'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PccCrmSummaryCard extends ConsumerWidget {
  const _PccCrmSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(crmRealtimeProvider);
    final async = ref.watch(crmSnapshotProvider);

    return PccPanel(
      title: 'CRM pipeline',
      subtitle:
          'Seeded crm_pipeline_stages with live lead counts. Edit stages in Sales CRM.',
      trailing: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardCrm),
        child: const Text('Open CRM'),
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: AdminDeskColors.gold),
          ),
        ),
        error: (e, _) =>
            Text(userFacingError(e), style: const TextStyle(color: AdminDeskColors.red)),
        data: (snap) {
          final counts = snap.stageCounts();
          final stages = [...snap.stages]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          if (stages.isEmpty) {
            return const Text(
              'No pipeline stages configured.',
              style: TextStyle(color: AdminDeskColors.muted),
            );
          }
          return Column(
            children: [
              for (final stage in stages)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    stage.name,
                    style: TextStyle(
                      color: stage.isActive
                          ? Colors.white
                          : AdminDeskColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${stage.slug} · ${stage.probabilityPct.toStringAsFixed(0)}% probability'
                    '${stage.isActive ? '' : ' · inactive'}',
                    style: const TextStyle(
                      color: AdminDeskColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Text(
                    '${counts[stage.slug] ?? 0}',
                    style: const TextStyle(
                      color: AdminDeskColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '${snap.leads.length} leads · ${snap.clients.length} clients · '
                '${snap.tasks.length} tasks'
                '${snap.fromRemote ? '' : ' · offline snapshot'}',
                style: const TextStyle(
                  color: AdminDeskColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PccConstructionSummaryCard extends ConsumerWidget {
  const _PccConstructionSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cpmsSnapshotProvider);
    return PccPanel(
      title: 'Construction',
      subtitle:
          'CPMS project pulse. Public site updates stay in Website CMS.',
      trailing: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardConstruction),
        child: const Text('Open CPMS'),
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: AdminDeskColors.gold),
          ),
        ),
        error: (e, _) =>
            Text(userFacingError(e), style: const TextStyle(color: AdminDeskColors.red)),
        data: (snap) {
          final pendingCos = snap.changeOrders
              .where((c) => c.status == ChangeOrderStatus.pending)
              .length;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _OpsStat(
                      label: 'Projects',
                      value: '${snap.projects.length}',
                      icon: LucideIcons.building2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpsStat(
                      label: 'Alerts',
                      value: '${snap.alerts.length}',
                      icon: LucideIcons.bell,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpsStat(
                      label: 'Pending COs',
                      value: '$pendingCos',
                      icon: LucideIcons.alertTriangle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      context.go(RoutePaths.dashboardWebsiteConstruction),
                  icon: const Icon(LucideIcons.globe, size: 14),
                  label: const Text('Public construction CMS'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PccMarketingSummaryCard extends ConsumerWidget {
  const _PccMarketingSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dxpSnapshotProvider);
    return PccPanel(
      title: 'Marketing',
      subtitle: 'DXP campaign and content inventory — edit in Marketing desk.',
      trailing: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardMarketing),
        child: const Text('Open Marketing'),
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: AdminDeskColors.gold),
          ),
        ),
        error: (e, _) =>
            Text(userFacingError(e), style: const TextStyle(color: AdminDeskColors.red)),
        data: (snap) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _OpsStat(
                      label: 'Campaigns',
                      value: '${snap.campaigns.length}',
                      icon: LucideIcons.megaphone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpsStat(
                      label: 'Landings',
                      value: '${snap.landingPages.length}',
                      icon: LucideIcons.layoutTemplate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OpsStat(
                      label: 'Blog posts',
                      value: '${snap.blogPosts.length}',
                      icon: LucideIcons.fileText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CRM leads synced: ${snap.crmLeadCount} · '
                  'qualified: ${snap.crmQualifiedCount}'
                  '${snap.fromRemote ? '' : ' · offline snapshot'}',
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OpsStat extends StatelessWidget {
  const _OpsStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminDeskColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AdminDeskColors.gold, size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AdminDeskColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cloudinary-only website media policy, health, library link, and migrations.
class PccMediaCloudinarySection extends ConsumerStatefulWidget {
  const PccMediaCloudinarySection({super.key});

  @override
  ConsumerState<PccMediaCloudinarySection> createState() =>
      _PccMediaCloudinarySectionState();
}

class _PccMediaCloudinarySectionState
    extends ConsumerState<PccMediaCloudinarySection> {
  bool _busy = false;
  String? _message;
  String? _error;

  Future<void> _run(
    String label,
    Future<Map<String, Object?>> Function() action,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '$label → $result';
      });
      ref.invalidate(platformHealthProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = userFacingError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(platformHealthProvider);
    final cloudinaryOn = ref.watch(cloudinaryEnabledProvider);
    final cloudinary = healthAsync.valueOrNull?.checks['cloudinary'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PccPanel(
          title: 'Media / Cloudinary',
          subtitle:
              'Website images and videos must deliver from res.cloudinary.com. '
              'API secrets stay in Supabase Edge Functions — never in the client.',
          trailing: TextButton.icon(
            onPressed: () => ref.invalidate(platformHealthProvider),
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Refresh'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  cloudinaryOn ? LucideIcons.checkCircle2 : LucideIcons.circleDashed,
                  color: cloudinaryOn
                      ? AdminDeskColors.green
                      : AdminDeskColors.muted,
                ),
                title: Text(
                  cloudinaryOn
                      ? 'Upload path ready (Edge Functions + Supabase)'
                      : 'Supabase not configured — Cloudinary uploads unavailable',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    if (CloudinaryConfig.hasClientHints)
                      'Client cloud: ${CloudinaryConfig.cloudName}'
                    else
                      'Client CLOUDINARY_CLOUD_NAME optional (sign response supplies it)',
                    if (cloudinary != null)
                      'Health: ${cloudinary.status.name} — ${cloudinary.notes}',
                  ].join('\n'),
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Policy: new image/video uploads refuse Supabase Storage. '
                'Hero save auto-migrates legacy Storage/Unsplash URLs into Cloudinary.',
                style: TextStyle(color: AdminDeskColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              PccDeepLinkCard(
                title: 'Website media library',
                description: 'Browse, upload, and attach Cloudinary assets.',
                icon: LucideIcons.image,
                actionLabel: 'Open',
                onOpen: () => context.go(RoutePaths.dashboardWebsiteMedia),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PccPanel(
          title: 'Migrate legacy website media',
          subtitle:
              'Import existing Storage/Unsplash URLs into Cloudinary without deleting sources.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AdminDeskColors.red),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: AdminDeskColors.green),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Hero media',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyWebsiteHeroMedia(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.image, size: 16),
                    label: const Text('Migrate heroes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Banners',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyBannerImages(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.panelTop, size: 16),
                    label: const Text('Migrate banners'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Partners',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyPartnerLogos(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.briefcase, size: 16),
                    label: const Text('Migrate partner logos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Testimonials',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyTestimonialAvatars(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.quote, size: 16),
                    label: const Text('Migrate testimonials'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Landing heroes',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyLandingHeroes(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.layoutTemplate, size: 16),
                    label: const Text('Migrate landing heroes'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Property images',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyPropertyImages(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.home, size: 16),
                    label: const Text('Migrate property images'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Blog covers',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyBlogCovers(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.newspaper, size: 16),
                    label: const Text('Migrate blog covers'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'All website media',
                              () => ref
                                  .read(cmsServiceProvider)
                                  .migrateAllWebsiteMediaToCloudinary(),
                            ),
                    icon: const Icon(LucideIcons.uploadCloud, size: 16),
                    label: const Text('Migrate all website media'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              'Batch edge migrate',
                              () async => Map<String, Object?>.from(
                                await ref
                                    .read(cmsServiceProvider)
                                    .migrateLegacyMediaBatch(),
                              ),
                            ),
                    icon: const Icon(LucideIcons.cloud, size: 16),
                    label: const Text('Edge batch migrate'),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(color: AdminDeskColors.gold),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Security / privacy deep-links — RBAC and audit remain systems of record.
class PccSecurityPrivacySection extends StatelessWidget {
  const PccSecurityPrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    return PccPanel(
      title: 'Security & privacy',
      subtitle:
          'Access control, sessions, and audit history stay in their desks. '
          'Settings never stores secrets in app_settings.',
      child: Column(
        children: [
          PccDeepLinkCard(
            title: 'Roles & permissions',
            description: 'RBAC matrix, role grants, and permission groups.',
            icon: LucideIcons.shield,
            actionLabel: 'Open',
            onOpen: () => context.go(RoutePaths.dashboardRoles),
          ),
          PccDeepLinkCard(
            title: 'Organization / staff',
            description: 'Staff invites, departments, and assignments.',
            icon: LucideIcons.users,
            actionLabel: 'Open',
            onOpen: () => context.go(RoutePaths.dashboardOrganization),
          ),
          PccDeepLinkCard(
            title: 'Activity logs',
            description: 'Cross-module audit trail including settings changes.',
            icon: LucideIcons.scrollText,
            actionLabel: 'Open',
            onOpen: () => context.go(RoutePaths.dashboardActivityLogs),
          ),
          PccDeepLinkCard(
            title: 'Account security',
            description: 'Signed-in user security preferences.',
            icon: LucideIcons.lock,
            actionLabel: 'Open',
            onOpen: () => context.go(RoutePaths.securityCenter),
          ),
          const SizedBox(height: 8),
          const Text(
            'Realtime: Platform Control Center subscribes to app_settings and '
            'invalidates portal flags, health, and finance/ops snapshots on change. '
            'Secrets (Cloudinary, email, SMS) remain Edge-only.',
            style: TextStyle(color: AdminDeskColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class PccAuditSection extends ConsumerWidget {
  const PccAuditSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditsAsync = ref.watch(recentSettingsAuditsProvider);
    final fmt = DateFormat('dd MMM yyyy · HH:mm:ss');

    return PccPanel(
      title: 'Settings audit trail',
      subtitle:
          'platform_settings module events. Full Activity Logs desk remains available for cross-module history.',
      trailing: TextButton(
        onPressed: () => context.go('/dashboard/activity-logs'),
        child: const Text('Open Activity Logs'),
      ),
      child: auditsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: AdminDeskColors.gold),
          ),
        ),
        error: (e, _) => Text(userFacingError(e), style: const TextStyle(color: AdminDeskColors.red)),
        data: (rows) {
          if (rows.isEmpty) {
            return const Text(
              'No audit rows yet.',
              style: TextStyle(color: AdminDeskColors.muted),
            );
          }
          return Column(
            children: [
              for (final row in rows)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminDeskColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminDeskColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['action'] ?? ''} · ${row['entity_id'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateTime.tryParse('${row['created_at']}') != null
                            ? fmt.format(
                                DateTime.parse('${row['created_at']}').toLocal(),
                              )
                            : '',
                        style: const TextStyle(
                          color: AdminDeskColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          final left = children[i];
          final right = i + 1 < children.length ? children[i + 1] : null;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: right ?? const SizedBox.shrink()),
              ],
            ),
          );
          rows.add(const SizedBox(height: 12));
        }
        return Column(children: rows);
      },
    );
  }
}
