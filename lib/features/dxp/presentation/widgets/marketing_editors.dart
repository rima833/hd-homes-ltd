import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

const _kCalendarChannels = [
  'blog',
  'email',
  'whatsapp',
  'social',
  'sms',
  'omni',
];

const _kCalendarStatuses = [
  'planned',
  'scheduled',
  'in_progress',
  'published',
  'cancelled',
];

Future<bool> showLandingPageEditor({
  required BuildContext context,
  required DxpService service,
  MediaService? mediaService,
  DxpLandingPage? existing,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _LandingPageEditorDialog(
      service: service,
      mediaService: mediaService,
      existing: existing,
    ),
  );
  return result ?? false;
}

Future<bool> showCampaignEditor({
  required BuildContext context,
  required DxpService service,
  DxpCampaign? existing,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _CampaignEditorDialog(
      service: service,
      existing: existing,
    ),
  );
  return result ?? false;
}

Future<bool> showCalendarEditor({
  required BuildContext context,
  required DxpService service,
  DxpCalendarItem? existing,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _CalendarEditorDialog(
      service: service,
      existing: existing,
    ),
  );
  return result ?? false;
}

class _LandingPageEditorDialog extends StatefulWidget {
  const _LandingPageEditorDialog({
    required this.service,
    this.mediaService,
    this.existing,
  });

  final DxpService service;
  final MediaService? mediaService;
  final DxpLandingPage? existing;

  @override
  State<_LandingPageEditorDialog> createState() =>
      _LandingPageEditorDialogState();
}

