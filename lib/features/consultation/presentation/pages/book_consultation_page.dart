import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/features/consultation/domain/entities/consultation_booking_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/consultation_booking_controller.dart';
import 'package:hdhomesproject/features/consultation/presentation/widgets/consultation_luxury_kit.dart';
import 'package:hdhomesproject/features/contact/data/providers/office_directory_provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ConsultationPage = BookConsultationPage;

class BookConsultationPage extends ConsumerStatefulWidget {
  const BookConsultationPage({super.key, this.embedded = false});

  /// When true, omit page chrome used on the public route (nav inset + hero).
  final bool embedded;

  @override
  ConsumerState<BookConsultationPage> createState() =>
      _BookConsultationPageState();
}

class _BookConsultationPageState extends ConsumerState<BookConsultationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _notes = TextEditingController();
  final _purpose = TextEditingController();
  final _propertyRef = TextEditingController();
  final _estate = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(currentUserProvider);
      if (profile != null) {
        if (_name.text.trim().isEmpty) {
          _name.text = profile.displayName;
        }
        if (_phone.text.trim().isEmpty &&
            (profile.phone?.isNotEmpty ?? false)) {
          _phone.text = profile.phone!;
        }
        if (_email.text.trim().isEmpty) {
          _email.text = profile.email;
        }
        if (_company.text.trim().isEmpty &&
            (profile.company?.isNotEmpty ?? false)) {
          _company.text = profile.company!;
        }
        ref
            .read(consultationBookingControllerProvider.notifier)
            .patch(
              (d) => d.copyWith(
                fullName: _name.text,
                phone: _phone.text,
                email: _email.text,
                company: _company.text,
              ),
            );
      }
      final office = ref.read(selectedOfficeForBookingProvider);
      if (office != null) {
        ref
            .read(consultationBookingControllerProvider.notifier)
            .patch(
              (d) => d.copyWith(
                meetingMethod: ConsultationMeetingMethod.office,
                officeLocationId: office.location.id,
              ),
            );
        return;
      }
      // Embedded hub / tests may not sit under a GoRouter route.
      final go = GoRouter.maybeOf(context);
      final q = go?.state.uri.queryParameters ?? const <String, String>{};
      final officeId = q['office'];
      if (officeId != null && officeId.isNotEmpty) {
        ref
            .read(consultationBookingControllerProvider.notifier)
            .patch(
              (d) => d.copyWith(
                meetingMethod: ConsultationMeetingMethod.office,
                officeLocationId: officeId,
              ),
            );
      }
      final property = q['property'];
      if (property != null &&
          property.isNotEmpty &&
          _propertyRef.text.isEmpty) {
        _propertyRef.text = property;
      }
      final interest = q['interest'];
      if (interest != null && interest.isNotEmpty && _purpose.text.isEmpty) {
        _purpose.text = interest;
      }
      final notes = q['notes'];
      if (notes != null && notes.isNotEmpty && _notes.text.isEmpty) {
        _notes.text = notes;
      }
      final slug = q['slug'];
      if (slug != null && slug.isNotEmpty && _estate.text.isEmpty) {
        _estate.text = slug;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _company.dispose();
    _notes.dispose();
    _purpose.dispose();
    _propertyRef.dispose();
    _estate.dispose();
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
    final service = ref.read(consultationBookingServiceProvider);
    final urls = <String>[
      ...ref.read(consultationBookingControllerProvider).documentUrls,
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
        urls.add(
          await service.uploadDocument(
          bytes: bytes,
          filename: f.name,
          contentType: contentType,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed for ${f.name}: $e')),
        );
      }
    }
    ref
        .read(consultationBookingControllerProvider.notifier)
        .patch((d) => d.copyWith(documentUrls: urls));
  }

  Future<void> _submit() async {
    _syncFormToDraft();
    final err = ref
        .read(consultationBookingControllerProvider.notifier)
        .validateStep(2);
    if (err != null) {
      ref
          .read(consultationBookingControllerProvider.notifier)
          .patch((d) => d.copyWith(error: err, step: 2));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      ref.read(consultationBookingControllerProvider.notifier).setStep(0);
      return;
    }
    final ok = await ref
        .read(consultationBookingControllerProvider.notifier)
        .submit();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation booked successfully')),
      );
    }
  }

  void _syncFormToDraft() {
    ref
        .read(consultationBookingControllerProvider.notifier)
        .patch(
          (d) => d.copyWith(
            fullName: _name.text,
            phone: _phone.text,
            email: _email.text,
            company: _company.text,
            notes: _notes.text,
            purpose: _purpose.text.trim().isEmpty ? null : _purpose.text.trim(),
            propertyReference: _propertyRef.text.trim().isEmpty
                ? null
                : _propertyRef.text.trim(),
            preferredEstate: _estate.text.trim().isEmpty
                ? null
                : _estate.text.trim(),
          ),
        );
  }

  void _goNext() {
    _syncFormToDraft();
    if (draftStep == 0 && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final ok = ref
        .read(consultationBookingControllerProvider.notifier)
        .goNext();
    if (!ok) return;
  }

  int get draftStep => ref.read(consultationBookingControllerProvider).step;

  @override
  Widget build(BuildContext context) {
    // Skip realtime on Contact Hub embed — teardown freezes public navigation.
    if (!widget.embedded) {
      ref.watch(consultationSlotsRealtimeProvider);
    }
    final draft = ref.watch(consultationBookingControllerProvider);
    final departmentsAsync = ref.watch(consultationDepartmentsProvider);
    final department = selectedConsultationDepartment(ref);
    final advisor = selectedConsultationAdvisor(ref);
    final slotsAsync = ref.watch(consultationSlotsProvider(department?.id));
    // Dual-column on desktop (including hub embed) to match mockup scale.
    final wide = !context.isMobile &&
        MediaQuery.sizeOf(context).width >= 980;
    final advisors =
        ref.watch(consultationAdvisorsProvider(department?.id)).valueOrNull ??
        const <ConsultationAdvisor>[];

    if (draft.submittedReference != null) {
      return _SuccessView(
        reference: draft.submittedReference!,
        department: department,
        advisor: advisor,
        draft: draft,
        embedded: widget.embedded,
        onReset: () {
          _name.clear();
          _phone.clear();
          _email.clear();
          _company.clear();
          _notes.clear();
          _purpose.clear();
          _propertyRef.clear();
          _estate.clear();
          ref.read(consultationBookingControllerProvider.notifier).reset();
        },
      );
    }

    final stepBody = switch (draft.step) {
      0 => _PersonalStep(
        name: _name,
        phone: _phone,
        email: _email,
        company: _company,
      ),
      1 => departmentsAsync.when(
        loading: () => const _BookingDataState(
          message: 'Loading consultation departments…',
          loading: true,
        ),
        error: (error, stackTrace) => _BookingDataState(
          message:
              'Consultation departments could not be loaded. No booking options have been substituted.',
          onRetry: () => ref.invalidate(consultationDepartmentsProvider),
        ),
        data: (loadedDepartments) => loadedDepartments.isEmpty
            ? _BookingDataState(
                message: 'No consultation departments are currently available.',
                onRetry: () => ref.invalidate(consultationDepartmentsProvider),
              )
            : _TypeStep(
                departments: loadedDepartments,
                selectedSlug: draft.departmentSlug,
                meetingMethod: draft.meetingMethod,
                advisors: advisors,
                selectedAdvisorId: draft.advisorId,
                onDepartment: (d) {
                  final n = ref.read(
                    consultationBookingControllerProvider.notifier,
                  );
                  n.patch(
                    (x) => x.copyWith(
                      departmentSlug: d.slug,
                      clearSelectedSlot: true,
                      clearAdvisorId: true,
                    ),
                  );
                },
                onMethod: (m) => ref
                    .read(consultationBookingControllerProvider.notifier)
                    .patch((x) => x.copyWith(meetingMethod: m)),
                onAdvisor: (id) => ref
                    .read(consultationBookingControllerProvider.notifier)
                    .patch(
                      (x) => id == null
                          ? x.copyWith(clearAdvisorId: true)
                          : x.copyWith(advisorId: id),
                    ),
              ),
      ),
      2 => slotsAsync.when(
        loading: () => const _BookingDataState(
          message: 'Checking live consultation availability…',
          loading: true,
        ),
        error: (error, stackTrace) => _BookingDataState(
          message:
              'Open times could not be loaded. Retry before selecting a time.',
          onRetry: () => ref.invalidate(consultationSlotsProvider),
        ),
        data: (loadedSlots) => _ScheduleStep(
          draft: draft,
          slots: loadedSlots,
          purpose: _purpose,
          propertyRef: _propertyRef,
          estate: _estate,
          notes: _notes,
          documentCount: draft.documentUrls.length,
          onBrowse: _pickFiles,
        ),
      ),
      _ => _ReviewStep(
      draft: draft,
      department: department,
      advisor: advisor,
        onEditPersonal: () =>
            ref.read(consultationBookingControllerProvider.notifier).setStep(0),
        onEditType: () =>
            ref.read(consultationBookingControllerProvider.notifier).setStep(1),
        onEditSchedule: () =>
            ref.read(consultationBookingControllerProvider.notifier).setStep(2),
      ),
    };

    final nav = _StepNav(
      step: draft.step,
      submitting: draft.submitting,
      error: draft.error,
      onBack: draft.step > 0
          ? () => ref
                .read(consultationBookingControllerProvider.notifier)
                .goBack()
          : null,
      onNext: draft.step < 3 ? _goNext : null,
      onSubmit: draft.step == 3 ? (draft.submitting ? null : _submit) : null,
    );

    final left = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSection(child: stepBody),
          if (!wide && draft.step < 3) ...[
            const SizedBox(height: 20),
            ConsultationSidebar(
              department: department,
              advisor: advisor,
              draft: draft,
              ctaLabel: draft.step == 3 ? 'Book Consultation' : 'Continue',
              onSubmit: draft.step == 3 ? _submit : _goNext,
            ),
          ],
          const SizedBox(height: 24),
          nav,
          const SizedBox(height: 40),
        ],
      ),
    );

    final embedded = widget.embedded;
    final body = Column(
      children: [
        if (!embedded) ...[
          SizedBox(height: MediaQuery.paddingOf(context).top + 88),
          const ConsultationHero(),
          const SizedBox(height: 28),
        ],
        ProgressStepper(
          step: draft.step,
          onStepTap: (s) {
            if (s <= draft.step) {
              ref
                  .read(consultationBookingControllerProvider.notifier)
                  .setStep(s);
            }
          },
        ),
        SizedBox(height: embedded ? 20 : 32),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: left),
              const SizedBox(width: 24),
              Expanded(
                flex: 3,
                child: ConsultationSidebar(
                  department: department,
                  advisor: advisor,
                  draft: draft,
                  ctaLabel: draft.step == 3
                      ? 'Book Consultation'
                      : 'Continue',
                  onSubmit: draft.step == 3 ? _submit : _goNext,
                ),
              ),
            ],
          )
        else
          left,
        if (embedded) const SizedBox(height: 8),
      ],
    );

    if (embedded) {
      return ColoredBox(color: ConsultationLux.bg, child: body);
    }

    return ColoredBox(
      color: ConsultationLux.bg,
      child: PageContainer(maxWidth: 1600, child: body),
    );
  }
}

