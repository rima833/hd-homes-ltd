import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_application_wizard.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Status filters shown as chips, in journey order.
const _statusFilters = <String?>[
  null,
  'draft',
  'submitted',
  'under_review',
  'documents_required',
  'approved',
  'payment_pending',
  'payment_active',
  'contract_pending',
  'completed',
  'rejected',
  'cancelled',
];

class ClientApplicationsPage extends ConsumerStatefulWidget {
  const ClientApplicationsPage({super.key});

  @override
  ConsumerState<ClientApplicationsPage> createState() =>
      _ClientApplicationsPageState();
}

class _ClientApplicationsPageState
    extends ConsumerState<ClientApplicationsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _statusFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  List<ClientPropertyApplication> _filter(
    List<ClientPropertyApplication> items,
  ) {
    final q = _query.trim().toLowerCase();
    return items.where((a) {
      if (_statusFilter != null &&
          a.status.toLowerCase() != _statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return (a.propertyTitle?.toLowerCase().contains(q) ?? false) ||
          (a.propertyLocation?.toLowerCase().contains(q) ?? false) ||
          a.shortId.toLowerCase().contains(q) ||
          ClientPropertyApplication.statusLabel(a.status)
              .toLowerCase()
              .contains(q);
    }).toList();
  }

  Future<void> _openWizard({String? resumeApplicationId}) async {
    final id = await showClientApplicationWizard(
      context,
      ref,
      resumeApplicationId: resumeApplicationId,
    );
    ref.invalidate(clientApplicationsProvider);
    if (id != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted for review.')),
      );
      context.go(RoutePaths.clientApplicationDetail(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(clientApplicationsProvider);

    return applicationsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientApplicationsProvider),
      ),
      data: (items) {
        final filtered = _filter(items);
        final counts = <String, int>{};
        for (final a in items) {
          final key = a.status.toLowerCase();
          counts[key] = (counts[key] ?? 0) + 1;
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clientApplicationsProvider);
            ref.invalidate(clientApplicationPropertyOptionsProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: _padding(context),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(onNewApplication: () => _openWizard()),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText:
                              'Search by property, location or reference',
                          prefixIcon: const Icon(LucideIcons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _statusFilters.map((status) {
                            final count = status == null
                                ? items.length
                                : counts[status] ?? 0;
                            final label = status == null
                                ? 'All'
                                : ClientPropertyApplication.statusLabel(status);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  count > 0 ? '$label ($count)' : label,
                                ),
                                selected: _statusFilter == status,
                                onSelected: (_) =>
                                    setState(() => _statusFilter = status),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ClientEmptyState(
                    title: items.isEmpty
                        ? 'No applications yet'
                        : 'No matching applications',
                    message: items.isEmpty
                        ? 'Start an application to reserve a property. Use Buying tools to model payment plans first.'
                        : 'Try a different search term or status filter.',
                    icon: items.isEmpty
                        ? LucideIcons.filePlus2
                        : LucideIcons.searchX,
                    action: items.isEmpty
                        ? Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _openWizard(),
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('New Application'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.charcoal,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(RoutePaths.clientTools),
                                icon: const Icon(
                                  LucideIcons.calculator,
                                  size: 16,
                                ),
                                label: const Text('Buying tools'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.gold,
                                  side: const BorderSide(color: AppColors.gold),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: _padding(context).copyWith(top: 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final a = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ApplicationCard(
                            application: a,
                            onViewDetails: () => context.go(
                              RoutePaths.clientApplicationDetail(a.id),
                            ),
                            onResumeDraft: a.status.toLowerCase() == 'draft'
                                ? () =>
                                    _openWizard(resumeApplicationId: a.id)
                                : null,
                          ),
                        );
                      },
                      childCount: filtered.length,
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

class _Header extends StatelessWidget {
  const _Header({required this.onNewApplication});

  final VoidCallback onNewApplication;

  @override
  Widget build(BuildContext context) {
    final cta = FilledButton.icon(
      onPressed: onNewApplication,
      icon: const Icon(LucideIcons.plus, size: 16),
      label: const Text('New Application'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.charcoal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Applications',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Track and manage your property applications.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.mobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              const SizedBox(height: 16),
              cta,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 16),
            cta,
          ],
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.onViewDetails,
    this.onResumeDraft,
  });

  final ClientPropertyApplication application;
  final VoidCallback onViewDetails;
  final VoidCallback? onResumeDraft;

  @override
  Widget build(BuildContext context) {
    final a = application;
    final stepIndex = a.timelineStepIndex;
    final totalStages = ClientPropertyApplication.timelineStages.length;
    final progress = stepIndex < 0
        ? 0.0
        : ((stepIndex + 1) / totalStages * 100).clamp(0, 100).toDouble();
    final isTerminated = stepIndex == -2;

    return ClientPortalCard(
      onTap: onViewDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.fileText,
                  color: AppColors.gold,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.propertyTitle ?? 'Property application',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (a.propertyLocation?.isNotEmpty ?? false)
                          a.propertyLocation!,
                        a.shortId,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ClientStatusChip(
                status: a.status,
                label: ClientPropertyApplication.statusLabel(a.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _MetaItem(
                icon: LucideIcons.wallet,
                label: 'Payment plan',
                value: a.paymentPlanLabel,
              ),
              _MetaItem(
                icon: LucideIcons.banknote,
                label: 'Offer',
                value: a.amountOffered != null
                    ? a.formattedOffer
                    : a.formattedPrice,
              ),
              if (a.createdAt != null)
                _MetaItem(
                  icon: LucideIcons.calendar,
                  label: 'Started',
                  value: DateFormat.yMMMd().format(a.createdAt!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isTerminated)
            Row(
              children: [
                Icon(
                  a.status.toLowerCase() == 'rejected'
                      ? LucideIcons.xCircle
                      : LucideIcons.ban,
                  size: 14,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  a.status.toLowerCase() == 'rejected'
                      ? 'This application was not approved.'
                      : 'This application was cancelled.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ],
            )
          else
            ClientProgressBar(
              label: stepIndex < 0
                  ? 'Draft — not submitted'
                  : 'Stage ${stepIndex + 1} of $totalStages',
              percent: progress,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (a.updatedAt != null)
                Expanded(
                  child: Text(
                    'Updated ${DateFormat.yMMMd().add_jm().format(a.updatedAt!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.slate500,
                        ),
                  ),
                )
              else
                const Spacer(),
              if (onResumeDraft != null) ...[
                FilledButton.icon(
                  onPressed: onResumeDraft,
                  icon: const Icon(LucideIcons.arrowRight, size: 14),
                  label: const Text('Resume draft'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.charcoal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              TextButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(LucideIcons.chevronRight, size: 14),
                label: const Text('View details'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.slate500),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.slate500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
