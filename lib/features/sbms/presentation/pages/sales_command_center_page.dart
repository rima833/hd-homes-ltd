import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/sbms/domain/entities/sbms_models.dart';
import 'package:hdhomesproject/features/sbms/domain/services/sbms_service.dart';
import 'package:hdhomesproject/features/sbms/presentation/providers/sbms_controller.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 5 — Sales Command Center™ admin workspace.
class SalesCommandCenterPage extends ConsumerWidget {
  const SalesCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(sbmsSnapshotProvider);
    final ui = ref.watch(sbmsControllerProvider);
    final controller = ref.read(sbmsControllerProvider.notifier);

    return Scaffold(
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load Sales Command Center: $e'),
        ),
        data: (snap) {
          final tickerKpis = snap.kpis;
          final ticker = tickerKpis.isEmpty
              ? 'Sales live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                ContainedPadding(
                  child: _SbmsHeader(
                    ticker: ticker,
                    fromRemote: snap.fromRemote,
                    onRefresh: controller.refresh,
                    onOpenDealRoom: () =>
                        controller.setTab(SbmsCommandTab.deals),
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
                    stages: snap.stages,
                    onSearch: controller.setSearch,
                    onStage: controller.setStageFilter,
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
    SbmsCommandCenterSnapshot snap,
    SbmsUiState ui,
    SbmsController controller,
  ) {
    switch (ui.selectedTab) {
      case SbmsCommandTab.overview:
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
              title: 'Sales Alerts',
              icon: LucideIcons.bell,
              child: _AlertList(alerts: snap.alerts),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Leaderboard',
              icon: LucideIcons.trophy,
              child: _LeaderboardList(rows: snap.leaderboard),
            ),
          ),
        ];
      case SbmsCommandTab.pipeline:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Pipeline Board',
              icon: LucideIcons.layoutGrid,
              child: _PipelineBoard(
                stages: snap.stages,
                counts: snap.stageCounts(),
                selected: ui.stageFilter,
                onSelectStage: controller.setStageFilter,
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Deals by stage',
              icon: LucideIcons.briefcase,
              child: _DealList(
                deals: controller.filteredDeals(snap),
                onOpen: controller.selectDeal,
              ),
            ),
          ),
        ];
      case SbmsCommandTab.reservations:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Reservations',
              icon: LucideIcons.bookmark,
              child: _ReservationList(
                reservations: controller.filteredReservations(snap),
              ),
            ),
          ),
        ];
      case SbmsCommandTab.bookings:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Bookings',
              icon: LucideIcons.calendar,
              child: _BookingList(bookings: snap.bookings),
            ),
          ),
        ];
      case SbmsCommandTab.quotes:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Quotes',
              icon: LucideIcons.fileText,
              child: _QuoteList(quotes: snap.quotes),
            ),
          ),
        ];
      case SbmsCommandTab.deals:
        final deal = controller.selectedDeal(snap);
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Digital Deal Room',
              icon: LucideIcons.doorOpen,
              child: deal == null
                  ? const Text('No deal selected')
                  : _DealRoomPanel(
                      deal: deal,
                      deals: snap.deals,
                      negotiations: snap.negotiations
                          .where((n) => n.orderId == deal.id)
                          .toList(),
                      quotes: snap.quotes
                          .where((q) => q.orderId == deal.id)
                          .toList(),
                      contracts: snap.contracts
                          .where((c) => c.orderId == deal.id)
                          .toList(),
                      onSelectDeal: controller.selectDeal,
                      service: ref.read(sbmsServiceProvider),
                    ),
            ),
          ),
        ];
      case SbmsCommandTab.commissions:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Commissions',
              icon: LucideIcons.percent,
              child: _CommissionList(commissions: snap.commissions),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Installments due',
              icon: LucideIcons.wallet,
              child: _InstallmentList(installments: snap.installments),
            ),
          ),
        ];
      case SbmsCommandTab.handovers:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Handovers',
              icon: LucideIcons.key,
              child: _HandoverList(handovers: snap.handovers),
            ),
          ),
        ];
      case SbmsCommandTab.approvals:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'Approvals queue',
              icon: LucideIcons.shieldCheck,
              child: _ApprovalList(requests: snap.discountRequests),
            ),
          ),
        ];
      case SbmsCommandTab.ai:
        return [
          ContainedPadding(
            child: _SectionCard(
              title: 'AI Sales Assistant™',
              icon: LucideIcons.sparkles,
              child: _AiAssistantPanel(
                insights: snap.aiInsights,
                deals: snap.deals,
                service: ref.read(sbmsServiceProvider),
              ),
            ),
          ),
          ContainedPadding(
            child: _SectionCard(
              title: 'Smart Deal Intelligence™',
              icon: LucideIcons.brain,
              child: _BulletList(items: snap.dealIntelligence),
            ),
          ),
          ContainedPadding(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                snap.forecastDisclaimer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondaryLight,
                    ),
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

class _SbmsHeader extends StatelessWidget {
  const _SbmsHeader({
    required this.ticker,
    required this.fromRemote,
    required this.onRefresh,
    required this.onOpenDealRoom,
  });

  final String ticker;
  final bool fromRemote;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenDealRoom;

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
                'Sales Command Center™',
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
                    onPressed: onOpenDealRoom,
                    icon: const Icon(LucideIcons.doorOpen, size: 16),
                    label: const Text('Deal Room'),
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
                      'Pipeline · reservations · bookings · quotes · commissions',
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
                          'Pipeline · reservations · bookings · quotes · commissions',
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

  final List<SbmsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cross = width >= 1100
              ? 4
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
                          maxLines: 2,
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
    required this.stages,
    required this.onSearch,
    required this.onStage,
  });

  final SbmsUiState ui;
  final List<SbmsPipelineStage> stages;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search deals, reservations, clients…',
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
                  label: const Text('All stages'),
                  selected: ui.stageFilter == null,
                  onSelected: (_) => onStage(null),
                ),
                ...stages.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(s.name),
                      selected: ui.stageFilter == s.slug,
                      onSelected: (_) => onStage(s.slug),
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

  final SbmsCommandTab selected;
  final ValueChanged<SbmsCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: SbmsCommandTab.values.map((tab) {
            final isSelected = tab == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab.label),
                selected: isSelected,
                onSelected: (_) => onSelect(tab),
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
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

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

class _PipelineBoard extends StatelessWidget {
  const _PipelineBoard({
    required this.stages,
    required this.counts,
    required this.selected,
    required this.onSelectStage,
  });

  final List<SbmsPipelineStage> stages;
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?> onSelectStage;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stages.map((s) {
          final count = counts[s.slug] ?? 0;
          final active = selected == s.slug;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () =>
                  onSelectStage(active ? null : s.slug),
              borderRadius: AppRadius.cardBorder,
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(
                    color: active
                        ? AppColors.gold
                        : AppColors.gold.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
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
      ),
    );
  }
}

class _DealList extends StatelessWidget {
  const _DealList({required this.deals, required this.onOpen});

  final List<SbmsDeal> deals;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) return const Text('No deals');
    return Column(
      children: deals
          .map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.briefcase, size: 18),
              title: Text(d.title),
              subtitle: Text(
                '${d.orderCode} · ${d.stageName ?? d.status.label} · ${d.valueDisplay}',
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => onOpen(d.id),
            ),
          )
          .toList(),
    );
  }
}

