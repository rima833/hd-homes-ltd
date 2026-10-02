import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_payment_intent_dialog.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientDashboardPage extends ConsumerWidget {
  const ClientDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(clientDashboardProvider);
    final conversationsAsync = ref.watch(clientConversationsProvider);

    return dashboardAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientDashboardSkeleton(),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientDashboardProvider),
      ),
      data: (snap) {
        if (snap == null) {
          return const ClientEmptyState(
            title: 'Sign in to view your dashboard',
            icon: LucideIcons.layoutDashboard,
          );
        }

        final openMessages = conversationsAsync.valueOrNull
                ?.where((c) => c.status == 'open')
                .length ??
            0;

        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(clientDashboardProvider);
            ref.invalidate(clientConversationsProvider);
          },
          child: _DashboardHome(
            snap: snap,
            openMessages: openMessages,
            connection: ref.watch(clientRealtimeConnectionProvider),
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
  });

  final ClientDashboardSnapshot snap;
  final int openMessages;
  final ClientRealtimeConnection connection;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _heroImageUrl {
    for (final p in snap.properties) {
      if (p.imageUrl != null && p.imageUrl!.isNotEmpty) return p.imageUrl;
    }
    return null;
  }

  double _paymentProgressFor(ClientInstallment installment) {
    final title = installment.propertyTitle;
    if (title == null) return 0;
    for (final p in snap.properties) {
      if (p.title == title) return p.paymentProgressPct;
    }
    return snap.properties.isNotEmpty ? snap.properties.first.paymentProgressPct : 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(clientPortalFeatureFlagsProvider);
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final isWide = w >= AppBreakpoints.tablet;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroBanner(
          greeting: _greeting,
          displayName: snap.displayName,
          clientCode: snap.client.clientCode ??
              'CLT-${snap.client.id.substring(0, 8).toUpperCase()}',
          imageUrl: _heroImageUrl,
          connection: connection,
          welcomeMessage: flags.welcomeMessage,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KpiRow(snap: snap, isWide: isWide),
              const SizedBox(height: 24),
              _QuickActionsStrip(
                openMessages: openMessages,
                flags: flags,
              ),
              const SizedBox(height: 28),
              if (isWide)
                _WideBody(
                  snap: snap,
                  paymentProgressFor: _paymentProgressFor,
                )
              else
                _NarrowBody(
                  snap: snap,
                  paymentProgressFor: _paymentProgressFor,
                ),
              if (flags.allowsPath(RoutePaths.clientReferrals)) ...[
                const SizedBox(height: 28),
                ClientReferralsBanner(
                  onTap: () => context.go(RoutePaths.clientReferrals),
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
    required this.clientCode,
    required this.connection,
    required this.welcomeMessage,
    this.imageUrl,
  });

  final String greeting;
  final String displayName;
  final String clientCode;
  final ClientRealtimeConnection connection;
  final String welcomeMessage;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= AppBreakpoints.tablet ? 24.0 : 16.0;
    final height = w >= AppBreakpoints.tablet ? 220.0 : 180.0;
    final showOffline = connection == ClientRealtimeConnection.error ||
        connection == ClientRealtimeConnection.offline;

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
                  AppColors.deepBlack.withValues(alpha: 0.55),
                  AppColors.deepBlack.withValues(alpha: 0.92),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Client ID: $clientCode',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
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
          ],
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.snap, required this.isWide});

  final ClientDashboardSnapshot snap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ClientKpiCard(
        label: 'Properties',
        value: '${snap.propertiesCount}',
        icon: LucideIcons.building2,
        subtitle: 'Active',
        onTap: () => context.go(RoutePaths.clientProperties),
      ),
      ClientKpiCard(
        label: 'Outstanding Payment',
        value: snap.formattedOutstanding,
        icon: LucideIcons.wallet,
        accent: AppColors.warning,
        subtitle: 'Due',
        onTap: () => context.go(RoutePaths.clientPayments),
      ),
      ClientKpiCard(
        label: 'Total Paid',
        value: snap.formattedTotalPaid,
        icon: LucideIcons.checkCircle2,
        accent: AppColors.success,
        subtitle: 'All time',
        onTap: () => context.go(RoutePaths.clientPayments),
      ),
      ClientKpiCard(
        label: 'Inspections',
        value: '${snap.upcomingInspections}',
        icon: LucideIcons.clipboardCheck,
        subtitle: 'Upcoming',
        onTap: () => context.go(RoutePaths.clientInspections),
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == cards.last ? 0 : 12),
                  child: c,
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
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
    final actions = <ClientQuickActionStripItem>[
      if (flags.allowsPath(RoutePaths.clientApplications))
        ClientQuickActionStripItem(
          label: 'Apply',
          icon: LucideIcons.filePlus2,
          onTap: () => context.go(RoutePaths.clientApplications),
        ),
      if (flags.allowsPath(RoutePaths.clientTools))
        ClientQuickActionStripItem(
          label: 'Tools',
          icon: LucideIcons.calculator,
          onTap: () => context.go(RoutePaths.clientTools),
        ),
      if (flags.allowsPath(RoutePaths.clientPayments))
        ClientQuickActionStripItem(
          label: 'Pay',
          icon: LucideIcons.creditCard,
          onTap: () => context.go(RoutePaths.clientPayments),
        ),
      if (flags.allowsPath(RoutePaths.clientDocuments))
        ClientQuickActionStripItem(
          label: 'Documents',
          icon: LucideIcons.fileText,
          onTap: () => context.go(RoutePaths.clientDocuments),
        ),
      if (flags.allowsPath(RoutePaths.clientInspections))
        ClientQuickActionStripItem(
          label: 'Inspect',
          icon: LucideIcons.clipboardCheck,
          onTap: () => context.go(RoutePaths.clientInspections),
        ),
      if (flags.allowsPath(RoutePaths.clientMessages))
        ClientQuickActionStripItem(
          label: 'Messages',
          icon: LucideIcons.messageSquare,
          badge: openMessages > 0 ? openMessages : null,
          onTap: () => context.go(RoutePaths.clientMessages),
        ),
      if (flags.allowsPath(RoutePaths.clientSupport))
        ClientQuickActionStripItem(
          label: 'Support',
          icon: LucideIcons.headphones,
          onTap: () => context.go(RoutePaths.clientSupport),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClientSectionHeader(title: 'Quick actions'),
        ClientQuickActionStrip(actions: actions),
      ],
    );
  }
}

