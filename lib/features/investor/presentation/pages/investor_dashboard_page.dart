import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Investor command center — metrics from Supabase holdings / distributions /
/// wallets / payment intents; refreshed by the portal realtime hub.
class InvestorDashboardPage extends ConsumerWidget {
  const InvestorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(investorDashboardProvider);
    final conversationsAsync = ref.watch(investorConversationsProvider);
    final constructionAsync = ref.watch(investorConstructionProvider);
    final referralsAsync = ref.watch(investorReferralsProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);

    return dashboardAsync.when(
      loading: () => const InvestorDashboardSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () => ref.invalidate(investorDashboardProvider),
      ),
      data: (snap) {
        if (snap == null) {
          return const InvestorEmptyState(
            title: 'Sign in to view your dashboard',
            message:
                'Your HD Homes investment account will appear here once you are signed in.',
            icon: LucideIcons.layoutDashboard,
          );
        }

        final openMessages = conversationsAsync.valueOrNull
                ?.fold<int>(0, (sum, c) => sum + c.unreadCount) ??
            0;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(investorDashboardProvider);
            ref.invalidate(investorConversationsProvider);
            ref.invalidate(investorConstructionProvider);
            ref.invalidate(investorReferralsProvider);
            ref.invalidate(investorUnreadCountProvider);
            ref.invalidate(investorPaymentsProvider);
          },
          child: _DashboardHome(
            snap: snap,
            openMessages: openMessages,
            construction: constructionAsync.valueOrNull,
            referrals: referralsAsync.valueOrNull,
            connection: connection,
          ),
        );
      },
    );
  }
}

class _DashboardHome extends ConsumerWidget {
  const _DashboardHome({
    required this.snap,
    required this.openMessages,
    required this.connection,
    this.construction,
    this.referrals,
  });

  final InvestorDashboardSnapshot snap;
  final int openMessages;
  final InvestorRealtimeConnection connection;
  final InvestorConstructionBundle? construction;
  final InvestorReferralSummary? referrals;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _heroImageUrl {
    for (final h in snap.holdings) {
      if (h.imageUrl != null && h.imageUrl!.isNotEmpty) return h.imageUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(investorPortalFeatureFlagsProvider);
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final isWide = w >= AppBreakpoints.tablet;
    final investorCode = snap.investor.investorCode ??
        'INV-${snap.investor.id.substring(0, 8).toUpperCase()}';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroBanner(
          greeting: _greeting,
          displayName: snap.displayName,
          investorCode: investorCode,
          portfolioValue: snap.formattedPortfolioValue,
          portfolioStatus: snap.portfolioStatus,
          imageUrl: _heroImageUrl,
          unreadNotifications: snap.unreadNotifications,
          connection: connection,
          welcomeMessage: flags.welcomeMessage,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snap.hasOutstandingPayments &&
                  flags.allowsPath(RoutePaths.investorPayments)) ...[
                _OutstandingBanner(
                  amount: snap.formattedOutstandingPayments,
                ),
                const SizedBox(height: 16),
              ],
              _KpiGrid(snap: snap, isWide: isWide),
              const SizedBox(height: 24),
              _QuickActionsStrip(
                openMessages: openMessages,
                flags: flags,
              ),
              const SizedBox(height: 28),
              if (isWide)
                _WideBody(snap: snap, construction: construction)
              else
                _NarrowBody(snap: snap, construction: construction),
              if (flags.allowsPath(RoutePaths.investorReferrals)) ...[
                const SizedBox(height: 28),
                InvestorReferralsBanner(
                  onTap: () => context.go(RoutePaths.investorReferrals),
                  referralCode: referrals?.referralCode,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.greeting,
    required this.displayName,
    required this.investorCode,
    required this.portfolioValue,
    required this.portfolioStatus,
    required this.connection,
    required this.welcomeMessage,
    this.imageUrl,
    this.unreadNotifications = 0,
  });

  final String greeting;
  final String displayName;
  final String investorCode;
  final String portfolioValue;
  final String portfolioStatus;
  final InvestorRealtimeConnection connection;
  final String welcomeMessage;
  final String? imageUrl;
  final int unreadNotifications;

  String get _statusLabel => switch (portfolioStatus) {
        'empty' => 'No holdings yet',
        'attention' => 'Payment attention',
        'kyc' => 'KYC action needed',
        _ => 'Portfolio active',
      };

  Color get _statusColor => switch (portfolioStatus) {
        'empty' => AppColors.slate400,
        'attention' => AppColors.warning,
        'kyc' => AppColors.error,
        _ => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final height = w >= AppBreakpoints.tablet ? 228.0 : 210.0;
    final showOffline = connection == InvestorRealtimeConnection.error ||
        connection == InvestorRealtimeConnection.offline;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            MediaDeliveryImage(
              url: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: const _HeroFallbackBackground(),
            )
          else
            const _HeroFallbackBackground(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepBlack.withValues(alpha: 0.5),
                  AppColors.deepBlack.withValues(alpha: 0.94),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$greeting, $displayName',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    if (showOffline)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: OfflineUpdatesNote(color: Colors.white70),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  welcomeMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HeroChip(
                      label: 'Investor ID: $investorCode',
                      emphasized: true,
                    ),
                    _HeroChip(label: 'Portfolio $portfolioValue'),
                    _HeroChip(
                      label: _statusLabel,
                      color: _statusColor,
                    ),
                    if (unreadNotifications > 0)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              context.go(RoutePaths.investorNotifications),
                          borderRadius: BorderRadius.circular(20),
                          child: _HeroChip(
                            label: '$unreadNotifications new',
                            icon: LucideIcons.bell,
                            emphasized: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    this.icon,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? (emphasized ? AppColors.gold : AppColors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.gold.withValues(alpha: 0.15)
            : AppColors.darkSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: emphasized ? 0.4 : 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallbackBackground extends StatelessWidget {
  const _HeroFallbackBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1510),
            Color(0xFF0F1115),
            Color(0xFF121820),
          ],
        ),
      ),
    );
  }
}

