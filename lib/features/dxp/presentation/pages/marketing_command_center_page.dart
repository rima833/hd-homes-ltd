import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';
import 'package:hdhomesproject/features/dxp/presentation/widgets/marketing_editors.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _marketingBackground = Color(0xFF07111F);
const _marketingPanel = Color(0xFF0B1728);
const _marketingPanelLight = Color(0xFF102039);
const _marketingBorder = Color(0xFF1C3553);

/// HD Homes Marketing Command Center — live ops hub.
class MarketingCommandCenterPage extends ConsumerWidget {
  const MarketingCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dxpRealtimeProvider);
    final asyncSnap = ref.watch(dxpSnapshotProvider);
    final ui = ref.watch(dxpControllerProvider);
    final realtimeConnected = ref.watch(dxpRealtimeConnectedProvider);
    final firstName = ref
        .watch(identitySessionProvider)
        .profile
        ?.firstName
        ?.trim();
    final controller = ref.read(dxpControllerProvider.notifier);
    final service = ref.read(dxpServiceProvider);

    return Scaffold(
      backgroundColor: _marketingBackground,
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load Marketing Command Center: $e')),
        data: (snap) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _MarketingWelcomeHero(
                    firstName: firstName,
                    fromRemote: snap.fromRemote,
                    realtimeConnected: realtimeConnected,
                    onRefresh: controller.refresh,
                    onCreate: () => _openCreateMenu(context, ref, service),
                  ),
                ),
                if (ui.lastMessage != null)
                  ContainedPadding(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(
                            LucideIcons.info,
                            color: AppColors.gold,
                          ),
                          title: Text(ui.lastMessage!),
                          dense: true,
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: controller.clearMessage,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (snap.loadWarnings.isNotEmpty)
                  ContainedPadding(
                    child: _DataWarningBanner(warnings: snap.loadWarnings),
                  ),
                ContainedPadding(
                  child: _KpiStrip(
                    kpis: snap.kpis,
                    onSelected: (kpi) => _openKpi(context, controller, kpi),
                  ),
                ),
                if (ui.selectedTab != DxpCommandTab.overview) ...[
                  ContainedPadding(
                    child: _WorkspaceLinks(onOpen: (path) => context.go(path)),
                  ),
                  ContainedPadding(
                    child: _SearchAndFilters(
                      ui: ui,
                      onSearch: controller.setSearch,
                      onStatus: controller.setStatusFilter,
                    ),
                  ),
                ],
                if (ui.selectedTab != DxpCommandTab.overview)
                  ContainedPadding(
                    child: _TabBar(
                      selected: ui.selectedTab,
                      onSelect: controller.setTab,
                    ),
                  ),
                ..._tabSlivers(context, ref, snap, ui, controller, service),
                const ContainedPadding(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openKpi(
    BuildContext context,
    DxpController controller,
    DxpKpi kpi,
  ) {
    switch (kpi.label) {
      case 'CRM Leads':
      case 'Qualified Leads':
      case 'Won / Clients':
        context.go(RoutePaths.dashboardCrm);
      case 'Active Campaigns':
      case 'Planned Budget':
        controller.setTab(DxpCommandTab.campaigns);
      case 'Published Content':
        controller.setTab(DxpCommandTab.pages);
      case 'Scheduled Content':
        controller.setTab(DxpCommandTab.calendar);
      case 'SEO Coverage':
      case 'Avg SEO Score':
      case 'SEO Issues':
        controller.setTab(DxpCommandTab.seo);
      case 'Awaiting CRM Sync':
        controller.setTab(DxpCommandTab.forms);
      case 'Media Assets':
        controller.setTab(DxpCommandTab.media);
    }
  }

  Future<void> _afterMutation(
    WidgetRef ref,
    DxpController controller,
    String message,
  ) async {
    controller.setMessage(message);
    await controller.refresh();
  }

  void _openCreateMenu(
    BuildContext context,
    WidgetRef ref,
    DxpService service,
  ) {
    final controller = ref.read(dxpControllerProvider.notifier);
    final media = ref.read(mediaServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget routeItem(IconData icon, String label, String path) {
          return ListTile(
            leading: Icon(icon, color: AppColors.gold),
            title: Text(label, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              context.go(path);
            },
          );
        }

        Widget actionItem(
          IconData icon,
          String label,
          Future<void> Function() action,
        ) {
          return ListTile(
            leading: Icon(icon, color: AppColors.gold),
            title: Text(label, style: const TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              await action();
            },
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              actionItem(LucideIcons.panelTop, 'New Landing Page', () async {
                final ok = await showLandingPageEditor(
                  context: context,
                  service: service,
                  mediaService: media,
                );
                if (ok) {
                  await _afterMutation(ref, controller, 'Landing page saved.');
                  controller.setTab(DxpCommandTab.landing);
                }
              }),
              actionItem(LucideIcons.megaphone, 'New Campaign', () async {
                final ok = await showCampaignEditor(
                  context: context,
                  service: service,
                );
                if (ok) {
                  await _afterMutation(ref, controller, 'Campaign saved.');
                  controller.setTab(DxpCommandTab.campaigns);
                }
              }),
              actionItem(LucideIcons.calendarPlus, 'Calendar Item', () async {
                final ok = await showCalendarEditor(
                  context: context,
                  service: service,
                );
                if (ok) {
                  await _afterMutation(ref, controller, 'Calendar item saved.');
                  controller.setTab(DxpCommandTab.calendar);
                }
              }),
              routeItem(
                LucideIcons.fileText,
                'New Blog Post',
                RoutePaths.dashboardWebsiteBlog,
              ),
              routeItem(
                LucideIcons.layoutTemplate,
                'Homepage Section',
                RoutePaths.dashboardWebsiteHomepage,
              ),
              routeItem(
                LucideIcons.image,
                'Upload Media',
                RoutePaths.dashboardWebsiteMedia,
              ),
              routeItem(
                LucideIcons.search,
                'SEO Entry',
                RoutePaths.dashboardWebsiteSeo,
              ),
              routeItem(
                LucideIcons.globe,
                'Website Control Center',
                RoutePaths.dashboardWebsite,
              ),
              routeItem(
                LucideIcons.users,
                'Open CRM Leads',
                RoutePaths.dashboardCrm,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    DxpCommandCenterSnapshot snap,
    DxpUiState ui,
    DxpController controller,
    DxpService service,
  ) {
    switch (ui.selectedTab) {
      case DxpCommandTab.overview:
        return [
          ContainedPadding(
            child: _OverviewDashboard(
              snapshot: snap,
              onCreateCampaign: () async {
                final ok = await showCampaignEditor(
                  context: context,
                  service: service,
                );
                if (ok) {
                  await _afterMutation(ref, controller, 'Campaign created.');
                }
              },
              onOpenWebsite: () => context.go(RoutePaths.dashboardWebsite),
              onOpenCrm: () => context.go(RoutePaths.dashboardCrm),
              onCreateContent: () =>
                  context.go(RoutePaths.dashboardWebsiteBlog),
              onTabSelect: controller.setTab,
            ),
          ),
        ];
      case DxpCommandTab.pages:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'CMS Pages',
              icon: LucideIcons.layout,
              trailing: TextButton(
                onPressed: () => context.go(RoutePaths.dashboardWebsitePages),
                child: const Text('Open in Website CMS'),
              ),
              child: _CmsPageList(
                pages: snap.cmsPages,
                onOpenCms: () => context.go(RoutePaths.dashboardWebsitePages),
                onTogglePublish: (page) async {
                  try {
                    await service.setPagePublished(
                      id: page.id,
                      published: !page.isPublished,
                    );
                    await _afterMutation(
                      ref,
                      controller,
                      page.isPublished
                          ? 'Page unpublished.'
                          : 'Page published.',
                    );
                  } catch (e) {
                    controller.setMessage('Publish failed: $e');
                  }
                },
              ),
            ),
          ),
        ];
      case DxpCommandTab.landing:
        final media = ref.read(mediaServiceProvider);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Landing Pages',
              icon: LucideIcons.panelTop,
              trailing: TextButton.icon(
                onPressed: () async {
                  final ok = await showLandingPageEditor(
                    context: context,
                    service: service,
                    mediaService: media,
                  );
                  if (ok) {
                    await _afterMutation(
                      ref,
                      controller,
                      'Landing page created.',
                    );
                  }
                },
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('New'),
              ),
              child: _LandingList(
                pages: controller.filteredLanding(snap),
                onEdit: (p) async {
                  final ok = await showLandingPageEditor(
                    context: context,
                    service: service,
                    mediaService: media,
                    existing: p,
                  );
                  if (ok) {
                    await _afterMutation(
                      ref,
                      controller,
                      'Landing page updated.',
                    );
                  }
                },
                onTogglePublish: (p) async {
                  try {
                    await service.setLandingPublished(
                      id: p.id,
                      published: !p.isPublished,
                    );
                    await _afterMutation(
                      ref,
                      controller,
                      p.isPublished
                          ? 'Landing unpublished.'
                          : 'Landing published.',
                    );
                  } catch (e) {
                    controller.setMessage('Publish failed: $e');
                  }
                },
                onArchive: (p) async {
                  try {
                    await service.archiveLandingPage(p.id);
                    await _afterMutation(ref, controller, 'Landing archived.');
                  } catch (e) {
                    controller.setMessage('Archive failed: $e');
                  }
                },
                onOpenPublic: (p) {
                  context.go(RoutePaths.landingPagePath(p.slug));
                },
              ),
            ),
          ),
        ];
      case DxpCommandTab.blog:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Blog Studio',
              icon: LucideIcons.newspaper,
              trailing: TextButton(
                onPressed: () => context.go(RoutePaths.dashboardWebsiteBlog),
                child: const Text('Open in Website CMS'),
              ),
              child: _BlogList(
                posts: controller.filteredBlogs(snap),
                onOpenCms: () => context.go(RoutePaths.dashboardWebsiteBlog),
                onTogglePublish: (post) async {
                  try {
                    await service.setBlogPublished(
                      id: post.id,
                      published: !post.isPublished,
                    );
                    await _afterMutation(
                      ref,
                      controller,
                      post.isPublished
                          ? 'Blog unpublished.'
                          : 'Blog published.',
                    );
                  } catch (e) {
                    controller.setMessage('Publish failed: $e');
                  }
                },
              ),
            ),
          ),
        ];
      case DxpCommandTab.media:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Media Library',
              icon: LucideIcons.image,
              trailing: TextButton(
                onPressed: () => context.go(RoutePaths.dashboardWebsiteMedia),
                child: const Text('Open in Website CMS'),
              ),
              child: _MediaList(
                assets: snap.mediaAssets,
                onOpenCms: () => context.go(RoutePaths.dashboardWebsiteMedia),
                onTogglePublish: (asset) async {
                  try {
                    await service.setMediaPublished(
                      id: asset.id,
                      published: !asset.isPublished,
                      title: asset.title,
                    );
                    await _afterMutation(
                      ref,
                      controller,
                      asset.isPublished
                          ? 'Media unpublished.'
                          : 'Media published.',
                    );
                  } catch (e) {
                    controller.setMessage('Publish failed: $e');
                  }
                },
              ),
            ),
          ),
        ];
      case DxpCommandTab.campaigns:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Omnichannel Campaigns',
              icon: LucideIcons.megaphone,
              trailing: TextButton.icon(
                onPressed: () async {
                  final ok = await showCampaignEditor(
                    context: context,
                    service: service,
                  );
                  if (ok) {
                    await _afterMutation(ref, controller, 'Campaign created.');
                  }
                },
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('New'),
              ),
              child: _CampaignList(
                campaigns: controller.filteredCampaigns(snap),
                onEdit: (c) async {
                  final ok = await showCampaignEditor(
                    context: context,
                    service: service,
                    existing: c,
                  );
                  if (ok) {
                    await _afterMutation(ref, controller, 'Campaign updated.');
                  }
                },
                onStatus: (c, status) async {
                  try {
                    await service.setCampaignStatus(id: c.id, status: status);
                    await _afterMutation(
                      ref,
                      controller,
                      'Campaign → ${status.label}',
                    );
                  } catch (e) {
                    controller.setMessage('Campaign status failed: $e');
                  }
                },
                onDelete: (c) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Archive campaign?'),
                      content: Text('Soft-delete “${c.name}”?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Archive'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await service.softDeleteCampaign(c.id);
                    await _afterMutation(ref, controller, 'Campaign archived.');
                  } catch (e) {
                    controller.setMessage('Delete failed: $e');
                  }
                },
              ),
            ),
          ),
        ];
      case DxpCommandTab.forms:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Form Submissions',
              icon: LucideIcons.clipboardList,
              trailing: TextButton(
                onPressed: () => context.go(RoutePaths.dashboardCrm),
                child: const Text('Open CRM'),
              ),
              child: _FormList(
                submissions: snap.formSubmissions,
                onResync: (s) async {
                  try {
                    final result = await service.resyncFormSubmissionToCrm(
                      s.id,
                    );
                    final leadId = result['crm_lead_id'];
                    await _afterMutation(
                      ref,
                      controller,
                      leadId != null
                          ? 'Synced to CRM lead $leadId'
                          : 'CRM sync complete',
                    );
                  } catch (e) {
                    controller.setMessage('CRM sync failed: $e');
                  }
                },
                onOpenCrm: () => context.go(RoutePaths.dashboardCrm),
              ),
            ),
          ),
        ];
      case DxpCommandTab.seo:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'SEO Health',
              icon: LucideIcons.search,
              trailing: TextButton(
                onPressed: () => context.go(RoutePaths.dashboardWebsiteSeo),
                child: const Text('Open in Website CMS'),
              ),
              child: _SeoList(
                items: snap.seoHealth,
                onOpenCms: () => context.go(RoutePaths.dashboardWebsiteSeo),
              ),
            ),
          ),
        ];
      case DxpCommandTab.calendar:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Content Calendar',
              icon: LucideIcons.calendarDays,
              trailing: TextButton.icon(
                onPressed: () async {
                  final ok = await showCalendarEditor(
                    context: context,
                    service: service,
                  );
                  if (ok) {
                    await _afterMutation(
                      ref,
                      controller,
                      'Calendar item created.',
                    );
                  }
                },
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('New'),
              ),
              child: _CalendarList(
                items: snap.calendar,
                onEdit: (item) async {
                  final ok = await showCalendarEditor(
                    context: context,
                    service: service,
                    existing: item,
                  );
                  if (ok) {
                    await _afterMutation(
                      ref,
                      controller,
                      'Calendar item updated.',
                    );
                  }
                },
                onStatus: (item, status) async {
                  try {
                    await service.setCalendarStatus(
                      id: item.id,
                      status: status,
                    );
                    await _afterMutation(ref, controller, 'Calendar → $status');
                  } catch (e) {
                    controller.setMessage('Calendar status failed: $e');
                  }
                },
                onDelete: (item) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete calendar item?'),
                      content: Text('Remove “${item.title}”?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await service.deleteCalendarItem(item.id);
                    await _afterMutation(
                      ref,
                      controller,
                      'Calendar item deleted.',
                    );
                  } catch (e) {
                    controller.setMessage('Delete failed: $e');
                  }
                },
              ),
            ),
          ),
        ];
    }
  }
}

