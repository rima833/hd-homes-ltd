import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/grca/domain/entities/grca_models.dart';
import 'package:hdhomesproject/features/grca/domain/services/grca_service.dart';
import 'package:hdhomesproject/features/grca/presentation/providers/grca_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 15 — GRC Command Center (GRCA).
class GrcCommandCenterPage extends ConsumerWidget {
  const GrcCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(grcaSnapshotProvider);
    final ui = ref.watch(grcaControllerProvider);
    final controller = ref.read(grcaControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load GRC Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'GRC Command Center live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _GrcaHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenAi: () => controller.setTab(GrcaCommandTab.ai),
                    onOpenRisks: () => controller.setTab(GrcaCommandTab.risks),
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
                  child: _EnterpriseFeatureStrip(onSelect: controller.setTab),
                ),
                ContainedPadding(
                  child: _SearchAndFilters(
                    ui: ui,
                    onSearch: controller.setSearch,
                    onStatus: controller.setStatusFilter,
                    onSeverity: controller.setSeverityFilter,
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
    GrcaCommandCenterSnapshot snap,
    GrcaUiState ui,
    GrcaController controller,
  ) {
    switch (ui.selectedTab) {
      case GrcaCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Governance Command Center™',
              icon: LucideIcons.scale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk · compliance · policies · audit · legal · board · BCM',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                  _ActivityList(activities: snap.activities),
                ],
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Critical / open risks',
              icon: LucideIcons.alertTriangle,
              child: _RiskList(
                items: snap.risks
                    .where((r) => r.isCriticalOpen || r.status == 'open')
                    .toList(),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Open audit findings',
              icon: LucideIcons.clipboardList,
              child: _FindingList(
                items: snap.auditFindings.where((f) => f.isOpen).toList(),
              ),
            ),
          ),
        ];
      case GrcaCommandTab.risks:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Intelligent Enterprise Risk Engine™',
              icon: LucideIcons.shieldAlert,
              child: _RiskList(items: controller.filteredRisks(snap)),
            ),
          ),
        ];
      case GrcaCommandTab.compliance:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Compliance Intelligence™',
              icon: LucideIcons.badgeCheck,
              child: _ComplianceList(items: snap.complianceFrameworks),
            ),
          ),
        ];
      case GrcaCommandTab.policies:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Corporate Policies',
              icon: LucideIcons.bookOpen,
              child: _PolicyList(items: controller.filteredPolicies(snap)),
            ),
          ),
        ];
      case GrcaCommandTab.audit:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Internal Audit Plans',
              icon: LucideIcons.clipboardCheck,
              child: _AuditPlanList(items: snap.auditPlans),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Audit Findings',
              icon: LucideIcons.fileWarning,
              child: _FindingList(items: controller.filteredFindings(snap)),
            ),
          ),
        ];
      case GrcaCommandTab.legal:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Executive Legal & Audit Intelligence™',
              icon: LucideIcons.gavel,
              child: _LegalList(items: controller.filteredLegalCases(snap)),
            ),
          ),
        ];
      case GrcaCommandTab.ethics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Ethics & Whistleblower (restricted)',
              icon: LucideIcons.eyeOff,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requires grc.ethics / grc.investigations — metadata only.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _EthicsList(items: snap.ethicsReports),
                ],
              ),
            ),
          ),
        ];
      case GrcaCommandTab.board:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Board Governance',
              icon: LucideIcons.users,
              child: _BoardList(items: snap.boardMeetings),
            ),
          ),
        ];
      case GrcaCommandTab.bcm:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Enterprise Resilience Center™',
              icon: LucideIcons.lifeBuoy,
              child: _BcmList(items: snap.bcmPlans),
            ),
          ),
        ];
      case GrcaCommandTab.calendar:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Regulatory Calendar',
              icon: LucideIcons.calendar,
              child: _CalendarList(items: snap.calendarEvents),
            ),
          ),
        ];
      case GrcaCommandTab.analytics:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'GRC Analytics & Reports',
              icon: LucideIcons.barChart3,
              child: _ReportList(items: snap.reports),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Live signals',
              icon: LucideIcons.radar,
              child: _SignalList(signals: GrcaService.detectGrcSignals(snap)),
            ),
          ),
        ];
      case GrcaCommandTab.ai:
        final service = ref.read(grcaServiceProvider);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'GRC Intelligence™',
              icon: LucideIcons.sparkles,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.generateIntelligenceBriefing(snap),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.aiDisclaimer,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                  const Divider(height: 24),
                  _AiList(items: snap.aiInsights),
                ],
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
  Widget build(BuildContext context) => SliverToBoxAdapter(child: child);
}