class _OutstandingBanner extends StatelessWidget {
  const _OutstandingBanner({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return InvestorPortalCard(
      onTap: () => context.go(RoutePaths.investorPayments),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.alertCircle,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding payments',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$amount awaiting verification or settlement',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: AppColors.gold, size: 18),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snap, required this.isWide});

  final InvestorDashboardSnapshot snap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final returnsUp = snap.totalReturns >= 0;
    final cards = [
      InvestorKpiCard(
        label: 'Portfolio value',
        value: snap.formattedPortfolioValue,
        icon: LucideIcons.pieChart,
        subtitle:
            '${snap.holdingsCount} holding${snap.holdingsCount == 1 ? '' : 's'}',
        onTap: () => context.go(RoutePaths.investorPortfolio),
      ),
      InvestorKpiCard(
        label: 'Total invested',
        value: snap.formattedTotalInvested,
        icon: LucideIcons.landmark,
        accent: AppColors.info,
        subtitle: 'Cost basis',
        onTap: () => context.go(RoutePaths.investorPortfolio),
      ),
      InvestorKpiCard(
        label: 'Capital growth',
        value: snap.formattedTotalReturns,
        icon: returnsUp ? LucideIcons.trendingUp : LucideIcons.trendingDown,
        accent: returnsUp ? AppColors.success : AppColors.error,
        subtitle: snap.totalInvested > 0
            ? '${returnsUp ? '+' : ''}${snap.returnsPct.toStringAsFixed(1)}% ROI'
            : 'Book appreciation',
        onTap: () => context.go(RoutePaths.investorAnalytics),
      ),
      InvestorKpiCard(
        label: 'Distributions paid',
        value: snap.formattedTotalDistributions,
        icon: LucideIcons.banknote,
        accent: AppColors.success,
        subtitle: 'All time',
        onTap: () => context.go(RoutePaths.investorPayments),
      ),
      InvestorKpiCard(
        label: 'Pending payouts',
        value: snap.formattedPendingDistributions,
        icon: LucideIcons.clock,
        accent: AppColors.warning,
        subtitle: 'Scheduled',
        onTap: () => context.go(RoutePaths.investorPayments),
      ),
      InvestorKpiCard(
        label: snap.hasOutstandingPayments
            ? 'Outstanding payments'
            : 'Wallet available',
        value: snap.hasOutstandingPayments
            ? snap.formattedOutstandingPayments
            : snap.formattedWalletAvailable,
        icon: snap.hasOutstandingPayments
            ? LucideIcons.alertCircle
            : LucideIcons.wallet,
        accent: snap.hasOutstandingPayments ? AppColors.warning : AppColors.info,
        subtitle: snap.hasOutstandingPayments
            ? 'Awaiting finance'
            : 'Ready to use',
        onTap: () => context.go(RoutePaths.investorPayments),
      ),
    ];