class ContainedPadding extends StatelessWidget {
  const ContainedPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _MarketingWelcomeHero extends StatelessWidget {
  const _MarketingWelcomeHero({
    required this.firstName,
    required this.fromRemote,
    required this.realtimeConnected,
    required this.onRefresh,
    required this.onCreate,
  });

  final String? firstName;
  final bool fromRemote;
  final bool realtimeConnected;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF10233D), Color(0xFF0C1B30), Color(0xFF14243A)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _HeroSkyline()),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 720;
                    final live = realtimeConnected || fromRemote;
                    final title = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$greeting${firstName == null || firstName!.isEmpty ? '' : ', $firstName'} 👋',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Here’s what’s happening across marketing today.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFFB9C7DA)),
                        ),
                        const SizedBox(height: 8),
                        _SyncPill(live: live),
                        if (!fromRemote) ...[
                          const SizedBox(height: 6),
                          const OfflineUpdatesNote(color: Color(0xFFB9C7DA)),
                        ],
                      ],
                    );
                    final actions = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        _HeroDateBadge(date: DateTime.now()),
                        FilledButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(LucideIcons.zap, size: 15),
                          label: const Text('Quick actions'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.goldLight,
                            foregroundColor: _marketingBackground,
                            minimumSize: const Size(132, 38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => onRefresh(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: .08,
                            ),
                          ),
                          icon: Icon(
                            LucideIcons.refreshCw,
                            size: 17,
                            color: live ? const Color(0xFF35D89A) : Colors.white,
                          ),
                        ),
                      ],
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 10), actions],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 16),
                        Flexible(child: actions),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDateBadge extends StatelessWidget {
  const _HeroDateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _marketingPanel.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.calendarDays, size: 15, color: AppColors.gold),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TODAY',
                style: TextStyle(
                  color: Color(0xFF8092AA),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d').format(date),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSkyline extends StatelessWidget {
  const _HeroSkyline();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: .50,
          child: CustomPaint(painter: _SkylinePainter()),
        ),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [AppColors.gold.withValues(alpha: .18), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .65, size.height * .35),
              radius: size.width * .58,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);

    final building = Paint()
      ..color = const Color(0xFF091321).withValues(alpha: .65);
    final lit = Paint()..color = AppColors.goldLight.withValues(alpha: .22);
    final widths = [0.18, 0.23, 0.16, 0.25, 0.20];
    var x = size.width * .08;
    for (var i = 0; i < widths.length; i++) {
      final width = size.width * widths[i];
      final height = size.height * (.30 + ((i * 19) % 34) / 100);
      final rect = Rect.fromLTWH(x, size.height - height, width, height);
      canvas.drawRect(rect, building);
      for (var wx = x + 8; wx < x + width - 4; wx += 13) {
        for (var wy = rect.top + 9; wy < size.height - 7; wy += 13) {
          canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 3), lit);
        }
      }
      x += width + 4;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WorkspaceLinks extends StatelessWidget {
  const _WorkspaceLinks({required this.onOpen});

  final void Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final links = <(String, String, IconData)>[
      ('Website', RoutePaths.dashboardWebsite, LucideIcons.globe),
      (
        'Homepage',
        RoutePaths.dashboardWebsiteHomepage,
        LucideIcons.layoutTemplate,
      ),
      ('Blog', RoutePaths.dashboardWebsiteBlog, LucideIcons.newspaper),
      ('Media', RoutePaths.dashboardWebsiteMedia, LucideIcons.image),
      ('SEO', RoutePaths.dashboardWebsiteSeo, LucideIcons.search),
      ('Banners', RoutePaths.dashboardWebsiteBanners, LucideIcons.megaphone),
      ('CRM Leads', RoutePaths.dashboardCrm, LucideIcons.users),
      ('Forms inbox', RoutePaths.dashboardWebsiteSupport, LucideIcons.inbox),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, path, icon) in links)
            ActionChip(
              avatar: Icon(icon, size: 16, color: AppColors.gold),
              label: Text(label),
              onPressed: () => onOpen(path),
              backgroundColor: AppColors.charcoal.withValues(alpha: 0.55),
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _DataWarningBanner extends StatelessWidget {
  const _DataWarningBanner({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: AppRadius.cardBorder,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.database, size: 18, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Some live data could not be loaded',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      warnings.join('\n'),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        live
            ? 'Your latest records are here.'
            : "We're gathering the latest records.",
        style: const TextStyle(
          color: Color(0xFF9CB0C8),
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis, required this.onSelected});

  final List<DxpKpi> kpis;
  final ValueChanged<DxpKpi> onSelected;

  IconData _iconFor(String label) => switch (label) {
    'CRM Leads' => LucideIcons.users,
    'Qualified Leads' => LucideIcons.userCheck,
    'Won / Clients' => LucideIcons.trophy,
    'Active Campaigns' => LucideIcons.megaphone,
    'Published Content' => LucideIcons.badgeCheck,
    'Scheduled Content' => LucideIcons.calendarClock,
    'Planned Budget' => LucideIcons.walletCards,
    'Awaiting CRM Sync' => LucideIcons.refreshCw,
    'Avg SEO Score' => LucideIcons.gauge,
    'SEO Coverage' => LucideIcons.gauge,
    'SEO Issues' => LucideIcons.alertCircle,
    'Media Assets' => LucideIcons.image,
    _ => LucideIcons.activity,
  };

  Color _accentFor(int index) => const [
    Color(0xFF35D89A),
    Color(0xFF36A2FF),
    Color(0xFFA66BFF),
    Color(0xFF35D5D0),
    Color(0xFFFF9E45),
    Color(0xFF45A7FF),
    Color(0xFFE0AA36),
    Color(0xFF9B55F5),
  ][index % 8];

  String _captionFor(String label) => switch (label) {
    'CRM Leads' => 'From the sales desk',
    'Qualified Leads' => 'Ready for follow-up',
    'Won / Clients' => 'Closed successfully',
    'Active Campaigns' => 'Running campaigns',
    'Published Content' => 'Currently published',
    'Scheduled Content' => 'Upcoming items',
    'Planned Budget' => 'Campaign allocation',
    'Avg SEO Score' => 'Audited page score',
    'SEO Coverage' => 'Title and description set',
    'Awaiting CRM Sync' => 'Forms not in CRM',
    'SEO Issues' => 'Recorded issue count',
    'Media Assets' => 'Library files',
    _ => 'Current total',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final columns = constraints.maxWidth >= 820
              ? 4
              : constraints.maxWidth >= 520
              ? 3
              : 2;
          final width =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var index = 0; index < kpis.length; index++)
                Builder(
                  builder: (context) {
                    final kpi = kpis[index];
                    final accent = _accentFor(index);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelected(kpi),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          width: width,
                          height: 92,
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
                          decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _marketingPanelLight,
                            accent.withValues(alpha: .11),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: .38),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: .07),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 25,
                                height: 25,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .20),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconFor(kpi.label),
                                  size: 13,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  kpi.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFC0CBDB),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                LucideIcons.arrowUpRight,
                                size: 12,
                                color: Color(0xFF60748C),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                kpi.displayValue,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x1FFFFFFF)),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _captionFor(kpi.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF74859C),
                                  fontSize: 7.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewDashboard extends StatelessWidget {
  const _OverviewDashboard({
    required this.snapshot,
    required this.onCreateCampaign,
    required this.onOpenWebsite,
    required this.onOpenCrm,
    required this.onCreateContent,
    required this.onTabSelect,
  });

  final DxpCommandCenterSnapshot snapshot;
  final VoidCallback onCreateCampaign;
  final VoidCallback onOpenWebsite;
  final VoidCallback onOpenCrm;
  final VoidCallback onCreateContent;
  final ValueChanged<DxpCommandTab> onTabSelect;

  @override
  Widget build(BuildContext context) {
    final performance = _DashboardPanel(
      title: 'Marketing Performance Overview',
      icon: LucideIcons.barChart3,
      trailing: const _PeriodPill(),
      child: _PerformanceBars(snapshot: snapshot),
    );
    final contentMix = _DashboardPanel(
      title: 'Lead Pipeline',
      icon: LucideIcons.pieChart,
      child: _LeadPipelineMix(stages: snapshot.funnel),
    );
    final quickActions = _DashboardPanel(
      title: 'Quick Actions',
      icon: LucideIcons.zap,
      child: _QuickActionList(
        onCreateCampaign: onCreateCampaign,
        onOpenWebsite: onOpenWebsite,
        onOpenCrm: onOpenCrm,
        onCreateContent: onCreateContent,
      ),
    );
    final pipeline = _DashboardPanel(
      title: 'Sales pipeline',
      icon: LucideIcons.inbox,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactOverviewTabs(onSelect: onTabSelect),
          const SizedBox(height: 10),
          _PipelineTable(stages: snapshot.funnel),
        ],
      ),
    );
    final activity = _DashboardPanel(
      title: 'Recent Activity',
      icon: LucideIcons.activity,
      child: _CompactActivityList(activities: snapshot.activities),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 930;
          final medium = constraints.maxWidth >= 650;
          final top = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: performance),
                    const SizedBox(width: 12),
                    Expanded(child: contentMix),
                    const SizedBox(width: 12),
                    Expanded(child: quickActions),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    performance,
                    const SizedBox(height: 12),
                    if (medium)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: contentMix),
                          const SizedBox(width: 12),
                          Expanded(child: quickActions),
                        ],
                      )
                    else ...[
                      contentMix,
                      const SizedBox(height: 12),
                      quickActions,
                    ],
                  ],
                );
          final bottom = constraints.maxWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: pipeline),
                    const SizedBox(width: 12),
                    Expanded(child: activity),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [pipeline, const SizedBox(height: 12), activity],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(child: top),
              const SizedBox(height: 12),
              bottom,
            ],
          );
        },
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _marketingPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _marketingBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.goldLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1B2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF234668)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.calendarDays, size: 9, color: Color(0xFF9CB0C8)),
          SizedBox(width: 5),
          Text(
            'Last 7 days',
            style: TextStyle(
              color: Color(0xFF9CB0C8),
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceBars extends StatelessWidget {
  const _PerformanceBars({required this.snapshot});

  final DxpCommandCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index)),
    );
    final leads = _countsByDay(days, [
      ...snapshot.crmLeadCapturedAt,
      ...snapshot.formSubmissions
          .where((item) => !item.isSyncedToCrm)
          .map((item) => item.submittedAt),
    ]);
    final content = _countsByDay(days, [
      ...snapshot.landingPages
          .where((item) => item.isPublished)
          .map((item) => item.publishedAt),
      ...snapshot.blogPosts
          .where((item) => item.isPublished)
          .map((item) => item.publishedAt),
      ...snapshot.cmsPages
          .where((item) => item.isPublished)
          .map((item) => item.publishedAt),
    ]);
    final campaigns = _countsByDay(
      days,
      snapshot.campaigns.map((item) => item.startsAt),
    );
    final hasActivity = [leads, content, campaigns].any(
      (series) => series.any((value) => value > 0),
    );
    if (!hasActivity) {
      return const _OverviewEmpty(
        icon: LucideIcons.barChart3,
        message:
            'No leads, publications, or campaign starts in the last 7 days.',
      );
    }
    const series = [
      ('Leads', Color(0xFF35D89A)),
      ('Content', Color(0xFF36A2FF)),
      ('Campaigns', Color(0xFFA66BFF)),
    ];
    return SizedBox(
      height: 118,
      child: Column(
        children: [
          Row(
            children: [
              for (final item in series) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: item.$2,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  item.$1,
                  style: const TextStyle(color: Color(0xFF8FA1B8), fontSize: 8),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: CustomPaint(
              painter: _PerformanceChartPainter(
                values: [leads, content, campaigns],
                colors: series.map((item) => item.$2).toList(),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final day in days)
                      Text(
                        DateFormat('MMM d').format(day),
                        style: const TextStyle(
                          color: Color(0xFF60758F),
                          fontSize: 6.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<double> _countsByDay(
    List<DateTime> days,
    Iterable<DateTime?> timestamps,
  ) {
    return [
      for (final day in days)
        timestamps
            .where(
              (at) =>
                  at != null &&
                  at.year == day.year &&
                  at.month == day.month &&
                  at.day == day.day,
            )
            .length
            .toDouble(),
    ];
  }
}

class _PerformanceChartPainter extends CustomPainter {
  const _PerformanceChartPainter({required this.values, required this.colors});

  final List<List<double>> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const labelSpace = 13.0;
    final chart = Rect.fromLTWH(0, 0, size.width, size.height - labelSpace);
    final grid = Paint()
      ..color = const Color(0xFF1A2C43)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    final maxValue = values
        .expand((series) => series)
        .fold<double>(1, (max, value) => value > max ? value : max);
    for (var seriesIndex = 0; seriesIndex < values.length; seriesIndex++) {
      final series = values[seriesIndex];
      if (series.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < series.length; i++) {
        final x = chart.left + chart.width * i / (series.length - 1);
        final y = chart.bottom - (series[i] / maxValue * chart.height * .82);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final color = colors[seriesIndex % colors.length];
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < series.length; i++) {
        final x = chart.left + chart.width * i / (series.length - 1);
        final y = chart.bottom - (series[i] / maxValue * chart.height * .82);
        canvas.drawCircle(Offset(x, y), 2.2, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PerformanceChartPainter oldDelegate) => true;
}

class _LeadPipelineMix extends StatelessWidget {
  const _LeadPipelineMix({required this.stages});

  final List<DxpFunnelStage> stages;

  @override
  Widget build(BuildContext context) {
    final visible = stages;
    final total = visible.fold<double>(0, (sum, stage) => sum + stage.value);
    const colors = [
      Color(0xFFE7B94D),
      Color(0xFF36A2FF),
      Color(0xFF35D89A),
      Color(0xFF8B9BB0),
    ];
    return SizedBox(
      height: 132,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _DonutPainter(
                values: visible.map((stage) => stage.value).toList(),
                colors: colors,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatDxpCount(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Total leads',
                      style: TextStyle(color: Color(0xFF71849C), fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          visible[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9EADC1),
                            fontSize: 9,
                          ),
                        ),
                      ),
                      Text(
                        total <= 0
                            ? '0%'
                            : '${(visible[i].value / total * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (i != visible.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide * .38;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.butt;
    paint.color = const Color(0xFF1B2B40);
    canvas.drawCircle(center, radius, paint);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    var start = -1.5708;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 6.28318;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _QuickActionList extends StatelessWidget {
  const _QuickActionList({
    required this.onCreateCampaign,
    required this.onOpenWebsite,
    required this.onOpenCrm,
    required this.onCreateContent,
  });

  final VoidCallback onCreateCampaign;
  final VoidCallback onOpenWebsite;
  final VoidCallback onOpenCrm;
  final VoidCallback onCreateContent;

  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, VoidCallback, bool)>[
      ('Create campaign', LucideIcons.plusCircle, onCreateCampaign, true),
      ('Website CMS', LucideIcons.globe, onOpenWebsite, false),
      ('Open CRM', LucideIcons.users, onOpenCrm, false),
      ('Create content', LucideIcons.filePlus, onCreateContent, false),
      (
        'Generate report',
        LucideIcons.fileText,
        () => context.go(RoutePaths.dashboardReports),
        false,
      ),
    ];
    return Column(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          SizedBox(
            width: double.infinity,
            height: 27,
            child: actions[index].$4
                ? FilledButton.icon(
                    onPressed: actions[index].$3,
                    icon: Icon(actions[index].$2, size: 13),
                    label: Text(actions[index].$1),
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: AppColors.goldLight,
                      foregroundColor: _marketingBackground,
                      textStyle: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: actions[index].$3,
                    icon: Icon(actions[index].$2, size: 13),
                    label: Text(actions[index].$1),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: const Color(0xFFC4D0E0),
                      side: const BorderSide(color: Color(0xFF263B55)),
                      textStyle: const TextStyle(fontSize: 9.5),
                    ),
                  ),
          ),
          if (index != actions.length - 1) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _CompactOverviewTabs extends StatelessWidget {
  const _CompactOverviewTabs({required this.onSelect});

  final ValueChanged<DxpCommandTab> onSelect;

  Widget _tabChip(DxpCommandTab tab) {
    final active = tab == DxpCommandTab.overview;
    return Material(
      color: active ? AppColors.goldLight : const Color(0xFF12233A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSelect(tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            tab.label,
            style: TextStyle(
              color: active ? _marketingBackground : const Color(0xFF8496AC),
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final tab in DxpCommandTab.values) _tabChip(tab),
            ],
          );
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: DxpCommandTab.values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 4),
            itemBuilder: (context, index) =>
                _tabChip(DxpCommandTab.values[index]),
          ),
        );
      },
    );
  }
}

class _PipelineTable extends StatelessWidget {
  const _PipelineTable({required this.stages});

  final List<DxpFunnelStage> stages;

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) {
      return const _OverviewEmpty(
        icon: LucideIcons.users,
        message: 'No CRM pipeline records yet.',
      );
    }
    final base = stages.fold<double>(0, (sum, stage) => sum + stage.value);
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'STAGE',
                style: TextStyle(color: Color(0xFF657891), fontSize: 8),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                'LEADS',
                textAlign: TextAlign.right,
                style: TextStyle(color: Color(0xFF657891), fontSize: 8),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                'SHARE',
                textAlign: TextAlign.right,
                style: TextStyle(color: Color(0xFF657891), fontSize: 8),
              ),
            ),
            SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Text(
                'OF TOTAL',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF657891), fontSize: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        for (var index = 0; index < stages.length; index++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: index.isEven
                  ? const Color(0xFF0F1D30)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _pipelineColor(index).withValues(alpha: .20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    index == 2 ? LucideIcons.trophy : LucideIcons.users,
                    size: 12,
                    color: _pipelineColor(index),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    stages[index].label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC8D2DF),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    stages[index].displayValue,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    base <= 0
                        ? '0%'
                        : '${((stages[index].value / base) * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: base <= 0
                          ? 0
                          : (stages[index].value / base).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: const Color(0xFF1B2B40),
                      color: _pipelineColor(index),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index != stages.length - 1) const SizedBox(height: 3),
        ],
      ],
    );
  }

  Color _pipelineColor(int index) => const [
    Color(0xFFA66BFF),
    Color(0xFF36A2FF),
    Color(0xFF35D89A),
  ][index % 3];
}

class _CompactActivityList extends StatelessWidget {
  const _CompactActivityList({required this.activities});

  final List<DxpActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const _OverviewEmpty(
        icon: LucideIcons.activity,
        message: 'Activity appears after real marketing changes.',
      );
    }
    return Column(
      children: [
        for (
          var index = 0;
          index < activities.length && index < 5;
          index++
        ) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _pipelineColor(index).withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.activity,
                  size: 10,
                  color: _pipelineColor(index),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activities[index].summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD2DBE7),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activityMeta(activities[index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71849C),
                        fontSize: 7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (index < activities.length - 1 && index < 4)
            const SizedBox(height: 5),
        ],
      ],
    );
  }

  Color _pipelineColor(int index) => const [
    Color(0xFF35D89A),
    Color(0xFF36A2FF),
    Color(0xFFA66BFF),
    Color(0xFFFF9E45),
  ][index % 4];

  String _activityMeta(DxpActivity activity) {
    final actor = activity.actorLabel ?? activity.action;
    final at = activity.occurredAt;
    if (at == null) return actor;
    final difference = DateTime.now().difference(at);
    final time = difference.inMinutes < 60
        ? '${difference.inMinutes.clamp(0, 59)}m ago'
        : difference.inHours < 24
        ? '${difference.inHours}h ago'
        : '${difference.inDays}d ago';
    return '$actor · $time';
  }
}

