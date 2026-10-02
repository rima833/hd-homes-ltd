import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientPropertyDetailPage extends ConsumerWidget {
  const ClientPropertyDetailPage({super.key, required this.property});

  final ClientProperty property;

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(clientPaymentsProvider);
    final timelineAsync = ref.watch(clientDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(property.title)),
      body: paymentsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const ClientPageSkeleton(showKpis: false, rows: 6),
        error: (e, _) => ClientErrorView(message: e),
        data: (bundle) {
          final propertyPayments = bundle.payments
              .where(
                (p) =>
                    p.propertyId == property.propertyId ||
                    p.propertyTitle == property.title,
              )
              .toList();
          final timeline = timelineAsync.valueOrNull?.recentTimeline ?? [];

          return ListView(
            padding: _padding(context),
            children: [
              _Gallery(imageUrl: property.imageUrl),
              const SizedBox(height: 20),
              Text(
                property.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (property.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 16, color: AppColors.slate400),
                    const SizedBox(width: 6),
                    Text(property.location!),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                property.formattedPrice,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                property.paymentStyleLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.gold.withValues(alpha: 0.9),
                    ),
              ),
              const SizedBox(height: 20),
              _AllocationStatusBanner(status: property.allocationStatus),
              if (property.celebrationMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClientPortalCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.sparkles,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          property.celebrationMessage,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.white,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ClientPortalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Specifications', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _SpecRow(label: 'Allocation', value: property.allocationStatus),
                    _SpecRow(
                      label: 'Purchase date',
                      value: property.purchaseDate != null
                          ? DateFormat.yMMMd().format(property.purchaseDate!)
                          : '—',
                    ),
                    _SpecRow(label: 'Status', value: property.constructionStatusLabel),
                    _SpecRow(label: 'Payment style', value: property.paymentStyleLabel),
                    _SpecRow(label: 'Currency', value: property.currency),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ClientPortalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ClientProgressBar(
                      label: 'Payment progress',
                      percent: property.paymentProgressPct,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.formattedAmountPaid} paid of ${property.formattedPrice}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ClientProgressBar(
                      label: 'Construction progress',
                      percent: property.constructionProgressPct,
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ClientSectionHeader(title: 'Payment history'),
              if (propertyPayments.isEmpty)
                const ClientPortalCard(
                  child: Text(
                    'No payments recorded for this property yet. Progress updates as verified payments land.',
                  ),
                )
              else
                ...propertyPayments.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClientPortalCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          p.isVerified
                              ? LucideIcons.checkCircle2
                              : LucideIcons.clock,
                          color: p.isVerified
                              ? AppColors.success
                              : AppColors.gold,
                        ),
                        title: Text(p.formattedAmount),
                        subtitle: Text(
                          p.paidAt != null
                              ? DateFormat.yMMMd().format(p.paidAt!)
                              : p.status,
                        ),
                        trailing: Text(
                          p.status,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (property.paymentProgressPct < 100)
                    FilledButton.icon(
                      onPressed: () => context.go(RoutePaths.clientPayments),
                      icon: const Icon(LucideIcons.creditCard, size: 16),
                      label: const Text('Make Payment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.charcoal,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.clientDocuments),
                    icon: const Icon(LucideIcons.fileText, size: 16),
                    label: const Text('Documents'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.clientConstruction),
                    icon: const Icon(LucideIcons.hardHat, size: 16),
                    label: const Text('Construction'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClientPortalCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      child: const Icon(LucideIcons.user, color: AppColors.gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Relationship manager',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.slate400,
                                ),
                          ),
                          Text(
                            property.relationshipManagerName ?? 'To be assigned',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.go(RoutePaths.clientMessages),
                      icon: const Icon(LucideIcons.messageCircle),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ClientSectionHeader(title: 'Timeline'),
              if (timeline.isEmpty)
                const ClientPortalCard(child: Text('No timeline events yet.'))
              else
                ...timeline.take(4).map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClientPortalCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.title),
                            subtitle: Text(
                              DateFormat.yMMMd().add_jm().format(e.occurredAt),
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardBorder,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? MediaDeliveryImage(
                url: imageUrl!,
                fit: BoxFit.cover,
                placeholder: Container(color: AppColors.slate700),
                errorWidget: _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: AppColors.slate700,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.image, size: 40, color: AppColors.slate400),
            const SizedBox(height: 8),
            Text(
              'Gallery',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
        ),
      );
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate400,
              )),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Route loader for `/client/properties/:propertyId`.
class ClientPropertyDetailLoader extends ConsumerWidget {
  const ClientPropertyDetailLoader({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(clientPropertyDetailProvider(propertyId));
    return propertyAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(
        body: ClientPageSkeleton(showKpis: false, rows: 6),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Property')),
        body: ClientErrorView(
          message: e,
          onRetry: () => ref.invalidate(clientPropertyDetailProvider(propertyId)),
        ),
      ),
      data: (property) {
        if (property == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Property')),
            body: const ClientEmptyState(
              title: 'Property not found',
              message: 'This property is not linked to your account.',
              icon: LucideIcons.building2,
            ),
          );
        }
        return ClientPropertyDetailPage(property: property);
      },
    );
  }
}

class _AllocationStatusBanner extends StatelessWidget {
  const _AllocationStatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = [
      'allocated',
      'documentation',
      'handover_pending',
      'handed_over',
    ];
    final labels = {
      'allocated': 'Allocated',
      'documentation': 'Documentation',
      'handover_pending': 'Handover soon',
      'handed_over': 'Welcome home',
      'pending': 'Pending',
      'reserved': 'Reserved',
      'in_progress': 'In progress',
      'completed': 'Completed',
    };
    final currentIdx = steps.indexOf(status.toLowerCase());

    return ClientPortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journey', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIdx = i ~/ 2;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: stepIdx <= currentIdx
                        ? AppColors.gold
                        : AppColors.neutral700,
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final isActive = stepIdx <= currentIdx;
              final isCurrent = stepIdx == currentIdx;
              return Column(
                children: [
                  Container(
                    width: isCurrent ? 28 : 20,
                    height: isCurrent ? 28 : 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isActive ? AppColors.gold : AppColors.neutral700,
                    ),
                    child: isActive
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.charcoal,
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[steps[stepIdx]] ?? steps[stepIdx],
                    style: TextStyle(
                      fontSize: 9,
                      color: isActive ? AppColors.white : AppColors.slate500,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