    if (isWide) {
      return Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 3; i < 6; i++) ...[
                if (i > 3) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[row * 2]),
              const SizedBox(width: 12),
              Expanded(child: cards[row * 2 + 1]),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickActionsStrip extends StatelessWidget {
  const _QuickActionsStrip({
    required this.openMessages,
    required this.flags,
  });

  final int openMessages;
  final PortalFeatureFlags flags;

  @override
  Widget build(BuildContext context) {
    final actions = <InvestorQuickActionStripItem>[
      if (flags.allowsPath(RoutePaths.investorPortfolio))
        InvestorQuickActionStripItem(
          label: 'Portfolio',
          icon: LucideIcons.briefcase,
          onTap: () => context.go(RoutePaths.investorPortfolio),
        ),
      if (flags.allowsPath(RoutePaths.investorTools))
        InvestorQuickActionStripItem(
          label: 'Tools',
          icon: LucideIcons.calculator,
          onTap: () => context.go(RoutePaths.investorTools),
        ),
      if (flags.allowsPath(RoutePaths.investorPayments))
        InvestorQuickActionStripItem(
          label: 'Pay now',
          icon: LucideIcons.creditCard,
          onTap: () => context.go(RoutePaths.investorPayments),
        ),
      if (flags.allowsPath(RoutePaths.investorConstruction))
        InvestorQuickActionStripItem(
          label: 'Construction',
          icon: LucideIcons.hardHat,
          onTap: () => context.go(RoutePaths.investorConstruction),
        ),
      if (flags.allowsPath(RoutePaths.investorReports))
        InvestorQuickActionStripItem(
          label: 'Statements',
          icon: LucideIcons.fileBarChart,
          onTap: () => context.go(RoutePaths.investorReports),
        ),
      if (flags.allowsPath(RoutePaths.investorMessages))
        InvestorQuickActionStripItem(
          label: 'Messages',
          icon: LucideIcons.messageSquare,
          badge: openMessages > 0 ? openMessages : null,
          onTap: () => context.go(RoutePaths.investorMessages),
        ),
      if (flags.allowsPath(RoutePaths.investorSupport))
        InvestorQuickActionStripItem(
          label: 'Support',
          icon: LucideIcons.headphones,
          onTap: () => context.go(RoutePaths.investorSupport),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InvestorSectionHeader(title: 'Quick actions'),
        InvestorQuickActionStrip(actions: actions),
      ],
    );
  }
}

class _WideBody extends StatelessWidget {
  const _WideBody({required this.snap, this.construction});

  final InvestorDashboardSnapshot snap;
  final InvestorConstructionBundle? construction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(
            children: [
              if (snap.commitments.isNotEmpty) ...[
                _CommitmentsCard(commitments: snap.commitments),
                const SizedBox(height: 20),
              ],
              _HoldingsCard(holdings: snap.holdings),
              const SizedBox(height: 20),
              _DistributionsCard(distributions: snap.recentDistributions),
              const SizedBox(height: 20),
              _ActivityCard(events: snap.recentActivity),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 9,
          child: Column(
            children: [
              _KycStatusCard(kycStatus: snap.kycStatus),
              const SizedBox(height: 20),
              _PerformanceCard(performance: snap.recentPerformance),
              const SizedBox(height: 20),
              _ConstructionCard(construction: construction),
              const SizedBox(height: 20),
              _WalletCard(wallet: snap.wallet),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody({required this.snap, this.construction});

  final InvestorDashboardSnapshot snap;
  final InvestorConstructionBundle? construction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (snap.commitments.isNotEmpty) ...[
          _CommitmentsCard(commitments: snap.commitments),
          const SizedBox(height: 20),
        ],
        _HoldingsCard(holdings: snap.holdings),
        const SizedBox(height: 20),
        _ConstructionCard(construction: construction),
        const SizedBox(height: 20),
        _KycStatusCard(kycStatus: snap.kycStatus),
        const SizedBox(height: 20),
        _DistributionsCard(distributions: snap.recentDistributions),
        const SizedBox(height: 20),
        _PerformanceCard(performance: snap.recentPerformance),
        const SizedBox(height: 20),
        _WalletCard(wallet: snap.wallet),
        const SizedBox(height: 20),
        _ActivityCard(events: snap.recentActivity),
      ],
    );
  }
}

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({required this.commitments});

  final List<InvestorCommitment> commitments;

