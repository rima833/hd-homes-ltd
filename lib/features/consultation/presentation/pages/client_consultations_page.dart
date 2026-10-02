import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/customer_consultation_models.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/customer_consultation_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_public_flow_sheets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientConsultationsPage extends ConsumerWidget {
  const ClientConsultationsPage({super.key});

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  Future<void> _openBooking(BuildContext context, WidgetRef ref) async {
    await showClientConsultationBookingSheet(context, ref);
    ref.invalidate(clientConsultationsProvider);
  }

  Future<void> _cancel(WidgetRef ref, String id) async {
    await ref.read(customerConsultationServiceProvider).cancelBooking(id);
    ref.invalidate(clientConsultationsProvider);
  }

  Future<void> _openMeeting(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(clientConsultationsProvider);

    return bookingsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientConsultationsProvider),
      ),
      data: (bookings) {
        final upcoming = bookings.where((b) => b.isUpcoming).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
        final past = bookings.where((b) => !b.isUpcoming).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(clientConsultationsProvider),
          child: ListView(
            padding: _padding(context),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Consultations',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Same multi-step booking flow as the public site.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openBooking(context, ref),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Book'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const ClientSectionHeader(title: 'Upcoming'),
              if (upcoming.isEmpty)
                ClientPortalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No upcoming consultations',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Book time with an HD Homes advisor to discuss buying options.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate400,
                            ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _openBooking(context, ref),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Book consultation'),
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
                  (b) => _BookingTile(
                    booking: b,
                    onCancel: b.canCancel ? () => _cancel(ref, b.id) : null,
                    onJoin: b.meetingUrl != null
                        ? () => _openMeeting(b.meetingUrl)
                        : null,
                  ),
                ),
              const SizedBox(height: 24),
              const ClientSectionHeader(title: 'Past'),
              if (past.isEmpty)
                const ClientPortalCard(child: Text('No past consultations.'))
              else
                ...past.map((b) => _BookingTile(booking: b)),
            ],
          ),
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({
    required this.booking,
    this.onCancel,
    this.onJoin,
  });

  final CustomerConsultationBooking booking;
  final VoidCallback? onCancel;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClientPortalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.video, color: AppColors.gold),
              title: Text(booking.reference),
              subtitle: Text(
                [
                  if (booking.departmentName != null) booking.departmentName,
                  DateFormat.yMMMd().add_jm().format(booking.scheduledAt),
                  booking.status,
                ].whereType<String>().join(' · '),
              ),
            ),
            if (booking.advisorName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Advisor: ${booking.advisorName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onJoin != null || onCancel != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (onJoin != null)
                    OutlinedButton.icon(
                      onPressed: onJoin,
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                      label: const Text('Join meeting'),
                    ),
                  if (onCancel != null)
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
