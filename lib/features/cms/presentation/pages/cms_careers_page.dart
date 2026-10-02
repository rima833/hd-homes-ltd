import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/career_applications_inbox.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Careers: settings + jobs + why-join + stats.
class CmsCareersPage extends ConsumerStatefulWidget {
  const CmsCareersPage({super.key});

  @override
  ConsumerState<CmsCareersPage> createState() => _CmsCareersPageState();
}

class _CmsCareersPageState extends ConsumerState<CmsCareersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(cmsCareersSettingsProvider);
    ref.invalidate(cmsCareerJobsProvider);
    ref.invalidate(cmsCareerBenefitsProvider);
    ref.invalidate(cmsCareerStatsProvider);
    ref.invalidate(publishedCareersSettingsProvider);
    ref.invalidate(publishedCareerJobsProvider);
    ref.invalidate(publishedCareerBenefitsProvider);
    ref.invalidate(publishedCareerStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Careers CMS',
            subtitle:
                'Manages the premium Careers UI on /about and /careers — hero, stats, why-join cards, jobs, and CV banner.',
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Settings'),
              Tab(text: 'Jobs'),
              Tab(text: 'Applications'),
              Tab(text: 'Why Join'),
              Tab(text: 'Stats'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SettingsTab(onChanged: _invalidate),
                _JobsTab(onChanged: _invalidate),
                const CareerApplicationsInbox(),
                _BenefitsTab(onChanged: _invalidate),
                _StatsTab(onChanged: _invalidate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'active' => 'Published',
      'closed' => 'Closed',
      _ => 'Draft',
    };
    final color = switch (status) {
      'active' => AppColors.success,
      'closed' => AppColors.warning,
      _ => AppColors.slate500,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Settings ───────────────────────────────────────────────────────────────

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCareersSettingsProvider);
    return async.when(
      loading: () => const AdminLoadingView(),
      error: (e, _) => AdminErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(cmsCareersSettingsProvider),
      ),
      data: (settings) {
        if (settings == null) {
          return const AdminEmptyState(
            title: 'Settings unavailable',
            message: 'Connect Supabase to manage careers content.',
            icon: LucideIcons.settings,
          );
        }
        return _SettingsForm(settings: settings, onChanged: onChanged);
      },
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, required this.onChanged});

  final CmsCareersSettings settings;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late TextEditingController _overline;
  late TextEditingController _title1;
  late TextEditingController _title2;
  late TextEditingController _body;
  late TextEditingController _imageUrl;
  late TextEditingController _ctaPrimary;
  late TextEditingController _ctaSecondary;
  late TextEditingController _cvText;
  late TextEditingController _cvCta;
  late TextEditingController _cvEmail;
  late TextEditingController _seoTitle;
  late TextEditingController _seoDescription;
  late TextEditingController _openOverride;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _overline = TextEditingController(text: s.heroOverline);
    _title1 = TextEditingController(text: s.heroTitleLine1);
    _title2 = TextEditingController(text: s.heroTitleLine2);
    _body = TextEditingController(text: s.heroBody);
    _imageUrl = TextEditingController(text: s.heroImageUrl ?? '');
    _ctaPrimary = TextEditingController(text: s.ctaPrimaryLabel);
    _ctaSecondary = TextEditingController(text: s.ctaSecondaryLabel);
    _cvText = TextEditingController(text: s.cvBannerText);
    _cvCta = TextEditingController(text: s.cvBannerCtaLabel);
    _cvEmail = TextEditingController(text: s.cvEmail);
    _seoTitle = TextEditingController(text: s.seoTitle ?? '');
    _seoDescription = TextEditingController(text: s.seoDescription ?? '');
    _openOverride = TextEditingController(
      text: s.openPositionsOverride?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _overline.dispose();
    _title1.dispose();
    _title2.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _ctaPrimary.dispose();
    _ctaSecondary.dispose();
    _cvText.dispose();
    _cvCta.dispose();
    _cvEmail.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    _openOverride.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read image bytes.');
      }
      final url = await ref.read(cmsServiceProvider).uploadCareersHeroImage(
            bytes: bytes,
            contentType: file?.extension == 'png' ? 'image/png' : 'image/jpeg',
          );
      _imageUrl.text = url;
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final overrideText = _openOverride.text.trim();
      await ref.read(cmsServiceProvider).upsertCareersSettings(
            id: widget.settings.id,
            heroOverline: _overline.text.trim(),
            heroTitleLine1: _title1.text.trim(),
            heroTitleLine2: _title2.text.trim(),
            heroBody: _body.text.trim(),
            heroImageUrl: _imageUrl.text.trim().isEmpty
                ? null
                : _imageUrl.text.trim(),
            cultureSummary: widget.settings.cultureSummary,
            aboutSubtitle: widget.settings.aboutSubtitle,
            ctaPrimaryLabel: _ctaPrimary.text.trim(),
            ctaSecondaryLabel: _ctaSecondary.text.trim(),
            cvBannerText: _cvText.text.trim(),
            cvBannerCtaLabel: _cvCta.text.trim(),
            cvEmail: _cvEmail.text.trim(),
            seoTitle: _seoTitle.text.trim().isEmpty
                ? null
                : _seoTitle.text.trim(),
            seoDescription: _seoDescription.text.trim().isEmpty
                ? null
                : _seoDescription.text.trim(),
            openPositionsOverride: overrideText.isEmpty
                ? null
                : int.tryParse(overrideText),
          );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Careers settings saved')),
        );
      }
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hero',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _field(_overline, 'Overline'),
              _field(_title1, 'Title line 1'),
              _field(_title2, 'Title line 2 (gold)'),
              _field(_body, 'Hero body', maxLines: 4),
              _field(_imageUrl, 'Hero image URL'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.upload, size: 16),
                label: Text(_uploading ? 'Uploading…' : 'Upload hero image'),
              ),
              const Divider(height: 32),
              Text(
                'CTAs & CV banner',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _field(_ctaPrimary, 'Primary CTA label'),
              _field(_ctaSecondary, 'Secondary CTA label'),
              _field(_cvText, 'CV banner text', maxLines: 3),
              _field(_cvCta, 'CV banner CTA'),
              _field(_cvEmail, 'Careers email'),
              _field(
                _openOverride,
                'Open positions override (blank = job count)',
              ),
              const Divider(height: 32),
              Text(
                'SEO',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _field(_seoTitle, 'SEO title'),
              _field(_seoDescription, 'SEO description', maxLines: 3),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.save, size: 16),
                  label: Text(_saving ? 'Saving…' : 'Save settings'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ApplicationSettingsCard(settingsId: widget.settings.id),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ApplicationSettingsCard extends ConsumerStatefulWidget {
  const _ApplicationSettingsCard({required this.settingsId});
  final String settingsId;

  @override
  ConsumerState<_ApplicationSettingsCard> createState() =>
      _ApplicationSettingsCardState();
}

class _ApplicationSettingsCardState
    extends ConsumerState<_ApplicationSettingsCard> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(careerApplicationSettingsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) => _ApplicationSettingsForm(
        settingsId: widget.settingsId,
        settings: s,
      ),
    );
  }
}