class _WideBody extends StatelessWidget {
  const _WideBody({
    required this.snap,
    required this.paymentProgressFor,
  });

  final ClientDashboardSnapshot snap;
  final double Function(ClientInstallment) paymentProgressFor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(
            children: [
              _InstallmentsCard(
                installments: snap.upcomingInstallments,
                paymentProgressFor: paymentProgressFor,
              ),
              const SizedBox(height: 20),
              _ActivityCard(events: snap.recentTimeline),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 9,
          child: Column(
            children: [
              _ProfileCompletionCard(percent: snap.accountCompletionPct),
              const SizedBox(height: 20),
              _ConstructionCard(properties: snap.constructionProgress),
              const SizedBox(height: 20),
              _DocumentsCard(documents: snap.recentDocuments),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody({
    required this.snap,
    required this.paymentProgressFor,
  });

  final ClientDashboardSnapshot snap;
  final double Function(ClientInstallment) paymentProgressFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InstallmentsCard(
          installments: snap.upcomingInstallments,
          paymentProgressFor: paymentProgressFor,
        ),
        const SizedBox(height: 20),
        _ProfileCompletionCard(percent: snap.accountCompletionPct),
        const SizedBox(height: 20),
        _ConstructionCard(properties: snap.constructionProgress),
        const SizedBox(height: 20),
        _DocumentsCard(documents: snap.recentDocuments),
        const SizedBox(height: 20),
        _ActivityCard(events: snap.recentTimeline),
      ],
    );
  }
}

class _InstallmentsCard extends ConsumerWidget {
  const _InstallmentsCard({
    required this.installments,
    required this.paymentProgressFor,
  });

