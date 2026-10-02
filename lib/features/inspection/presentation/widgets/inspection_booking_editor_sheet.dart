import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_admin_models.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_admin_providers.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

Future<bool> showInspectionBookingEditor({
  required BuildContext context,
  required WidgetRef ref,
  AdminInspectionRow? existing,
  DateTime? initialDay,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InspectionBookingEditorDialog(
      existing: existing,
      initialDay: initialDay,
    ),
  );
  return result == true;
}

class _InspectionBookingEditorDialog extends ConsumerStatefulWidget {
  const _InspectionBookingEditorDialog({
    this.existing,
    this.initialDay,
  });

  final AdminInspectionRow? existing;
  final DateTime? initialDay;

  @override
  ConsumerState<_InspectionBookingEditorDialog> createState() =>
      _InspectionBookingEditorDialogState();
}

class _InspectionBookingEditorDialogState
    extends ConsumerState<_InspectionBookingEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _language;
  late final TextEditingController _meetingUrl;

  String? _propertyId;
  String? _advisorId;
  late String _status;
  late String _type;
  late DateTime _scheduledAt;
  bool _saving = false;
  String? _error;

  static const _types = [
    ('site_visit', 'Site visit'),
    ('virtual_tour', 'Virtual tour'),
    ('open_house', 'Open house'),
    ('investor_visit', 'Investor visit'),
    ('handover', 'Handover'),
  ];

  static const _statuses = [
    ('scheduled', 'Scheduled'),
    ('confirmed', 'Confirmed'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
    ('no_show', 'No-show'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.visitorName ?? '');
    _email = TextEditingController(text: e?.visitorEmail ?? '');
    _phone = TextEditingController(text: e?.visitorPhone ?? '');
    _language = TextEditingController(text: e?.preferredLanguage ?? '');
    _meetingUrl = TextEditingController(text: e?.meetingUrl ?? '');
    _propertyId = e?.propertyId;
    _advisorId = e?.advisorId;
    _status = e?.status ?? 'scheduled';
    _type = e?.inspectionType ?? 'site_visit';
    final day = widget.initialDay ?? DateTime.now().add(const Duration(days: 1));
    _scheduledAt = e?.scheduledAt.toLocal() ??
        DateTime(day.year, day.month, day.day, 10, 0);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _language.dispose();
    _meetingUrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_propertyId == null || _propertyId!.isEmpty) {
      setState(() => _error = 'Select a property');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(inspectionAdminServiceProvider).upsertInspection(
            AdminInspectionDraft(
              id: widget.existing?.id,
              propertyId: _propertyId!,
              scheduledAt: _scheduledAt,
              status: _status,
              inspectionType: _type,
              visitorName: _name.text.trim(),
              visitorEmail: _email.text.trim(),
              visitorPhone: _phone.text.trim(),
              advisorId: _advisorId,
              clearAdvisor: widget.existing != null && _advisorId == null,
              preferredLanguage: _language.text.trim(),
              meetingUrl: _meetingUrl.text.trim(),
              reason: widget.existing == null
                  ? 'Created by admin'
                  : 'Edited by admin',
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(adminInspectionPropertyOptionsProvider);
    final advisorsAsync = ref.watch(adminInspectionAdvisorOptionsProvider);
    final isEdit = widget.existing != null;
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');

    return Dialog(
      backgroundColor: InspectionAdminUi.surfaceElevated,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit inspection' : 'New inspection',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEdit
                              ? 'Update schedule, visitor, and assignment'
                              : 'Create a booking on behalf of a visitor',
                          style: const TextStyle(
                            color: InspectionAdminUi.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: InspectionAdminUi.border),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    propertiesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text(userFacingError(e),
                          style: const TextStyle(color: Colors.redAccent)),
                      data: (props) {
                        final selected = props.any((p) => p.id == _propertyId)
                            ? _propertyId
                            : null;
                        return DropdownButtonFormField<String>(
                          key: ValueKey('property-$selected'),
                          initialValue: selected,
                          dropdownColor: InspectionAdminUi.surface,
                          decoration: InspectionAdminUi.fieldDecoration(
                            'Property',
                            prefix: const Icon(LucideIcons.building2, size: 16),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            for (final p in props)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(p.title),
                              ),
                          ],
                          onChanged: (v) => setState(() => _propertyId = v),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InspectionAdminUi.fieldDecoration(
                          'Date & time',
                          prefix: const Icon(LucideIcons.calendar, size: 16),
                        ),
                        child: Text(
                          fmt.format(_scheduledAt),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('type-$_type'),
                            initialValue: _type,
                            dropdownColor: InspectionAdminUi.surface,
                            decoration:
                                InspectionAdminUi.fieldDecoration('Type'),
                            style: const TextStyle(color: Colors.white),
                            items: [
                              for (final t in _types)
                                DropdownMenuItem(
                                  value: t.$1,
                                  child: Text(t.$2),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? _type),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('status-$_status'),
                            initialValue: _status,
                            dropdownColor: InspectionAdminUi.surface,
                            decoration:
                                InspectionAdminUi.fieldDecoration('Status'),
                            style: const TextStyle(color: Colors.white),
                            items: [
                              for (final s in _statuses)
                                DropdownMenuItem(
                                  value: s.$1,
                                  child: Text(s.$2),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _status = v ?? _status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    advisorsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (advisors) {
                        final selected =
                            advisors.any((a) => a.id == _advisorId)
                                ? _advisorId
                                : null;
                        return DropdownButtonFormField<String?>(
                          key: ValueKey('advisor-$selected'),
                          initialValue: selected,
                          dropdownColor: InspectionAdminUi.surface,
                          decoration: InspectionAdminUi.fieldDecoration(
                            'Assigned agent',
                            prefix: const Icon(LucideIcons.user, size: 16),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Unassigned'),
                            ),
                            for (final a in advisors)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text(a.fullName),
                              ),
                          ],
                          onChanged: (v) => setState(() => _advisorId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Visitor details',
                      style: TextStyle(
                        color: InspectionAdminUi.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _name,
                      style: const TextStyle(color: Colors.white),
                      decoration: InspectionAdminUi.fieldDecoration('Full name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InspectionAdminUi.fieldDecoration('Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InspectionAdminUi.fieldDecoration('Phone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _language,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          InspectionAdminUi.fieldDecoration('Preferred language'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _meetingUrl,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          InspectionAdminUi.fieldDecoration('Meeting URL'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: InspectionAdminUi.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: InspectionAdminUi.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isEdit ? LucideIcons.save : LucideIcons.plus),
                    label: Text(isEdit ? 'Save changes' : 'Create booking'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
