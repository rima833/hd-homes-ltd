import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/home/data/providers/roi_calculator_provider.dart';
import 'package:hdhomesproject/features/home/domain/roi_calculator_math.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → ROI Calculator
class CmsRoiCalculatorPage extends ConsumerWidget {
  const CmsRoiCalculatorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsRoiCalculatorSettingsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'ROI calculator',
            subtitle:
                'Investment amount bounds, growth rates, compounding, disclaimer, and CTA.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (e, _) => AdminErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(cmsRoiCalculatorSettingsProvider),
              ),
              data: (settings) {
                if (settings == null) {
                  return const AdminEmptyState(
                    title: 'Settings unavailable',
                    message: 'Connect Supabase to manage ROI calculator settings.',
                    icon: LucideIcons.lineChart,
                  );
                }
                return _SettingsForm(
                  settings: settings,
                  onChanged: () {
                    ref.invalidate(cmsRoiCalculatorSettingsProvider);
                    ref.invalidate(publishedRoiCalculatorSettingsProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, required this.onChanged});

  final CmsRoiCalculatorSettings settings;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late TextEditingController _overline;
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late TextEditingController _inputsTitle;
  late TextEditingController _inputsSubtitle;
  late TextEditingController _resultsTitle;
  late TextEditingController _info;
  late TextEditingController _disclaimer;
  late TextEditingController _ctaLabel;
  late TextEditingController _ctaPath;
  late TextEditingController _currencySymbol;
  late TextEditingController _currencyCode;
  late TextEditingController _amountMin;
  late TextEditingController _amountMax;
  late TextEditingController _amountDefault;
  late TextEditingController _growthMin;
  late TextEditingController _growthMax;
  late TextEditingController _growthDefault;
  late TextEditingController _yearsMin;
  late TextEditingController _yearsMax;
  late TextEditingController _yearsDefault;
  late bool _enabled;
  late bool _showChart;
  late String _method;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncFrom(widget.settings);
  }

  @override
  void didUpdateWidget(covariant _SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.id != widget.settings.id ||
        oldWidget.settings.updatedAtSafe != widget.settings.updatedAtSafe) {
      _syncFrom(widget.settings);
    }
  }

  void _syncFrom(CmsRoiCalculatorSettings s) {
    _overline = TextEditingController(text: s.overline);
    _title = TextEditingController(text: s.title);
    _subtitle = TextEditingController(text: s.subtitle);
    _inputsTitle = TextEditingController(text: s.inputsTitle);
    _inputsSubtitle = TextEditingController(text: s.inputsSubtitle);
    _resultsTitle = TextEditingController(text: s.resultsTitle);
    _info = TextEditingController(text: s.infoText);
    _disclaimer = TextEditingController(text: s.disclaimerText);
    _ctaLabel = TextEditingController(text: s.ctaLabel);
    _ctaPath = TextEditingController(text: s.ctaPath);
    _currencySymbol = TextEditingController(text: s.currencySymbol);
    _currencyCode = TextEditingController(text: s.currencyCode);
    _amountMin = TextEditingController(text: s.amountMin.toStringAsFixed(0));
    _amountMax = TextEditingController(text: s.amountMax.toStringAsFixed(0));
    _amountDefault =
        TextEditingController(text: s.amountDefault.toStringAsFixed(0));
    _growthMin = TextEditingController(text: s.growthMin.toStringAsFixed(1));
    _growthMax = TextEditingController(text: s.growthMax.toStringAsFixed(1));
    _growthDefault =
        TextEditingController(text: s.growthDefault.toStringAsFixed(1));
    _yearsMin = TextEditingController(text: s.yearsMin.toStringAsFixed(0));
    _yearsMax = TextEditingController(text: s.yearsMax.toStringAsFixed(0));
    _yearsDefault =
        TextEditingController(text: s.yearsDefault.toStringAsFixed(0));
    _enabled = s.isEnabled;
    _showChart = s.showChart;
    _method = s.compoundingMethod;
  }

  @override
  void dispose() {
    _overline.dispose();
    _title.dispose();
    _subtitle.dispose();
    _inputsTitle.dispose();
    _inputsSubtitle.dispose();
    _resultsTitle.dispose();
    _info.dispose();
    _disclaimer.dispose();
    _ctaLabel.dispose();
    _ctaPath.dispose();
    _currencySymbol.dispose();
    _currencyCode.dispose();
    _amountMin.dispose();
    _amountMax.dispose();
    _amountDefault.dispose();
    _growthMin.dispose();
    _growthMax.dispose();
    _growthDefault.dispose();
    _yearsMin.dispose();
    _yearsMax.dispose();
    _yearsDefault.dispose();
    super.dispose();
  }

  double _d(TextEditingController c, double fallback) =>
      double.tryParse(c.text.trim()) ?? fallback;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertRoiCalculatorSettings(
            id: widget.settings.id,
            isEnabled: _enabled,
            overline: _overline.text.trim(),
            title: _title.text.trim(),
            subtitle: _subtitle.text.trim(),
            inputsTitle: _inputsTitle.text.trim(),
            inputsSubtitle: _inputsSubtitle.text.trim(),
            resultsTitle: _resultsTitle.text.trim(),
            infoText: _info.text.trim(),
            disclaimerText: _disclaimer.text.trim(),
            ctaLabel: _ctaLabel.text.trim(),
            ctaPath: _ctaPath.text.trim(),
            currencySymbol: _currencySymbol.text.trim().isEmpty
                ? '₦'
                : _currencySymbol.text.trim(),
            currencyCode: _currencyCode.text.trim().isEmpty
                ? 'NGN'
                : _currencyCode.text.trim(),
            compoundingMethod: _method,
            amountMin: _d(_amountMin, 1000000),
            amountMax: _d(_amountMax, 100000000),
            amountDefault: _d(_amountDefault, 5000000),
            growthMin: _d(_growthMin, 1),
            growthMax: _d(_growthMax, 30),
            growthDefault: _d(_growthDefault, 15),
            yearsMin: _d(_yearsMin, 1),
            yearsMax: _d(_yearsMax, 10),
            yearsDefault: _d(_yearsDefault, 3),
            showChart: _showChart,
          );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ROI calculator settings saved')),
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
    final preview = RoiCalculatorMath.estimate(
      amount: _d(_amountDefault, 5000000),
      annualGrowthPercent: _d(_growthDefault, 15),
      years: _d(_yearsDefault, 3),
      method: _method,
    );
    final currency = NumberFormat.currency(
      locale: 'en_NG',
      symbol: _currencySymbol.text.trim().isEmpty
          ? '₦'
          : _currencySymbol.text.trim(),
      decimalDigits: 0,
    );

    return ListView(
      children: [
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable calculator'),
                subtitle: const Text('When off, the public ROI section is hidden'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show growth chart'),
                value: _showChart,
                onChanged: (v) => setState(() => _showChart = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Compounding method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'compound', child: Text('Compound')),
                  DropdownMenuItem(value: 'simple', child: Text('Simple')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
              ),
              const SizedBox(height: 12),
              _tf(_overline, 'Overline'),
              _tf(_title, 'Title'),
              _tf(_subtitle, 'Subtitle', maxLines: 2),
              _tf(_inputsTitle, 'Inputs card title'),
              _tf(_inputsSubtitle, 'Inputs card subtitle', maxLines: 2),
              _tf(_resultsTitle, 'Results card title'),
              _tf(_info, 'Info text', maxLines: 3),
              _tf(_disclaimer, 'Disclaimer', maxLines: 3),
              _tf(_ctaLabel, 'CTA label'),
              _tf(_ctaPath, 'CTA path (e.g. /investment)'),
              _tf(_currencySymbol, 'Currency symbol'),
              _tf(_currencyCode, 'Currency code'),
              const Divider(height: 28),
              Text(
                'Investment amount',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _tf(_amountMin, 'Min (NGN)'),
              _tf(_amountMax, 'Max (NGN)'),
              _tf(_amountDefault, 'Default (NGN)'),
              const Divider(height: 28),
              Text(
                'Annual growth (%)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _tf(_growthMin, 'Min %'),
              _tf(_growthMax, 'Max %'),
              _tf(_growthDefault, 'Default %'),
              const Divider(height: 28),
              Text(
                'Holding period (years)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _tf(_yearsMin, 'Min years'),
              _tf(_yearsMax, 'Max years'),
              _tf(_yearsDefault, 'Default years'),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: Text(_saving ? 'Saving…' : 'Save settings'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview (defaults)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Using default amount / growth / years and $_method interest.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _previewRow('Projected value', currency.format(preview.projectedValue)),
              _previewRow('Net profit', currency.format(preview.netProfit)),
              _previewRow(
                'Total ROI',
                '${preview.totalRoiPercent.toStringAsFixed(1)}%',
              ),
              _previewRow(
                'Annualized',
                '${preview.annualizedReturnPercent.toStringAsFixed(1)}% avg',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

extension on CmsRoiCalculatorSettings {
  /// Lightweight dirty check helper for form rebuilds.
  String get updatedAtSafe =>
      '$isEnabled|$compoundingMethod|$amountDefault|$growthDefault|$yearsDefault';
}