  final List<ClientInstallment> installments;
  final double Function(ClientInstallment) paymentProgressFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Upcoming Installments',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.clientPayments),
            child: const Text('View all', style: TextStyle(color: AppColors.gold)),
          ),
        ),
        if (installments.isEmpty)
          const ClientPortalCard(
            child: Text(
              'No upcoming installments. When finance schedules payments, they will appear here.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          ClientPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: installments.asMap().entries.map((entry) {
                final i = entry.key;
                final inst = entry.value;
                final isOverdue = inst.dueDate.isBefore(DateTime.now());
                final progress = paymentProgressFor(inst);

                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: AppColors.neutral700.withValues(alpha: 0.4),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isOverdue
                                          ? AppColors.error
                                          : AppColors.gold)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  LucideIcons.calendar,
                                  size: 16,
                                  color: isOverdue
                                      ? AppColors.error
                                      : AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inst.propertyTitle ?? 'Installment',
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
                                      'Due ${DateFormat.yMMMd().format(inst.dueDate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isOverdue
                                                ? AppColors.error
                                                : AppColors.slate400,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    inst.formattedAmount,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: () =>
                                        showClientPaymentIntentDialog(
                                      context,
                                      ref,
                                      installment: inst,
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.gold,
                                      foregroundColor: AppColors.charcoal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Pay Now'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (progress > 0) ...[
                            const SizedBox(height: 14),
                            ClientProgressBar(
                              label: 'Payment progress',
                              percent: progress,
                              showLabel: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ClientSectionHeader(title: 'Profile completion'),
        ClientPortalCard(
          onTap: () => context.go(RoutePaths.clientSettings),
          child: Row(
            children: [
              ClientCircularGauge(percent: percent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification & details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ClientProgressBar(
                      label: '',
                      percent: percent,
                      showLabel: false,
                      height: 8,
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

class _ConstructionCard extends StatelessWidget {
  const _ConstructionCard({required this.properties});

  final List<ClientProperty> properties;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Construction Progress',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.clientConstruction),
            child: const Text('View updates', style: TextStyle(color: AppColors.gold)),
          ),
        ),
        if (properties.isEmpty)
          const ClientPortalCard(
            child: Text(
              'No construction updates yet. Progress will appear once a property is allocated.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          ...properties.take(2).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClientPortalCard(
                    onTap: () => context.go(RoutePaths.clientConstruction),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.hardHat,
                            color: AppColors.info,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              ClientProgressBar(
                                label: 'Build progress',
                                percent: p.constructionProgressPct,
                                color: AppColors.gold,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({
    required this.documents,
  });

  final List<ClientDocument> documents;

  Future<void> _openDocument(
    BuildContext context,
    WidgetRef ref,
    ClientDocument doc,
  ) async {
    final safeUrl =
        await ref.read(clientServiceProvider).resolveDocumentUrl(doc.fileUrl);
    final uri = Uri.tryParse(safeUrl);
    if (uri == null || !context.mounted) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Recent Documents',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.clientDocuments),
            child: const Text('View all', style: TextStyle(color: AppColors.gold)),
          ),
        ),
        if (documents.isEmpty)
          const ClientPortalCard(
            child: Text(
              'No documents yet. Allocation letters and contracts will show here.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          ClientPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: documents.take(3).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: AppColors.neutral700.withValues(alpha: 0.4),
                      ),
                    InkWell(
                      onTap: () => _openDocument(context, ref, d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.fileText,
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
                                    d.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: AppColors.white),
                                  ),
                                  if (d.documentType != null)
                                    Text(
                                      d.documentType!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate400),
                                    ),
                                ],
                              ),
                            ),
                            if (d.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  DateFormat.yMMMd().format(d.createdAt!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.slate500),
                                ),
                              ),
                            const Icon(
                              LucideIcons.download,
                              size: 16,
                              color: AppColors.gold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.events});

  final List<ClientTimelineEvent> events;

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(d);
  }

  static IconData _iconForType(String type) {
    return switch (type) {
      'payment' => LucideIcons.creditCard,
      'document' => LucideIcons.fileText,
      'inspection' => LucideIcons.clipboardCheck,
      'construction' => LucideIcons.hardHat,
      'milestone' => LucideIcons.flag,
      _ => LucideIcons.activity,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Recent Activity',
          action: TextButton(
            onPressed: () => context.go(RoutePaths.clientApplications),
            child: const Text('View all', style: TextStyle(color: AppColors.gold)),
          ),
        ),
        if (events.isEmpty)
          const ClientPortalCard(
            child: Text(
              'No recent activity yet. Applications, payments, and milestones will show here.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          ClientPortalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: events.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: AppColors.neutral700.withValues(alpha: 0.4),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _iconForType(e.eventType),
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
                                  e.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                if (e.body != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    e.body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.slate400),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(e.occurredAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
