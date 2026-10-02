import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientReferralsPage extends ConsumerWidget {
  const ClientReferralsPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Referral code copied')));
    }
  }

  Future<void> _shareWhatsApp(String code) async {
    final text = Uri.encodeComponent(
      'Join HD Homes with my referral code: $code — ${SeoConfig.siteUrl}',
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
        'subject': 'HD Homes Referral',
        'body': 'Use my referral code $code when you purchase with HD Homes.',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralsAsync = ref.watch(clientReferralsProvider);
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return referralsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientReferralsProvider),
      ),
      data: (summary) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientReferralsProvider),
          child: ListView(
            padding: _padding(context),
            children: [
              Text(
                'Referrals',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              ClientPortalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your referral code',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            summary.referralCode,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          onPressed: () =>
                              _copyCode(context, summary.referralCode),
                          icon: const Icon(LucideIcons.copy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Share.share(
                            'Join HD Homes with code ${summary.referralCode}',
                          ),
                          icon: const Icon(LucideIcons.share2, size: 16),
                          label: const Text('Share'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _shareWhatsApp(summary.referralCode),
                          icon: const Icon(LucideIcons.messageCircle, size: 16),
                          label: const Text('WhatsApp'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _shareEmail(summary.referralCode),
                          icon: const Icon(LucideIcons.mail, size: 16),
                          label: const Text('Email'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClientKpiCard(
                      label: 'Pending earnings',
                      value: fmt.format(summary.pendingEarnings),
                      icon: LucideIcons.clock,
                      accent: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClientKpiCard(
                      label: 'Paid earnings',
                      value: fmt.format(summary.paidEarnings),
                      icon: LucideIcons.wallet,
                      accent: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ClientSectionHeader(title: 'Commission history'),
              if (summary.commissions.isEmpty)
                ClientPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No commissions yet',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Share your code above. Successful referrals appear here when finance posts commissions.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...summary.commissions.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClientPortalCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          LucideIcons.gift,
                          color: AppColors.gold,
                        ),
                        title: Text(fmt.format(c.amount)),
                        subtitle: Text(
                          [
                            if (c.referralCode != null) c.referralCode,
                            if (c.paidAt != null)
                              'Paid ${DateFormat.yMMMd().format(c.paidAt!)}',
                          ].whereType<String>().join(' · '),
                        ),
                        trailing: Chip(
                          label: Text(c.status),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