class _ReservationList extends StatelessWidget {
  const _ReservationList({required this.reservations});

  final List<SbmsReservation> reservations;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) return const Text('No reservations');
    return Column(
      children: reservations.map((r) {
        final urgency = r.isExpiringSoon
            ? ' · EXPIRES SOON'
            : r.isExpired
                ? ' · EXPIRED'
                : '';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            LucideIcons.bookmark,
            size: 18,
            color: r.isExpiringSoon ? Colors.orange : null,
          ),
          title: Text('${r.reservationCode}$urgency'),
          subtitle: Text(
            '${r.clientName ?? '—'} · ${r.status.label} · ${r.amountDisplay}',
          ),
        );
      }).toList(),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({required this.bookings});

  final List<SbmsBooking> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return const Text('No bookings');
    final fmt = DateFormat('dd MMM · HH:mm');
    return Column(
      children: bookings
          .map(
            (b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.calendar, size: 18),
              title: Text('${b.bookingCode} · ${b.bookingType.label}'),
              subtitle: Text(
                '${b.clientName ?? '—'} · ${fmt.format(b.scheduledAt)} · ${b.location ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuoteList extends StatelessWidget {
  const _QuoteList({required this.quotes});

  final List<SbmsQuote> quotes;

  @override
  Widget build(BuildContext context) {
    if (quotes.isEmpty) return const Text('No quotes');
    return Column(
      children: quotes
          .map(
            (q) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.fileText, size: 18),
              title: Text('${q.quoteCode} · ${q.totalDisplay}'),
              subtitle: Text(
                '${q.clientName ?? '—'} · ${q.status.label} · estimate',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DealRoomPanel extends StatelessWidget {
  const _DealRoomPanel({
    required this.deal,
    required this.deals,
    required this.negotiations,
    required this.quotes,
    required this.contracts,
    required this.onSelectDeal,
    required this.service,
  });

  final SbmsDeal deal;
  final List<SbmsDeal> deals;
  final List<SbmsNegotiation> negotiations;
  final List<SbmsQuote> quotes;
  final List<SbmsContract> contracts;
  final ValueChanged<String> onSelectDeal;
  final SbmsService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: deals
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(d.orderCode),
                      selected: d.id == deal.id,
                      onSelected: (_) => onSelectDeal(d.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          deal.title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          '${deal.clientName ?? '—'} · ${deal.stageName ?? deal.status.label} · ${deal.valueDisplay}',
        ),
        const SizedBox(height: 8),
        Text(
          service.generateDealSummary(deal),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Negotiation timeline',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ...negotiations.map(
          (n) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(n.eventType),
            subtitle: Text(
              '${n.actorLabel ?? ''} · ${n.body ?? ''} · ${n.amountDisplay}',
            ),
          ),
        ),
        if (quotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Quotes', style: Theme.of(context).textTheme.titleSmall),
          ...quotes.map(
            (q) => Text('• ${q.quoteCode} ${q.totalDisplay} (${q.status.label})'),
          ),
        ],
        if (contracts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Contracts', style: Theme.of(context).textTheme.titleSmall),
          ...contracts.map(
            (c) =>
                Text('• ${c.contractCode} ${c.valueDisplay} (${c.status.label})'),
          ),
        ],
      ],
    );
  }
}

class _CommissionList extends StatelessWidget {
  const _CommissionList({required this.commissions});

  final List<SbmsCommission> commissions;

  @override
  Widget build(BuildContext context) {
    if (commissions.isEmpty) return const Text('No commissions');
    return Column(
      children: commissions
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.percent, size: 18),
              title: Text('${c.commissionCode} · ${c.amountDisplay}'),
              subtitle: Text(
                '${c.agentName ?? '—'} · ${c.status.label} · ${c.commissionPercent}%',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InstallmentList extends StatelessWidget {
  const _InstallmentList({required this.installments});

  final List<SbmsInstallment> installments;

  @override
  Widget build(BuildContext context) {
    if (installments.isEmpty) return const Text('No installments');
    final fmt = DateFormat('dd MMM yyyy');
    return Column(
      children: installments
          .map(
            (i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                LucideIcons.wallet,
                size: 18,
                color: i.isDueSoon ? Colors.orange : null,
              ),
              title: Text('#${i.installmentNo} · ${i.amountDisplay}'),
              subtitle: Text(
                '${fmt.format(i.dueDate)} · ${i.status.label}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HandoverList extends StatelessWidget {
  const _HandoverList({required this.handovers});

  final List<SbmsHandover> handovers;

  @override
  Widget build(BuildContext context) {
    if (handovers.isEmpty) return const Text('No handovers');
    return Column(
      children: handovers.map((h) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.key, size: 18),
              title: Text(h.clientName ?? 'Handover'),
              subtitle: Text(
                '${h.status} · ${h.doneCount}/${h.checklist.length} checklist',
              ),
            ),
            ...h.checklist.map(
              (c) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      c.done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                      size: 14,
                      color: c.done ? Colors.green : null,
                    ),
                    const SizedBox(width: 6),
                    Text(c.item),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.requests});

  final List<SbmsDiscountRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const Text('No pending approvals');
    return Column(
      children: requests
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.shieldCheck, size: 18),
              title: Text(
                '${r.discountName ?? 'Discount'} · ${r.requestedValue}%',
              ),
              subtitle: Text(
                '${r.requesterLabel ?? '—'} · ${r.status.label} · ${r.justification ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});

  final List<SbmsActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No activity');
    return Column(
      children: activities
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.activity, size: 16),
              title: Text(a.title),
              subtitle: Text(
                '${a.actorLabel ?? ''} · ${a.description ?? ''}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts});

  final List<SbmsAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const Text('No alerts');
    return Column(
      children: alerts
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                LucideIcons.bell,
                size: 16,
                color: a.severity == 'high' ? Colors.orange : null,
              ),
              title: Text(a.title),
              subtitle: Text(a.body ?? ''),
            ),
          )
          .toList(),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.rows});

  final List<SbmsLeaderboardRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('No leaderboard snapshot');
    return Column(
      children: rows
          .map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                child: Text('${r.rank}'),
              ),
              title: Text(r.agentName),
              subtitle: Text(
                '${r.dealsWon} deals · ${r.revenueDisplay} · ${r.periodLabel}',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AiAssistantPanel extends StatelessWidget {
  const _AiAssistantPanel({
    required this.insights,
    required this.deals,
    required this.service,
  });

  final List<SbmsAiInsight> insights;
  final List<SbmsDeal> deals;
  final SbmsService service;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...insights.map(
          (i) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.sparkles, size: 16),
            title: Text(i.title),
            subtitle: Text(i.body),
          ),
        ),
        if (deals.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Deal summary stub',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(service.generateDealSummary(deals.first)),
        ],
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
