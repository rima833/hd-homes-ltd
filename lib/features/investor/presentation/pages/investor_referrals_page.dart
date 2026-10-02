import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestorReferralsPage extends ConsumerWidget {
  const InvestorReferralsPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral code copied')));
    }
  }

  Future<void> _shareWhatsApp(String code) async {
    final text = Uri.encodeComponent(
      'Invest with HD Homes using my referral code: $code — ${SeoConfig.canonicalFor(RoutePaths.investment)}',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareEmail(String code) async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'HD Homes Investment Referral',
        'body': 'Use my referral code $code when you invest with HD Homes.',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralsAsync = ref.watch(investorReferralsProvider);
    final connection = ref.watch(investorRealtimeConnectionProvider);
    final live = connection == InvestorRealtimeConnection.live;
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final pad = _padding(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return referralsAsync.when(
      loading: () => const InvestorPageSkeleton(),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () => ref.invalidate(investorReferralsProvider),
      ),
      data: (summary) {
        final code = summary.referralCode;
        final hasCode = code.isNotEmpty;
        final rules = summary.programRules;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(investorReferralsProvider);
            await ref.read(investorReferralsProvider.future);
          },
          child: ListView(
            padding: pad,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Referrals',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rules.headline,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LiveChip(live: live, connection: connection),
                ],
              ),
              const SizedBox(height: 20),
              InvestorPortalCard(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
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
                              LucideIcons.gift,
                              color: AppColors.gold,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your referral code',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!hasCode)
                        Text(
                          'Your referral code will appear here once the program is enabled for your account.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.slate400),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                code,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                    ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy',
                              onPressed: () => _copyCode(context, code),
                              icon: const Icon(
                                LucideIcons.copy,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => Share.share(
                                'Invest with HD Homes — referral code: $code\n${SeoConfig.canonicalFor(RoutePaths.investment)}',
                              ),
                              icon: const Icon(LucideIcons.share2, size: 16),
                              label: const Text('Share'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.charcoal,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _shareWhatsApp(code),
                              icon: const Icon(
                                LucideIcons.messageCircle,
                                size: 16,
                              ),
                              label: const Text('WhatsApp'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gold,
                                side: const BorderSide(color: AppColors.gold),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _shareEmail(code),
                              icon: const Icon(LucideIcons.mail, size: 16),
                              label: const Text('Email'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.white,
                                side: BorderSide(
                                  color: AppColors.neutral700.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'Pending earnings',
                        value: fmt.format(summary.pendingEarnings),
                        icon: LucideIcons.clock,
                        accent: AppColors.warning,
                        subtitle: 'Awaiting payout',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'Paid out',
                        value: fmt.format(summary.paidEarnings),
                        icon: LucideIcons.checkCircle2,
                        accent: AppColors.success,
                        subtitle: 'All time',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InvestorKpiCard(
                        label: 'Successful',
                        value: '${summary.successfulReferrals}',
                        icon: LucideIcons.users,
                        accent: AppColors.info,
                        subtitle: 'Funded referrals',
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InvestorKpiCard(
                            label: 'Pending earnings',
                            value: fmt.format(summary.pendingEarnings),
                            icon: LucideIcons.clock,
                            accent: AppColors.warning,
                            subtitle: 'Awaiting payout',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InvestorKpiCard(
                            label: 'Paid out',
                            value: fmt.format(summary.paidEarnings),
                            icon: LucideIcons.checkCircle2,
                            accent: AppColors.success,
                            subtitle: 'All time',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InvestorKpiCard(
                      label: 'Successful referrals',
                      value: '${summary.successfulReferrals}',
                      icon: LucideIcons.users,
                      accent: AppColors.info,
                      subtitle: 'Funded & settled',
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              InvestorSectionHeader(
                title: 'How it works',
                subtitle: rules.rewardLabel,
              ),
              InvestorPortalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < rules.steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rules.steps[i],
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.slate400),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      rules.notes,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              InvestorSectionHeader(
                title: 'Commission history',
                subtitle: summary.commissions.isEmpty
                    ? null
                    : '${summary.commissions.length} record${summary.commissions.length == 1 ? '' : 's'}',
              ),
              if (summary.commissions.isEmpty)
                const InvestorPortalCard(
                  child: Text(
                    'No referral commissions yet. Share your code and earnings will appear here live.',
                    style: TextStyle(color: AppColors.slate400),
                  ),
                )
              else
                InvestorPortalCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < summary.commissions.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: AppColors.neutral700.withValues(alpha: 0.4),
                          ),
                        _CommissionTile(commission: summary.commissions[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _CommissionTile extends StatelessWidget {
  const _CommissionTile({required this.commission});

  final InvestorReferralCommission commission;

  @override
  Widget build(BuildContext context) {
    final isPaid =
        commission.status == 'paid' || commission.status == 'completed';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPaid ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPaid ? LucideIcons.checkCircle2 : LucideIcons.clock,
              color: isPaid ? AppColors.success : AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commission.formattedAmount,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    commission.status.toUpperCase(),
                    if (commission.referralCode != null)
                      commission.referralCode!,
                    if (commission.paidAt != null)
                      DateFormat.yMMMd().format(commission.paidAt!)
                    else if (commission.createdAt != null)
                      DateFormat.yMMMd().format(commission.createdAt!),
                  ].join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live, required this.connection});

  final bool live;
  final InvestorRealtimeConnection connection;

  @override
  Widget build(BuildContext context) {
    if (live || connection == InvestorRealtimeConnection.connecting) {
      return const SizedBox.shrink();
    }
    return const OfflineUpdatesNote();
  }
}