class _OverviewEmpty extends StatelessWidget {
  const _OverviewEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1C2E),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF536A85)),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8193A9), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onStatus,
  });

  final DxpUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            decoration: InputDecoration(
              hintText: 'Search campaigns, pages and posts…',
              prefixIcon: const Icon(LucideIcons.search, size: 17),
              isDense: true,
              filled: true,
              fillColor: _marketingPanelLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _marketingBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _marketingBorder),
              ),
            ),
            onChanged: onSearch,
          );
          final status = DropdownButtonFormField<String?>(
            initialValue: ui.statusFilter,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: _marketingPanelLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(value: 'paused', child: Text('Paused')),
            ],
            onChanged: onStatus,
          );
          if (constraints.maxWidth < 520) {
            return Column(
              children: [search, const SizedBox(height: 8), status],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 8),
              SizedBox(width: 150, child: status),
            ],
          );
        },
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final DxpCommandTab selected;
  final ValueChanged<DxpCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _marketingPanel,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _marketingBorder),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: DxpCommandTab.values.map((tab) {
              final active = tab == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(tab.label),
                  selected: active,
                  onSelected: (_) => onSelect(tab),
                  showCheckmark: false,
                  selectedColor: AppColors.goldLight,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: active
                        ? AppColors.goldLight
                        : Colors.white.withValues(alpha: .12),
                  ),
                  labelStyle: TextStyle(
                    color: active
                        ? _marketingBackground
                        : const Color(0xFF9FAFC2),
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 2,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        elevation: 0,
        borderRadius: AppRadius.cardBorder,
        color: _marketingPanel,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: _marketingBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({
    required this.campaigns,
    this.onEdit,
    this.onStatus,
    this.onDelete,
  });

  final List<DxpCampaign> campaigns;
  final Future<void> Function(DxpCampaign)? onEdit;
  final Future<void> Function(DxpCampaign, CampaignStatus)? onStatus;
  final Future<void> Function(DxpCampaign)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) {
      return const _EmptyHint(
        message:
            'No campaigns yet. Create one to track channel spend and status.',
      );
    }
    return Column(
      children: campaigns.map((c) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(c.name),
          subtitle: Text(
            '${c.channel} · ${c.status.label}'
            '${c.campaignCode != null ? ' · ${c.campaignCode}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.budgetAmount > 0
                    ? DxpKpi(
                        label: '',
                        value: c.budgetAmount,
                        unit: 'currency',
                      ).displayValue
                    : c.status.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (onEdit != null || onStatus != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        await onEdit?.call(c);
                      case 'active':
                        await onStatus?.call(c, CampaignStatus.active);
                      case 'paused':
                        await onStatus?.call(c, CampaignStatus.paused);
                      case 'draft':
                        await onStatus?.call(c, CampaignStatus.draft);
                      case 'delete':
                        await onDelete?.call(c);
                    }
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onStatus != null) ...[
                      const PopupMenuItem(
                        value: 'active',
                        child: Text('Set Active'),
                      ),
                      const PopupMenuItem(
                        value: 'paused',
                        child: Text('Pause'),
                      ),
                      const PopupMenuItem(
                        value: 'draft',
                        child: Text('Back to Draft'),
                      ),
                    ],
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Archive'),
                      ),
                  ],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CmsPageList extends StatelessWidget {
  const _CmsPageList({
    required this.pages,
    this.onOpenCms,
    this.onTogglePublish,
  });

  final List<DxpCmsPage> pages;
  final VoidCallback? onOpenCms;
  final Future<void> Function(DxpCmsPage)? onTogglePublish;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return _EmptyHint(
        message: 'No CMS pages loaded. Manage pages in Website CMS.',
        actionLabel: 'Open Website CMS',
        onAction: onOpenCms,
      );
    }
    return Column(
      children: pages
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.title),
              subtitle: Text(
                '/${p.slug} · ${p.isPublished ? 'Published' : 'Unpublished'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.seoScore != null)
                    Text('SEO ${p.seoScore!.toStringAsFixed(0)}'),
                  if (onTogglePublish != null)
                    TextButton(
                      onPressed: () => onTogglePublish!(p),
                      child: Text(p.isPublished ? 'Unpublish' : 'Publish'),
                    ),
                ],
              ),
              onTap: onOpenCms,
            ),
          )
          .toList(),
    );
  }
}

