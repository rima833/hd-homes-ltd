import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
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
import 'package:url_launcher/url_launcher.dart';

const _cancellableStatuses = {'draft', 'submitted'};
const _uploadableStatuses = {'draft', 'documents_required'};

/// Client-facing detail view for a single property application.
class ClientApplicationDetailPage extends ConsumerWidget {
  const ClientApplicationDetailPage({super.key, required this.applicationId});

  final String applicationId;

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.all(w >= AppBreakpoints.tablet ? 24 : 16);
  }

  void _backToList(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(RoutePaths.clientApplications);
  }

  Future<void> _resumeDraft(BuildContext context, WidgetRef ref) async {
    await showClientApplicationWizard(
      context,
      ref,
      resumeApplicationId: applicationId,
    );
    ref.invalidate(clientApplicationsProvider);
    ref.invalidate(clientApplicationDetailProvider(applicationId));
    ref.invalidate(clientApplicationTimelineProvider(applicationId));
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Cancel this application?'),
        content: const Text(
          'The application will be withdrawn and can no longer be reviewed. '
          'You can always start a new one for the same property.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Cancel application'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final record = await ref.read(clientRecordProvider.future);
    if (record == null) return;

    try {
      await ref.read(clientServiceProvider).cancelApplication(
            clientId: record.id,
            applicationId: applicationId,
          );
      ref.invalidate(clientApplicationsProvider);
      ref.invalidate(clientApplicationDetailProvider(applicationId));
      ref.invalidate(clientApplicationTimelineProvider(applicationId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application cancelled.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'Could not cancel. Please try again.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationAsync =
        ref.watch(clientApplicationDetailProvider(applicationId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to applications',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => _backToList(context),
        ),
        title: Text(
          applicationAsync.valueOrNull?.propertyTitle ?? 'Application',
        ),
      ),
      body: applicationAsync.when(
        skipLoadingOnReload: true,
        loading: () => const ClientPageSkeleton(showKpis: false, rows: 6),
        error: (e, _) => ClientErrorView(
          message: e,
          onRetry: () =>
              ref.invalidate(clientApplicationDetailProvider(applicationId)),
        ),
        data: (application) {
          if (application == null) {
            return ClientEmptyState(
              title: 'Application not found',
              message: 'This application is not linked to your account.',
              icon: LucideIcons.fileText,
              action: FilledButton.icon(
                onPressed: () => _backToList(context),
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text('Back to applications'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
            );
          }

          final status = application.status.toLowerCase();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(clientApplicationDetailProvider(applicationId));
              ref.invalidate(clientApplicationDocumentsProvider(applicationId));
              ref.invalidate(clientApplicationTimelineProvider(applicationId));
            },
            child: ListView(
              padding: _padding(context),
              children: [
                _DetailHeader(application: application),
                const SizedBox(height: 20),
                _StageTimeline(application: application),
                const SizedBox(height: 20),
                _SummarySection(application: application),
                const SizedBox(height: 20),
                _DocumentsSection(
                  applicationId: applicationId,
                  propertyId: application.propertyId,
                  canUpload: _uploadableStatuses.contains(status),
                ),
                const SizedBox(height: 20),
                _PaymentsSection(application: application),
                const SizedBox(height: 20),
                _LinkedPropertySection(application: application),
                const SizedBox(height: 20),
                _InspectionsSection(application: application),
                const SizedBox(height: 20),
                _ActivitySection(applicationId: applicationId),
                const SizedBox(height: 24),
                _ActionBar(
                  onResume:
                      status == 'draft' ? () => _resumeDraft(context, ref) : null,
                  onCancel: _cancellableStatuses.contains(status)
                      ? () => _cancel(context, ref)
                      : null,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.application});

  final ClientPropertyApplication application;

  @override
  Widget build(BuildContext context) {
    final a = application;
    return ClientPortalCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.propertyTitle ?? 'Property application',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.hash,
                          size: 13,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          a.shortId,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClientStatusChip(
                status: a.status,
                label: ClientPropertyApplication.statusLabel(a.status),
              ),
            ],
          ),
          if (a.propertyLocation?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  size: 14,
                  color: AppColors.slate400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a.propertyLocation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({required this.application});

  final ClientPropertyApplication application;

  @override
  Widget build(BuildContext context) {
    final stages = ClientPropertyApplication.timelineStages;
    final currentIndex = application.timelineStepIndex;
    final status = application.status.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Application journey',
          subtitle: currentIndex == -1
              ? 'Submit this draft to start the review journey.'
              : currentIndex == -2
                  ? 'This application is closed.'
                  : 'Currently at ${ClientPropertyApplication.statusLabel(status)}.',
        ),
        ClientPortalCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: List.generate(stages.length, (index) {
              final isDone = currentIndex >= 0 && index < currentIndex;
              final isCurrent = index == currentIndex;
              final isLast = index == stages.length - 1;
              final accent = isCurrent
                  ? AppColors.gold
                  : isDone
                      ? AppColors.success
                      : AppColors.neutral700;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: isCurrent ? 26 : 20,
                        height: isCurrent ? 26 : 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent || isDone
                              ? accent
                              : AppColors.neutral800,
                          border: Border.all(color: accent, width: 1.5),
                        ),
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: AppColors.white,
                              )
                            : isCurrent
                                ? const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: AppColors.charcoal,
                                  )
                                : null,
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 30,
                          color: isDone
                              ? AppColors.success
                              : AppColors.neutral800,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: isCurrent ? 3 : 1,
                        bottom: isLast ? 0 : 18,
                      ),
                      child: Text(
                        ClientPropertyApplication.statusLabel(stages[index]),
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isCurrent
                                      ? AppColors.gold
                                      : isDone
                                          ? AppColors.white
                                          : AppColors.slate500,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.application});

  final ClientPropertyApplication application;

  @override
  Widget build(BuildContext context) {
    final a = application;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(title: 'Summary'),
        ClientPortalCard(
          child: Column(
            children: [
              _KeyValueRow(label: 'Payment plan', value: a.paymentPlanLabel),
              _KeyValueRow(
                label: 'Your offer',
                value: a.amountOffered != null ? a.formattedOffer : '—',
              ),
              _KeyValueRow(label: 'Listed price', value: a.formattedPrice),
              if (a.propertyType?.isNotEmpty ?? false)
                _KeyValueRow(
                  label: 'Property type',
                  value: a.propertyType!.replaceAll('-', ' '),
                ),
              _KeyValueRow(
                label: 'Created',
                value: a.createdAt != null
                    ? DateFormat.yMMMd().add_jm().format(a.createdAt!)
                    : '—',
              ),
              _KeyValueRow(
                label: 'Last updated',
                value: a.updatedAt != null
                    ? DateFormat.yMMMd().add_jm().format(a.updatedAt!)
                    : '—',
                isLast: a.notes == null || a.notes!.isEmpty,
              ),
              if (a.notes?.isNotEmpty ?? false)
                _KeyValueRow(
                  label: 'Your notes',
                  value: a.notes!,
                  isLast: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentsSection extends ConsumerStatefulWidget {
  const _DocumentsSection({
    required this.applicationId,
    required this.propertyId,
    required this.canUpload,
  });

  final String applicationId;
  final String propertyId;
  final bool canUpload;

  @override
  ConsumerState<_DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends ConsumerState<_DocumentsSection> {
  bool _uploading = false;

  Future<void> _openDocument(ClientDocument doc) async {
    final safeUrl =
        await ref.read(clientServiceProvider).resolveDocumentUrl(doc.fileUrl);
    final uri = Uri.tryParse(safeUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _upload() async {
    final types =
        await ref.read(applicationRequiredDocumentTypesProvider.future);
    if (!mounted) return;

    final type = types.isEmpty
        ? null
        : await showModalBottomSheet<ApplicationRequiredDocumentType>(
            context: context,
            backgroundColor: AppColors.darkSurface,
            builder: (ctx) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'Which document is this?',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  ...types.map(
                    (t) => ListTile(
                      leading: const Icon(
                        LucideIcons.fileText,
                        color: AppColors.gold,
                      ),
                      title: Text(t.name),
                      subtitle: t.description == null
                          ? null
                          : Text(t.description!),
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                  ),
                ],
              ),
            ),
          );

    if (types.isNotEmpty && type == null) return;
    if (!mounted) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }

    final record = await ref.read(clientRecordProvider.future);
    if (record == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(clientServiceProvider).uploadApplicationDocument(
            clientId: record.id,
            applicationId: widget.applicationId,
            propertyId: widget.propertyId,
            documentType: type?.code ?? 'other',
            fileName: file.name,
            bytes: bytes,
            title: type?.name,
          );
      ref.invalidate(
        clientApplicationDocumentsProvider(widget.applicationId),
      );
      ref.invalidate(clientDocumentsProvider);
      if (!mounted) return;
      setState(() => _uploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'Upload failed. Please try again.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync =
        ref.watch(clientApplicationDocumentsProvider(widget.applicationId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Documents',
          subtitle: 'Files attached to this application.',
          action: widget.canUpload
              ? (_uploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: _upload,
                      icon: const Icon(LucideIcons.upload, size: 14),
                      label: const Text('Upload'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                      ),
                    ))
              : null,
        ),
        docsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ClientPortalCard(
            child: ClientCardSkeleton(),
          ),
          error: (e, _) => ClientPortalCard(
            child: Text(
              userFacingError(e, fallback: 'Could not load documents.'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          data: (docs) {
            if (docs.isEmpty) {
              return ClientPortalCard(
                child: Text(
                  widget.canUpload
                      ? 'No documents attached yet. Upload the files requested '
                          'for your application.'
                      : 'No documents attached to this application.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              );
            }
            return Column(
              children: docs
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClientPortalCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            LucideIcons.fileText,
                            color: AppColors.gold,
                          ),
                          title: Text(d.title),
                          subtitle: Text(
                            [
                              if (d.documentType != null)
                                d.documentType!.replaceAll('_', ' '),
                              d.reviewStatus.replaceAll('_', ' '),
                              if (d.createdAt != null)
                                DateFormat.yMMMd().format(d.createdAt!),
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            tooltip: 'Open document',
                            icon: const Icon(LucideIcons.download, size: 18),
                            onPressed: () => _openDocument(d),
                          ),
                          onTap: () => _openDocument(d),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PaymentsSection extends ConsumerWidget {
  const _PaymentsSection({required this.application});

  final ClientPropertyApplication application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(clientPaymentsProvider);
    final fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Payments',
          subtitle: 'Recorded against this property.',
          action: TextButton.icon(
            onPressed: () => context.go(RoutePaths.clientPayments),
            icon: const Icon(LucideIcons.creditCard, size: 14),
            label: const Text('Payments'),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        ),
        paymentsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ClientPortalCard(
            child: ClientCardSkeleton(),
          ),
          error: (e, _) => ClientPortalCard(
            child: Text(
              userFacingError(e, fallback: 'Could not load payments.'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          data: (bundle) {
            final title = application.propertyTitle;
            final payments = title == null
                ? const <ClientPayment>[]
                : bundle.payments
                    .where((p) => p.propertyTitle == title)
                    .toList();
            final installments = bundle.installments
                .where((i) => i.propertyId == application.propertyId)
                .toList();

            if (payments.isEmpty && installments.isEmpty) {
              return ClientPortalCard(
                child: Text(
                  'No payments or installments are linked to this property '
                  'yet. A schedule is created once the application is '
                  'approved.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                      ),
                ),
              );
            }

            final paid = payments
                .where((p) => p.status == 'completed' || p.status == 'paid')
                .fold<double>(0, (sum, p) => sum + p.amount);
            final outstanding = installments
                .where((i) => i.isPayable)
                .fold<double>(0, (sum, i) => sum + i.payableAmount);

            return ClientPortalCard(
              child: Column(
                children: [
                  _KeyValueRow(label: 'Total paid', value: fmt.format(paid)),
                  _KeyValueRow(
                    label: 'Outstanding',
                    value: fmt.format(outstanding),
                  ),
                  _KeyValueRow(
                    label: 'Payments recorded',
                    value: '${payments.length}',
                  ),
                  _KeyValueRow(
                    label: 'Installments',
                    value: '${installments.length}',
                    isLast: true,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LinkedPropertySection extends ConsumerWidget {
  const _LinkedPropertySection({required this.application});

  final ClientPropertyApplication application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(clientPropertiesProvider);
    final properties = propertiesAsync.valueOrNull ?? const <ClientProperty>[];
    final match = properties
        .where((p) => p.propertyId == application.propertyId)
        .toList();

    if (match.isEmpty) return const SizedBox.shrink();
    final property = match.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(title: 'Construction'),
        ClientPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClientProgressBar(
                label: 'Construction progress',
                percent: property.constructionProgressPct,
                color: AppColors.info,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.clientConstruction),
                    icon: const Icon(LucideIcons.hardHat, size: 14),
                    label: const Text('Construction updates'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      RoutePaths.clientPropertyDetail(property.propertyId),
                    ),
                    icon: const Icon(LucideIcons.building2, size: 14),
                    label: const Text('My property'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InspectionsSection extends ConsumerWidget {
  const _InspectionsSection({required this.application});

  final ClientPropertyApplication application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(clientInspectionsProvider);
    final inspections = (inspectionsAsync.valueOrNull ??
            const <ClientInspection>[])
        .where((i) => i.propertyId == application.propertyId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Inspections',
          action: TextButton.icon(
            onPressed: () => context.go(RoutePaths.clientInspections),
            icon: const Icon(LucideIcons.calendarCheck, size: 14),
            label: const Text('Bookings'),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        ),
        if (inspections.isEmpty)
          ClientPortalCard(
            child: Text(
              'No inspections booked for this property.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          )
        else
          ...inspections.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClientPortalCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    LucideIcons.calendarClock,
                    color: AppColors.gold,
                  ),
                  title: Text(
                    DateFormat.yMMMd().add_jm().format(i.scheduledAt),
                  ),
                  subtitle: Text(i.inspectionType.replaceAll('_', ' ')),
                  trailing: ClientStatusChip(status: i.status),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync =
        ref.watch(clientApplicationTimelineProvider(applicationId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClientSectionHeader(
          title: 'Activity',
          action: TextButton.icon(
            onPressed: () => context.go(RoutePaths.clientMessages),
            icon: const Icon(LucideIcons.messageCircle, size: 14),
            label: const Text('Message us'),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        ),
        timelineAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ClientPortalCard(
            child: ClientCardSkeleton(),
          ),
          error: (e, _) => ClientPortalCard(
            child: Text(
              userFacingError(e, fallback: 'Could not load activity.'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          data: (events) {
            if (events.isEmpty) {
              return ClientPortalCard(
                child: Text(
                  'Updates on this application will appear here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              );
            }
            return Column(
              children: events
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClientPortalCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.history,
                              size: 16,
                              color: AppColors.gold,
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
                                  if (e.body?.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      e.body!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                AppColors.textSecondaryDark,
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd()
                                        .add_jm()
                                        .format(e.occurredAt),
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
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({this.onResume, this.onCancel});

  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (onResume == null && onCancel == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (onResume != null)
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(LucideIcons.arrowRight, size: 16),
            label: const Text('Resume draft'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.charcoal,
            ),
          ),
        if (onCancel != null)
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(LucideIcons.ban, size: 16),
            label: const Text('Cancel application'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            ),
          ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
