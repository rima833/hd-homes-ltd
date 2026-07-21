import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:hdhomesproject/features/dxp/presentation/providers/dxp_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 8 — Marketing Command Center™ admin workspace.
class MarketingCommandCenterPage extends ConsumerWidget {
  const MarketingCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(dxpSnapshotProvider);
    final ui = ref.watch(dxpControllerProvider);
    final controller = ref.read(dxpControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Marketing Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Marketing live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _DxpHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenOmni: () =>
                        controller.setTab(DxpCommandTab.campaigns),
                    onOpenAi: () => controller.setTab(DxpCommandTab.ai),
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
                ContainedPadding(child: _KpiStrip(kpis: snap.kpis)),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                  ),
                ),
                ContainedPadding(
                  child: _TabBar(
                    selected: ui.selectedTab,
                    onSelect: controller.setTab,
                  ),
                ),
                ..._tabSlivers(context, ref, snap, ui, controller),
                const ContainedPadding(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _tabSlivers(
    BuildContext context,
    WidgetRef ref,
    DxpCommandCenterSnapshot snap,
    DxpUiState ui,
    DxpController controller,
  ) {
    switch (ui.selectedTab) {
      case DxpCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Experience Orchestration',
              icon: LucideIcons.layoutTemplate,
              child: _FunnelPanel(funnel: snap.funnel),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Omnichannel Hub',
              icon: LucideIcons.radio,
              child: _CampaignList(campaigns: snap.campaigns.take(3).toList()),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Digital Intelligence',
              icon: LucideIcons.activity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActivityList(activities: snap.activities),
                  const Divider(height: 24),
                  _AlertList(alerts: snap.alerts),
                ],
              ),
            ),
          ),
        ];
      case DxpCommandTab.pages:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'CMS Pages · Visual Builder stub',
              icon: LucideIcons.layout,
              child: _CmsPageList(pages: snap.cmsPages),
            ),
          ),
        ];
      case DxpCommandTab.landing:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Landing Pages',
              icon: LucideIcons.panelTop,
              child: _LandingList(
                pages: controller.filteredLanding(snap),
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
              child: _BlogList(posts: controller.filteredBlogs(snap)),
            ),
          ),
        ];
      case DxpCommandTab.media:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Media Library',
              icon: LucideIcons.image,
              child: _MediaList(assets: snap.mediaAssets),
            ),
          ),
        ];
      case DxpCommandTab.campaigns:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Omnichannel Campaigns',
              icon: LucideIcons.megaphone,
              child: _CampaignList(
                campaigns: controller.filteredCampaigns(snap),
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
              child: _FormList(submissions: snap.formSubmissions),
            ),
          ),
        ];
      case DxpCommandTab.seo:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'SEO Health',
              icon: LucideIcons.search,
              child: _SeoList(items: snap.seoHealth),
            ),
          ),
        ];
      case DxpCommandTab.calendar:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Content Calendar',
              icon: LucideIcons.calendarDays,
              child: _CalendarList(items: snap.calendar),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'A/B Experiments',
              icon: LucideIcons.flaskConical,
              child: _AbList(tests: snap.abTests),
            ),
          ),
        ];
      case DxpCommandTab.ai:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Content Studio',
              icon: LucideIcons.sparkles,
              child: _AiStudioPanel(
                snap: snap,
                onBriefing: () {
                  final briefing = ref
                      .read(dxpServiceProvider)
                      .generateContentBriefing(snap);
                  controller.setMessage(briefing);
                },
                onSignals: () {
                  final items = DxpService.detectConversionSignals(snap);
                  controller.setMessage(items.join(' · '));
                },
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Insights',
              icon: LucideIcons.brain,
              child: _AiList(insights: snap.aiInsights),
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

class _DxpHeader extends StatelessWidget {
  const _DxpHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenOmni,
    required this.onOpenAi,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenOmni;
  final VoidCallback onOpenAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.deepBlack.withValues(alpha: 0.9),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Text(
                'Marketing Command Center™',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenOmni,
                    icon: const Icon(LucideIcons.radio, size: 16),
                    label: const Text('Omnichannel'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('AI Studio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => onRefresh(),
                    icon: const Icon(
                      LucideIcons.rotateCcw,
                      color: AppColors.white,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: AppRadius.cardBorder,
                    ),
                    child: Text(
                      fromRemote ? 'LIVE' : 'DEMO',
                      style: TextStyle(
                        color:
                            fromRemote ? Colors.greenAccent : AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Text(
                      'CMS · campaigns · SEO · forms · AI content',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        Text(
                          'Experience Orchestration · Omnichannel Hub · AI Content Studio',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryDark,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<DxpKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kpis
            .map(
              (k) => Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                  ),
                  borderRadius: AppRadius.cardBorder,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      k.displayValue,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search campaigns, pages, posts…',
                prefixIcon: Icon(LucideIcons.search, size: 18),
                isDense: true,
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: ui.statusFilter,
            hint: const Text('Status'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All')),
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(value: 'paused', child: Text('Paused')),
            ],
            onChanged: onStatus,
          ),
        ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: DxpCommandTab.values.map((tab) {
          final active = tab == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tab.label),
              selected: active,
              onSelected: (_) => onSelect(tab),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        elevation: 0,
        borderRadius: AppRadius.cardBorder,
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
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

class _FunnelPanel extends StatelessWidget {
  const _FunnelPanel({required this.funnel});

  final List<DxpFunnelStage> funnel;

  @override
  Widget build(BuildContext context) {
    if (funnel.isEmpty) {
      return const Text('No funnel metrics yet.');
    }
    return Column(
      children: funnel.map((stage) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.filter, size: 16),
          title: Text(stage.label),
          trailing: Text(
            stage.displayValue,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({required this.campaigns});

  final List<DxpCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) return const Text('No campaigns.');
    return Column(
      children: campaigns
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.name),
              subtitle: Text(
                '${c.channel} · ${c.status.label}'
                '${c.campaignCode != null ? ' · ${c.campaignCode}' : ''}',
              ),
              trailing: Text(
                '${formatDxpCount(c.conversions)} conv',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CmsPageList extends StatelessWidget {
  const _CmsPageList({required this.pages});

  final List<DxpCmsPage> pages;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const Text(
        'Visual Builder stub — CMS pages load after SQL apply / from existing pages.',
      );
    }
    return Column(
      children: pages
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.title),
              subtitle: Text('/${p.slug} · ${p.isPublished ? 'Published' : 'Unpublished'}'),
              trailing: p.seoScore == null
                  ? null
                  : Text('SEO ${p.seoScore!.toStringAsFixed(0)}'),
            ),
          )
          .toList(),
    );
  }
}

class _LandingList extends StatelessWidget {
  const _LandingList({required this.pages});

  final List<DxpLandingPage> pages;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const Text('No landing pages.');
    return Column(
      children: pages
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.title),
              subtitle: Text(
                '${p.status.label}'
                '${p.ctaLabel != null ? ' · CTA: ${p.ctaLabel}' : ''}',
              ),
              trailing: p.seoScore == null
                  ? null
                  : Text('SEO ${p.seoScore!.toStringAsFixed(0)}'),
            ),
          )
          .toList(),
    );
  }
}

class _BlogList extends StatelessWidget {
  const _BlogList({required this.posts});

  final List<DxpBlogPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const Text('No blog posts.');
    return Column(
      children: posts.map((b) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(b.title),
          subtitle: Text(
            '${b.status.label}'
            '${b.aiGenerated ? ' · AI-generated (editable)' : ''}',
          ),
          trailing: b.seoScore == null
              ? null
              : Text('SEO ${b.seoScore!.toStringAsFixed(0)}'),
        );
      }).toList(),
    );
  }
}

class _MediaList extends StatelessWidget {
  const _MediaList({required this.assets});

  final List<DxpMediaAsset> assets;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const Text('No media assets.');
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
              subtitle: Text(m.folderName ?? m.fileType),
            ),
          )
          .toList(),
    );
  }
}