  @override
  Widget build(BuildContext context) {
    final open = commitments.where((c) => c.isOpen).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Capital commitments',
          subtitle: open > 0
              ? '$open open · recorded by HD Homes'
              : 'Recorded by HD Homes',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorPayments),
            child: const Text(
              'Payments',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        InvestorPortalCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < commitments.length && i < 5; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  onTap: () => context.go(RoutePaths.investorPayments),
                  title: Text(
                    commitments[i].opportunityTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(commitments[i].status.replaceAll('_', ' ')),
                  trailing: Text(
                    commitments[i].formattedAmount,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HoldingsCard extends StatelessWidget {
  const _HoldingsCard({required this.holdings});

  final List<InvestorHolding> holdings;

  @override
  Widget build(BuildContext context) {
    final visible = holdings.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Your holdings',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorPortfolio),
            child: const Text(
              'View all',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        if (visible.isEmpty)
          InvestorPortalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No investments yet',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Browse opportunities, run the ROI calculator, then book a consultation. '
                  'Holdings appear here in real time once HD Homes assigns them.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go(RoutePaths.investorTools),
                      icon: const Icon(LucideIcons.calculator, size: 16),
                      label: const Text('Investment tools'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.charcoal,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go(RoutePaths.investment),
                      icon: const Icon(LucideIcons.building2, size: 16),
                      label: const Text('Opportunities'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  _HoldingTile(holding: visible[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.holding});

  final InvestorHolding holding;

  @override
  Widget build(BuildContext context) {
    final gain = holding.gainLoss;
    final gainPct = holding.gainLossPct;
    final isUp = gain >= 0;
    final gainColor = isUp ? AppColors.success : AppColors.error;

    return InkWell(
      onTap: () => context.go(RoutePaths.investorHoldingDetail(holding.id)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: holding.imageUrl != null
                    ? MediaDeliveryImage(
                        url: holding.imageUrl!,
                        fit: BoxFit.cover,
                        thumbnail: true,
                        errorWidget: const _HoldingThumbFallback(),
                      )
                    : const _HoldingThumbFallback(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    holding.location ??
                        '${holding.units.toStringAsFixed(holding.units == holding.units.roundToDouble() ? 0 : 1)} units',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  holding.formattedCurrentValue,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isUp ? '+' : ''}${gainPct.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: gainColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.slate500,
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingThumbFallback extends StatelessWidget {
  const _HoldingThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gold.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.building2,
        color: AppColors.gold,
        size: 22,
      ),
    );
  }
}

class _DistributionsCard extends StatelessWidget {
  const _DistributionsCard({required this.distributions});

  final List<InvestorDistribution> distributions;

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'processing':
        return AppColors.info;
      case 'scheduled':
        return AppColors.warning;
      default:
        return AppColors.slate400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = distributions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Recent distributions',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorPayments),
            child: const Text(
              'View all',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        if (visible.isEmpty)
          const InvestorPortalCard(
            child: Text(
              'No distributions yet. When payouts are scheduled or paid, they will show here live.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _statusColor(visible[i].status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.banknote,
                            size: 16,
                            color: _statusColor(visible[i].status),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visible[i]
                                    .distributionType
                                    .replaceAll('_', ' ')
                                    .split(' ')
                                    .map(
                                      (w) => w.isEmpty
                                          ? w
                                          : '${w[0].toUpperCase()}${w.substring(1)}',
                                    )
                                    .join(' '),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                visible[i].status.toUpperCase() +
                                    (visible[i].scheduledAt != null
                                        ? ' · ${DateFormat.yMMMd().format(visible[i].scheduledAt!)}'
                                        : visible[i].paidAt != null
                                            ? ' · ${DateFormat.yMMMd().format(visible[i].paidAt!)}'
                                            : ''),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.slate400),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          visible[i].formattedAmount,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.events});

  final List<InvestorActivity> events;

  IconData _iconForType(String type) {
    switch (type) {
      case 'distribution':
        return LucideIcons.banknote;
      case 'document':
        return LucideIcons.fileText;
      case 'performance':
        return LucideIcons.trendingUp;
      case 'construction':
        return LucideIcons.hardHat;
      case 'payment':
        return LucideIcons.creditCard;
      default:
        return LucideIcons.activity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = events.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InvestorSectionHeader(title: 'Recent activity'),
        if (visible.isEmpty)
          const InvestorPortalCard(
            child: Text(
              'No recent activity yet. Portfolio updates and payouts will stream here.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          InvestorPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.neutral700.withValues(alpha: 0.4),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _iconForType(visible[i].eventType),
                            size: 16,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visible[i].title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (visible[i].description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  visible[i].description!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.slate400),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.yMMMd()
                                    .add_jm()
                                    .format(visible[i].occurredAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _KycStatusCard extends StatelessWidget {
  const _KycStatusCard({required this.kycStatus});

  final String kycStatus;

  double get _percent {
    switch (kycStatus) {
      case 'approved':
      case 'verified':
        return 100;
      case 'submitted':
      case 'in_review':
      case 'under_review':
        return 65;
      case 'rejected':
      case 'expired':
        return 35;
      default:
        return 20;
    }
  }

  String get _label {
    switch (kycStatus) {
      case 'approved':
      case 'verified':
        return 'Verified';
      case 'submitted':
      case 'in_review':
      case 'under_review':
        return 'Under review';
      case 'rejected':
        return 'Action needed';
      case 'expired':
        return 'Expired';
      default:
        return 'Pending verification';
    }
  }

  Color get _accent {
    switch (kycStatus) {
      case 'approved':
      case 'verified':
        return AppColors.success;
      case 'rejected':
      case 'expired':
        return AppColors.error;
      case 'submitted':
      case 'in_review':
      case 'under_review':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InvestorSectionHeader(title: 'KYC status'),
        InvestorPortalCard(
          onTap: () => context.go(RoutePaths.investorSettings),
          child: Row(
            children: [
              InvestorCircularGauge(percent: _percent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep your profile and documents current for faster payouts.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                    const SizedBox(height: 10),
                    InvestorProgressBar(
                      label: '',
                      percent: _percent,
                      color: _accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.performance});

  final List<InvestorPerformance> performance;

  @override
  Widget build(BuildContext context) {
    final values = performance.map((p) => p.nav).toList();
    final labels = performance
        .map(
          (p) =>
              p.asOfDate != null ? DateFormat.MMM().format(p.asOfDate!) : '—',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Portfolio NAV',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorAnalytics),
            child: const Text(
              'Analytics',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        if (values.isEmpty)
          const InvestorPortalCard(
            child: Text(
              'Performance history will appear once valuations are published.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          InvestorPortalCard(
            onTap: () => context.go(RoutePaths.investorAnalytics),
            child: InvestorSimpleBarChart(values: values, labels: labels),
          ),
      ],
    );
  }
}

class _ConstructionCard extends StatelessWidget {
  const _ConstructionCard({this.construction});

  final InvestorConstructionBundle? construction;

  @override
  Widget build(BuildContext context) {
    final hasData = construction != null &&
        (construction!.updates.isNotEmpty ||
            construction!.milestones.isNotEmpty ||
            construction!.overallPercent > 0);
    final percent = construction?.overallPercent ?? 0;
    final latest = construction?.updates.isNotEmpty == true
        ? construction!.updates.first
        : null;
    final milestonesDone = construction?.milestones
            .where((m) =>
                m.status == 'completed' ||
                m.status == 'done' ||
                m.completedAt != null)
            .length ??
        0;
    final milestonesTotal = construction?.milestones.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Construction progress',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorConstruction),
            child: const Text(
              'View site',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        InvestorPortalCard(
          onTap: () => context.go(RoutePaths.investorConstruction),
          child: !hasData
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No construction updates yet',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Site progress for your holdings will appear here when published by the construction team.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.hardHat,
                            color: AppColors.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latest?.title ?? 'Site updates',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                milestonesTotal > 0
                                    ? '$milestonesDone of $milestonesTotal milestones complete'
                                    : 'Construction updates for your holdings',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.slate400),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(0)}%',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InvestorProgressBar(
                      label: 'Overall progress',
                      percent: percent,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({this.wallet});

  final InvestorWallet? wallet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InvestorSectionHeader(
          title: 'Wallet',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.investorPayments),
            child: const Text(
              'Manage',
              style: TextStyle(color: AppColors.gold),
            ),
          ),
        ),
        InvestorPortalCard(
          onTap: () => context.go(RoutePaths.investorPayments),
          child: Column(
            children: [
              _WalletRow(
                label: 'Available',
                value: wallet?.formattedAvailable ?? '₦0',
                accent: AppColors.success,
              ),
              const SizedBox(height: 12),
              _WalletRow(
                label: 'Pending',
                value: wallet != null
                    ? NumberFormat.currency(symbol: '₦', decimalDigits: 0)
                        .format(wallet!.pendingBalance)
                    : '₦0',
                accent: AppColors.warning,
              ),
              const SizedBox(height: 12),
              _WalletRow(
                label: 'Total',
                value: wallet?.formattedTotal ?? '₦0',
                accent: AppColors.gold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.slate400,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