class _ApplicationSettingsForm extends ConsumerStatefulWidget {
  const _ApplicationSettingsForm({
    required this.settingsId,
    required this.settings,
  });
  final String settingsId;
  final CareerApplicationSettings settings;

  @override
  ConsumerState<_ApplicationSettingsForm> createState() =>
      _ApplicationSettingsFormState();
}

class _ApplicationSettingsFormState
    extends ConsumerState<_ApplicationSettingsForm> {
  late bool _enabled;
  late bool _general;
  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _disabled;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.applicationsEnabled;
    _general = widget.settings.allowGeneralApplication;
    _title = TextEditingController(text: widget.settings.confirmationTitle);
    _message = TextEditingController(text: widget.settings.confirmationMessage);
    _disabled = TextEditingController(text: widget.settings.disabledMessage);
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _disabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Public application form', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Applications enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow general applications'),
            value: _general,
            onChanged: (v) => setState(() => _general = v),
          ),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Confirmation title')),
          const SizedBox(height: 8),
          TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Confirmation message')),
          const SizedBox(height: 8),
          TextField(controller: _disabled, maxLines: 2, decoration: const InputDecoration(labelText: 'Disabled message')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await ref.read(websiteFormsAdminServiceProvider).saveCareerApplicationSettings(
                          settingsId: widget.settingsId,
                          enabled: _enabled,
                          confirmationTitle: _title.text,
                          confirmationMessage: _message.text,
                          maxCvBytes: widget.settings.maxCvBytes,
                          allowGeneral: _general,
                          disabledMessage: _disabled.text,
                        );
                    ref.invalidate(careerApplicationSettingsProvider);
                    if (mounted) setState(() => _saving = false);
                  },
            child: Text(_saving ? 'Saving…' : 'Save application settings'),
          ),
        ],
      ),
    );
  }
}