class _LandingList extends StatelessWidget {
  const _LandingList({
    required this.pages,
    this.onEdit,
    this.onTogglePublish,
    this.onArchive,
    this.onOpenPublic,
  });

  final List<DxpLandingPage> pages;
  final Future<void> Function(DxpLandingPage)? onEdit;
  final Future<void> Function(DxpLandingPage)? onTogglePublish;
  final Future<void> Function(DxpLandingPage)? onArchive;
  final void Function(DxpLandingPage)? onOpenPublic;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const _EmptyHint(
        message: 'No landing pages. Create one from Create → New Landing Page.',
      );
    }
    return Column(
      children: pages.map((p) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(p.title),
          subtitle: Text(
            '${RoutePaths.landingPagePath(p.slug)} · ${p.status.label}'
            '${p.ctaLabel != null ? ' · CTA: ${p.ctaLabel}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.seoScore != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('SEO ${p.seoScore!.toStringAsFixed(0)}'),
                ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await onEdit?.call(p);
                    case 'publish':
                      await onTogglePublish?.call(p);
                    case 'archive':
                      await onArchive?.call(p);
                    case 'open':
                      onOpenPublic?.call(p);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'publish',
                    child: Text(p.isPublished ? 'Unpublish' : 'Publish'),
                  ),
                  if (p.isPublished)
                    const PopupMenuItem(
                      value: 'open',
                      child: Text('Open public page'),
                    ),
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BlogList extends StatelessWidget {
  const _BlogList({
    required this.posts,
    this.onOpenCms,
    this.onTogglePublish,
  });

  final List<DxpBlogPost> posts;
  final VoidCallback? onOpenCms;
  final Future<void> Function(DxpBlogPost)? onTogglePublish;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _EmptyHint(
        message: 'No blog posts. Create and publish in Website CMS.',
        actionLabel: 'Open Blog CMS',
        onAction: onOpenCms,
      );
    }
    return Column(
      children: posts.map((b) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(b.title),
          subtitle: Text(
            '${b.status.label}'
            '${kAiFeaturesEnabled && b.aiGenerated ? ' · AI-generated (editable)' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (b.seoScore != null)
                Text('SEO ${b.seoScore!.toStringAsFixed(0)}'),
              if (onTogglePublish != null)
                TextButton(
                  onPressed: () => onTogglePublish!(b),
                  child: Text(b.isPublished ? 'Unpublish' : 'Publish'),
                ),
            ],
          ),
          onTap: onOpenCms,
        );
      }).toList(),
    );
  }
}