class _FormList extends StatelessWidget {
  const _FormList({required this.submissions});

  final List<DxpFormSubmission> submissions;

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) return const Text('No submissions.');
    return Column(
      children: submissions
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.displayName ?? s.email ?? s.id),
              subtitle: Text(
                '${s.status} · ${s.sourcePath ?? '—'}'
                '${s.submittedAt != null ? ' · ${DateFormat.MMMd().format(s.submittedAt!)}' : ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SeoList extends StatelessWidget {
  const _SeoList({required this.items});

  final List<DxpSeoHealth> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No SEO audits.');
    return Column(
      children: items
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.metaTitle ?? s.path),
              subtitle: Text('${s.path} · ${s.issueCount} issue(s)'),
              trailing: Text(s.healthScore.toStringAsFixed(0)),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarList extends StatelessWidget {
  const _CalendarList({required this.items});

  final List<DxpCalendarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('Calendar empty.');
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.title),
              subtitle: Text(
                '${c.channel} · ${c.status} · ${DateFormat.MMMd().add_jm().format(c.scheduledFor)}',
              ),
              trailing: Text(c.ownerLabel ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _AbList extends StatelessWidget {
  const _AbList({required this.tests});

  final List<DxpAbTest> tests;

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) return const Text('No A/B tests.');
    return Column(
      children: tests
          .map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.name),
              subtitle: Text(t.hypothesis ?? t.status),
              trailing: Text(t.status),
            ),
          )
          .toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<DxpActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No recent activity.');
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.history, size: 16),
              title: Text(a.summary),
              subtitle: Text(a.actorLabel ?? a.action),
            ),
          )
          .toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<DxpAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No alerts.');
    return Column(
      children: alerts
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                a.severity == 'warning'
                    ? LucideIcons.alertTriangle
                    : LucideIcons.bell,
                size: 16,
                color: a.severity == 'warning' ? Colors.orange : AppColors.gold,
              ),
              title: Text(a.title),
              subtitle: Text(a.body ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _AiStudioPanel extends StatelessWidget {
  const _AiStudioPanel({
    required this.snap,
    required this.onBriefing,
    required this.onSignals,
  });

  final DxpCommandCenterSnapshot snap;
  final VoidCallback onBriefing;
  final VoidCallback onSignals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          snap.aiDisclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onBriefing,
              icon: const Icon(LucideIcons.fileText, size: 16),
              label: const Text('Content briefing'),
            ),
            OutlinedButton.icon(
              onPressed: onSignals,
              icon: const Icon(LucideIcons.gauge, size: 16),
              label: const Text('Conversion signals'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiList extends StatelessWidget {
  const _AiList({required this.insights});

  final List<DxpAiInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const Text('No AI insights.');
    return Column(
      children: insights
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(i.title),
              subtitle: Text(
                '${i.body}\n${i.disclaimer}'
                '${i.confidencePct != null ? ' · ${i.confidencePct!.toStringAsFixed(0)}% conf.' : ''}'
                '${i.editable ? ' · editable' : ''}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}