// ─── Jobs ───────────────────────────────────────────────────────────────────

class _JobsTab extends ConsumerWidget {
  const _JobsTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCareerJobsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _open(context, ref, null),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add job'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const AdminLoadingView(),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(cmsCareerJobsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AdminEmptyState(
                  title: 'No job openings',
                  message: 'Publish roles for the Current Opportunities carousel.',
                  icon: LucideIcons.briefcase,
                  action: FilledButton.icon(
                    onPressed: () => _open(context, ref, null),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add job'),
                  ),
                );
              }
              return ReorderableListView.builder(
                itemCount: items.length,
                buildDefaultDragHandles: false,
                onReorder: (o, n) => _reorder(ref, items, o, n),
                itemBuilder: (context, i) {
                  final job = items[i];
                  final active = job.status == 'active';
                  return ReorderableDragStartListener(
                    key: ValueKey(job.id),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminCard(
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.gripVertical,
                              size: 18,
                              color: AppColors.slate500,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${job.department} · ${job.location} · ${job.employmentType}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.slate500),
                                  ),
                                  const SizedBox(height: 6),
                                  _StatusChip(status: job.status),
                                ],
                              ),
                            ),
                            Switch(
                              value: active,
                              activeTrackColor: AppColors.gold,
                              onChanged: (v) async {
                                await ref.read(cmsServiceProvider).upsertCareerJob(
                                      id: job.id,
                                      title: job.title,
                                      department: job.department,
                                      location: job.location,
                                      employmentType: job.employmentType,
                                      summary: job.summary,
                                      description: job.description,
                                      requirements: job.requirements,
                                      applicationDeadline: job.applicationDeadline,
                                      iconName: job.iconName,
                                      applyUrl: job.applyUrl,
                                      sortOrder: job.sortOrder,
                                      isFeatured: job.isFeatured,
                                      status: v ? 'active' : 'draft',
                                    );
                                onChanged();
                              },
                            ),
                            IconButton(
                              onPressed: () => _open(context, ref, job),
                              icon: const Icon(LucideIcons.pencil, size: 18),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(cmsServiceProvider)
                                    .deleteCareerJob(job.id);
                                onChanged();
                              },
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsCareerJob> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < reordered.length; i++) {
      final next = (i + 1) * 10;
      if (reordered[i].sortOrder != next) {
        await service.setCareerJobSortOrder(reordered[i].id, next);
      }
    }
    onChanged();
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CmsCareerJob? job,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _JobDialog(job: job),
    );
    onChanged();
  }
}

class _JobDialog extends ConsumerStatefulWidget {
  const _JobDialog({this.job});

  final CmsCareerJob? job;

  @override
  ConsumerState<_JobDialog> createState() => _JobDialogState();
}