class _LandingPageEditorDialogState extends State<_LandingPageEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _headline;
  late final TextEditingController _subheadline;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _ctaUrl;
  late final TextEditingController _goal;
  String? _heroImageUrl;
  var _publish = false;
  var _saving = false;
  var _uploadingHero = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _headline = TextEditingController(text: e?.headline ?? '');
    _subheadline = TextEditingController(text: e?.subheadline ?? '');
    _ctaLabel = TextEditingController(text: e?.ctaLabel ?? '');
    _ctaUrl = TextEditingController(text: e?.ctaUrl ?? '');
    _goal = TextEditingController(text: e?.conversionGoal ?? '');
    _heroImageUrl = e?.heroImageUrl;
    _publish = e?.isPublished ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _headline.dispose();
    _subheadline.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _pickHero() async {
    final media = widget.mediaService;
    if (media == null || !media.isCloudinaryEnabled) {
      setState(() => _error = 'Cloudinary is not configured for uploads.');
      return;
    }
    setState(() {
      _uploadingHero = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read image bytes.');
      }
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : name.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      final asset = await media.uploadImage(
        UploadMediaRequest(
          bytes: bytes,
          contentType: contentType,
          originalFilename: file.name,
          entityType: MediaEntityType.marketing,
          entityId: widget.existing?.id,
          role: 'hero',
          folderName: 'Landing Heroes',
          title: _title.text.trim().isEmpty
              ? 'Landing hero'
              : '${_title.text.trim()} hero',
          isCover: true,
        ),
      );
      if (!mounted) return;
      setState(() => _heroImageUrl = asset.deliveryUrl);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploadingHero = false);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.upsertLandingPage(
        id: widget.existing?.id,
        title: title,
        slug: _slug.text.trim(),
        headline: _headline.text.trim().isEmpty ? null : _headline.text.trim(),
        subheadline: _subheadline.text.trim().isEmpty
            ? null
            : _subheadline.text.trim(),
        heroImageUrl: _heroImageUrl?.trim().isEmpty == true
            ? null
            : _heroImageUrl?.trim(),
        ctaLabel:
            _ctaLabel.text.trim().isEmpty ? null : _ctaLabel.text.trim(),
        ctaUrl: _ctaUrl.text.trim().isEmpty ? null : _ctaUrl.text.trim(),
        conversionGoal: _goal.text.trim().isEmpty ? null : _goal.text.trim(),
        status: _publish
            ? LandingPageStatus.published
            : (widget.existing?.status ?? LandingPageStatus.draft),
        publish: _publish,
      );
      if (mounted) Navigator.pop(context, true);
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
    final isEdit = widget.existing != null;
    final hero = _heroImageUrl?.trim();
    return AlertDialog(
      title: Text(isEdit ? 'Edit Landing Page' : 'New Landing Page'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  hintText: 'auto from title if empty',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _headline,
                decoration: const InputDecoration(labelText: 'Headline'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subheadline,
                decoration: const InputDecoration(labelText: 'Subheadline'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hero image (Cloudinary)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              if (hero != null && hero.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: MediaDeliveryImage(
                      url: hero,
                      fit: BoxFit.cover,
                      errorWidget: const ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: Icon(LucideIcons.imageOff),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: (_saving || _uploadingHero) ? null : _pickHero,
                    icon: _uploadingHero
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.upload, size: 16),
                    label: Text(
                      hero == null || hero.isEmpty
                          ? 'Upload hero'
                          : 'Replace hero',
                    ),
                  ),
                  if (hero != null && hero.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _heroImageUrl = null),
                      child: const Text('Clear'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctaLabel,
                decoration: const InputDecoration(labelText: 'CTA label'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctaUrl,
                decoration: const InputDecoration(labelText: 'CTA URL'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _goal,
                decoration:
                    const InputDecoration(labelText: 'Conversion goal'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish now'),
                subtitle: const Text(
                  'Live at /lp/{slug} when published.',
                ),
                value: _publish,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _publish = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _uploadingHero ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepBlack,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _CampaignEditorDialog extends StatefulWidget {
  const _CampaignEditorDialog({
    required this.service,
    this.existing,
  });

  final DxpService service;
  final DxpCampaign? existing;

  @override
  State<_CampaignEditorDialog> createState() => _CampaignEditorDialogState();
}

class _CampaignEditorDialogState extends State<_CampaignEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _channel;
  late final TextEditingController _code;
  late final TextEditingController _objective;
  late final TextEditingController _budget;
  late CampaignStatus _status;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _channel = TextEditingController(text: e?.channel ?? 'omni');
    _code = TextEditingController(text: e?.campaignCode ?? '');
    _objective = TextEditingController(text: e?.objective ?? '');
    _budget = TextEditingController(
      text: e == null || e.budgetAmount == 0
          ? ''
          : e.budgetAmount.toStringAsFixed(0),
    );
    _status = e?.status ?? CampaignStatus.draft;
  }

  @override
  void dispose() {
    _name.dispose();
    _channel.dispose();
    _code.dispose();
    _objective.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.upsertCampaign(
        id: widget.existing?.id,
        name: name,
        channel: _channel.text.trim().isEmpty ? 'omni' : _channel.text.trim(),
        campaignCode: _code.text.trim().isEmpty ? null : _code.text.trim(),
        objective:
            _objective.text.trim().isEmpty ? null : _objective.text.trim(),
        budgetAmount: double.tryParse(_budget.text.trim()) ?? 0,
        status: _status,
      );
      if (mounted) Navigator.pop(context, true);
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
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Campaign' : 'New Campaign'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _channel,
                decoration: const InputDecoration(
                  labelText: 'Channel',
                  hintText: 'email · sms · social · omni',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Campaign code'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _objective,
                decoration: const InputDecoration(labelText: 'Objective'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _budget,
                decoration: const InputDecoration(
                  labelText: 'Budget (NGN)',
                  prefixIcon: Icon(LucideIcons.banknote, size: 16),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CampaignStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: CampaignStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _status = v);
                      },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepBlack,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _CalendarEditorDialog extends StatefulWidget {
  const _CalendarEditorDialog({
    required this.service,
    this.existing,
  });

  final DxpService service;
  final DxpCalendarItem? existing;

  @override
  State<_CalendarEditorDialog> createState() => _CalendarEditorDialogState();
}

class _CalendarEditorDialogState extends State<_CalendarEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _contentType;
  late final TextEditingController _owner;
  late final TextEditingController _notes;
  late String _channel;
  late String _status;
  late DateTime _scheduledFor;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _contentType = TextEditingController(text: e?.contentType ?? 'post');
    _owner = TextEditingController(text: e?.ownerLabel ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _channel = e?.channel ?? 'blog';
    if (!_kCalendarChannels.contains(_channel)) {
      _channel = 'blog';
    }
    _status = e?.status ?? 'planned';
    if (!_kCalendarStatuses.contains(_status)) {
      _status = 'planned';
    }
    _scheduledFor = e?.scheduledFor ??
        DateTime.now().add(const Duration(days: 1)).copyWith(
              hour: 10,
              minute: 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );
  }

  @override
  void dispose() {
    _title.dispose();
    _contentType.dispose();
    _owner.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledFor),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledFor = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.upsertCalendarItem(
        id: widget.existing?.id,
        title: title,
        scheduledFor: _scheduledFor,
        channel: _channel,
        contentType:
            _contentType.text.trim().isEmpty ? null : _contentType.text.trim(),
        status: _status,
        ownerLabel: _owner.text.trim().isEmpty ? null : _owner.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
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
    final isEdit = widget.existing != null;
    final whenLabel =
        DateFormat.yMMMd().add_jm().format(_scheduledFor.toLocal());
    return AlertDialog(
      title: Text(isEdit ? 'Edit Calendar Item' : 'New Calendar Item'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _channel,
                decoration: const InputDecoration(labelText: 'Channel'),
                items: _kCalendarChannels
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _channel = v);
                      },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentType,
                decoration: const InputDecoration(
                  labelText: 'Content type',
                  hintText: 'post · campaign · story',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _kCalendarStatuses
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        if (v != null) setState(() => _status = v);
                      },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Scheduled for'),
                subtitle: Text(whenLabel),
                trailing: IconButton(
                  tooltip: 'Pick date & time',
                  onPressed: _saving ? null : _pickSchedule,
                  icon: const Icon(LucideIcons.calendarClock),
                ),
              ),
              TextField(
                controller: _owner,
                decoration: const InputDecoration(labelText: 'Owner'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepBlack,
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
