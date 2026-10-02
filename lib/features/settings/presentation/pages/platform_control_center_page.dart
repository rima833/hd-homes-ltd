import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/admin_email_settings_panel.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:hdhomesproject/features/crm/presentation/providers/crm_controller.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/presentation/controllers/platform_settings_edit_controller.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:hdhomesproject/features/settings/presentation/widgets/pcc_sections.dart';
import 'package:hdhomesproject/features/settings/presentation/widgets/platform_control_nav.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium Platform Control Center — Admin → Settings.
class PlatformControlCenterPage extends ConsumerStatefulWidget {
  const PlatformControlCenterPage({super.key, this.initialSection});

  final PlatformControlSection? initialSection;

  @override
  ConsumerState<PlatformControlCenterPage> createState() =>
      _PlatformControlCenterPageState();
}

class _PlatformControlCenterPageState
    extends ConsumerState<PlatformControlCenterPage> {
  late PlatformControlSection _section;
  int _formSeed = 0;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection ?? PlatformControlSection.overview;
  }

  @override
  void didUpdateWidget(covariant PlatformControlCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != null &&
        widget.initialSection != oldWidget.initialSection) {
      _section = widget.initialSection!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(supabaseConfiguredProvider);
    final settingsAsync = ref.watch(adminPlatformSettingsProvider);
    final edit = ref.watch(platformSettingsEditControllerProvider);
    final editCtrl = ref.read(platformSettingsEditControllerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final sectionEditable = PlatformControlNav.itemFor(_section).editable;

    ref.listen(platformSettingsEditControllerProvider, (prev, next) {
      if (prev == null) return;
      if (prev.isDirty && !next.isDirty && !next.saving) {
        setState(() => _formSeed++);
      }
    });

    return ColoredBox(
      color: AdminDeskColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            dirty: edit.isDirty,
            saving: edit.saving,
            configured: configured,
            showSaveActions: sectionEditable,
            canSave: configured && sectionEditable && edit.isDirty && !edit.saving,
            onSave: () async {
              final ok = await editCtrl.save();
              if (ok && mounted) setState(() => _formSeed++);
            },
            onDiscard: () {
              editCtrl.reset();
              setState(() => _formSeed++);
            },
            onRefresh: () {
              ref.invalidate(adminPlatformSettingsProvider);
              ref.invalidate(platformHealthProvider);
              ref.invalidate(recentSettingsAuditsProvider);
              ref.invalidate(fapmsSnapshotProvider);
              ref.invalidate(supportConfigurationProvider);
              ref.invalidate(crmSnapshotProvider);
              ref.invalidate(cpmsSnapshotProvider);
              ref.invalidate(dxpSnapshotProvider);
              ref.invalidate(cshopSnapshotProvider);
            },
          ),
          if (edit.error != null)
            _InlineBanner(text: edit.error!, isError: true),
          if (edit.savedNotice != null)
            _InlineBanner(text: edit.savedNotice!, isError: false),
          if (!wide)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _MobileSectionPicker(
                section: _section,
                onChanged: (s) => setState(() => _section = s),
              ),
            ),
          Expanded(
            child: settingsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminDeskColors.gold),
              ),
              error: (e, _) => AdminDeskEmptyState(
                title: 'Unable to load settings',
                message: '$e',
                icon: LucideIcons.alertTriangle,
                action: TextButton(
                  onPressed: () =>
                      ref.invalidate(adminPlatformSettingsProvider),
                  child: const Text('Retry'),
                ),
              ),
              data: (_) {
                final draft = edit.draft;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      SizedBox(
                        width: 248,
                        child: _SideNav(
                          section: _section,
                          onSelect: (s) => setState(() => _section = s),
                        ),
                      ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey(_section),
                          child: _SectionBody(
                            section: _section,
                            draft: draft,
                            formSeed: _formSeed,
                            onPatch: editCtrl.patchDraft,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dirty,
    required this.saving,
    required this.configured,
    required this.showSaveActions,
    required this.canSave,
    required this.onSave,
    required this.onDiscard,
    required this.onRefresh,
  });

  final bool dirty;
  final bool saving;
  final bool configured;
  final bool showSaveActions;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminDeskColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PLATFORM CONTROL CENTER',
                  style: TextStyle(
                    color: AdminDeskColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  configured
                      ? (dirty
                          ? 'Unsaved changes — review and save when ready.'
                          : 'Live configuration for HD Homes website and portals.')
                      : 'Supabase is not configured. Connect credentials to persist.',
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            color: AdminDeskColors.muted,
          ),
          if (showSaveActions) ...[
            if (dirty) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: saving ? null : onDiscard,
                child: const Text('Discard'),
              ),
            ],
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: canSave ? onSave : null,
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(LucideIcons.save, size: 16),
              label: Text(saving ? 'Saving…' : 'Save changes'),
              style: FilledButton.styleFrom(
                backgroundColor: AdminDeskColors.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isError ? AdminDeskColors.red : AdminDeskColors.green)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isError ? AdminDeskColors.red : AdminDeskColors.green)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? AdminDeskColors.red : AdminDeskColors.green,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.section, required this.onSelect});
  final PlatformControlSection section;
  final ValueChanged<PlatformControlSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? lastGroup;
    for (final item in PlatformControlNav.items) {
      if (item.group != lastGroup) {
        if (lastGroup != null) children.add(const SizedBox(height: 14));
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Text(
              item.group.toUpperCase(),
              style: TextStyle(
                color: AdminDeskColors.muted.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
        );
        lastGroup = item.group;
      }
      children.add(
        _NavTile(
          item: item,
          selected: item.section == section,
          onTap: () => onSelect(item.section),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AdminDeskColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: children,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final PlatformControlNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AdminDeskColors.gold.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: selected ? AdminDeskColors.gold : AdminDeskColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : AdminDeskColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSectionPicker extends StatelessWidget {
  const _MobileSectionPicker({
    required this.section,
    required this.onChanged,
  });
  final PlatformControlSection section;
  final ValueChanged<PlatformControlSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PlatformControlSection>(
      initialValue: section,
      dropdownColor: AdminDeskColors.elevated,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AdminDeskColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminDeskColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminDeskColors.border),
        ),
      ),
      items: [
        for (final item in PlatformControlNav.items)
          DropdownMenuItem(value: item.section, child: Text(item.label)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.draft,
    required this.formSeed,
    required this.onPatch,
  });

  final PlatformControlSection section;
  final PlatformSettingsBundle draft;
  final int formSeed;
  final void Function({
    Map<String, dynamic>? company,
    Map<String, dynamic>? contact,
    Map<String, dynamic>? theme,
    Map<String, dynamic>? seo,
    Map<String, dynamic>? social,
    Map<String, dynamic>? websiteFeatures,
    Map<String, dynamic>? maintenance,
    Map<String, dynamic>? portalFeatures,
    Map<String, dynamic>? integrations,
  }) onPatch;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: switch (section) {
        PlatformControlSection.overview => const PccOverviewSection(),
        PlatformControlSection.business => PccBusinessSection(
            draft: draft,
            formSeed: formSeed,
            onPatch: ({company}) => onPatch(company: company),
          ),
        PlatformControlSection.brandSocial => PccBrandSocialSection(
            draft: draft,
            formSeed: formSeed,
            onPatch: ({theme, social}) =>
                onPatch(theme: theme, social: social),
          ),
        PlatformControlSection.contact => PccContactSection(
            draft: draft,
            formSeed: formSeed,
            onPatch: ({contact}) => onPatch(contact: contact),
          ),
        PlatformControlSection.publicWebsite => PccWebsiteSection(
            draft: draft,
            formSeed: formSeed,
            onPatch: ({websiteFeatures, maintenance}) => onPatch(
              websiteFeatures: websiteFeatures,
              maintenance: maintenance,
            ),
          ),
        PlatformControlSection.seo => PccSeoSection(
            draft: draft,
            formSeed: formSeed,
            onPatch: ({seo}) => onPatch(seo: seo),
          ),
        PlatformControlSection.clientPortal => PccPortalSection(
            title: 'Client Portal modules',
            subtitle:
                'Staff-managed visibility for client portal navigation and tools.',
            portalKey: 'client',
            draft: draft,
            onPatch: ({portalFeatures}) =>
                onPatch(portalFeatures: portalFeatures),
            keys: const [
              'enabled',
              'show_dashboard',
              'show_properties',
              'show_payments',
              'show_documents',
              'show_inspections',
              'show_construction',
              'show_messages',
              'show_support',
              'show_referrals',
              'show_notifications',
            ],
          ),
        PlatformControlSection.investorPortal => PccPortalSection(
            title: 'Investor Portal modules',
            subtitle:
                'Staff-managed visibility for investor portal navigation and tools.',
            portalKey: 'investor',
            draft: draft,
            onPatch: ({portalFeatures}) =>
                onPatch(portalFeatures: portalFeatures),
            keys: const [
              'enabled',
              'show_dashboard',
              'show_portfolio',
              'show_analytics',
              'show_construction',
              'show_reports',
              'show_payments',
              'show_documents',
              'show_messages',
              'show_support',
              'show_referrals',
              'show_notifications',
            ],
          ),
        PlatformControlSection.homepageNav => const PccDeepLinksSection(
            title: 'Homepage & navigation',
            subtitle:
                'Managed in Website CMS — open the live editors for homepage sections, menus, and footer.',
            links: [
              (
                'Homepage sections',
                'Hero, featured content, and section visibility.',
                LucideIcons.layoutTemplate,
                RoutePaths.dashboardWebsiteHomepage,
              ),
              (
                'Menus',
                'Public header and navigation structure.',
                LucideIcons.menu,
                RoutePaths.dashboardWebsiteMenus,
              ),
              (
                'Footer',
                'Footer links and legal destinations.',
                LucideIcons.panelBottom,
                RoutePaths.dashboardWebsiteFooter,
              ),
            ],
          ),
        PlatformControlSection.contentCms => const PccDeepLinksSection(
            title: 'Content & CMS',
            subtitle:
                'Pages, blog, banners, testimonials, and media stay in Website CMS.',
            links: [
              (
                'Website hub',
                'All CMS desks and content workflows.',
                LucideIcons.globe,
                RoutePaths.dashboardWebsite,
              ),
              (
                'Pages & hubs',
                'Static pages and hub content.',
                LucideIcons.fileText,
                RoutePaths.dashboardWebsitePages,
              ),
              (
                'Blog',
                'Articles, categories, and authors.',
                LucideIcons.newspaper,
                RoutePaths.dashboardWebsiteBlog,
              ),
              (
                'Banners',
                'Public announcement banners.',
                LucideIcons.megaphone,
                RoutePaths.dashboardWebsiteBanners,
              ),
            ],
          ),
        PlatformControlSection.properties => const PccDeepLinksSection(
            title: 'Properties',
            subtitle:
                'Listings and estates are managed in the Properties desks — not duplicated here.',
            links: [
              (
                'Estates',
                'Estate communities and galleries.',
                LucideIcons.map,
                RoutePaths.dashboardEstates,
              ),
              (
                'Listings',
                'Property inventory and publish controls.',
                LucideIcons.home,
                RoutePaths.dashboardProperties,
              ),
            ],
          ),
        PlatformControlSection.finance => const PccFinanceSection(),
        PlatformControlSection.opsModules => const PccOpsModulesSection(),
        PlatformControlSection.staffRoles => const PccDeepLinksSection(
            title: 'Staff & roles',
            subtitle:
                'People, organization, and RBAC remain the system of record.',
            links: [
              (
                'Organization',
                'Teams, departments, and staff directory.',
                LucideIcons.users,
                RoutePaths.dashboardOrganization,
              ),
              (
                'Roles & permissions',
                'RBAC console and permission matrix.',
                LucideIcons.shield,
                RoutePaths.dashboardRoles,
              ),
              (
                'Platform users',
                'Accounts and access inventory.',
                LucideIcons.userCog,
                RoutePaths.dashboardPlatformUsers,
              ),
            ],
          ),
        PlatformControlSection.mediaCloudinary =>
            const PccMediaCloudinarySection(),
        PlatformControlSection.securityPrivacy =>
            const PccSecurityPrivacySection(),
        PlatformControlSection.integrations => PccIntegrationsSection(
            draft: draft,
            onPatch: ({integrations}) => onPatch(integrations: integrations),
          ),
        PlatformControlSection.email => const AdminEmailSettingsPanel(),
        PlatformControlSection.audit => const PccAuditSection(),
      },
    );
  }
}