class _JobDialogState extends ConsumerState<_JobDialog> {
  late TextEditingController _title;
  late TextEditingController _department;
  late TextEditingController _location;
  late TextEditingController _type;
  late TextEditingController _summary;
  late TextEditingController _description;
  late TextEditingController _requirements;
  late TextEditingController _deadline;
  late TextEditingController _icon;
  late TextEditingController _applyUrl;
  late TextEditingController _sort;
  bool _featured = false;
  bool _published = true;
  bool _closed = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _title = TextEditingController(text: j?.title ?? '');
    _department = TextEditingController(text: j?.department ?? '');
    _location = TextEditingController(text: j?.location ?? '');
    _type = TextEditingController(text: j?.employmentType ?? 'Full Time');
    _summary = TextEditingController(text: j?.summary ?? '');
    _description = TextEditingController(text: j?.description ?? '');
    _requirements = TextEditingController(text: j?.requirements ?? '');
    _deadline = TextEditingController(
      text: j?.applicationDeadline == null
          ? ''
          : j!.applicationDeadline!.toIso8601String().split('T').first,
    );
    _icon = TextEditingController(text: j?.iconName ?? 'briefcase');
    _applyUrl = TextEditingController(text: j?.applyUrl ?? '');
    _sort = TextEditingController(text: '${j?.sortOrder ?? 0}');
    _featured = j?.isFeatured ?? false;
    _closed = (j?.status ?? '') == 'closed';
    _published = (j?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _title.dispose();
    _department.dispose();
    _location.dispose();
    _type.dispose();
    _summary.dispose();
    _description.dispose();
    _requirements.dispose();
    _deadline.dispose();
    _icon.dispose();
    _applyUrl.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertCareerJob(
            id: widget.job?.id,
            title: _title.text.trim(),
            department: _department.text.trim(),
            location: _location.text.trim(),
            employmentType: _type.text.trim(),
            summary: _summary.text.trim(),
            description: _description.text.trim(),
            requirements: _requirements.text.trim(),
            applicationDeadline: _deadline.text.trim().isEmpty
                ? null
                : DateTime.tryParse(_deadline.text.trim()),
            iconName: _icon.text.trim().isEmpty ? 'briefcase' : _icon.text.trim(),
            applyUrl: _applyUrl.text.trim().isEmpty
                ? null
                : _applyUrl.text.trim(),
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            isFeatured: _featured,
            status: _closed
                ? 'closed'
                : (_published ? 'active' : 'draft'),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.job == null ? 'Add job' : 'Edit job'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tf(_title, 'Title'),
              _tf(_department, 'Department'),
              _tf(_location, 'Location'),
              _tf(_type, 'Employment type'),
              _tf(_summary, 'Summary', maxLines: 3),
              _tf(_description, 'Description', maxLines: 4),
              _tf(_requirements, 'Requirements', maxLines: 4),
              _tf(_deadline, 'Application deadline (YYYY-MM-DD, optional)'),
              _tf(_icon, 'Icon name'),
              _tf(_applyUrl, 'Apply URL (optional)'),
              _tf(_sort, 'Sort order'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Featured'),
                value: _featured,
                onChanged: (v) => setState(() => _featured = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published / open'),
                value: _published && !_closed,
                onChanged: (v) => setState(() {
                  _published = v;
                  if (v) _closed = false;
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Closed'),
                value: _closed,
                onChanged: (v) => setState(() {
                  _closed = v;
                  if (v) _published = false;
                }),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _tf(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// ─── Benefits ───────────────────────────────────────────────────────────────

class _BenefitsTab extends ConsumerWidget {
  const _BenefitsTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCareerBenefitsProvider);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _open(context, ref, null),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add card'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const AdminLoadingView(),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(cmsCareerBenefitsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AdminEmptyState(
                  title: 'No culture cards',
                  message: 'Add Why Join HD Homes cards.',
                  icon: LucideIcons.sparkles,
                  action: FilledButton.icon(
                    onPressed: () => _open(context, ref, null),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add card'),
                  ),
                );
              }
              return ReorderableListView.builder(
                itemCount: items.length,
                buildDefaultDragHandles: false,
                onReorder: (o, n) => _reorder(ref, items, o, n),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final active = item.status == 'active';
                  return ReorderableDragStartListener(
                    key: ValueKey(item.id),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminCard(
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.gripVertical,
                              size: 18,
                              color: AppColors.slate500,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (item.description.isNotEmpty)
                                    Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                  const SizedBox(height: 6),
                                  _StatusChip(status: active ? 'active' : 'draft'),
                                ],
                              ),
                            ),
                            Switch(
                              value: active,
                              activeTrackColor: AppColors.gold,
                              onChanged: (v) async {
                                await ref
                                    .read(cmsServiceProvider)
                                    .upsertCareerBenefit(
                                      id: item.id,
                                      title: item.title,
                                      description: item.description,
                                      iconName: item.iconName,
                                      sortOrder: item.sortOrder,
                                      status: v ? 'active' : 'draft',
                                    );
                                onChanged();
                              },
                            ),
                            IconButton(
                              onPressed: () => _open(context, ref, item),
                              icon: const Icon(LucideIcons.pencil, size: 18),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(cmsServiceProvider)
                                    .deleteCareerBenefit(item.id);
                                onChanged();
                              },
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsCareerBenefit> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < reordered.length; i++) {
      final next = (i + 1) * 10;
      if (reordered[i].sortOrder != next) {
        await service.setCareerBenefitSortOrder(reordered[i].id, next);
      }
    }
    onChanged();
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CmsCareerBenefit? item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BenefitDialog(item: item),
    );
    onChanged();
  }
}

class _BenefitDialog extends ConsumerStatefulWidget {
  const _BenefitDialog({this.item});

  final CmsCareerBenefit? item;

  @override
  ConsumerState<_BenefitDialog> createState() => _BenefitDialogState();
}

class _BenefitDialogState extends ConsumerState<_BenefitDialog> {
  late TextEditingController _title;
  late TextEditingController _description;
  late TextEditingController _icon;
  late TextEditingController _sort;
  bool _published = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _title = TextEditingController(text: i?.title ?? '');
    _description = TextEditingController(text: i?.description ?? '');
    _icon = TextEditingController(text: i?.iconName ?? 'sparkles');
    _sort = TextEditingController(text: '${i?.sortOrder ?? 0}');
    _published = (i?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _icon.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertCareerBenefit(
            id: widget.item?.id,
            title: _title.text.trim(),
            description: _description.text.trim(),
            iconName: _icon.text.trim().isEmpty ? 'sparkles' : _icon.text.trim(),
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add culture card' : 'Edit culture card'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _icon,
              decoration: const InputDecoration(
                labelText: 'Icon name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sort,
              decoration: const InputDecoration(
                labelText: 'Sort order',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              value: _published,
              onChanged: (v) => setState(() => _published = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

// ─── Stats ──────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCareerStatsProvider);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _open(context, ref, null),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add statistic'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const AdminLoadingView(),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(cmsCareerStatsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AdminEmptyState(
                  title: 'No career stats',
                  message: 'Add the four KPI cards under the hero.',
                  icon: LucideIcons.barChart3,
                  action: FilledButton.icon(
                    onPressed: () => _open(context, ref, null),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add statistic'),
                  ),
                );
              }
              return ReorderableListView.builder(
                itemCount: items.length,
                buildDefaultDragHandles: false,
                onReorder: (o, n) => _reorder(ref, items, o, n),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final active = item.status == 'active';
                  return ReorderableDragStartListener(
                    key: ValueKey(item.id),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AdminCard(
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.gripVertical,
                              size: 18,
                              color: AppColors.slate500,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.value} · ${item.label}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  _StatusChip(status: active ? 'active' : 'draft'),
                                ],
                              ),
                            ),
                            Switch(
                              value: active,
                              activeTrackColor: AppColors.gold,
                              onChanged: (v) async {
                                await ref
                                    .read(cmsServiceProvider)
                                    .upsertCareerStat(
                                      id: item.id,
                                      value: item.value,
                                      label: item.label,
                                      iconName: item.iconName,
                                      sortOrder: item.sortOrder,
                                      status: v ? 'active' : 'draft',
                                    );
                                onChanged();
                              },
                            ),
                            IconButton(
                              onPressed: () => _open(context, ref, item),
                              icon: const Icon(LucideIcons.pencil, size: 18),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(cmsServiceProvider)
                                    .deleteCareerStat(item.id);
                                onChanged();
                              },
                              icon: const Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsCareerStat> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < reordered.length; i++) {
      final next = (i + 1) * 10;
      if (reordered[i].sortOrder != next) {
        await service.setCareerStatSortOrder(reordered[i].id, next);
      }
    }
    onChanged();
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CmsCareerStat? item,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StatDialog(item: item),
    );
    onChanged();
  }
}

class _StatDialog extends ConsumerStatefulWidget {
  const _StatDialog({this.item});