class _MediaList extends StatelessWidget {
  const _MediaList({
    required this.assets,
    this.onOpenCms,
    this.onTogglePublish,
  });

  final List<DxpMediaAsset> assets;
  final VoidCallback? onOpenCms;
  final Future<void> Function(DxpMediaAsset)? onTogglePublish;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return _EmptyHint(
        message: 'No media assets. Upload via Website CMS (Cloudinary).',
        actionLabel: 'Open Media CMS',
        onAction: onOpenCms,
      );
    }
    return Column(
      children: assets
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                m.fileType == 'document'
                    ? LucideIcons.fileText
                    : LucideIcons.image,
                size: 16,
              ),
              title: Text(m.title ?? m.fileUrl),
              subtitle: Text(
                '${m.folderName ?? m.fileType} · ${m.isPublished ? 'Published' : 'Unpublished'}',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'Media actions',
                onSelected: (value) async {
                  switch (value) {
                    case 'publish':
                      await onTogglePublish?.call(m);
                    case 'open':
                      onOpenCms?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'publish',
                    child: Text(m.isPublished ? 'Unpublish' : 'Publish'),
                  ),
                  const PopupMenuItem(
                    value: 'open',
                    child: Text('Open in Website CMS'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FormList extends StatelessWidget {
  const _FormList({required this.submissions, this.onResync, this.onOpenCrm});

  final List<DxpFormSubmission> submissions;
  final Future<void> Function(DxpFormSubmission)? onResync;
  final VoidCallback? onOpenCrm;

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return _EmptyHint(
        message:
            'No form submissions yet. Live submissions sync to CRM when name + phone are present.',
        actionLabel: 'Open CRM',
        onAction: onOpenCrm,
      );
    }
    return Column(
      children: submissions.map((s) {
        final syncLabel = s.isSyncedToCrm ? 'CRM synced' : 'Not in CRM';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          isThreeLine: true,
          title: Text(s.displayName ?? s.email ?? s.id),
          subtitle: Text(
            '${s.status} · $syncLabel · ${s.sourcePath ?? '—'}'
            '${s.submittedAt != null ? ' · ${DateFormat.MMMd().format(s.submittedAt!)}' : ''}'
            '${s.phone != null ? '\n${s.phone}' : ''}',
          ),
          trailing: s.isSyncedToCrm
              ? IconButton(
                  tooltip: 'Open CRM',
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  onPressed: onOpenCrm,
                )
              : TextButton(
                  onPressed: onResync == null ? null : () => onResync!(s),
                  child: const Text('Send to CRM'),
                ),
        );
      }).toList(),
    );
  }
}

class _SeoList extends StatelessWidget {
  const _SeoList({required this.items, this.onOpenCms});

  final List<DxpSeoHealth> items;
  final VoidCallback? onOpenCms;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyHint(
        message: 'No SEO audits. Manage meta in Website CMS.',
        actionLabel: 'Open SEO CMS',
        onAction: onOpenCms,
      );
    }
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.metaTitle ?? s.path),
              subtitle: Text(
                s.hasRecordedScore
                    ? '${s.path} · ${s.issueCount} issue(s)'
                    : '${s.path} · ${s.hasCoverage ? 'Title and description set' : 'Missing title or description'} · Not audited',
              ),
              trailing: Text(
                s.hasRecordedScore
                    ? s.healthScore.toStringAsFixed(0)
                    : (s.hasCoverage ? 'Covered' : 'Gap'),
              ),
              onTap: onOpenCms,
            ),
          )
          .toList(),
    );
  }
}