class _PersonalStep extends StatelessWidget {
  const _PersonalStep({
    required this.name,
    required this.phone,
    required this.email,
    required this.company,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController company;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: LucideIcons.user,
                    title: 'Personal Information',
            subtitle: 'Tell us about yourself.',
                  ),
                  const SizedBox(height: 20),
          PremiumTextField(
            label: 'Full name',
            controller: name,
            hint: 'Enter your full name',
            icon: LucideIcons.user,
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, c) {
              final stacked = c.maxWidth < 560;
                      final phoneField = PremiumTextField(
                label: 'Phone number',
                controller: phone,
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().length < 7) ? 'Required' : null,
                      );
                      final emailField = PremiumTextField(
                label: 'Email address',
                controller: email,
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Required' : null,
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
                          const SizedBox(height: 14),
          PremiumTextField(
            label: 'Company (optional)',
            controller: company,
            icon: LucideIcons.briefcase,
          ),
        ],
      ),
    );
  }
}

class _BookingDataState extends StatelessWidget {
  const _BookingDataState({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ConsultationLux.gold,
              ),
            )
          else
            const Icon(LucideIcons.info, color: ConsultationLux.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: ConsultationLux.muted),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({
    required this.departments,
    required this.selectedSlug,
    required this.meetingMethod,
    required this.advisors,
    required this.selectedAdvisorId,
    required this.onDepartment,
    required this.onMethod,
    required this.onAdvisor,
  });

