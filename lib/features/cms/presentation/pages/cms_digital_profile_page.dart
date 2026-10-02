import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Digital Profile: content, downloads, and trust KPIs.
class CmsDigitalProfilePage extends ConsumerWidget {
  const CmsDigitalProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsDigitalCompanyProfileProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Digital company profile',
            subtitle:
                'About page profile card, PDF/brochure downloads, and trust KPIs — also used on Trust.',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () =>
                    ref.invalidate(cmsDigitalCompanyProfileProvider),
              ),
              data: (profile) {
                if (profile == null) {
                  return const AdminEmptyState(
                    title: 'Profile not found',
                    message: 'Could not load digital company profile settings.',
                    icon: LucideIcons.building2,
                  );
                }
                return _DigitalProfileEditor(profile: profile);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DigitalProfileEditor extends ConsumerStatefulWidget {
  const _DigitalProfileEditor({required this.profile});

  final CmsDigitalCompanyProfile profile;

  @override
  ConsumerState<_DigitalProfileEditor> createState() =>
      _DigitalProfileEditorState();
}

class _DigitalProfileEditorState extends ConsumerState<_DigitalProfileEditor> {
  late final TextEditingController _overline;
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _cardTitle;
  late final TextEditingController _cardDescription;
  late final TextEditingController _features;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _viewUrl;
  late final TextEditingController _mockupImageUrl;
  late final TextEditingController _pdfLabel;
  late final TextEditingController _pdfUrl;
  late final TextEditingController _pdfMeta;
  late final TextEditingController _brochureLabel;
  late final TextEditingController _brochureUrl;
  late final TextEditingController _brochureMeta;
  late final TextEditingController _trustMessage;
  late final TextEditingController _yearsValue;
  late final TextEditingController _yearsSuffix;
  late final TextEditingController _yearsLabel;
  late final TextEditingController _homesValue;
  late final TextEditingController _homesSuffix;
  late final TextEditingController _homesLabel;
  late final TextEditingController _clientsValue;
  late final TextEditingController _clientsSuffix;
  late final TextEditingController _clientsLabel;
  late final TextEditingController _projectsValue;
  late final TextEditingController _projectsSuffix;
  late final TextEditingController _projectsLabel;

  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _overline = TextEditingController(text: p.overline);
    _title = TextEditingController(text: p.title);
    _subtitle = TextEditingController(text: p.subtitle);
    _cardTitle = TextEditingController(text: p.cardTitle);
    _cardDescription = TextEditingController(text: p.cardDescription);
    _features = TextEditingController(text: p.features.join('\n'));
    _ctaLabel = TextEditingController(text: p.ctaLabel);
    _viewUrl = TextEditingController(text: p.viewUrl);
    _mockupImageUrl = TextEditingController(text: p.mockupImageUrl ?? '');
    _pdfLabel = TextEditingController(text: p.pdfLabel);
    _pdfUrl = TextEditingController(text: p.pdfUrl);
    _pdfMeta = TextEditingController(text: p.pdfMeta);
    _brochureLabel = TextEditingController(text: p.brochureLabel);
    _brochureUrl = TextEditingController(text: p.brochureUrl);
    _brochureMeta = TextEditingController(text: p.brochureMeta);
    _trustMessage = TextEditingController(text: p.trustMessage);
    _yearsValue = TextEditingController(text: '${p.yearsValue}');
    _yearsSuffix = TextEditingController(text: p.yearsSuffix);
    _yearsLabel = TextEditingController(text: p.yearsLabel);
    _homesValue = TextEditingController(text: '${p.homesValue}');
    _homesSuffix = TextEditingController(text: p.homesSuffix);
    _homesLabel = TextEditingController(text: p.homesLabel);
    _clientsValue = TextEditingController(text: '${p.clientsValue}');
    _clientsSuffix = TextEditingController(text: p.clientsSuffix);
    _clientsLabel = TextEditingController(text: p.clientsLabel);
    _projectsValue = TextEditingController(text: '${p.projectsValue}');
    _projectsSuffix = TextEditingController(text: p.projectsSuffix);
    _projectsLabel = TextEditingController(text: p.projectsLabel);
  }

  @override
  void dispose() {
    _overline.dispose();
    _title.dispose();
    _subtitle.dispose();
    _cardTitle.dispose();
    _cardDescription.dispose();
    _features.dispose();
    _ctaLabel.dispose();
    _viewUrl.dispose();
    _mockupImageUrl.dispose();
    _pdfLabel.dispose();
    _pdfUrl.dispose();
    _pdfMeta.dispose();
    _brochureLabel.dispose();
    _brochureUrl.dispose();
    _brochureMeta.dispose();
    _trustMessage.dispose();
    _yearsValue.dispose();
    _yearsSuffix.dispose();
    _yearsLabel.dispose();
    _homesValue.dispose();
    _homesSuffix.dispose();
    _homesLabel.dispose();
    _clientsValue.dispose();
    _clientsSuffix.dispose();
    _clientsLabel.dispose();
    _projectsValue.dispose();
    _projectsSuffix.dispose();
    _projectsLabel.dispose();
    super.dispose();
  }

  List<String> _parseFeatures() => _features.text
      .split(RegExp(r'[\n,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  int _intOf(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  Future<void> _uploadMockup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await ref.read(cmsServiceProvider).uploadDigitalProfileAsset(
            bytes: bytes,
            contentType: file?.extension == 'png' ? 'image/png' : 'image/jpeg',
            folder: 'digital-profile',
          );
      _mockupImageUrl.text = url;
      if (mounted) setState(() => _uploading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = userFacingError(e);
        });
      }
    }
  }

  Future<void> _uploadDoc({
    required TextEditingController urlCtrl,
    required TextEditingController metaCtrl,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final ext = (file?.extension ?? 'pdf').toLowerCase();
      final contentType = switch (ext) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        _ => 'application/octet-stream',
      };
      final url = await ref.read(cmsServiceProvider).uploadDigitalProfileAsset(
            bytes: bytes,
            contentType: contentType,
            folder: 'digital-profile/docs',
          );
      urlCtrl.text = url;
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      final now = DateTime.now();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      metaCtrl.text =
          '$mb MB | Updated ${months[now.month - 1]} ${now.day}, ${now.year}';
      if (mounted) setState(() => _uploading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = userFacingError(e);
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertDigitalCompanyProfile(
            id: widget.profile.id,
            overline: _overline.text.trim(),
            title: _title.text.trim(),
            subtitle: _subtitle.text.trim(),
            cardTitle: _cardTitle.text.trim(),
            cardDescription: _cardDescription.text.trim(),
            features: _parseFeatures(),
            ctaLabel: _ctaLabel.text.trim(),
            viewUrl: _viewUrl.text.trim(),
            mockupImageUrl: _mockupImageUrl.text.trim().isEmpty
                ? null
                : _mockupImageUrl.text.trim(),
            pdfLabel: _pdfLabel.text.trim(),
            pdfUrl: _pdfUrl.text.trim(),
            pdfMeta: _pdfMeta.text.trim(),
            brochureLabel: _brochureLabel.text.trim(),
            brochureUrl: _brochureUrl.text.trim(),
            brochureMeta: _brochureMeta.text.trim(),
            trustMessage: _trustMessage.text.trim(),
            yearsValue: _intOf(_yearsValue, widget.profile.yearsValue),
            yearsSuffix: _yearsSuffix.text.trim(),
            yearsLabel: _yearsLabel.text.trim(),
            homesValue: _intOf(_homesValue, widget.profile.homesValue),
            homesSuffix: _homesSuffix.text.trim(),
            homesLabel: _homesLabel.text.trim(),
            clientsValue: _intOf(_clientsValue, widget.profile.clientsValue),
            clientsSuffix: _clientsSuffix.text.trim(),
            clientsLabel: _clientsLabel.text.trim(),
            projectsValue: _intOf(_projectsValue, widget.profile.projectsValue),
            projectsSuffix: _projectsSuffix.text.trim(),
            projectsLabel: _projectsLabel.text.trim(),
          );
      ref.invalidate(cmsDigitalCompanyProfileProvider);
      ref.invalidate(publishedDigitalCompanyProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digital profile saved')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
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
                'Section header & interactive card',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _field(_overline, 'Overline'),
              _field(_title, 'Title'),
              _field(_subtitle, 'Subtitle', maxLines: 3),
              _field(_cardTitle, 'Card title'),
              _field(_cardDescription, 'Card description', maxLines: 4),
              _field(
                _features,
                'Features (one per line)',
                maxLines: 8,
              ),
              _field(_ctaLabel, 'CTA label'),
              _field(_viewUrl, 'View profile URL'),
              Row(
                children: [
                  Expanded(
                    child: _field(_mockupImageUrl, 'Mockup image URL'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadMockup,
                    icon: const Icon(LucideIcons.upload, size: 16),
                    label: Text(_uploading ? 'Uploading…' : 'Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Downloads',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _field(_pdfLabel, 'PDF label'),
              Row(
                children: [
                  Expanded(child: _field(_pdfUrl, 'PDF URL')),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _uploadDoc(
                              urlCtrl: _pdfUrl,
                              metaCtrl: _pdfMeta,
                            ),
                    icon: const Icon(LucideIcons.upload, size: 16),
                    label: const Text('Upload PDF'),
                  ),
                ],
              ),
              _field(_pdfMeta, 'PDF meta (size | updated)'),
              const SizedBox(height: 8),
              _field(_brochureLabel, 'Brochure label'),
              Row(
                children: [
                  Expanded(child: _field(_brochureUrl, 'Brochure URL')),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _uploadDoc(
                              urlCtrl: _brochureUrl,
                              metaCtrl: _brochureMeta,
                            ),
                    icon: const Icon(LucideIcons.upload, size: 16),
                    label: const Text('Upload brochure'),
                  ),
                ],
              ),
              _field(_brochureMeta, 'Brochure meta (size | updated)'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trust bar KPIs',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Shown on About when Company Statistics are empty. '
                'Values come from Admin → Website → Statistics '
                '(show on About) and update in real time.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.neutral200),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _KpiPreview(
                      value: '${_yearsValue.text}${_yearsSuffix.text}',
                      label: _yearsLabel.text,
                    ),
                    _KpiPreview(
                      value: '${_homesValue.text}${_homesSuffix.text}',
                      label: _homesLabel.text,
                    ),
                    _KpiPreview(
                      value: '${_clientsValue.text}${_clientsSuffix.text}',
                      label: _clientsLabel.text,
                    ),
                    _KpiPreview(
                      value: '${_projectsValue.text}${_projectsSuffix.text}',
                      label: _projectsLabel.text,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _field(_trustMessage, 'Trust message', maxLines: 2),
              const SizedBox(height: 8),
              _kpiRow('Years', _yearsValue, _yearsSuffix, _yearsLabel),
              _kpiRow('Homes', _homesValue, _homesSuffix, _homesLabel),
              _kpiRow('Clients', _clientsValue, _clientsSuffix, _clientsLabel),
              _kpiRow(
                'Projects',
                _projectsValue,
                _projectsSuffix,
                _projectsLabel,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.save, size: 16),
            label: Text(_saving ? 'Saving…' : 'Save digital profile'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _kpiRow(
    String title,
    TextEditingController value,
    TextEditingController suffix,
    TextEditingController label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: TextField(
              controller: value,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: suffix,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Suffix',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: label,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiPreview extends StatelessWidget {
  const _KpiPreview({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.isEmpty ? '—' : value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          label.isEmpty ? 'Label' : label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.slate500,
              ),
        ),
      ],
    );
  }
}
