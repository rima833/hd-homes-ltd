import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Payment Calculator
class CmsPaymentCalculatorPage extends ConsumerStatefulWidget {
  const CmsPaymentCalculatorPage({super.key});

  @override
  ConsumerState<CmsPaymentCalculatorPage> createState() =>
      _CmsPaymentCalculatorPageState();
}

class _CmsPaymentCalculatorPageState
    extends ConsumerState<CmsPaymentCalculatorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _invalidate() {
    ref.invalidate(cmsCalculatorSettingsProvider);
    ref.invalidate(cmsCalculatorPaymentPlansProvider);
    ref.invalidate(cmsCalculatorApplicationsProvider);
    ref.invalidate(publishedCalculatorSettingsProvider);
    ref.invalidate(publishedCalculatorPaymentPlansProvider);
    ref.invalidate(publishedCalculatorPropertiesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Payment calculator',
            subtitle:
                'Plans, deposit rules, and calculator applications. Open an application to review the figures and reply. The applicant sees that reply under the calculator on the public site, in client Buying Tools, and in investor Investment Tools.',
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.slate500,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'Settings'),
              Tab(text: 'Plans'),
              Tab(text: 'Applications'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SettingsTab(onChanged: _invalidate),
                _PlansTab(onChanged: _invalidate),
                _ApplicationsTab(onChanged: _invalidate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCalculatorSettingsProvider);
    return async.when(
      loading: () => const AdminLoadingView(),
      error: (e, _) => AdminErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(cmsCalculatorSettingsProvider),
      ),
      data: (settings) {
        if (settings == null) {
          return const AdminEmptyState(
            title: 'Settings unavailable',
            message: 'Connect Supabase to manage calculator settings.',
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

  final CmsCalculatorSettings settings;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late TextEditingController _overline;
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late TextEditingController _info;
  late TextEditingController _cta;
  late TextEditingController _priceMin;
  late TextEditingController _priceMax;
  late TextEditingController _priceDefault;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _overline = TextEditingController(text: s.overline);
    _title = TextEditingController(text: s.title);
    _subtitle = TextEditingController(text: s.subtitle);
    _info = TextEditingController(text: s.infoText);
    _cta = TextEditingController(text: s.applyCtaLabel);
    _priceMin = TextEditingController(text: s.priceMin.toStringAsFixed(0));
    _priceMax = TextEditingController(text: s.priceMax.toStringAsFixed(0));
    _priceDefault = TextEditingController(
      text: s.priceDefault.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _overline.dispose();
    _title.dispose();
    _subtitle.dispose();
    _info.dispose();
    _cta.dispose();
    _priceMin.dispose();
    _priceMax.dispose();
    _priceDefault.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .upsertCalculatorSettings(
            id: widget.settings.id,
            overline: _overline.text.trim(),
            title: _title.text.trim(),
            subtitle: _subtitle.text.trim(),
            infoText: _info.text.trim(),
            applyCtaLabel: _cta.text.trim(),
            priceMin: double.tryParse(_priceMin.text.trim()) ?? 10000000,
            priceMax: double.tryParse(_priceMax.text.trim()) ?? 200000000,
            priceDefault:
                double.tryParse(_priceDefault.text.trim()) ?? 50000000,
            trustItems: widget.settings.trustItems,
          );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calculator settings saved')),
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
            children: [
              _tf(_overline, 'Overline'),
              _tf(_title, 'Title'),
              _tf(_subtitle, 'Subtitle', maxLines: 2),
              _tf(_info, 'Info text', maxLines: 3),
              _tf(_cta, 'Apply CTA label'),
              _tf(_priceMin, 'Price slider min (NGN)'),
              _tf(_priceMax, 'Price slider max (NGN)'),
              _tf(_priceDefault, 'Default price (NGN)'),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
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

class _PlansTab extends ConsumerWidget {
  const _PlansTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCalculatorPaymentPlansProvider);
    final propertiesAsync = ref.watch(publishedCalculatorPropertiesProvider);

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _open(
              context,
              ref,
              null,
              propertiesAsync.valueOrNull ?? const [],
            ),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add plan'),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const AdminLoadingView(),
            error: (e, _) => AdminErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(cmsCalculatorPaymentPlansProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AdminEmptyState(
                  title: 'No payment plans',
                  message: 'Create a global or property-specific plan.',
                  icon: LucideIcons.calculator,
                  action: FilledButton.icon(
                    onPressed: () => _open(
                      context,
                      ref,
                      null,
                      propertiesAsync.valueOrNull ?? const [],
                    ),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Add plan'),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final plan = items[i];
                  final active = plan.status == 'active';
                  return AdminCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${plan.isGlobal ? 'Global' : '${plan.propertyIds.length} properties'}'
                                ' · ${plan.interestRateDefault}% · '
                                '${plan.durationMonthsMin}-${plan.durationMonthsMax} mo',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: active,
                          activeTrackColor: AppColors.gold,
                          onChanged: (v) async {
                            await ref
                                .read(cmsServiceProvider)
                                .upsertCalculatorPaymentPlan(
                                  id: plan.id,
                                  name: plan.name,
                                  description: plan.description,
                                  isGlobal: plan.isGlobal,
                                  interestRateDefault: plan.interestRateDefault,
                                  interestRateMin: plan.interestRateMin,
                                  interestRateMax: plan.interestRateMax,
                                  durationMonthsDefault:
                                      plan.durationMonthsDefault,
                                  durationMonthsMin: plan.durationMonthsMin,
                                  durationMonthsMax: plan.durationMonthsMax,
                                  depositPercentMin: plan.depositPercentMin,
                                  depositPercentDefault:
                                      plan.depositPercentDefault,
                                  minDepositAmount: plan.minDepositAmount,
                                  maxDepositAmount: plan.maxDepositAmount,
                                  calculationMethod: plan.calculationMethod,
                                  sortOrder: plan.sortOrder,
                                  status: v ? 'active' : 'draft',
                                  propertyIds: plan.propertyIds,
                                );
                            onChanged();
                          },
                        ),
                        IconButton(
                          onPressed: () => _open(
                            context,
                            ref,
                            plan,
                            propertiesAsync.valueOrNull ?? const [],
                          ),
                          icon: const Icon(LucideIcons.pencil, size: 18),
                        ),
                        IconButton(
                          onPressed: () async {
                            await ref
                                .read(cmsServiceProvider)
                                .deleteCalculatorPaymentPlan(plan.id);
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    CmsCalculatorPaymentPlan? plan,
    List<CmsPropertyFeatured> properties,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PlanDialog(plan: plan, properties: properties),
    );
    onChanged();
  }
}

class _PlanDialog extends ConsumerStatefulWidget {
  const _PlanDialog({this.plan, required this.properties});

  final CmsCalculatorPaymentPlan? plan;
  final List<CmsPropertyFeatured> properties;

  @override
  ConsumerState<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends ConsumerState<_PlanDialog> {
  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _interestDefault;
  late TextEditingController _interestMin;
  late TextEditingController _interestMax;
  late TextEditingController _durationDefault;
  late TextEditingController _durationMin;
  late TextEditingController _durationMax;
  late TextEditingController _depositPercentMin;
  late TextEditingController _depositPercentDefault;
  late TextEditingController _minDeposit;
  late TextEditingController _sort;
  bool _isGlobal = true;
  bool _published = true;
  String _method = 'reducing_balance';
  late Set<String> _propertyIds;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _interestDefault = TextEditingController(
      text: '${p?.interestRateDefault ?? 12}',
    );
    _interestMin = TextEditingController(text: '${p?.interestRateMin ?? 0}');
    _interestMax = TextEditingController(text: '${p?.interestRateMax ?? 30}');
    _durationDefault = TextEditingController(
      text: '${p?.durationMonthsDefault ?? 24}',
    );
    _durationMin = TextEditingController(text: '${p?.durationMonthsMin ?? 6}');
    _durationMax = TextEditingController(
      text: '${p?.durationMonthsMax ?? 120}',
    );
    _depositPercentMin = TextEditingController(
      text: '${p?.depositPercentMin ?? 10}',
    );
    _depositPercentDefault = TextEditingController(
      text: '${p?.depositPercentDefault ?? 20}',
    );
    _minDeposit = TextEditingController(
      text: '${p?.minDepositAmount ?? 1000000}',
    );
    _sort = TextEditingController(text: '${p?.sortOrder ?? 0}');
    _isGlobal = p?.isGlobal ?? true;
    _published = (p?.status ?? 'active') == 'active';
    _method = p?.calculationMethod ?? 'reducing_balance';
    _propertyIds = {...?p?.propertyIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _interestDefault.dispose();
    _interestMin.dispose();
    _interestMax.dispose();
    _durationDefault.dispose();
    _durationMin.dispose();
    _durationMax.dispose();
    _depositPercentMin.dispose();
    _depositPercentDefault.dispose();
    _minDeposit.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .upsertCalculatorPaymentPlan(
            id: widget.plan?.id,
            name: _name.text.trim(),
            description: _description.text.trim(),
            isGlobal: _isGlobal,
            interestRateDefault:
                double.tryParse(_interestDefault.text.trim()) ?? 12,
            interestRateMin: double.tryParse(_interestMin.text.trim()) ?? 0,
            interestRateMax: double.tryParse(_interestMax.text.trim()) ?? 30,
            durationMonthsDefault:
                int.tryParse(_durationDefault.text.trim()) ?? 24,
            durationMonthsMin: int.tryParse(_durationMin.text.trim()) ?? 6,
            durationMonthsMax: int.tryParse(_durationMax.text.trim()) ?? 120,
            depositPercentMin:
                double.tryParse(_depositPercentMin.text.trim()) ?? 10,
            depositPercentDefault:
                double.tryParse(_depositPercentDefault.text.trim()) ?? 20,
            minDepositAmount:
                double.tryParse(_minDeposit.text.trim()) ?? 1000000,
            calculationMethod: _method,
            sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
            status: _published ? 'active' : 'draft',
            propertyIds: _isGlobal ? const [] : _propertyIds.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plan == null ? 'Add plan' : 'Edit plan'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tf(_name, 'Name'),
              _tf(_description, 'Description', maxLines: 2),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Global plan'),
                subtitle: const Text('Available for all properties'),
                value: _isGlobal,
                onChanged: (v) => setState(() => _isGlobal = v),
              ),
              if (!_isGlobal) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assigned properties',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in widget.properties)
                        CheckboxListTile(
                          dense: true,
                          value: _propertyIds.contains(p.id),
                          title: Text(p.title),
                          subtitle: Text(p.displayPrice),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _propertyIds.add(p.id);
                              } else {
                                _propertyIds.remove(p.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Calculation method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'reducing_balance',
                    child: Text('Reducing balance (EMI)'),
                  ),
                  DropdownMenuItem(value: 'flat', child: Text('Flat interest')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
              ),
              const SizedBox(height: 10),
              _tf(_interestDefault, 'Default interest %'),
              _tf(_interestMin, 'Min interest %'),
              _tf(_interestMax, 'Max interest %'),
              _tf(_durationDefault, 'Default duration (months)'),
              _tf(_durationMin, 'Min duration'),
              _tf(_durationMax, 'Max duration'),
              _tf(_depositPercentMin, 'Min deposit %'),
              _tf(_depositPercentDefault, 'Default deposit %'),
              _tf(_minDeposit, 'Absolute min deposit (NGN)'),
              _tf(_sort, 'Sort order'),
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

class _ApplicationsTab extends ConsumerWidget {
  const _ApplicationsTab({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cmsCalculatorApplicationsProvider);
    final currency = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );
    final when = DateFormat('d MMM yyyy, h:mm a');

    return async.when(
      loading: () => const AdminLoadingView(),
      error: (e, _) => AdminErrorView(
        message: userFacingError(
          e,
          fallback: 'Applications could not be loaded.',
        ),
        onRetry: () => ref.invalidate(cmsCalculatorApplicationsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AdminEmptyState(
            title: 'No applications yet',
            message:
                'When a client applies from the payment calculator, the request, plan figures, and your reply appear here.',
            icon: LucideIcons.inbox,
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final app = items[i];
            final created = app.createdAt?.toLocal();
            return AdminCard(
              onTap: () => _openApplication(context, ref, app, currency, when),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.fullName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      _StatusChip(label: app.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      app.email,
                      if (app.phone.isNotEmpty) app.phone,
                      if (app.city.isNotEmpty) app.city,
                    ].join(' · '),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${app.planName.isEmpty ? 'Payment plan' : app.planName} · '
                    '${currency.format(app.monthlyPayment)} / month · '
                    '${app.durationMonths} mo',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
                  ),
                  if (created != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      when.format(created),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    app.hasReply
                        ? 'Replied: ${app.adminReply}'
                        : 'No reply yet — open to respond',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: app.hasReply ? AppColors.gold : AppColors.slate500,
                      fontWeight: app.hasReply
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openApplication(
    BuildContext context,
    WidgetRef ref,
    CmsCalculatorApplication app,
    NumberFormat currency,
    DateFormat when,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ApplicationReplyDialog(
        application: app,
        currency: currency,
        when: when,
      ),
    );
    if (saved == true) onChanged();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ApplicationReplyDialog extends ConsumerStatefulWidget {
  const _ApplicationReplyDialog({
    required this.application,
    required this.currency,
    required this.when,
  });

  final CmsCalculatorApplication application;
  final NumberFormat currency;
  final DateFormat when;

  @override
  ConsumerState<_ApplicationReplyDialog> createState() =>
      _ApplicationReplyDialogState();
}

class _ApplicationReplyDialogState
    extends ConsumerState<_ApplicationReplyDialog> {
  static const _statuses = [
    'new',
    'reviewed',
    'contacted',
    'qualified',
    'converted',
    'closed',
    'spam',
  ];

  late String _status;
  late final TextEditingController _reply;
  late final TextEditingController _notes;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final status = widget.application.status;
    _status = _statuses.contains(status) ? status : 'new';
    _reply = TextEditingController(text: widget.application.adminReply);
    _notes = TextEditingController(text: widget.application.notes);
  }

  @override
  void dispose() {
    _reply.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(cmsServiceProvider)
          .updateCalculatorApplicationStatus(
            id: widget.application.id,
            status: _status,
            notes: _notes.text,
            adminReply: _reply.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = userFacingError(e, fallback: 'The reply could not be saved.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final currency = widget.currency;
    final created = app.createdAt?.toLocal();
    final facts = [
      ('Plan', app.planName.isEmpty ? 'Payment plan' : app.planName),
      ('Price', currency.format(app.propertyPrice)),
      ('Deposit', currency.format(app.depositAmount)),
      ('Financed', currency.format(app.loanAmount)),
      ('Monthly', currency.format(app.monthlyPayment)),
      ('Duration', '${app.durationMonths} months'),
      ('Rate', '${app.interestRate}%'),
      ('Total repayment', currency.format(app.totalRepayment)),
      ('Total interest', currency.format(app.totalInterest)),
      ('Contact via', app.preferredContactLabel),
      if (app.occupation.isNotEmpty) ('Occupation', app.occupation),
      if (app.city.isNotEmpty) ('City', app.city),
    ];

    return AlertDialog(
      title: Text(app.fullName),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  app.email,
                  if (app.phone.isNotEmpty) app.phone,
                  if (created != null) widget.when.format(created),
                ].join(' · '),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  for (final fact in facts)
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fact.$1,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.slate500),
                          ),
                          Text(fact.$2),
                        ],
                      ),
                    ),
                ],
              ),
              if (app.applicantMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Client message',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(app.applicantMessage),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                  DropdownMenuItem(
                    value: 'contacted',
                    child: Text('Contacted'),
                  ),
                  DropdownMenuItem(
                    value: 'qualified',
                    child: Text('Qualified'),
                  ),
                  DropdownMenuItem(
                    value: 'converted',
                    child: Text('Converted'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _status = value);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reply,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Reply to client',
                  helperText:
                      'Shown under the calculator for this applicant on the public site, client portal, and investor portal.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Internal note',
                  helperText: 'Staff only. The client does not see this.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
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
          child: Text(_saving ? 'Saving…' : 'Save reply'),
        ),
      ],
    );
  }
}