  final List<ConsultationDepartment> departments;
  final String selectedSlug;
  final ConsultationMeetingMethod meetingMethod;
  final List<ConsultationAdvisor> advisors;
  final String? selectedAdvisorId;
  final ValueChanged<ConsultationDepartment> onDepartment;
  final ValueChanged<ConsultationMeetingMethod> onMethod;
  final ValueChanged<String?> onAdvisor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                icon: LucideIcons.layers,
                    title: 'Choose Consultation Department',
                subtitle: 'Select the team best suited to help you.',
                  ),
                  const SizedBox(height: 18),
                    DepartmentGrid(
                      departments: departments,
                selectedSlug: selectedSlug,
                onSelected: onDepartment,
                    ),
                ],
            ),
          ),
          const SizedBox(height: 20),
        MeetingMethodSelector(value: meetingMethod, onChanged: onMethod),
          const SizedBox(height: 20),
        LuxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                icon: LucideIcons.userCheck,
                title: 'Your Advisor',
                subtitle: 'We can assign the best available specialist.',
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => onAdvisor(null),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedAdvisorId == null
                        ? ConsultationLux.gold.withValues(alpha: 0.12)
                        : ConsultationLux.elevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedAdvisorId == null
                          ? ConsultationLux.gold
                          : ConsultationLux.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedAdvisorId == null
                            ? LucideIcons.checkCircle2
                            : LucideIcons.circle,
                          color: ConsultationLux.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Let HD Homes assign the best available advisor',
                          style: GoogleFonts.inter(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (advisors.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...advisors.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => onAdvisor(a.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedAdvisorId == a.id
                              ? ConsultationLux.gold.withValues(alpha: 0.12)
                              : ConsultationLux.elevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedAdvisorId == a.id
                                ? ConsultationLux.gold
                                : ConsultationLux.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: ConsultationLux.border,
                              backgroundImage: a.photoUrl != null
                                  ? NetworkImage(a.photoUrl!)
                                  : null,
                              child: a.photoUrl == null
                                  ? Text(
                                      a.fullName.isNotEmpty
                                          ? a.fullName[0]
                                          : 'A',
                                      style: const TextStyle(
                                        color: ConsultationLux.gold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.fullName,
                                    style: GoogleFonts.inter(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    a.title,
                                    style: GoogleFonts.inter(
                                      color: ConsultationLux.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${a.rating.toStringAsFixed(1)} · ${a.experienceYears}+ yrs · ${a.languages.join(', ')}',
                                    style: GoogleFonts.inter(
                                      color: ConsultationLux.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedAdvisorId == a.id)
                              const Icon(
                                LucideIcons.checkCircle2,
                                color: ConsultationLux.gold,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleStep extends ConsumerWidget {
  const _ScheduleStep({
    required this.draft,
    required this.slots,
    required this.purpose,
    required this.propertyRef,
    required this.estate,
    required this.notes,
    required this.documentCount,
    required this.onBrowse,
  });

  final ConsultationBookingDraft draft;
  final List<ConsultationSlot> slots;
  final TextEditingController purpose;
  final TextEditingController propertyRef;
  final TextEditingController estate;
  final TextEditingController notes;
  final int documentCount;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuxuryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: LucideIcons.calendar,
                title: 'Calendar',
                subtitle: 'Timezone: Africa/Lagos · open times update as they are booked',
              ),
              const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, c) {
                  final stacked = c.maxWidth < 720;
                        final calendar = LuxuryCalendar(
                    selectedDate: draft.selectedDate,
                          slots: slots,
                    onDateSelected: (day) {
                            ref
                          .read(consultationBookingControllerProvider.notifier)
                                .patch(
                            (x) => x.copyWith(
                              selectedDate: day,
                                    clearSelectedSlot: true,
                                  ),
                                );
                          },
                        );
                  final times = TimeSlotGrid(
                    slots: slots,
                    selectedDate: draft.selectedDate,
                          selected: draft.selectedSlot,
                    onSelected: (slot) {
                      ref
                          .read(consultationBookingControllerProvider.notifier)
                          .patch(
                            (x) => x.copyWith(
                              selectedSlot: slot,
                              selectedDate: slot.date,
                            ),
                          );
                    },
                        );
                        if (stacked) {
                          return Column(
                      children: [calendar, const SizedBox(height: 16), times],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: calendar),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: times),
                          ],
                        );
                      },
                    ),
                ],
            ),
          ),
          const SizedBox(height: 20),
        LuxuryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                icon: LucideIcons.fileText,
                    title: 'Additional Details',
                subtitle: 'Help us prepare for your consultation.',
                  ),
                  const SizedBox(height: 16),
              PremiumTextField(
                label: 'Purpose of consultation',
                controller: purpose,
                icon: LucideIcons.target,
              ),
              const SizedBox(height: 12),
              PremiumDropdown<String>(
                        label: 'Budget',
                        value: draft.budget,
                        hint: 'Select budget range',
                items:
                    const [
                          'Under ₦50M',
                          '₦50M – ₦100M',
                          '₦100M – ₦250M',
                          '₦250M – ₦500M',
                          'Above ₦500M',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => ref
                            .read(consultationBookingControllerProvider.notifier)
                    .patch((x) => x.copyWith(budget: v)),
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                label: 'Property reference',
                controller: propertyRef,
                icon: LucideIcons.hash,
              ),
              const SizedBox(height: 12),
              PremiumTextField(
                label: 'Preferred estate',
                controller: estate,
                icon: LucideIcons.mapPin,
              ),
              const SizedBox(height: 12),
              PremiumDropdown<String>(
                        label: 'Timeline',
                        value: draft.timeline,
                        hint: 'When do you plan to proceed?',
                items:
                    const [
                          'Immediately',
                          '1–3 months',
                          '3–6 months',
                          '6–12 months',
                          'Exploring',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => ref
                            .read(consultationBookingControllerProvider.notifier)
                    .patch((x) => x.copyWith(timeline: v)),
              ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                  'Investment interest',
                  style: TextStyle(color: AppColors.white),
                    ),
                activeThumbColor: ConsultationLux.gold,
                    value: draft.investmentInterest,
                    onChanged: (v) => ref
                        .read(consultationBookingControllerProvider.notifier)
                    .patch((x) => x.copyWith(investmentInterest: v)),
                  ),
                  PremiumTextField(
                label: 'Additional notes',
                controller: notes,
                    maxLines: 4,
                hint: 'Share anything we should prepare…',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        UploadCard(documentCount: documentCount, onBrowse: onBrowse),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.draft,
    required this.department,
    required this.advisor,
    required this.onEditPersonal,
    required this.onEditType,
    required this.onEditSchedule,
  });

  final ConsultationBookingDraft draft;
  final ConsultationDepartment? department;
  final ConsultationAdvisor? advisor;
  final VoidCallback onEditPersonal;
  final VoidCallback onEditType;
  final VoidCallback onEditSchedule;

  @override
  Widget build(BuildContext context) {
    final method = switch (draft.meetingMethod) {
      ConsultationMeetingMethod.phone => 'Phone',
      ConsultationMeetingMethod.video => 'Video Meeting',
      ConsultationMeetingMethod.office => 'Office Meeting',
    };
    final date = draft.selectedSlot?.scheduledAt;
    final dateLabel = date == null
        ? '—'
        : DateFormat('EEEE, d MMMM yyyy').format(date.toLocal());
    final timeLabel = date == null
        ? '—'
        : '${DateFormat('h:mm a').format(date.toLocal())} WAT';

    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: LucideIcons.clipboardCheck,
            title: 'Review & Confirm',
            subtitle: 'Confirm your private consultation details.',
          ),
          const SizedBox(height: 20),
          _ReviewBlock(
            title: 'Personal details',
            onEdit: onEditPersonal,
            rows: [
              ('Name', draft.fullName),
              ('Phone', draft.phone),
              ('Email', draft.email),
              if (draft.company.trim().isNotEmpty) ('Company', draft.company),
            ],
          ),
          const SizedBox(height: 14),
          _ReviewBlock(
            title: 'Consultation',
            onEdit: onEditType,
            rows: [
              ('Department', department?.name ?? draft.departmentSlug),
              ('Meeting', method),
              ('Advisor', advisor?.fullName ?? 'Best available'),
              ('Duration', '${department?.durationMinutes ?? 45} minutes'),
            ],
          ),
          const SizedBox(height: 14),
          _ReviewBlock(
            title: 'Schedule',
            onEdit: onEditSchedule,
            rows: [
              ('Date', dateLabel),
              ('Time', timeLabel),
              if (draft.purpose != null) ('Purpose', draft.purpose!),
              if (draft.budget != null) ('Budget', draft.budget!),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ConsultationLux.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ConsultationLux.gold.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Price: Free Consultation',
              style: GoogleFonts.inter(
                color: ConsultationLux.goldLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsultationLux.elevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConsultationLux.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: ConsultationLux.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          for (final row in rows) ...[
            const SizedBox(height: 8),
            _SummaryRow(row.$1, row.$2),
          ],
        ],
      ),
    );
  }
}