class _GrcaHeader extends StatelessWidget {
  const _GrcaHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenAi,
    required this.onOpenRisks,
  });

  final String ticker;
  final bool fromRemote;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenRisks;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepBlack,
            AppColors.charcoal.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GRC Command Center',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fromRemote ? 'Live · Supabase' : 'Demo dataset',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenAi,
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('GRC AI'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenRisks,
                    icon: const Icon(LucideIcons.shieldAlert, size: 16),
                    label: const Text('Risks'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.white,
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      color: AppColors.white,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), actions],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Governance, Risk, Compliance, Audit & Legal',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.activity, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ticker,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnterpriseFeatureStrip extends StatelessWidget {
  const _EnterpriseFeatureStrip({required this.onSelect});

  final void Function(GrcaCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (GrcaCommandTab.overview, 'Governance™', LucideIcons.scale),
      (GrcaCommandTab.risks, 'Risk Engine™', LucideIcons.shieldAlert),
      (GrcaCommandTab.compliance, 'Compliance™', LucideIcons.badgeCheck),
      (GrcaCommandTab.legal, 'Legal & Audit™', LucideIcons.gavel),
      (GrcaCommandTab.bcm, 'Resilience™', LucideIcons.lifeBuoy),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map(
              (e) => ActionChip(
                avatar: Icon(e.$3, size: 16),
                label: Text(e.$2),
                onPressed: () => onSelect(e.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<GrcaKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final k = kpis[i];
            return Container(
              width: 148,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    k.displayValue,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: k.status == 'watch'
                              ? AppColors.gold
                              : AppColors.charcoal,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onStatus,
    required this.onSeverity,
  });

  final GrcaUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onSeverity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search risks, findings, policies, cases…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
              ),
              isDense: true,
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All status'),
                selected: ui.statusFilter == null,
                onSelected: (_) => onStatus(null),
              ),
              FilterChip(
                label: const Text('Open'),
                selected: ui.statusFilter == 'open',
                onSelected: (_) => onStatus('open'),
              ),
              FilterChip(
                label: const Text('Active'),
                selected: ui.statusFilter == 'active',
                onSelected: (_) => onStatus('active'),
              ),
              FilterChip(
                label: const Text('Critical'),
                selected: ui.severityFilter == 'critical',
                onSelected: (_) => onSeverity(
                  ui.severityFilter == 'critical' ? null : 'critical',
                ),
              ),
              FilterChip(
                label: const Text('High'),
                selected: ui.severityFilter == 'high',
                onSelected: (_) => onSeverity(
                  ui.severityFilter == 'high' ? null : 'high',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final GrcaCommandTab selected;
  final void Function(GrcaCommandTab) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: GrcaCommandTab.values
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: selected == t,
                    onSelected: (_) => onSelect(t),
                  ),
                ),
              )
              .toList(),
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
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: AppColors.charcoal.withValues(alpha: 0.08),
          ),
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
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<GrcaActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No recent activity');
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.activity, size: 16),
              title: Text(a.summary),
              subtitle: Text(a.actorLabel ?? a.action),
            ),
          )
          .toList(),
    );
  }
}

class _RiskList extends StatelessWidget {
  const _RiskList({required this.items});

  final List<GrcaRisk> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No risks');
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.shieldAlert,
                size: 18,
                color: r.severity == 'critical' ? AppColors.gold : null,
              ),
              title: Text(r.title),
              subtitle: Text(
                '${r.code ?? ''} · ${r.severity} · ${r.status}',
              ),
              trailing: Text(r.ownerLabel ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _ComplianceList extends StatelessWidget {
  const _ComplianceList({required this.items});

  final List<GrcaComplianceFramework> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No frameworks');
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.badgeCheck, size: 18),
              title: Text(c.name),
              subtitle: Text(
                '${c.code ?? ''} · ${c.regulatorLabel ?? ''} · ${c.scorePct.toStringAsFixed(1)}%',
              ),
              trailing: Text(c.status),
            ),
          )
          .toList(),
    );
  }
}

class _PolicyList extends StatelessWidget {
  const _PolicyList({required this.items});

  final List<GrcaPolicy> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No policies');
    return Column(
      children: items
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.bookOpen, size: 18),
              title: Text(p.title),
              subtitle: Text(
                '${p.code ?? ''} · ${p.policyDomain} · ${p.ownerLabel ?? ''}',
              ),
              trailing: Text(p.status),
            ),
          )
          .toList(),
    );
  }
}