class _CalendarList extends StatelessWidget {
  const _CalendarList({
    required this.items,
    this.onEdit,
    this.onStatus,
    this.onDelete,
  });

  final List<DxpCalendarItem> items;
  final Future<void> Function(DxpCalendarItem)? onEdit;
  final Future<void> Function(DxpCalendarItem, String status)? onStatus;
  final Future<void> Function(DxpCalendarItem)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyHint(
        message: 'Calendar empty. Schedule a post or campaign send.',
      );
    }
    return Column(
      children: items.map((c) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(c.title),
          subtitle: Text(
            '${c.channel}'
            '${c.contentType != null ? ' · ${c.contentType}' : ''}'
            ' · ${c.status} · ${DateFormat.MMMd().add_jm().format(c.scheduledFor.toLocal())}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.ownerLabel != null && c.ownerLabel!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(c.ownerLabel!),
                ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await onEdit?.call(c);
                    case 'planned':
                    case 'scheduled':
                    case 'published':
                    case 'cancelled':
                      await onStatus?.call(c, v);
                    case 'delete':
                      await onDelete?.call(c);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'planned',
                    child: Text('Mark planned'),
                  ),
                  const PopupMenuItem(
                    value: 'scheduled',
                    child: Text('Mark scheduled'),
                  ),
                  const PopupMenuItem(
                    value: 'published',
                    child: Text('Mark published'),
                  ),
                  const PopupMenuItem(
                    value: 'cancelled',
                    child: Text('Mark cancelled'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