class _StepNav extends StatelessWidget {
  const _StepNav({
    required this.step,
    required this.submitting,
    required this.error,
    this.onBack,
    this.onNext,
    this.onSubmit,
  });

  final int step;
  final bool submitting;
  final String? error;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
              error!,
                style: const TextStyle(color: ConsultationLux.danger),
              ),
            ),
        if (onSubmit != null)
          PremiumButton(
            label: 'Book Consultation',
            loading: submitting,
            onPressed: onSubmit,
          )
        else if (onNext != null)
          PremiumButton(
            label: step == 0
                ? 'Continue'
                : step == 1
                ? 'Continue to Schedule'
                : 'Review Booking',
            onPressed: onNext,
          ),
        if (onBack != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: onBack,
            child: const Text(
              'Back',
              style: TextStyle(color: ConsultationLux.gold),
            ),
          ),
        ],
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.shieldCheck,
                size: 14,
                color: ConsultationLux.gold,
              ),
              SizedBox(width: 6),
              Text(
                'Your information is 100% secure',
                style: TextStyle(color: ConsultationLux.muted, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}

class ConsultationHero extends StatelessWidget {
  const ConsultationHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'CONSULTATION',
          style: GoogleFonts.inter(
                color: ConsultationLux.gold,
                fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
            fontSize: 12,
              ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            style: GoogleFonts.playfairDisplay(
              color: AppColors.white,
              fontSize: context.isMobile ? 32 : 44,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
            children: [
              const TextSpan(text: 'Book Your '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      ConsultationLux.goldGradient.createShader(bounds),
                  child: Text(
                    'Private Consultation',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: context.isMobile ? 32 : 44,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Meet with our specialists in property sales, investment, legal advisory, construction, architecture, mortgages and strategic partnerships.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: ConsultationLux.muted,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class DepartmentGrid extends StatelessWidget {
  const DepartmentGrid({
    super.key,
    required this.departments,
    required this.selectedSlug,
    required this.onSelected,
  });

  final List<ConsultationDepartment> departments;
  final String selectedSlug;
  final ValueChanged<ConsultationDepartment> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000
            ? 4
            : c.maxWidth >= 700
            ? 3
            : c.maxWidth >= 480
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: departments.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: cols == 1 ? 2.4 : 0.95,
          ),
          itemBuilder: (context, i) {
            final d = departments[i];
            return DepartmentCard(
              department: d,
              selected: d.slug == selectedSlug,
              onTap: () => onSelected(d),
            );
          },
        );
      },
    );
  }
}

class DepartmentCard extends StatefulWidget {
  const DepartmentCard({
    super.key,
    required this.department,
    required this.selected,
    required this.onTap,
  });

  final ConsultationDepartment department;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<DepartmentCard> createState() => _DepartmentCardState();
}

class _DepartmentCardState extends State<DepartmentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover || selected ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: ConsultationLux.elevated,
            borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ConsultationLux.gold : ConsultationLux.border,
            width: selected ? 1.6 : 1,
          ),
            boxShadow: selected || _hover
              ? [
                  BoxShadow(
                      color: ConsultationLux.gold.withValues(alpha: 0.22),
                    blurRadius: 18,
                      offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                        Icon(
                          departmentIcon(widget.department.iconName),
                    color: ConsultationLux.gold,
                          size: 22,
                ),
                const Spacer(),
                        if (selected)
                          const Icon(
                            LucideIcons.checkCircle2,
                            color: ConsultationLux.gold,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                      widget.department.name,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                        widget.department.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ConsultationLux.muted,
                  fontSize: 12,
                          height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
                      'Response: ${widget.department.responseTimeLabel}',
                      style: const TextStyle(
                        color: ConsultationLux.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
                    const SizedBox(height: 4),
            Text(
                      '${widget.department.advisorCount} Advisors',
              style: const TextStyle(
                color: ConsultationLux.muted,
                fontSize: 11,
              ),
            ),
          ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData departmentIcon(String name) {
  switch (name) {
    case 'headset':
      return LucideIcons.headphones;
    case 'trending-up':
      return LucideIcons.trendingUp;
    case 'scale':
      return LucideIcons.scale;
    case 'hard-hat':
      return LucideIcons.hammer;
    case 'compass':
      return LucideIcons.compass;
    case 'landmark':
      return LucideIcons.landmark;
    case 'life-buoy':
      return LucideIcons.heartHandshake;
    case 'handshake':
      return LucideIcons.users;
    default:
      return LucideIcons.circle;
  }
}

class MeetingMethodSelector extends StatelessWidget {
  const MeetingMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ConsultationMeetingMethod value;
  final ValueChanged<ConsultationMeetingMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: LucideIcons.video,
            title: 'Meeting Method',
            subtitle: 'Choose how you would like to connect.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 700;
              final cards = [
                MeetingMethodCard(
                  title: 'Phone Consultation',
                  description: 'Speak directly with an advisor.',
                  benefit: 'Fast & personal',
                  duration: '30–45 mins',
                  wait: '~5 min wait',
                  icon: LucideIcons.phone,
                  selected: value == ConsultationMeetingMethod.phone,
                  onTap: () => onChanged(ConsultationMeetingMethod.phone),
                ),
                MeetingMethodCard(
                  title: 'Video Consultation',
                  description: 'Face-to-face virtual meeting.',
                  benefit: 'Screen share ready',
                  duration: '45 mins',
                  wait: 'Immediate',
                  icon: LucideIcons.video,
                  selected: value == ConsultationMeetingMethod.video,
                  onTap: () => onChanged(ConsultationMeetingMethod.video),
                ),
                MeetingMethodCard(
                  title: 'Office Meeting',
                  description: 'Visit our HD Homes lounge.',
                  benefit: 'Premium hospitality',
                  duration: '60 mins',
                  wait: 'By appointment',
                  icon: LucideIcons.building2,
                  selected: value == ConsultationMeetingMethod.office,
                  onTap: () => onChanged(ConsultationMeetingMethod.office),
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      cards[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class MeetingMethodCard extends StatelessWidget {
  const MeetingMethodCard({
    super.key,
    required this.title,
    required this.description,
    required this.benefit,
    required this.duration,
    required this.wait,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final String benefit;
  final String duration;
  final String wait;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ConsultationLux.elevated,
        borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? ConsultationLux.gold : ConsultationLux.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ConsultationLux.gold.withValues(alpha: 0.2),
                  blurRadius: 16,
                  ),
                ]
              : null,
        ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: ConsultationLux.gold, size: 26),
                const Spacer(),
                Icon(
                  selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                  color: selected
                      ? ConsultationLux.gold
                      : ConsultationLux.muted,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: ConsultationLux.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              benefit,
              style: const TextStyle(
                color: ConsultationLux.goldLight,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$duration · $wait',
              style: const TextStyle(
                color: ConsultationLux.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LuxuryCalendar extends StatelessWidget {
  const LuxuryCalendar({
    super.key,
    required this.selectedDate,
    required this.slots,
    required this.onDateSelected,
  });

  final DateTime? selectedDate;
  final List<ConsultationSlot> slots;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = selectedDate ?? DateTime(now.year, now.month);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final startWeekday = first.weekday % 7;
    final availableDays = {
      for (final s in slots.where((s) => s.available))
        DateTime(s.date.year, s.date.month, s.date.day),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsultationLux.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ConsultationLux.border),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: ConsultationLux.muted,
                      fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final date = DateTime(month.year, month.month, day);
              final hasSlots = availableDays.contains(date);
              final selected =
                  selectedDate != null &&
                  selectedDate!.year == date.year &&
                  selectedDate!.month == date.month &&
                  selectedDate!.day == date.day;
              final past = date.isBefore(
                DateTime(now.year, now.month, now.day),
              );
              return InkWell(
                onTap: past || !hasSlots ? null : () => onDateSelected(date),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected
                        ? ConsultationLux.gold
                        : hasSlots
                        ? ConsultationLux.success.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? ConsultationLux.gold
                          : hasSlots
                          ? ConsultationLux.success.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                  child: Text(
                      '$day',
                    style: TextStyle(
                        color: past
                            ? ConsultationLux.muted.withValues(alpha: 0.4)
                            : selected
                            ? ConsultationLux.bg
                            : AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedDate,
    required this.selected,
    required this.onSelected,
  });

  final List<ConsultationSlot> slots;
  final DateTime? selectedDate;
  final ConsultationSlot? selected;
  final ValueChanged<ConsultationSlot> onSelected;

  @override
  Widget build(BuildContext context) {
    final daySlots = selectedDate == null
        ? const <ConsultationSlot>[]
        : slots
              .where(
                (s) =>
                    s.date.year == selectedDate!.year &&
                    s.date.month == selectedDate!.month &&
                    s.date.day == selectedDate!.day,
              )
              .toList();

    Widget section(String title, String period) {
      final items = daySlots.where((s) => s.period == period).toList();
      if (items.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                Text(
            title,
                  style: const TextStyle(
              color: ConsultationLux.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
            Wrap(
            spacing: 8,
            runSpacing: 8,
              children: [
              for (final s in items)
                  _SlotChip(
                  slot: s,
                  selected: selected?.scheduledAt == s.scheduledAt,
                  onTap: s.available ? () => onSelected(s) : null,
                  ),
              ],
            ),
          const SizedBox(height: 14),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConsultationLux.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ConsultationLux.border),
      ),
      child: selectedDate == null
          ? const Text(
              'Select a date to view available slots.',
              style: TextStyle(color: ConsultationLux.muted),
            )
          : daySlots.isEmpty
          ? const Text(
              'No slots available for this date.',
              style: TextStyle(color: ConsultationLux.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section('Morning', 'morning'),
                section('Afternoon', 'afternoon'),
                section('Evening', 'evening'),
              ],
            ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final ConsultationSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = slot.available;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? ConsultationLux.gold.withValues(alpha: 0.18)
              : ConsultationLux.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? ConsultationLux.gold
                : available
                ? ConsultationLux.success
                : ConsultationLux.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  LucideIcons.check,
                size: 14,
                color: ConsultationLux.gold,
              ),
              ),
            Text(
              slot.label,
              style: TextStyle(
                color: available ? AppColors.white : ConsultationLux.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadCard extends StatelessWidget {
  const UploadCard({
    super.key,
    required this.documentCount,
    required this.onBrowse,
  });

  final int documentCount;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: LucideIcons.uploadCloud,
            title: 'Upload Documents',
            subtitle: 'PDF, DOCX, images · max 10MB each',
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onBrowse,
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: ConsultationLux.gold.withValues(alpha: 0.55),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.uploadCloud,
                      color: ConsultationLux.gold,
                      size: 32,
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
                        color: ConsultationLux.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: onBrowse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ConsultationLux.gold,
                        side: const BorderSide(color: ConsultationLux.gold),
                      ),
                      child: const Text('Browse Files'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConsultationSidebar extends StatelessWidget {
  const ConsultationSidebar({
    super.key,
    required this.department,
    required this.advisor,
    required this.draft,
    required this.onSubmit,
    this.ctaLabel = 'Confirm Consultation',
  });

  final ConsultationDepartment? department;
  final ConsultationAdvisor? advisor;
  final ConsultationBookingDraft draft;
  final VoidCallback onSubmit;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConsultationSummaryCard(
          department: department,
          advisor: advisor,
          draft: draft,
        ),
        const SizedBox(height: 14),
        PremiumButton(
          label: ctaLabel,
          loading: draft.submitting,
          onPressed: draft.submitting ? null : onSubmit,
        ),
      ],
    );
  }
}

class ConsultationSummaryCard extends StatelessWidget {
  const ConsultationSummaryCard({
    super.key,
    required this.department,
    required this.advisor,
    required this.draft,
  });

  final ConsultationDepartment? department;
  final ConsultationAdvisor? advisor;
  final ConsultationBookingDraft draft;

  @override
  Widget build(BuildContext context) {
    final method = switch (draft.meetingMethod) {
      ConsultationMeetingMethod.phone => 'Phone Consultation',
      ConsultationMeetingMethod.video => 'Video Meeting',
      ConsultationMeetingMethod.office => 'Office Meeting',
    };
    return LuxuryCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D2430), Color(0xFF0E1015)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.building2,
                    color: ConsultationLux.gold,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Consultation Summary',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: ConsultationLux.goldGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Free Consultation',
                        style: TextStyle(
                          color: ConsultationLux.bg,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow('Department', department?.name ?? '—'),
                _SummaryRow('Meeting Type', method),
                _SummaryRow(
                  'Date',
                  draft.selectedDate == null
                      ? '—'
                      : DateFormat(
                          'EEE, d MMM yyyy',
                        ).format(draft.selectedDate!),
                ),
                _SummaryRow('Time', draft.selectedSlot?.label ?? '—'),
                _SummaryRow('Advisor', advisor?.fullName ?? 'Auto-assigned'),
                _SummaryRow(
                  'Duration',
                  '${department?.durationMinutes ?? 45} minutes',
                ),
                _SummaryRow('Price', 'Complimentary'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
        Icon(icon, color: ConsultationLux.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ConsultationLux.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ConsultationLux.muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
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

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.reference,
    required this.onReset,
    this.department,
    this.advisor,
    this.draft,
    this.embedded = false,
  });

  final String reference;
  final VoidCallback onReset;
  final ConsultationDepartment? department;
  final ConsultationAdvisor? advisor;
  final ConsultationBookingDraft? draft;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final slot = draft?.selectedSlot?.scheduledAt;
    final method = switch (draft?.meetingMethod) {
      ConsultationMeetingMethod.phone => 'Phone',
      ConsultationMeetingMethod.video => 'Video Consultation',
      ConsultationMeetingMethod.office => 'Office Meeting',
      null => 'Consultation',
    };

    return ColoredBox(
      color: ConsultationLux.bg,
      child: PageContainer(
        maxWidth: 720,
        child: Padding(
          padding: EdgeInsets.only(
            top: embedded ? 24 : MediaQuery.paddingOf(context).top + 100,
            bottom: embedded ? 24 : 80,
          ),
          child: LuxuryCard(
            child: Column(
              children: [
                const Icon(
                  LucideIcons.checkCircle2,
                  color: ConsultationLux.success,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Consultation Confirmed',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your private consultation has been successfully booked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ConsultationLux.muted),
                ),
                const SizedBox(height: 24),
                _ReviewBlock(
                  title: 'Booking details',
                  onEdit: () {},
                  rows: [
                    ('Booking ID', reference),
                    ('Department', department?.name ?? '—'),
                    ('Advisor', advisor?.fullName ?? 'Assigned soon'),
                    ('Meeting', method),
                    if (slot != null)
                      (
                        'Date',
                        DateFormat('EEEE, d MMMM yyyy').format(slot.toLocal()),
                      ),
                    if (slot != null)
                      (
                        'Time',
                        '${DateFormat('h:mm a').format(slot.toLocal())} WAT',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                PremiumButton(
                      label: 'Add to Calendar',
                      onPressed: slot == null
                          ? null
                          : () => _addToCalendar(
                              reference: reference,
                              department: department?.name,
                              advisor: advisor?.fullName,
                              start: slot,
                              durationMinutes:
                                  department?.durationMinutes ?? 45,
                              method: method,
                            ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        if (embedded && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                          return;
                        }
                        context.go(RoutePaths.clientConsultations);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ConsultationLux.gold,
                        side: const BorderSide(color: ConsultationLux.gold),
                      ),
                      child: const Text('View Booking'),
                ),
              ],
            ),
                const SizedBox(height: 12),
                PremiumButton(label: 'Book Another', onPressed: onReset),
                if (!embedded) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.contact),
                    child: const Text(
                      'Back to Contact',
                      style: TextStyle(color: ConsultationLux.gold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addToCalendar({
    required String reference,
    required DateTime start,
    required int durationMinutes,
    required String method,
    String? department,
    String? advisor,
  }) async {
    final end = start.add(Duration(minutes: durationMinutes));
    String fmt(DateTime d) {
      final u = d.toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${u.year}${two(u.month)}${two(u.day)}T'
          '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
    }

    final title = Uri.encodeComponent(
      'HD Homes Consultation${department != null ? ' — $department' : ''}',
    );
    final details = Uri.encodeComponent(
      'Booking $reference\nMeeting: $method'
      '${advisor != null ? '\nAdvisor: $advisor' : ''}',
    );
    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=$title'
      '&dates=${fmt(start)}/${fmt(end)}'
      '&details=$details'
      '&ctz=Africa/Lagos',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
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