class _AuditPlanList extends StatelessWidget {
  const _AuditPlanList({required this.items});

  final List<GrcaAuditPlan> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No audit plans');
    return Column(
      children: items
          .map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.clipboardCheck, size: 18),
              title: Text(p.title),
              subtitle: Text(
                '${p.code ?? ''} · ${p.fiscalYear ?? ''} · ${p.leadAuditorLabel ?? ''}',
              ),
              trailing: Text(p.status),
            ),
          )
          .toList(),
    );
  }
}

class _FindingList extends StatelessWidget {
  const _FindingList({required this.items});

  final List<GrcaAuditFinding> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No findings');
    return Column(
      children: items
          .map(
            (f) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.fileWarning,
                size: 18,
                color: f.severity == 'high' || f.severity == 'critical'
                    ? AppColors.gold
                    : null,
              ),
              title: Text(f.title),
              subtitle: Text(
                '${f.code ?? ''} · ${f.severity} · ${f.status}',
              ),
              trailing: Text(f.ownerLabel ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _LegalList extends StatelessWidget {
  const _LegalList({required this.items});

  final List<GrcaLegalCase> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No legal cases');
    return Column(
      children: items
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.gavel, size: 18),
              title: Text(c.title),
              subtitle: Text(
                '${c.code ?? ''} · ${c.caseType} · ${c.riskLevel}',
              ),
              trailing: Text(c.status),
            ),
          )
          .toList(),
    );
  }
}

class _EthicsList extends StatelessWidget {
  const _EthicsList({required this.items});

  final List<GrcaEthicsReport> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No ethics reports');
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.eyeOff, size: 18),
              title: Text(e.code ?? e.id),
              subtitle: Text(
                '${e.reportCategory} · ${e.status} · ${e.summaryRedacted ?? 'metadata only'}',
              ),
              trailing: Text(e.severity),
            ),
          )
          .toList(),
    );
  }
}

class _BoardList extends StatelessWidget {
  const _BoardList({required this.items});

  final List<GrcaBoardMeeting> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No board meetings');
    return Column(
      children: items
          .map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.users, size: 18),
              title: Text(m.title),
              subtitle: Text(
                '${m.code ?? ''} · ${m.locationLabel ?? ''} · ${m.chairLabel ?? ''}',
              ),
              trailing: Text(m.status),
            ),
          )
          .toList(),
    );
  }
}

class _BcmList extends StatelessWidget {
  const _BcmList({required this.items});

  final List<GrcaBcmPlan> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No BCM plans');
    return Column(
      children: items
          .map(
            (b) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.lifeBuoy, size: 18),
              title: Text(b.title),
              subtitle: Text(
                '${b.code ?? ''} · RTO ${b.rtoHours ?? '-'}h · RPO ${b.rpoHours ?? '-'}h',
              ),
              trailing: Text(b.status),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarList extends StatelessWidget {
  const _CalendarList({required this.items});

  final List<GrcaCalendarEvent> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No calendar events');
    return Column(
      children: items
          .map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.calendar,
                size: 18,
                color: e.isDueSoon ? AppColors.gold : null,
              ),
              title: Text(e.title),
              subtitle: Text(
                '${e.regulatorLabel ?? ''} · ${e.eventType} · ${e.status}',
              ),
              trailing: Text(e.ownerLabel ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.items});

  final List<GrcaReport> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No reports');
    return Column(
      children: items
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.fileText, size: 18),
              title: Text(r.title),
              subtitle: Text('${r.reportType} · ${r.periodLabel ?? ''}'),
            ),
          )
          .toList(),
    );
  }
}

class _SignalList extends StatelessWidget {
  const _SignalList({required this.signals});

  final List<String> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const Text('No active signals');
    return Column(
      children: signals
          .map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.radar, size: 16),
              title: Text(s),
            ),
          )
          .toList(),
    );
  }
}

class _AiList extends StatelessWidget {
  const _AiList({required this.items});

  final List<GrcaAiInsight> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No AI insights');
    return Column(
      children: items
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.sparkles, size: 18),
              title: Text(i.title),
              subtitle: Text(
                '${i.body}\n${i.disclaimer}'
                '${i.confidencePct != null ? ' · ${i.confidencePct!.toStringAsFixed(0)}%' : ''}',
              ),
              isThreeLine: true,
            ),
          )
          .toList(),
    );
  }
}
