import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Opens the guided property application flow.
///
/// Returns the application id when the client submits, or `null` when the flow
/// is dismissed. Drafts saved along the way persist even when `null` is
/// returned, so the client can resume from the applications list.
Future<String?> showClientApplicationWizard(
  BuildContext context,
  WidgetRef ref, {
  String? resumeApplicationId,
  String? initialPropertyId,
}) async {
  final record = await ref.read(clientRecordProvider.future);
  if (!context.mounted) return null;
  if (record == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your client profile is still being prepared.'),
      ),
    );
    return null;
  }

  ClientPropertyApplication? existing;
  if (resumeApplicationId != null) {
    existing = await ref.read(
      clientApplicationDetailProvider(resumeApplicationId).future,
    );
    if (!context.mounted) return null;
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.deepBlack.withValues(alpha: 0.72),
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final isCompact = size.width < 700;
      final wizard = _ApplicationWizard(
        clientId: record.id,
        existing: existing,
        initialPropertyId: initialPropertyId ?? existing?.propertyId,
      );

      if (isCompact) {
        return Dialog.fullscreen(
          backgroundColor: AppColors.darkSurface,
          child: SafeArea(child: wizard),
        );
      }

      return Dialog(
        backgroundColor: AppColors.darkSurface,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.18)),
        ),
        child: SizedBox(
          width: 760,
          height: size.height * 0.9,
          child: wizard,
        ),
      );
    },
  );
}

class _ApplicationWizard extends ConsumerStatefulWidget {
  const _ApplicationWizard({
    required this.clientId,
    this.existing,
    this.initialPropertyId,
  });

  final String clientId;
  final ClientPropertyApplication? existing;
  final String? initialPropertyId;

  @override
  ConsumerState<_ApplicationWizard> createState() => _ApplicationWizardState();
}

class _ApplicationWizardState extends ConsumerState<_ApplicationWizard> {
  static const _stepTitles = <String>[
    'Select property',
    'Application details',
    'Your information',
    'Supporting documents',
    'Review & submit',
  ];

  final _searchCtrl = TextEditingController();
  final _offerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _fmt = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  int _step = 0;
  String _query = '';
  String? _propertyId;
  String? _planCode;
  String? _applicationId;
  bool _busy = false;
  String? _error;
  final _uploadingTypes = <String>{};

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _applicationId = existing?.id;
    _propertyId = widget.initialPropertyId ?? existing?.propertyId;
    _planCode = existing?.paymentPlan;
    if (existing?.amountOffered != null) {
      _offerCtrl.text = existing!.amountOffered!.toStringAsFixed(0);
    }
    _notesCtrl.text = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _offerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _offerAmount =>
      double.tryParse(_offerCtrl.text.replaceAll(',', '').trim());

  String? get _notes {
    final value = _notesCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  String _friendlyError(Object error) {
    return userFacingError(
      error,
      fallback: 'Something went wrong. Please try again.',
    );
  }

  /// Persists the current answers as a draft and returns its id.
  Future<String?> _saveDraft({bool notify = true}) async {
    final propertyId = _propertyId;
    if (propertyId == null) {
      setState(() => _error = 'Select a property first.');
      return null;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final id = await ref.read(clientServiceProvider).saveApplicationDraft(
            clientId: widget.clientId,
            propertyId: propertyId,
            applicationId: _applicationId,
            paymentPlan: _planCode,
            amountOffered: _offerAmount,
            notes: _notes,
          );
      ref.invalidate(clientApplicationsProvider);
      ref.invalidate(clientApplicationDetailProvider(id));
      if (!mounted) return id;
      setState(() {
        _applicationId = id;
        _busy = false;
      });
      if (notify) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved.')),
        );
      }
      return id;
    } catch (e) {
      if (!mounted) return null;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
      return null;
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _error = null);

    switch (_step) {
      case 0:
        if (_propertyId == null) {
          setState(() => _error = 'Select a property to continue.');
          return;
        }
      case 1:
        if (_planCode == null) {
          setState(() => _error = 'Choose a payment plan to continue.');
          return;
        }
      case 2:
        // Documents need a persisted application to attach to.
        if (await _saveDraft(notify: false) == null) return;
      default:
        break;
    }

