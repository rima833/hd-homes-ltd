import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_booking_models.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_booking_controller.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_luxury_kit.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium Book Inspection experience — dedicated public page.
/// Pass [embedded] when nesting inside the Contact hub.
typedef InspectionPage = BookInspectionPage;

class BookInspectionPage extends ConsumerStatefulWidget {
  const BookInspectionPage({
    super.key,
    this.embedded = false,
    this.initialPropertyId,
    this.initialEstateId,
  });

  /// When true, omit page chrome that the Contact hub already provides.
  final bool embedded;
  final String? initialPropertyId;
  final String? initialEstateId;

  @override
  ConsumerState<BookInspectionPage> createState() => _BookInspectionPageState();
}

class _BookInspectionPageState extends ConsumerState<BookInspectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  final _sectionKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
  ProviderSubscription<AuthSessionSnapshot>? _identitySub;

  @override
  void initState() {
    super.initState();
    _name.addListener(_syncPersonal);
    _phone.addListener(_syncPersonal);
    _email.addListener(_syncPersonal);
    _notes.addListener(_syncNotes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefillIdentity();
      _applyInitialProperty();
      try {
        if (ref.read(supabaseConfiguredProvider)) {
          _identitySub = ref.listenManual(identitySessionProvider, (prev, next) {
            if (next.profile != null) _prefillIdentity();
          });
        }
      } catch (_) {
        // Tests / builds without an initialized Supabase client.
      }
    });
  }

  @override
  void didUpdateWidget(covariant BookInspectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPropertyId != widget.initialPropertyId ||
        oldWidget.initialEstateId != widget.initialEstateId) {
      _applyInitialProperty();
    }
  }

  void _prefillIdentity() {
    try {
      if (!ref.read(supabaseConfiguredProvider)) return;
      final profile = ref.read(identitySessionProvider).profile;
      if (profile == null) return;
      if (_name.text.trim().isEmpty) _name.text = profile.displayName;
      if (_email.text.trim().isEmpty) _email.text = profile.email;
      if (_phone.text.trim().isEmpty &&
          profile.phone != null &&
          profile.phone!.isNotEmpty) {
        _phone.text = profile.phone!;
      }
    } catch (_) {
      // Tests / builds without an initialized Supabase client.
    }
  }

  void _applyInitialProperty() {
    final propertyId = widget.initialPropertyId;
    if (propertyId == null || propertyId.isEmpty) return;
    ref
        .read(inspectionBookingControllerProvider.notifier)
        .preselectProperty(propertyId, estateId: widget.initialEstateId);
  }

  void _syncPersonal() {
    if (!mounted) return;
    ref
        .read(inspectionBookingControllerProvider.notifier)
        .patch(
          (d) => d.copyWith(
            fullName: _name.text,
            phone: _phone.text,
            email: _email.text,
          ),
        );
  }

  void _syncNotes() {
    if (!mounted) return;
    ref
        .read(inspectionBookingControllerProvider.notifier)
        .patch((d) => d.copyWith(notes: _notes.text));
  }

  void _revealWizard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = context.findRenderObject();
      if (target is RenderObject) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.08,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _identitySub?.close();
    _name.removeListener(_syncPersonal);
    _phone.removeListener(_syncPersonal);
    _email.removeListener(_syncPersonal);
    _notes.removeListener(_syncNotes);
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final service = ref.read(inspectionBookingServiceProvider);
    final urls = <String>[
      ...ref.read(inspectionBookingControllerProvider).documentUrls,
    ];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${f.name} exceeds 10MB')));
        continue;
      }
      final name = f.name.toLowerCase();
      final contentType = name.endsWith('.pdf')
          ? 'application/pdf'
          : name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.doc') || name.endsWith('.docx')
          ? 'application/msword'
          : 'image/jpeg';
      try {
        final url = await service.uploadDocument(
          bytes: bytes,
          filename: f.name,
          contentType: contentType,
        );
        urls.add(url);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed for ${f.name}: $e')),
        );
      }
    }
    ref
        .read(inspectionBookingControllerProvider.notifier)
        .patch((d) => d.copyWith(documentUrls: urls));
  }

  Future<void> _submit() async {
    _syncPersonal();
    _syncNotes();
    if (!(_formKey.currentState?.validate() ?? false)) {
      ref.read(inspectionBookingControllerProvider.notifier).setStep(0);
      _revealWizard();
      return;
    }
    final ok = await ref
        .read(inspectionBookingControllerProvider.notifier)
        .submit();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection booked successfully')),
      );
    } else {
      _revealWizard();
    }
  }

  void _goNext() {
    _syncPersonal();
    _syncNotes();
    _formKey.currentState?.validate();
    final ok = ref.read(inspectionBookingControllerProvider.notifier).goNext();
    if (ok) _revealWizard();
  }

  void _goBack() {
    ref.read(inspectionBookingControllerProvider.notifier).goBack();
    _revealWizard();
  }

  List<CmsPropertyFeatured> _filterProperties(
    List<CmsPropertyFeatured> properties,
    List<CmsEstateSummary> estates,
    String? estateId,
  ) {
    if (estateId == null) return properties;
    String? estateName;
    for (final e in estates) {
      if (e.id == estateId) {
        estateName = e.name;
        break;
      }
    }
    if (estateName == null) return properties;
    return properties.where((p) => p.estateName == estateName).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Realtime sockets are expensive to tear down — skip on Contact Hub embed
    // so leaving the page via nav does not freeze the public site.
    if (!widget.embedded) {
      ref.watch(inspectionBookingRealtimeProvider);
    }

    final draft = ref.watch(inspectionBookingControllerProvider);
    final propertiesAsync = ref.watch(inspectionBookablePropertiesProvider);
    final estatesAsync = ref.watch(publishedEstatesCatalogProvider);
    final property = selectedInspectionProperty(ref);
    final estate = selectedInspectionEstate(ref);
    final embedded = widget.embedded;
    // Dual-column matches mockup on desktop — safe inside hub scroll (Row
    // Expanded needs width, not height).
    final wide = !context.isMobile &&
        MediaQuery.sizeOf(context).width >= 980;
    final topInset = embedded ? 0.0 : MediaQuery.paddingOf(context).top + 88;
    final primaryLabel = draft.step < 4 ? 'Continue' : 'Book Inspection';
    final primaryAction = draft.step < 4
        ? _goNext
        : (draft.submitting ? null : _submit);
    final actionHeight = embedded
        ? (draft.step < 4 ? 52.0 : 56.0)
        : (draft.step < 4 ? 64.0 : 72.0);

    if (draft.submittedReference != null) {
      return _SuccessView(
        reference: draft.submittedReference!,
        inspectionId: draft.submittedInspectionId,
        onReset: () {
          _name.clear();
          _phone.clear();
          _email.clear();
          _notes.clear();
          ref.read(inspectionBookingControllerProvider.notifier).reset();
        },
      );
    }

    final steps = <Widget>[
      KeyedSubtree(
        key: _sectionKeys[0],
        child: PersonalInfoCard(name: _name, phone: _phone, email: _email),
      ),
      KeyedSubtree(
        key: _sectionKeys[1],
        child: PropertySelectionCard(
          properties: _filterProperties(
            propertiesAsync.valueOrNull ?? const [],
            estatesAsync.valueOrNull ?? const [],
            draft.estateId,
          ),
          estates: estatesAsync.valueOrNull ?? const [],
          selectedPropertyId: draft.propertyId,
          selectedEstateId: draft.estateId,
          loading: propertiesAsync.isLoading || estatesAsync.isLoading,
          onProperty: (p) {
            final notifier = ref.read(
              inspectionBookingControllerProvider.notifier,
            );
            String? estateId;
            if (p != null) {
              final estates =
                  estatesAsync.valueOrNull ?? const <CmsEstateSummary>[];
              for (final e in estates) {
                if (p.estateName != null && e.name == p.estateName) {
                  estateId = e.id;
                  break;
                }
              }
            }
            notifier.selectProperty(p, estateId: estateId);
          },
          onEstate: (id) => ref
              .read(inspectionBookingControllerProvider.notifier)
              .selectEstate(id),
        ),
      ),
      KeyedSubtree(
        key: _sectionKeys[2],
        child: ScheduleCard(
          draft: draft,
          propertyId: draft.propertyId,
          estateId: draft.estateId,
          enableRealtime: !embedded,
          onDate: (d) => ref
              .read(inspectionBookingControllerProvider.notifier)
              .patch(
                (x) => x.copyWith(
                  preferredDate: DateTime(d.year, d.month, d.day),
                  clearPreferredTime: true,
                  clearScheduledAt: true,
                  clearError: true,
                ),
              ),
          onSlot: (slot) => ref
              .read(inspectionBookingControllerProvider.notifier)
              .patch(
                (x) => x.copyWith(
                  preferredDate: DateTime(
                    slot.date.year,
                    slot.date.month,
                    slot.date.day,
                  ),
                  preferredTime: slot.timeOfDay,
                  scheduledAt: slot.scheduledAt,
                  clearError: true,
                ),
              ),
          onAdvisor: (id) {
            final cleaned = id.trim().isEmpty ? null : id;
            final current = ref
                .read(inspectionBookingControllerProvider)
                .advisorId;
            if (cleaned == current) return;
            ref
                .read(inspectionBookingControllerProvider.notifier)
                .patch(
                  (x) => x.copyWith(
                    advisorId: cleaned,
                    clearAdvisorId: cleaned == null,
                    clearPreferredTime: cleaned != null,
                    clearScheduledAt: cleaned != null,
                  ),
                );
          },
        ),
      ),
      KeyedSubtree(
        key: _sectionKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MeetingTypeSelector(
              value: draft.meetingType,
              onChanged: (v) => ref
                  .read(inspectionBookingControllerProvider.notifier)
                  .patch((x) => x.copyWith(meetingType: v)),
            ),
            if (draft.meetingType == InspectionMeetingType.physical) ...[
              const SizedBox(height: 16),
              MeetupLogisticsCard(
                mode: draft.meetupMode,
                pickupAddress: draft.pickupAddress,
                officeId: draft.meetupOfficeId,
                offices: ref.watch(contactHubCmsProvider).offices,
                onModeChanged: (m) => ref
                    .read(inspectionBookingControllerProvider.notifier)
                    .patch((x) => x.copyWith(meetupMode: m)),
                onPickupChanged: (v) => ref
                    .read(inspectionBookingControllerProvider.notifier)
                    .patch((x) => x.copyWith(pickupAddress: v)),
                onOfficeChanged: (office) => ref
                    .read(inspectionBookingControllerProvider.notifier)
                    .patch(
                      (x) => office == null
                          ? x.copyWith(
                              clearMeetupOfficeId: true,
                              clearMeetupOfficeLabel: true,
                            )
                          : x.copyWith(
                              meetupOfficeId: office.id,
                              meetupOfficeLabel:
                                  '${office.name} — ${office.city}',
                            ),
                    ),
              ),
            ],
            const SizedBox(height: 16),
            UploadDocumentsCard(
              notes: _notes,
              documentCount: draft.documentUrls.length,
              onBrowse: _pickFiles,
              compact: embedded,
              onNotesChanged: (v) => ref
                  .read(inspectionBookingControllerProvider.notifier)
                  .patch((x) => x.copyWith(notes: v)),
            ),
            const SizedBox(height: 16),
            LuxuryCard(
              child: _DropdownField(
                label: 'Preferred language',
                value: draft.preferredLanguage,
                items: const ['English', 'Yoruba', 'Igbo', 'Hausa', 'French'],
                onChanged: (v) => ref
                    .read(inspectionBookingControllerProvider.notifier)
                    .patch(
                      (x) => x.copyWith(preferredLanguage: v ?? 'English'),
                    ),
              ),
            ),
            const SizedBox(height: 16),
            LeadQualificationCard(
              draft: draft,
              onChanged: (fn) => ref
                  .read(inspectionBookingControllerProvider.notifier)
                  .patch(fn),
            ),
          ],
        ),
      ),
      KeyedSubtree(
        key: _sectionKeys[4],
        child: LuxuryCard(
          child: InspectionSummaryCard(
            estateName: estate?.name ?? property?.estateName,
            propertyName: property?.title,
            propertyType: _propertyTypeLabel(property),
            draft: draft,
            advisorName: selectedInspectionAdvisor(ref)?.name,
          ),
        ),
      ),
    ];

    final stepBody = switch (draft.step) {
      0 => steps[0],
      1 => steps[1],
      2 => steps[2],
      3 => steps[3],
      _ => steps[4],
    };

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              draft.error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        PremiumButton(
          label: primaryLabel,
          loading: draft.submitting && draft.step >= 4,
          height: actionHeight,
          onPressed: primaryAction,
        ),
        if (draft.step > 0) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _goBack,
            child: const Text(
              'Back',
              style: TextStyle(color: InspectionLux.gold),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shieldCheck, size: 14, color: InspectionLux.gold),
            SizedBox(width: 6),
            Text(
              'Your information is 100% secure',
              style: TextStyle(color: InspectionLux.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );

    final left = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(key: ValueKey(draft.step), child: stepBody),
          ),
          const SizedBox(height: 28),
          actions,
          const SizedBox(height: 40),
        ],
      ),
    );

    final summary = PropertySummarySidebar(
      property: property,
      estate: estate,
      draft: draft,
    );

    final body = Column(
      children: [
        if (!embedded) ...[
          SizedBox(height: topInset > 100 ? topInset : 100),
          const _HeroHeader(),
          const SizedBox(height: 28),
        ],
        Center(
          child: InspectionStepper(
            step: draft.step,
            maxStepReached: draft.maxStepReached,
            onStepTap: (s) {
              ref.read(inspectionBookingControllerProvider.notifier).setStep(s);
              _revealWizard();
            },
          ),
        ),
        const SizedBox(height: 24),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: left),
              const SizedBox(width: 24),
              Expanded(flex: 7, child: summary),
            ],
          )
        else ...[
          left,
          const SizedBox(height: 20),
          _MobileSummaryDrawer(
            property: property,
            estate: estate,
            draft: draft,
          ),
        ],
        if (!embedded) ...[
          const SizedBox(height: 28),
          const _TrustBar(),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 8),
      ],
    );

    if (embedded) {
      return ColoredBox(color: InspectionLux.bg, child: body);
    }

    return ColoredBox(
      color: InspectionLux.bg,
      child: PageContainer(child: body),
    );
  }
}

