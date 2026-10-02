import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_public_flow_sheets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientInspectionsPage extends ConsumerWidget {
  const ClientInspectionsPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _openBooking(
    BuildContext context,
    WidgetRef ref, {
    String? propertyId,
  }) async {
    await showClientInspectionBookingSheet(
      context,
      ref,
      initialPropertyId: propertyId,
    );
    ref.invalidate(clientInspectionsProvider);
  }

  Future<void> _cancelInspection(WidgetRef ref, String id) async {
    await ref.read(clientServiceProvider).cancelInspection(id);
    ref.invalidate(clientInspectionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(clientInspectionsProvider);

    return inspectionsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientInspectionsProvider),
      ),
      data: (inspections) {
        final now = DateTime.now();
        final upcoming = inspections
            .where(
              (i) =>
                  (i.status == 'scheduled' || i.status == 'confirmed') &&
                  i.scheduledAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final past = inspections
            .where(
              (i) =>
                  !(i.status == 'scheduled' || i.status == 'confirmed') ||
                  !i.scheduledAt.isAfter(now),
            )
            .toList();

        final nextDate = upcoming.isNotEmpty ? upcoming.first.scheduledAt : null;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openBooking(context, ref),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Book inspection'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(clientInspectionsProvider),
            child: ListView(
              padding: _padding(context),
              children: [
                Text(
                  'Inspections',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Same booking flow as the public site — property, live slots, and confirmation.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate400,
                      ),
                ),
                const SizedBox(height: 16),
                ClientPortalCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.calendarDays,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next inspection',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.slate400),
                            ),
                            Text(
                              nextDate != null
                                  ? DateFormat('EEEE, MMM d').format(nextDate)
                                  : 'None scheduled',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const ClientSectionHeader(title: 'Upcoming'),
                if (upcoming.isEmpty)
                  ClientPortalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No upcoming inspections',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Book a site visit for a listing or an allocated property.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate400,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openBooking(context, ref),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Book inspection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...upcoming.map(
                    (i) => _InspectionTile(
                      inspection: i,
                      onCancel: () => _cancelInspection(ref, i.id),
                    ),
                  ),
                const SizedBox(height: 24),
                const ClientSectionHeader(title: 'Past'),
                if (past.isEmpty)
                  const ClientPortalCard(child: Text('No past inspections.'))
                else
                  ...past.map((i) => _InspectionTile(inspection: i)),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({required this.inspection, this.onCancel});

  final ClientInspection inspection;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final canCancel = (inspection.status == 'scheduled' ||
            inspection.status == 'confirmed') &&
        onCancel != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClientPortalCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            inspection.status == 'completed'
                ? LucideIcons.checkCircle2
                : inspection.status == 'cancelled'
                    ? LucideIcons.xCircle
                    : LucideIcons.clipboardCheck,
            color: AppColors.gold,
          ),
          title: Text(inspection.propertyTitle ?? 'Property inspection'),
          subtitle: Text(
            '${DateFormat.yMMMd().add_jm().format(inspection.scheduledAt)} · ${inspection.status}',
          ),
          trailing: canCancel
              ? TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                )
              : Chip(
                  label: Text(inspection.status),
                  visualDensity: VisualDensity.compact,
                ),
        ),
      ),
    );
  }
}