    if (!mounted) return;
    setState(() => _step = _step + 1);
  }

  void _back() {
    if (_busy || _step == 0) return;
    setState(() {
      _error = null;
      _step -= 1;
    });
  }

  Future<void> _pickAndUpload(ApplicationRequiredDocumentType type) async {
    final applicationId = _applicationId;
    final propertyId = _propertyId;
    if (applicationId == null || propertyId == null) {
      setState(() => _error = 'Save a draft before attaching documents.');
      return;
    }

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
      setState(() => _error = 'Could not read the selected file.');
      return;
    }

    setState(() {
      _uploadingTypes.add(type.code);
      _error = null;
    });

    try {
      await ref.read(clientServiceProvider).uploadApplicationDocument(
            clientId: widget.clientId,
            applicationId: applicationId,
            propertyId: propertyId,
            documentType: type.code,
            fileName: file.name,
            bytes: bytes,
            title: type.name,
          );
      ref.invalidate(clientApplicationDocumentsProvider(applicationId));
      ref.invalidate(clientDocumentsProvider);
      if (!mounted) return;
      setState(() => _uploadingTypes.remove(type.code));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingTypes.remove(type.code);
        _error = _friendlyError(e);
      });
    }
  }

  List<ApplicationRequiredDocumentType> _missingRequiredDocs() {
    final types =
        ref.read(applicationRequiredDocumentTypesProvider).valueOrNull ??
            const <ApplicationRequiredDocumentType>[];
    final applicationId = _applicationId;
    final uploaded = applicationId == null
        ? const <ClientDocument>[]
        : ref
                .read(clientApplicationDocumentsProvider(applicationId))
                .valueOrNull ??
            const <ClientDocument>[];
    final uploadedCodes =
        uploaded.map((d) => d.documentType).whereType<String>().toSet();
    return types
        .where((t) => t.isRequired && !uploadedCodes.contains(t.code))
        .toList();
  }

  Future<bool> _confirmMissingDocuments(
    List<ApplicationRequiredDocumentType> missing,
  ) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text('Documents still missing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These documents are required to complete the review. '
              'You can submit now and upload them later, but the review '
              'will not start until they arrive.',
            ),
            const SizedBox(height: 12),
            ...missing.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.name)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.charcoal,
            ),
            child: const Text('Submit anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final propertyId = _propertyId;
    if (propertyId == null) {
      setState(() {
        _step = 0;
        _error = 'Select a property to continue.';
      });
      return;
    }
    final planCode = _planCode;
    if (planCode == null) {
      setState(() {
        _step = 1;
        _error = 'Choose a payment plan to continue.';
      });
      return;
    }

    final missing = _missingRequiredDocs();
    if (missing.isNotEmpty) {
      final proceed = await _confirmMissingDocuments(missing);
      if (!mounted || !proceed) return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final id = await ref.read(clientServiceProvider).submitApplication(
            clientId: widget.clientId,
            propertyId: propertyId,
            paymentPlan: planCode,
            amountOffered: _offerAmount,
            notes: _notes,
            applicationId: _applicationId,
          );
      ref.invalidate(clientApplicationsProvider);
      ref.invalidate(clientApplicationDetailProvider(id));
      ref.invalidate(clientApplicationTimelineProvider(id));
      ref.invalidate(clientDashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _step == _stepTitles.length - 1;

    return Column(
      children: [
        _header(context),
        const Divider(height: 1, color: AppColors.neutral800),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _buildStep(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.neutral800),
        _footer(context, isLastStep: isLastStep),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.filePlus2,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existing == null
                          ? 'New application'
                          : 'Resume application',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${_step + 1} of ${_stepTitles.length} · '
                      '${_stepTitles[_step]}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: AppColors.slate400),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_step + 1) / _stepTitles.length,
              minHeight: 4,
              backgroundColor: AppColors.neutral800,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, {required bool isLastStep}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _busy ? null : _back,
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text('Back'),
            ),
          const Spacer(),
          if (_propertyId != null)
            TextButton.icon(
              onPressed: _busy ? null : () => _saveDraft(),
              icon: const Icon(LucideIcons.save, size: 16),
              label: const Text('Save draft'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondaryDark,
              ),
            ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _busy ? null : (isLastStep ? _submit : _next),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.charcoal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.charcoal,
                    ),
                  )
                : Icon(
                    isLastStep ? LucideIcons.send : LucideIcons.arrowRight,
                    size: 16,
                  ),
            label: Text(isLastStep ? 'Submit application' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _propertyStep(),
      1 => _detailsStep(),
      2 => _clientInfoStep(),
      3 => _documentsStep(),
      _ => _reviewStep(),
    };
  }

  // ── Step 1: property ──────────────────────────────────────────────────────

  Widget _propertyStep() {
    final optionsAsync = ref.watch(clientApplicationPropertyOptionsProvider);

    return optionsAsync.when(
      loading: () => const ClientCardSkeleton(height: 200),
      error: (e, _) => ClientErrorView(
        message: _friendlyError(e),
        onRetry: () =>
            ref.invalidate(clientApplicationPropertyOptionsProvider),
      ),
      data: (options) {
        if (options.isEmpty) {
          return const ClientEmptyState(
            title: 'No properties available',
            message: 'There are no published listings open for application '
                'right now. Please check back soon.',
            icon: LucideIcons.building2,
          );
        }

        final q = _query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? options
            : options
                .where(
                  (o) =>
                      o.title.toLowerCase().contains(q) ||
                      (o.location?.toLowerCase().contains(q) ?? false) ||
                      (o.propertyType?.toLowerCase().contains(q) ?? false),
                )
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, location or type',
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
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const ClientEmptyState(
                title: 'No matching properties',
                message: 'Try a different search term.',
                icon: LucideIcons.searchX,
              )
            else
              ...filtered.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PropertyOptionCard(
                    option: option,
                    selected: option.propertyId == _propertyId,
                    onTap: () {
                      if (option.propertyId == _propertyId) return;
                      setState(() {
                        _propertyId = option.propertyId;
                        _planCode = null;
                        _error = null;
                      });
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Step 2: details ───────────────────────────────────────────────────────

  Widget _detailsStep() {
    final plansAsync = ref.watch(applicationPaymentPlansProvider(_propertyId));
    final option = _selectedOption();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (option != null) ...[
          _SelectedPropertyBanner(option: option),
          const SizedBox(height: 20),
        ],
        ClientSectionHeader(
          title: 'Payment plan',
          subtitle: 'Choose how you would like to pay for this property.',
        ),
        plansAsync.when(
          loading: () => const ClientCardSkeleton(height: 120),
          error: (e, _) => ClientErrorView(
            message: _friendlyError(e),
            onRetry: () =>
                ref.invalidate(applicationPaymentPlansProvider(_propertyId)),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return const ClientEmptyState(
                title: 'No payment plans available',
                message: 'Sales has not published a payment plan for this '
                    'property yet. Please contact your relationship manager.',
                icon: LucideIcons.wallet,
              );
            }
            return Column(
              children: plans
                  .map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PaymentPlanCard(
                        plan: plan,
                        selected: plan.code == _planCode,
                        onTap: () => setState(() {
                          _planCode = plan.code;
                          _error = null;
                        }),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        ClientSectionHeader(
          title: 'Your offer',
          subtitle: 'Optional — leave blank to accept the listed price.',
        ),
        TextField(
          controller: _offerCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Offer amount',
            prefixText: '₦ ',
            helperText: option?.price != null
                ? 'Listed at ${option!.formattedPrice}'
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ── Step 3: client info ───────────────────────────────────────────────────

  Widget _clientInfoStep() {
    final session = ref.watch(identitySessionProvider);
    final profile = session.profile;
    final email = profile?.email ?? session.email ?? '—';
    final phone = profile?.phone;
    final address = profile?.address;
    final incomplete = (phone?.isEmpty ?? true) || (address?.isEmpty ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClientSectionHeader(
          title: 'Applicant details',
          subtitle: 'Taken from your profile. Update them in Settings if '
              'anything is out of date.',
        ),
        ClientPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: LucideIcons.user,
                label: 'Full name',
                value: profile?.displayName ?? '—',
              ),
              _InfoRow(
                icon: LucideIcons.mail,
                label: 'Email',
                value: email,
              ),
              _InfoRow(
                icon: LucideIcons.phone,
                label: 'Phone',
                value: (phone?.isNotEmpty ?? false) ? phone! : 'Not provided',
              ),
              _InfoRow(
                icon: LucideIcons.mapPin,
                label: 'Address',
                value:
                    (address?.isNotEmpty ?? false) ? address! : 'Not provided',
                isLast: true,
              ),
            ],
          ),
        ),
        if (incomplete) ...[
          const SizedBox(height: 12),
          ClientPortalCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A phone number and residential address speed up '
                    'verification. You can still continue and add them later '
                    'from Settings.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        ClientSectionHeader(
          title: 'Notes for our team',
          subtitle: 'Optional — anything we should know about this purchase.',
        ),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Preferred unit, timelines, financing questions…',
          ),
        ),
      ],
    );
  }

  // ── Step 4: documents ─────────────────────────────────────────────────────

  Widget _documentsStep() {
    final typesAsync = ref.watch(applicationRequiredDocumentTypesProvider);
    final applicationId = _applicationId;

    if (applicationId == null) {
      return ClientEmptyState(
        title: 'Draft not saved yet',
        message: 'Save this application as a draft so documents can be '
            'attached to it.',
        icon: LucideIcons.save,
        action: FilledButton.icon(
          onPressed: _busy ? null : () => _saveDraft(),
          icon: const Icon(LucideIcons.save, size: 16),
          label: const Text('Save draft'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.charcoal,
          ),
        ),
      );
    }

    final docsAsync =
        ref.watch(clientApplicationDocumentsProvider(applicationId));

    return typesAsync.when(
      loading: () => const ClientCardSkeleton(height: 160),
      error: (e, _) => ClientErrorView(
        message: _friendlyError(e),
        onRetry: () =>
            ref.invalidate(applicationRequiredDocumentTypesProvider),
      ),
      data: (types) {
        if (types.isEmpty) {
          return const ClientEmptyState(
            title: 'No documents required',
            message: 'Nothing to upload for this application. Continue to '
                'review your details.',
            icon: LucideIcons.checkCircle2,
          );
        }

        final uploaded = docsAsync.valueOrNull ?? const <ClientDocument>[];
        final byType = <String, ClientDocument>{};
        for (final doc in uploaded) {
          final type = doc.documentType;
          if (type != null) byType.putIfAbsent(type, () => doc);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClientSectionHeader(
              title: 'Supporting documents',
              subtitle: 'PDF or image (JPG, PNG, WebP).',
            ),
            ...types.map(
              (type) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentSlot(
                  type: type,
                  document: byType[type.code],
                  uploading: _uploadingTypes.contains(type.code),
                  onUpload: () => _pickAndUpload(type),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Step 5: review ────────────────────────────────────────────────────────

  Widget _reviewStep() {
    final option = _selectedOption();
    final plan = _selectedPlan();
    final session = ref.watch(identitySessionProvider);
    // Subscribed here so the outstanding-document warning stays in sync.
    ref.watch(applicationRequiredDocumentTypesProvider);
    final applicationId = _applicationId;
    final uploaded = applicationId == null
        ? const <ClientDocument>[]
        : ref
                .watch(clientApplicationDocumentsProvider(applicationId))
                .valueOrNull ??
            const <ClientDocument>[];
    final missing = _missingRequiredDocs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (option != null) ...[
          _SelectedPropertyBanner(option: option),
          const SizedBox(height: 16),
        ],
        ClientPortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: LucideIcons.wallet,
                label: 'Payment plan',
                value: plan?.name ?? _planCode?.replaceAll('_', ' ') ?? '—',
              ),
              _InfoRow(
                icon: LucideIcons.banknote,
                label: 'Your offer',
                value: _offerAmount != null
                    ? _fmt.format(_offerAmount)
                    : 'Listed price',
              ),
              _InfoRow(
                icon: LucideIcons.user,
                label: 'Applicant',
                value: session.profile?.displayName ??
                    session.email ??
                    'Client',
              ),
              _InfoRow(
                icon: LucideIcons.paperclip,
                label: 'Documents attached',
                value: '${uploaded.length}',
                isLast: _notes == null,
              ),
              if (_notes != null)
                _InfoRow(
                  icon: LucideIcons.messageSquare,
                  label: 'Notes',
                  value: _notes!,
                  isLast: true,
                ),
            ],
          ),
        ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClientPortalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${missing.length} required document'
                      '${missing.length == 1 ? '' : 's'} outstanding',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  missing.map((t) => t.name).join(', '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        ClientPortalCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, size: 18, color: AppColors.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Submitting sends this application to our sales team for '
                  'review. Allocation, contracts and payment schedules are '
                  'confirmed by HD Homes after review.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ClientApplicationPropertyOption? _selectedOption() {
    final id = _propertyId;
    if (id == null) return null;
    final options =
        ref.watch(clientApplicationPropertyOptionsProvider).valueOrNull;
    if (options == null) return null;
    for (final option in options) {
      if (option.propertyId == id) return option;
    }
    return null;
  }

  ApplicationPaymentPlan? _selectedPlan() {
    final code = _planCode;
    if (code == null) return null;
    final plans =
        ref.watch(applicationPaymentPlansProvider(_propertyId)).valueOrNull;
    if (plans == null) return null;
    for (final plan in plans) {
      if (plan.code == code) return plan;
    }
    return null;
  }
}

class _PropertyOptionCard extends StatelessWidget {
  const _PropertyOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ClientApplicationPropertyOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.08)
                : AppColors.darkSurface.withValues(alpha: 0.6),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : AppColors.neutral700.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.building2,
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
                      option.title,
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
                        if (option.location?.isNotEmpty ?? false)
                          option.location!,
                        if (option.propertyType?.isNotEmpty ?? false)
                          option.propertyType!.replaceAll('-', ' '),
                        if (option.bedrooms != null)
                          '${option.bedrooms} bed',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.formattedPrice,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                color: selected ? AppColors.gold : AppColors.neutral600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPropertyBanner extends StatelessWidget {
  const _SelectedPropertyBanner({required this.option});

  final ClientApplicationPropertyOption option;

  @override
  Widget build(BuildContext context) {
    return ClientPortalCard(
      child: Row(
        children: [
          const Icon(LucideIcons.building2, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (option.location?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    option.location!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            option.formattedPrice,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPlanCard extends StatelessWidget {
  const _PaymentPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final ApplicationPaymentPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (plan.installmentMonths != null)
        '${plan.installmentMonths} month${plan.installmentMonths == 1 ? '' : 's'}',
      if (plan.initialDepositPercent != null)
        '${plan.initialDepositPercent!.toStringAsFixed(0)}% initial deposit',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.08)
                : AppColors.darkSurface.withValues(alpha: 0.6),
            borderRadius: AppRadius.cardBorder,
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : AppColors.neutral700.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.gold,
                            ),
                      ),
                    ],
                    if (plan.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        plan.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondaryDark,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                color: selected ? AppColors.gold : AppColors.neutral600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentSlot extends StatelessWidget {
  const _DocumentSlot({
    required this.type,
    required this.document,
    required this.uploading,
    required this.onUpload,
  });

  final ApplicationRequiredDocumentType type;
  final ClientDocument? document;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final uploaded = document != null;

    return ClientPortalCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            uploaded ? LucideIcons.checkCircle2 : LucideIcons.fileText,
            color: uploaded ? AppColors.success : AppColors.slate400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        type.name,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                    if (type.isRequired) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  uploaded
                      ? (document!.fileName ?? document!.title)
                      : (type.description ?? 'Not uploaded yet'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: uploaded
                            ? AppColors.success
                            : AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (uploading)
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              onPressed: onUpload,
              icon: Icon(
                uploaded ? LucideIcons.refreshCw : LucideIcons.upload,
                size: 14,
              ),
              label: Text(uploaded ? 'Replace' : 'Upload'),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.slate400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
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