class StickySidebar extends StatelessWidget {
  const StickySidebar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(alignment: Alignment.topCenter, child: child);
  }
}

class _MobileSummaryDrawer extends StatefulWidget {
  const _MobileSummaryDrawer({
    required this.property,
    required this.estate,
    required this.draft,
  });

  final CmsPropertyFeatured? property;
  final CmsEstateSummary? estate;
  final InspectionBookingDraft draft;

  @override
  State<_MobileSummaryDrawer> createState() => _MobileSummaryDrawerState();
}

class _MobileSummaryDrawerState extends State<_MobileSummaryDrawer> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(InspectionLux.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking summary',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.property?.title ?? 'No property selected yet',
                          style: const TextStyle(
                            color: InspectionLux.muted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    color: InspectionLux.gold,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            InspectionSummaryCard(
              estateName: widget.estate?.name ?? widget.property?.estateName,
              propertyName: widget.property?.title,
              propertyType: _propertyTypeLabel(widget.property),
              draft: widget.draft,
              advisorName: null,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'INSPECTION',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: InspectionLux.gold,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Book an inspection',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: context.isMobile ? 28 : 36,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Text(
            'Pick a property, choose a live slot, and confirm your tour.',
            textAlign: TextAlign.center,
            style: TextStyle(color: InspectionLux.muted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class PersonalInfoCard extends StatelessWidget {
  const PersonalInfoCard({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.user,
            title: 'Personal Information',
            subtitle: 'Tell us how we can reach you.',
          ),
          const SizedBox(height: 20),
          LuxuryTextField(
            label: 'Full name',
            hint: 'Enter your full name',
            controller: name,
            icon: LucideIcons.user,
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 560;
              final phoneField = LuxuryTextField(
                label: 'Phone number',
                hint: 'Enter your phone number',
                controller: phone,
                icon: LucideIcons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().length < 7) return 'Required';
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits.length < 10 || digits.length > 15) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              );
              final emailField = LuxuryTextField(
                label: 'Email address',
                hint: 'Enter your email address',
                controller: email,
                icon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Valid email required'
                    : null,
              );
              if (stacked) {
                return Column(
                  children: [
                    phoneField,
                    const SizedBox(height: 14),
                    emailField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: phoneField),
                  const SizedBox(width: 14),
                  Expanded(child: emailField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PropertySelectionCard extends StatelessWidget {
  const PropertySelectionCard({
    super.key,
    required this.properties,
    required this.estates,
    required this.selectedPropertyId,
    required this.selectedEstateId,
    required this.onProperty,
    required this.onEstate,
    this.loading = false,
  });

  final List<CmsPropertyFeatured> properties;
  final List<CmsEstateSummary> estates;
  final String? selectedPropertyId;
  final String? selectedEstateId;
  final ValueChanged<CmsPropertyFeatured?> onProperty;
  final ValueChanged<String?> onEstate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final selected = properties.where((p) => p.id == selectedPropertyId);
    final property = selected.isEmpty ? null : selected.first;

    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.home,
            title: 'Choose Property',
            subtitle: 'Select the property and estate for your inspection.',
          ),
          const SizedBox(height: 20),
          if (loading)
            const SizedBox(
              height: 96,
              child: Center(
                child: CircularProgressIndicator(color: InspectionLux.gold),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 700;
                final propertyPane = _PropertyPicker(
                  properties: properties,
                  selected: property,
                  onChanged: onProperty,
                );
                final estatePane = _EstatePicker(
                  estates: estates,
                  selectedId: selectedEstateId,
                  onChanged: onEstate,
                );
                if (stacked) {
                  return Column(
                    children: [
                      propertyPane,
                      const SizedBox(height: 14),
                      estatePane,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: propertyPane),
                    const SizedBox(width: 14),
                    Expanded(child: estatePane),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PropertyPicker extends StatelessWidget {
  const _PropertyPicker({
    required this.properties,
    required this.selected,
    required this.onChanged,
  });

  final List<CmsPropertyFeatured> properties;
  final CmsPropertyFeatured? selected;
  final ValueChanged<CmsPropertyFeatured?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property', style: TextStyle(color: InspectionLux.muted)),
        const SizedBox(height: 8),
        LuxuryDropdown<String>(
          value: selected?.id,
          hint: 'Select property',
          items: [
            for (final p in properties)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            CmsPropertyFeatured? match;
            for (final p in properties) {
              if (p.id == id) match = p;
            }
            onChanged(match);
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: selected!.coverImageUrl == null
                  ? Container(color: InspectionLux.elevated)
                  : MediaDeliveryImage(
                      url: selected!.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: Container(color: InspectionLux.elevated),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                label: selected!.marketingStatus ?? 'Available',
                color: AppColors.success,
              ),
              if (selected!.bedrooms != null)
                _MetaChip(label: '${selected!.bedrooms} Beds'),
              if (selected!.bathrooms != null)
                _MetaChip(label: '${selected!.bathrooms} Baths'),
              if (selected!.buildingSizeSqm != null ||
                  selected!.landSizeSqm != null)
                _MetaChip(
                  label:
                      '${(selected!.buildingSizeSqm ?? selected!.landSizeSqm)!.round()} sqm',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EstatePicker extends StatelessWidget {
  const _EstatePicker({
    required this.estates,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CmsEstateSummary> estates;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    CmsEstateSummary? selected;
    for (final e in estates) {
      if (e.id == selectedId) selected = e;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Estate', style: TextStyle(color: InspectionLux.muted)),
        const SizedBox(height: 8),
        LuxuryDropdown<String>(
          value: selectedId,
          hint: 'Select estate',
          items: [
            for (final e in estates)
              DropdownMenuItem(
                value: e.id,
                child: Text(e.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: InspectionLux.elevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: InspectionLux.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.map,
                      color: InspectionLux.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selected.name,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (selected.city != null) selected.city!,
                    if (selected.state != null) selected.state!,
                    if (selected.marketingStatus != null)
                      selected.marketingStatus!,
                  ].join(' · '),
                  style: const TextStyle(
                    color: InspectionLux.muted,
                    fontSize: 12,
                  ),
                ),
                if (selected.priceFromLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'From ${selected.priceFromLabel}',
                    style: const TextStyle(color: InspectionLux.goldLight),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? InspectionLux.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 12)),
    );
  }
}

class ScheduleCard extends ConsumerWidget {
  const ScheduleCard({
    super.key,
    required this.draft,
    required this.propertyId,
    required this.estateId,
    required this.onDate,
    required this.onSlot,
    required this.onAdvisor,
    this.enableRealtime = true,
  });

  final InspectionBookingDraft draft;
  final String? propertyId;
  final String? estateId;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<InspectionSlot> onSlot;
  final ValueChanged<String> onAdvisor;
  final bool enableRealtime;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _slotOnDay(InspectionSlot slot, DateTime day) {
    final localSched = slot.scheduledAt.toLocal();
    return _sameDay(slot.date, day) || _sameDay(localSched, day);
  }

  bool _isSelected(InspectionBookingDraft draft, InspectionSlot slot) {
    if (draft.scheduledAt == null) return false;
    return draft.scheduledAt!
            .toUtc()
            .difference(slot.scheduledAt.toUtc())
            .inMinutes
            .abs() <
        1;
  }

  Future<void> _pickTime(
    BuildContext context,
    List<InspectionSlot> slots,
  ) async {
    if (slots.isEmpty) return;
    final chosen = await showModalBottomSheet<InspectionSlot>(
      context: context,
      backgroundColor: InspectionLux.elevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select preferred time',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in slots)
                      ChoiceChip(
                        label: Text(slot.label),
                        selected: _isSelected(draft, slot),
                        selectedColor: InspectionLux.gold.withValues(
                          alpha: 0.25,
                        ),
                        labelStyle: TextStyle(
                          color: _isSelected(draft, slot)
                              ? InspectionLux.goldLight
                              : AppColors.white,
                        ),
                        side: BorderSide(
                          color: InspectionLux.gold.withValues(alpha: 0.45),
                        ),
                        onSelected: (_) => Navigator.of(ctx).pop(slot),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null) onSlot(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (enableRealtime) {
      ref.watch(inspectionBookingRealtimeProvider);
      if (propertyId != null) {
        ref.watch(inspectionSlotsRealtimeProvider(propertyId!));
      }
    }
    final slotsAsync = propertyId == null
        ? const AsyncValue<List<InspectionSlot>>.data([])
        : ref.watch(
            inspectionSlotsProvider(
              InspectionSlotQuery(
                propertyId: propertyId!,
                estateId: estateId,
                advisorId: draft.advisorId,
                from: draft.preferredDate,
              ),
            ),
          );

    final allSlots = slotsAsync.valueOrNull ?? const <InspectionSlot>[];
    var slotsForDay = draft.preferredDate == null
        ? const <InspectionSlot>[]
        : allSlots
              .where((s) => s.available && _slotOnDay(s, draft.preferredDate!))
              .toList();

    if (draft.scheduledAt != null &&
        !slotsAsync.isLoading &&
        slotsForDay.isNotEmpty &&
        !slotsForDay.any((s) => _isSelected(draft, s))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(inspectionBookingControllerProvider.notifier)
            .clearUnavailableSlot();
      });
    }

    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.calendar,
            title: 'Preferred schedule',
            subtitle: 'Times update as other tours are booked.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F8A4C).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF1F8A4C).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Times stay current as tours are booked.',
                  style: TextStyle(
                    color: Color(0xFF9AA3B2),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (propertyId == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Select a property first to load available times.',
                style: TextStyle(color: InspectionLux.muted),
              ),
            ),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 700;
              final children = [
                _ScheduleTile(
                  label: 'Preferred date',
                  value: draft.preferredDate == null
                      ? 'Select date'
                      : DateFormat(
                          'EEE, d MMM yyyy',
                        ).format(draft.preferredDate!),
                  icon: LucideIcons.calendarDays,
                  onTap: propertyId == null
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final first = now.add(const Duration(days: 1));
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: first,
                            lastDate: now.add(const Duration(days: 120)),
                            initialDate:
                                draft.preferredDate ??
                                now.add(const Duration(days: 2)),
                          );
                          if (picked != null) onDate(picked);
                        },
                ),
                _ScheduleTile(
                  label: 'Preferred time',
                  value:
                      draft.preferredTime?.label ??
                      (draft.preferredDate == null
                          ? 'Select a date first'
                          : slotsAsync.isLoading
                          ? 'Loading times…'
                          : slotsForDay.isEmpty
                          ? 'No slots — try another date'
                          : 'Tap to select time'),
                  icon: LucideIcons.clock,
                  loading: slotsAsync.isLoading,
                  onTap:
                      propertyId == null ||
                          draft.preferredDate == null ||
                          slotsForDay.isEmpty
                      ? null
                      : () => _pickTime(context, slotsForDay),
                ),
                _AdvisorPicker(
                  selectedId: draft.advisorId,
                  onChanged: onAdvisor,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      children[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: children[i]),
                  ],
                ],
              );
            },
          ),
          if (propertyId != null && draft.preferredDate != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Available times',
              style: TextStyle(
                color: InspectionLux.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (slotsAsync.hasError) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Times could not be refreshed. Retry before selecting a time.',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(inspectionSlotsProvider),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: InspectionLux.gold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (slotsAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: InspectionLux.gold,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Checking live availability…',
                      style: TextStyle(
                        color: InspectionLux.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else if (slotsForDay.isEmpty)
              const Text(
                'No inspection slots are available for this date. Please choose another day.',
                style: TextStyle(color: InspectionLux.muted),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slotsForDay)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSlot(slot),
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _isSelected(draft, slot)
                                ? InspectionLux.gold.withValues(alpha: 0.25)
                                : InspectionLux.elevated,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: InspectionLux.gold.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            slot.label,
                            style: TextStyle(
                              color: _isSelected(draft, slot)
                                  ? InspectionLux.goldLight
                                  : AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: InspectionLux.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: InspectionLux.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: InspectionLux.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: InspectionLux.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: InspectionLux.gold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvisorPicker extends ConsumerWidget {
  const _AdvisorPicker({required this.selectedId, required this.onChanged});
  final String? selectedId;
  final ValueChanged<String> onChanged;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisorsAsync = ref.watch(inspectionAdvisorsProvider);
    final advisors = (advisorsAsync.valueOrNull ?? const <InspectionAdvisor>[])
        .where((a) => _uuid.hasMatch(a.id))
        .toList();
    final value = selectedId != null && advisors.any((a) => a.id == selectedId)
        ? selectedId
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InspectionLux.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InspectionLux.border),
      ),
      child: advisorsAsync.isLoading
          ? const SizedBox(
              height: 48,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: InspectionLux.gold,
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                dropdownColor: InspectionLux.elevated,
                hint: const Text(
                  'Preferred advisor (optional)',
                  style: TextStyle(color: InspectionLux.muted),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Any available advisor',
                      style: TextStyle(color: InspectionLux.muted),
                    ),
                  ),
                  for (final a in advisors)
                    DropdownMenuItem(
                      value: a.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: InspectionLux.gold.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage: a.avatarUrl != null
                                ? NetworkImage(a.avatarUrl!)
                                : null,
                            child: a.avatarUrl == null
                                ? Text(
                                    a.name.isEmpty
                                        ? 'A'
                                        : a.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: InspectionLux.gold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  a.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                  ),
                                ),
                                Text(
                                  a.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: InspectionLux.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
    );
  }
}

class MeetingTypeSelector extends StatelessWidget {
  const MeetingTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final InspectionMeetingType value;
  final ValueChanged<InspectionMeetingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.mapPin,
            title: 'Meeting type',
            subtitle: 'Choose how you want to experience the property.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 640;
              final physical = _MeetingOption(
                selected: value == InspectionMeetingType.physical,
                icon: LucideIcons.home,
                title: 'Physical Tour',
                description: 'Visit the site in person',
                benefit: 'Best for serious buyers',
                onTap: () => onChanged(InspectionMeetingType.physical),
              );
              final virtual = _MeetingOption(
                selected: value == InspectionMeetingType.virtual,
                icon: LucideIcons.video,
                title: 'Virtual Tour',
                description: 'Video walkthrough',
                benefit: 'Ideal for diaspora clients',
                onTap: () => onChanged(InspectionMeetingType.virtual),
              );
              if (stacked) {
                return Column(
                  children: [physical, const SizedBox(height: 12), virtual],
                );
              }
              return Row(
                children: [
                  Expanded(child: physical),
                  const SizedBox(width: 12),
                  Expanded(child: virtual),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Pickup address / office visit / meet at property — physical tours only.
class MeetupLogisticsCard extends StatefulWidget {
  const MeetupLogisticsCard({
    super.key,
    required this.mode,
    required this.pickupAddress,
    required this.officeId,
    required this.offices,
    required this.onModeChanged,
    required this.onPickupChanged,
    required this.onOfficeChanged,
  });

  final InspectionMeetupMode mode;
  final String pickupAddress;
  final String? officeId;
  final List<OfficeLocation> offices;
  final ValueChanged<InspectionMeetupMode> onModeChanged;
  final ValueChanged<String> onPickupChanged;
  final ValueChanged<OfficeLocation?> onOfficeChanged;

  @override
  State<MeetupLogisticsCard> createState() => _MeetupLogisticsCardState();
}

class _MeetupLogisticsCardState extends State<MeetupLogisticsCard> {
  late final TextEditingController _pickup;

  @override
  void initState() {
    super.initState();
    _pickup = TextEditingController(text: widget.pickupAddress);
  }

  @override
  void didUpdateWidget(covariant MeetupLogisticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickupAddress != _pickup.text &&
        widget.pickupAddress != oldWidget.pickupAddress) {
      _pickup.text = widget.pickupAddress;
    }
  }

  @override
  void dispose() {
    _pickup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.navigation,
            title: 'Arrival & pickup',
            subtitle:
                'Tell us where to meet you — we can pick you up or welcome you at an office.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 720;
              final options = [
                _MeetupModeChip(
                  selected: widget.mode == InspectionMeetupMode.meetAtProperty,
                  icon: LucideIcons.mapPin,
                  title: 'Meet at property',
                  subtitle: 'Arrive at the site yourself',
                  onTap: () => widget.onModeChanged(
                    InspectionMeetupMode.meetAtProperty,
                  ),
                ),
                _MeetupModeChip(
                  selected: widget.mode == InspectionMeetupMode.meetAtOffice,
                  icon: LucideIcons.building2,
                  title: 'Come to our office',
                  subtitle: 'Start from an HD Homes office',
                  onTap: () =>
                      widget.onModeChanged(InspectionMeetupMode.meetAtOffice),
                ),
                _MeetupModeChip(
                  selected: widget.mode == InspectionMeetupMode.pickup,
                  icon: LucideIcons.car,
                  title: 'Pick me up',
                  subtitle: 'Share your pickup location',
                  onTap: () =>
                      widget.onModeChanged(InspectionMeetupMode.pickup),
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      options[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: options[i]),
                  ],
                ],
              );
            },
          ),
          if (widget.mode == InspectionMeetupMode.pickup) ...[
            const SizedBox(height: 16),
            LuxuryTextField(
              label: 'Pickup location *',
              controller: _pickup,
              maxLines: 2,
              hint: 'Street address, landmark, or estate gate…',
              onChanged: widget.onPickupChanged,
            ),
          ],
          if (widget.mode == InspectionMeetupMode.meetAtOffice) ...[
            const SizedBox(height: 16),
            _DropdownField(
              label: 'Office to visit *',
              value: widget.officeId,
              items: widget.offices.map((o) => o.id).toList(),
              itemLabels: {
                for (final o in widget.offices) o.id: '${o.name} — ${o.city}',
              },
              onChanged: (id) {
                if (id == null) {
                  widget.onOfficeChanged(null);
                  return;
                }
                OfficeLocation? match;
                for (final o in widget.offices) {
                  if (o.id == id) {
                    match = o;
                    break;
                  }
                }
                widget.onOfficeChanged(match);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MeetupModeChip extends StatelessWidget {
  const _MeetupModeChip({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: InspectionLux.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? InspectionLux.gold : InspectionLux.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: InspectionLux.gold),
                const Spacer(),
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  size: 16,
                  color: selected ? InspectionLux.gold : InspectionLux.muted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: InspectionLux.muted,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingOption extends StatelessWidget {
  const _MeetingOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.benefit,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final String benefit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: InspectionLux.elevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? InspectionLux.gold : InspectionLux.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: InspectionLux.gold.withValues(alpha: 0.2),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: InspectionLux.gold),
                const Spacer(),
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color: selected ? InspectionLux.gold : InspectionLux.muted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(color: InspectionLux.muted),
            ),
            const SizedBox(height: 10),
            Text(
              benefit,
              style: const TextStyle(
                color: InspectionLux.goldLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadDocumentsCard extends StatelessWidget {
  const UploadDocumentsCard({
    super.key,
    required this.notes,
    required this.documentCount,
    required this.onBrowse,
    required this.onNotesChanged,
    this.compact = false,
  });

  final TextEditingController notes;
  final int documentCount;
  final VoidCallback onBrowse;
  final ValueChanged<String> onNotesChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.uploadCloud,
            title: 'Additional information',
            subtitle: 'Upload supporting documents and share optional notes.',
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onBrowse,
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: InspectionLux.gold.withValues(alpha: 0.55),
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 20 : 36,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.uploadCloud,
                      color: InspectionLux.gold,
                      size: compact ? 26 : 32,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Drag & drop files here',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      documentCount == 0
                          ? 'PDF, images, DOC · max 10MB'
                          : '$documentCount file(s) attached',
                      style: const TextStyle(
                        color: InspectionLux.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: onBrowse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: InspectionLux.gold,
                        side: const BorderSide(color: InspectionLux.gold),
                      ),
                      child: const Text('Browse files'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          LuxuryTextField(
            label: 'Optional notes',
            controller: notes,
            maxLines: compact ? 2 : 4,
            hint: 'Anything we should prepare for your visit?',
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: notes,
            builder: (context, value, _) => Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${value.text.length}/500',
                style: const TextStyle(
                  color: InspectionLux.muted,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class LeadQualificationCard extends StatelessWidget {
  const LeadQualificationCard({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final InspectionBookingDraft draft;
  final void Function(InspectionBookingDraft Function(InspectionBookingDraft))
  onChanged;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: InspectionLux.gold,
          collapsedIconColor: InspectionLux.gold,
          title: const _CardHeader(
            icon: LucideIcons.sparkles,
            title: 'Smart lead qualification',
            subtitle: 'Optional — helps us assign the right advisor.',
          ),
          children: [
            const SizedBox(height: 8),
            _DropdownField(
              label: 'Budget',
              value: draft.budget,
              items: const [
                'Under ₦50M',
                '₦50M – ₦100M',
                '₦100M – ₦250M',
                '₦250M+',
              ],
              onChanged: (v) => onChanged((d) => d.copyWith(budget: v)),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Timeline',
              value: draft.timeline,
              items: const [
                'Immediate',
                '1–3 months',
                '3–6 months',
                '6+ months',
              ],
              onChanged: (v) => onChanged((d) => d.copyWith(timeline: v)),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Financing method',
              value: draft.financing,
              items: const [
                'Cash',
                'Mortgage',
                'Payment plan',
                'Investor funding',
              ],
              onChanged: (v) => onChanged((d) => d.copyWith(financing: v)),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Preferred location',
              value: draft.location,
              items: const [
                'Lekki',
                'Victoria Island',
                'Ikeja',
                'Abuja',
                'Other',
              ],
              onChanged: (v) => onChanged((d) => d.copyWith(location: v)),
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'Property type',
              value: draft.propertyType,
              items: const [
                'Apartment',
                'Duplex',
                'Terrace',
                'Land',
                'Penthouse',
              ],
              onChanged: (v) => onChanged((d) => d.copyWith(propertyType: v)),
            ),
            const SizedBox(height: 16),
            const Text('Purpose', style: TextStyle(color: InspectionLux.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in InspectionPurpose.values)
                  ChoiceChip(
                    label: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                    selected: draft.purpose == p,
                    onSelected: (_) => onChanged((d) => d.copyWith(purpose: p)),
                    selectedColor: InspectionLux.gold.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: draft.purpose == p
                          ? InspectionLux.goldLight
                          : InspectionLux.muted,
                    ),
                    backgroundColor: InspectionLux.elevated,
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Investment interest',
                style: TextStyle(color: AppColors.white),
              ),
              value: draft.investmentInterest,
              activeThumbColor: InspectionLux.gold,
              onChanged: (v) =>
                  onChanged((d) => d.copyWith(investmentInterest: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabels,
  });

  final String label;
  final String? value;
  final List<String> items;
  final Map<String, String>? itemLabels;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : null;
    return LuxuryDropdown<String>(
      label: label,
      value: safeValue,
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text(
              itemLabels?[i] ?? i,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class PropertySummarySidebar extends ConsumerWidget {
  const PropertySummarySidebar({
    super.key,
    required this.property,
    required this.estate,
    required this.draft,
  });

  final CmsPropertyFeatured? property;
  final CmsEstateSummary? estate;
  final InspectionBookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisorName =
        selectedInspectionAdvisor(ref)?.name ?? 'HD Homes Experts';

    return Column(
      children: [
        _SelectedPropertyCard(property: property, estate: estate),
        const SizedBox(height: 14),
        LuxuryCard(
          child: InspectionSummaryCard(
            estateName: estate?.name ?? property?.estateName,
            propertyName: property?.title,
            propertyType: _propertyTypeLabel(property),
            draft: draft,
            advisorName: advisorName,
          ),
        ),
      ],
    );
  }
}

class _SelectedPropertyCard extends StatelessWidget {
  const _SelectedPropertyCard({required this.property, required this.estate});

  final CmsPropertyFeatured? property;
  final CmsEstateSummary? estate;

  @override
  Widget build(BuildContext context) {
    final location = [
      property?.city,
      property?.state,
      estate?.city,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toSet();
    final locationLabel = location.isEmpty
        ? (estate?.name ?? 'Select a property to continue')
        : location.join(', ');
    final price = property?.priceLabel?.trim().isNotEmpty == true
        ? property!.priceLabel!
        : (property?.listingPrice == null
              ? 'Price on request'
              : '₦${NumberFormat('#,##0').format(property!.listingPrice)}');
    final status = property?.marketingStatus ?? 'Available';

    return LuxuryCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your selected property',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.heart,
                  size: 18,
                  color: InspectionLux.gold.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 86,
                    height: 72,
                    child: property?.coverImageUrl == null
                        ? ColoredBox(
                            color: InspectionLux.elevated,
                            child: const Center(
                              child: Icon(
                                LucideIcons.image,
                                color: InspectionLux.muted,
                                size: 22,
                              ),
                            ),
                          )
                        : MediaDeliveryImage(
                            url: property!.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: const ColoredBox(
                              color: InspectionLux.elevated,
                              child: Center(
                                child: Icon(
                                  LucideIcons.image,
                                  color: InspectionLux.muted,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property?.title ?? 'No property selected',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 12,
                            color: InspectionLux.gold,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: InspectionLux.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF12151B),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(InspectionLux.radius),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 14,
                  color: InspectionLux.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: InspectionLux.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

String? _propertyTypeLabel(CmsPropertyFeatured? property) {
  if (property == null) return null;
  final type = property.propertyType?.trim();
  if (property.bedrooms != null) {
    final unit = (type == null || type.isEmpty) ? 'Duplex' : type;
    if (unit.toLowerCase().contains('bedroom')) return unit;
    return '${property.bedrooms} Bedroom $unit';
  }
  return type;
}

class InspectionSummaryCard extends StatelessWidget {
  const InspectionSummaryCard({
    super.key,
    required this.estateName,
    required this.propertyName,
    required this.draft,
    required this.advisorName,
    this.propertyType,
  });

  final String? estateName;
  final String? propertyName;
  final String? propertyType;
  final InspectionBookingDraft draft;
  final String? advisorName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SidebarTitle(
          title: 'Inspection summary',
          icon: LucideIcons.calendar,
        ),
        const SizedBox(height: 14),
        _SummaryRow(label: 'Estate', value: estateName ?? '—'),
        _SummaryRow(
          label: 'Property type',
          value: propertyType ?? propertyName ?? '—',
        ),
        _SummaryRow(
          label: 'Date',
          value: draft.preferredDate == null
              ? '—'
              : DateFormat('d MMM yyyy').format(draft.preferredDate!),
        ),
        _SummaryRow(label: 'Time', value: draft.preferredTime?.label ?? '—'),
        _SummaryRow(
          label: 'Meeting type',
          value: draft.meetingType == InspectionMeetingType.virtual
              ? 'Virtual tour'
              : 'Physical tour',
        ),
        if (draft.meetingType == InspectionMeetingType.physical)
          _SummaryRow(
            label: 'Arrival',
            value: switch (draft.meetupMode) {
              InspectionMeetupMode.meetAtProperty => 'Meet at property',
              InspectionMeetupMode.meetAtOffice =>
                draft.meetupOfficeLabel ?? 'HD Homes office',
              InspectionMeetupMode.pickup => draft.pickupAddress.trim().isEmpty
                  ? 'Pickup arranged'
                  : 'Pickup: ${draft.pickupAddress.trim()}',
            },
          ),
        _SummaryRow(label: 'Advisor', value: advisorName ?? 'HD Homes Experts'),
        const _SummaryRow(label: 'Est. duration', value: '60–90 mins'),
        const _SummaryRow(label: 'Travel buffer', value: '30 mins'),
      ],
    );
  }
}

class _SidebarTitle extends StatelessWidget {
  const _SidebarTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        Icon(icon, size: 16, color: InspectionLux.gold),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: InspectionLux.muted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBar extends StatelessWidget {
  const _TrustBar();

  @override
  Widget build(BuildContext context) {
    final items = const [
      (LucideIcons.shieldCheck, 'Secure & Private', 'Your data is protected'),
      (LucideIcons.clock, 'Fast Response', "We'll contact you shortly"),
      (
        LucideIcons.calendar,
        'Flexible Scheduling',
        'Pick a time that works for you',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final children = [
          for (final item in items)
            _TrustItem(icon: item.$1, title: item.$2, subtitle: item.$3),
        ];
        if (stacked) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: InspectionLux.gold.withValues(alpha: 0.55),
            ),
          ),
          child: Icon(icon, size: 18, color: InspectionLux.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: InspectionLux.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: InspectionLux.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: InspectionLux.gold, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: InspectionLux.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.reference,
    required this.onReset,
    this.inspectionId,
  });

  final String reference;
  final VoidCallback onReset;
  final String? inspectionId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: InspectionLux.bg,
      child: PageContainer(
        child: Align(
          alignment: Alignment.topCenter,
          child: LuxuryCard(
            margin: const EdgeInsets.symmetric(vertical: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.checkCircle2,
                  color: InspectionLux.gold,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Inspection booked',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reference $reference',
                  style: const TextStyle(color: InspectionLux.goldLight),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Our team will confirm your slot shortly via email and SMS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: InspectionLux.muted),
                ),
                if (inspectionId != null && inspectionId!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Consumer(
                    builder: (context, ref, _) {
                      ref.watch(inspectionBookingRealtimeProvider);
                      final statusAsync = ref.watch(
                        inspectionBookingStatusProvider(inspectionId!),
                      );
                      return statusAsync.when(
                        loading: () => const Text(
                          'Checking latest booking status…',
                          style: TextStyle(
                            color: InspectionLux.muted,
                            fontSize: 12,
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (row) {
                          if (row == null) return const SizedBox.shrink();
                          final status = '${row['status'] ?? 'scheduled'}';
                          final color = switch (status) {
                            'confirmed' => AppColors.success,
                            'completed' => Colors.blueAccent,
                            'cancelled' => AppColors.error,
                            'no_show' => Colors.orangeAccent,
                            _ => InspectionLux.gold,
                          };
                          final label = status.replaceAll('_', ' ').trim();
                          final pretty = label.isEmpty
                              ? 'Scheduled'
                              : '${label[0].toUpperCase()}${label.substring(1)}';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: color.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              'Status: $pretty',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                PremiumButton(
                  label: 'Book another inspection',
                  onPressed: onReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
