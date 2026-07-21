import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/domain/services/imp_service.dart';
import 'package:hdhomesproject/features/imp/presentation/providers/imp_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 4 — Investor Command Center™ admin workspace.
class InvestorCommandCenterPage extends ConsumerWidget {
  const InvestorCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(impSnapshotProvider);
    final ui = ref.watch(impControllerProvider);
    final controller = ref.read(impControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Investor Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'IMP live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _ImpHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpen360: () =>
                        controller.setTab(ImpCommandTab.investor360),
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
                    onType: controller.setTypeFilter,
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
    ImpCommandCenterSnapshot snap,
    ImpUiState ui,
    ImpController controller,
  ) {
    switch (ui.selectedTab) {
      case ImpCommandTab.overview:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Activity Timeline',
              icon: LucideIcons.gitBranch,
              child: _ActivityList(activities: snap.activities),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Open Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(alerts: snap.alerts),
            ),
          ),
        ];
      case ImpCommandTab.investors:
        return [
          ContainedPadding(
            child: _InvestorList(
              investors: controller.filteredInvestors(snap),
              onOpen: controller.selectInvestor,
            ),
          ),
        ];
      case ImpCommandTab.opportunities:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Capital Raise Manager™',
              icon: LucideIcons.landmark,
              child: _OpportunityList(
                opportunities: controller.filteredOpportunities(snap),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Recent Commitments',
              icon: LucideIcons.badgeCheck,
              child: _CommitmentList(commitments: snap.commitments),
            ),
          ),
        ];
      case ImpCommandTab.portfolio:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Portfolio Intelligence',
              icon: LucideIcons.pieChart,
              child: _PortfolioPanel(
                holdings: snap.holdings,
                wallets: snap.wallets,
                totalValue: ImpService.computePortfolioValue(snap.holdings),
              ),
            ),
          ),
        ];
      case ImpCommandTab.distributions:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Distributions Queue',
              icon: LucideIcons.banknote,
              child: _DistributionList(distributions: snap.distributions),
            ),
          ),
        ];
      case ImpCommandTab.alerts:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Alerts',
              icon: LucideIcons.alertTriangle,
              child: _AlertList(alerts: snap.alerts),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Activity Timeline',
              icon: LucideIcons.activity,
              child: _ActivityList(activities: snap.activities),
            ),
          ),
        ];
      case ImpCommandTab.ai:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Investment Assistant™',
              icon: LucideIcons.sparkles,
              child: _AiAssistantPanel(
                insights: snap.aiInsights,
                investors: snap.investors,
                service: ref.read(impServiceProvider),
              ),
            ),
          ),
        ];
      case ImpCommandTab.investor360:
        final investor = controller.selectedInvestor(snap);
        ImpWallet? wallet;
        if (investor != null) {
          for (final w in snap.wallets) {
            if (w.investorId == investor.id) {
              wallet = w;
              break;
            }
          }
        }
        return [
          ContainedPadding(
            child: _SectionCard(
              title: '360° Investor Workspace',
              icon: LucideIcons.userCircle,
              child: investor == null
                  ? const Text('No investor selected')
                  : _Investor360Panel(
                      investor: investor,
                      investors: snap.investors,
                      holdings: snap.holdings
                          .where((h) => h.investorId == investor.id)
                          .toList(),
                      distributions: snap.distributions
                          .where((d) => d.investorId == investor.id)
                          .toList(),
                      activities: snap.activities
                          .where((a) => a.investorId == investor.id)
                          .toList(),
                      wallet: wallet,
                      onSelectInvestor: controller.selectInvestor,
                      service: ref.read(impServiceProvider),
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

class _ImpHeader extends StatelessWidget {
  const _ImpHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpen360,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpen360;

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
                'Investor Command Center™',
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
                    onPressed: onOpen360,
                    icon: const Icon(LucideIcons.scan, size: 16),
                    label: const Text('360° Investor'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.deepBlack,
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
                      'AUM · capital raise · portfolios · distributions · AI',
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        Text(
                          'AUM · capital raise · portfolios · distributions · AI',
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppRadius.cardBorder,
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.activity,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ticker,
                    style: const TextStyle(color: AppColors.white),
                    overflow: TextOverflow.ellipsis,
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

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final List<ImpKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cross = width >= 1100
              ? 6
              : width >= 720
                  ? 3
                  : 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kpis.map((kpi) {
              final tileWidth = (width - (8 * (cross - 1))) / cross;
              return SizedBox(
                width: tileWidth,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.cardBorder,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kpi.label,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kpi.displayValue,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.ui,
    required this.onSearch,
    required this.onType,
  });

  final ImpUiState ui;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search investors, codes, opportunities…',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.cardBorder),
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All types'),
                  selected: ui.typeFilter == null,
                  onSelected: (_) => onType(null),
                ),
                ...InvestorType.values.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(t.label),
                      selected: ui.typeFilter == t.slug,
                      onSelected: (_) => onType(t.slug),
                    ),
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

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final ImpCommandTab selected;
  final ValueChanged<ImpCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ImpCommandTab.values.map((tab) {
            final active = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: active,
                onSelected: (_) => onSelect(tab),
                selectedColor: AppColors.gold.withValues(alpha: 0.35),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 8),
                  ],
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
      ),
    );
  }
}

class _InvestorList extends StatelessWidget {
  const _InvestorList({required this.investors, required this.onOpen});

  final List<ImpInvestor> investors;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (investors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No investors match filters'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: investors.map((inv) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                child: Text(
                  inv.fullName.isNotEmpty ? inv.fullName[0] : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(inv.fullName),
              subtitle: Text(
                '${inv.investorCode} · ${inv.investorType.label} · ${inv.lifecycleStatus.label} · KYC ${inv.kycStatus.label}',
              ),
              trailing: Text(
                inv.aumDisplay,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => onOpen(inv.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OpportunityList extends StatelessWidget {
  const _OpportunityList({required this.opportunities});

  final List<ImpOpportunity> opportunities;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) {
      return const Text('No opportunities');
    }
    return Column(
      children: opportunities.map((opp) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      opp.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Chip(
                    label: Text(opp.status.label),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${opp.code} · Raised ${formatImpMoney(opp.amountRaised)} / ${formatImpMoney(opp.targetRaise)} (${opp.fundedPct.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Projected return: ${opp.projectedReturnLabel}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                opp.returnDisclaimer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (opp.fundedPct / 100).clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CommitmentList extends StatelessWidget {
  const _CommitmentList({required this.commitments});

  final List<ImpCommitment> commitments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: commitments.map((c) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(c.opportunityTitle ?? 'Commitment'),
          subtitle: Text('${c.investorName ?? c.investorId} · ${c.status}'),
          trailing: Text(
            c.amountDisplay,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }
}

class _PortfolioPanel extends StatelessWidget {
  const _PortfolioPanel({
    required this.holdings,
    required this.wallets,
    required this.totalValue,
  });

  final List<ImpHolding> holdings;
  final List<ImpWallet> wallets;
  final double totalValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Holdings value: ${formatImpMoney(totalValue)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        ...holdings.map(
          (h) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(h.label),
            subtitle: Text(
              '${h.investorName ?? 'Investor'} · cost ${formatImpMoney(h.costBasis)}',
            ),
            trailing: Text(
              formatImpMoney(h.currentValue),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const Divider(),
        Text(
          'Wallets',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        ...wallets.map(
          (w) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(w.investorName ?? w.investorId),
            subtitle: Text(
              'Available ${formatImpMoney(w.availableBalance)} · Pending ${formatImpMoney(w.pendingBalance)}',
            ),
            trailing: Text(formatImpMoney(w.totalBalance)),
          ),
        ),
      ],
    );
  }
}

class _DistributionList extends StatelessWidget {
  const _DistributionList({required this.distributions});

  final List<ImpDistribution> distributions;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd();
    return Column(
      children: distributions.map((d) {
        final when = d.paidAt ?? d.scheduledAt;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            d.status == DistributionStatus.paid
                ? LucideIcons.checkCircle
                : LucideIcons.clock,
            color: AppColors.gold,
            size: 18,
          ),
          title: Text(d.opportunityTitle ?? d.reference ?? 'Distribution'),
          subtitle: Text(
            '${d.investorName ?? d.investorId} · ${d.status.label}'
            '${when != null ? ' · ${fmt.format(when)}' : ''}',
          ),
          trailing: Text(
            d.amountDisplay,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<ImpAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No alerts');
    return Column(
      children: alerts.map((a) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            LucideIcons.bell,
            size: 18,
            color: a.severity == AlertSeverity.critical ||
                    a.severity == AlertSeverity.high
                ? Colors.redAccent
                : AppColors.gold,
          ),
          title: Text(a.title),
          subtitle: Text(
            '${a.severity.label} · ${a.status}${a.body != null ? '\n${a.body}' : ''}',
          ),
          isThreeLine: a.body != null,
        );
      }).toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<ImpActivity> activities;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd().add_jm();
    if (activities.isEmpty) return const Text('No activity');
    return Column(
      children: activities.map((a) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.circle, size: 10, color: AppColors.gold),
          title: Text(a.title),
          subtitle: Text(
            '${a.investorName ?? a.investorId} · ${a.eventType}'
            '${a.occurredAt != null ? ' · ${fmt.format(a.occurredAt!)}' : ''}'
            '${a.description != null ? '\n${a.description}' : ''}',
          ),
          isThreeLine: a.description != null,
        );
      }).toList(),
    );
  }
}

class _AiAssistantPanel extends StatelessWidget {
  const _AiAssistantPanel({
    required this.insights,
    required this.investors,
    required this.service,
  });

  final List<ImpAiInsight> insights;
  final List<ImpInvestor> investors;
  final ImpService service;

  @override
  Widget build(BuildContext context) {
    final sample = investors.isEmpty ? null : investors.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...insights.map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (i.isAiGenerated)
                      Chip(
                        label: const Text('AI'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(i.body),
              ],
            ),
          ),
        ),
        if (sample != null) ...[
          const Divider(),
          Text(
            'Sample portfolio summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(service.generatePortfolioSummary(sample)),
        ],
      ],
    );
  }
}

class _Investor360Panel extends StatelessWidget {
  const _Investor360Panel({
    required this.investor,
    required this.investors,
    required this.holdings,
    required this.distributions,
    required this.activities,
    required this.onSelectInvestor,
    required this.service,
    this.wallet,
  });

  final ImpInvestor investor;
  final List<ImpInvestor> investors;
  final List<ImpHolding> holdings;
  final List<ImpDistribution> distributions;
  final List<ImpActivity> activities;
  final ImpWallet? wallet;
  final ValueChanged<String> onSelectInvestor;
  final ImpService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(investor.id),
          initialValue: investor.id,
          decoration: const InputDecoration(
            labelText: 'Investor',
            isDense: true,
          ),
          items: investors
              .map(
                (i) => DropdownMenuItem(
                  value: i.id,
                  child: Text(i.fullName),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) onSelectInvestor(id);
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(investor.investorType.label)),
            Chip(label: Text(investor.lifecycleStatus.label)),
            Chip(label: Text('KYC ${investor.kycStatus.label}')),
            Chip(label: Text(investor.riskLevel.label)),
            ...investor.tags.map((t) => Chip(label: Text(t))),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'AUM ${investor.aumDisplay} · Committed ${formatImpMoney(investor.totalCommitted)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (investor.email != null) Text(investor.email!),
        if (investor.company != null) Text(investor.company!),
        if (wallet != null) ...[
          const SizedBox(height: 8),
          Text(
            'Wallet available ${formatImpMoney(wallet!.availableBalance)}',
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'AI summary',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(service.generatePortfolioSummary(investor)),
        if (holdings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Holdings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          ...holdings.map(
            (h) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(h.label),
              trailing: Text(formatImpMoney(h.currentValue)),
            ),
          ),
        ],
        if (distributions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Distributions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          ...distributions.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(d.status.label),
              trailing: Text(d.amountDisplay),
            ),
          ),
        ],
        if (activities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          ...activities.take(5).map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(a.title),
                  subtitle: a.description != null ? Text(a.description!) : null,
                ),
              ),
        ],
      ],
    );
  }
}