  final CmsCareerStat? item;

  @override
  ConsumerState<_StatDialog> createState() => _StatDialogState();
}

class _StatDialogState extends ConsumerState<_StatDialog> {
  late TextEditingController _value;
  late TextEditingController _label;
  late TextEditingController _icon;
  late TextEditingController _sort;
  bool _published = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _value = TextEditingController(text: i?.value ?? '');
    _label = TextEditingController(text: i?.label ?? '');
    _icon = TextEditingController(text: i?.iconName ?? 'briefcase');
    _sort = TextEditingController(text: '${i?.sortOrder ?? 0}');
    _published = (i?.status ?? 'active') == 'active';
  }

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    _icon.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_value.text.trim().isEmpty || _label.text.trim().isEmpty) {
      setState(() => _error = 'Value and label are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertCareerStat(
            id: widget.item?.id,
            value: _value.text.trim(),
            label: _label.text.trim(),
            iconName: _icon.text.trim().isEmpty ? 'briefcase' : _icon.text.trim(),
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add statistic' : 'Edit statistic'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _value,
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _icon,
              decoration: const InputDecoration(
                labelText: 'Icon name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sort,
              decoration: const InputDecoration(
                labelText: 'Sort order',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Published'),
              value: _published,
              onChanged: (v) => setState(() => _published = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
