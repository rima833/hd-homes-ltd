import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:hdhomesproject/features/home/domain/payment_plan_math.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/calculator_applications_panel.dart';
import 'package:hdhomesproject/features/home/presentation/widgets/calculator_apply_dialog.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Payment plan calculator — public site, client Buying Tools, and investor
/// Investment Tools.
class HomePaymentCalculatorSection extends ConsumerWidget {
  const HomePaymentCalculatorSection({super.key, this.wrapInSection = true});

  /// When false, skips [SectionWrapper] (investor portal embed).
  final bool wrapInSection;

  static const bg = Color(0xFF0A0A0A);
  static const panel = Color(0xFF121212);
  static const card = Color(0xFF161616);
  static const gold = Color(0xFFD4AF37);
  static const goldBright = Color(0xFFE8C547);
  static const goldDeep = Color(0xFFB8860B);
  static const muted = Color(0xFF8A8A8A);
  static const ink = Color(0xFF1A1408);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref
            .watch(publishedPlatformSettingsProvider)
            .valueOrNull
            ?.enablePaymentCalculator ??
        true;
    if (!enabled) return const SizedBox.shrink();

    final settingsAsync = ref.watch(publishedCalculatorSettingsProvider);
    final plansAsync = ref.watch(publishedCalculatorPaymentPlansProvider);
    final propertiesAsync = ref.watch(publishedCalculatorPropertiesProvider);
    final state = ref.watch(paymentCalculatorControllerProvider);
    final controller = ref.read(paymentCalculatorControllerProvider.notifier);

    final body = settingsAsync.when(
      loading: () => const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(color: gold)),
      ),
      error: (e, _) => _ErrorBox(message: '$e'),
      data: (settings) {
        if (plansAsync.isLoading && plansAsync.valueOrNull == null) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator(color: gold)),
          );
        }
        if (plansAsync.hasError && plansAsync.valueOrNull == null) {
          return _ErrorBox(message: '${plansAsync.error}');
        }
        final plans = plansAsync.valueOrNull ?? const [];
        if (plans.isEmpty || state == null) {
          return const _ErrorBox(
            message: 'No active payment plans are available yet.',
          );
        }
        final plan = controller.selectedPlan ?? plans.first;
        final estimate = controller.estimate!;
        final properties = propertiesAsync.valueOrNull ?? const [];
        final stacked = context.isMobile || context.screenWidth < 920;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 1180),
              padding: EdgeInsets.symmetric(
                horizontal: stacked ? 18 : 36,
                vertical: stacked ? 28 : 40,
              ),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: stacked ? -20 : 40,
                    top: -30,
                    child: IgnorePointer(
                      child: Icon(
                        LucideIcons.building2,
                        size: stacked ? 160 : 260,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                  stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InputsColumn(
                              settings: settings,
                              plans: plans,
                              properties: properties,
                              state: state,
                              plan: plan,
                              controller: controller,
                            ),
                            const SizedBox(height: 28),
                            _ResultsCard(
                              settings: settings,
                              estimate: estimate,
                              expand: false,
                              onApply: () => openCalculatorApplyDialog(
                                context,
                                ref,
                                settings: settings,
                                plan: plan,
                                state: state,
                                estimate: estimate,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _TrustRow(items: settings.trustItems),
                          ],
                        )
                      : Column(
                          children: [
                            _MatchedHeightRow(
                              inputs: _InputsColumn(
                                settings: settings,
                                plans: plans,
                                properties: properties,
                                state: state,
                                plan: plan,
                                controller: controller,
                              ),
                              estimate: (expand) => _ResultsCard(
                                settings: settings,
                                estimate: estimate,
                                expand: expand,
                                onApply: () => openCalculatorApplyDialog(
                                  context,
                                  ref,
                                  settings: settings,
                                  plan: plan,
                                  state: state,
                                  estimate: estimate,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 12,
                                  child: SizedBox.shrink(),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
                                  flex: 9,
                                  child: _TrustRow(items: settings.trustItems),
                                ),
                              ],
                            ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const CalculatorApplicationsPanel(),
          ],
        );
      },
    );

    if (!wrapInSection) return body;

    return SectionWrapper(
      backgroundColor: bg,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: context.isMobile ? 36 : 56,
      ),
      child: body,
    );
  }
}

class _InputsColumn extends StatelessWidget {
  const _InputsColumn({
    required this.settings,
    required this.plans,
    required this.properties,
    required this.state,
    required this.plan,
    required this.controller,
  });

  final CmsCalculatorSettings settings;
  final List<CmsCalculatorPaymentPlan> plans;
  final List<CmsPropertyFeatured> properties;
  final PaymentCalculatorState state;
  final CmsCalculatorPaymentPlan plan;
  final PaymentCalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final gold = HomePaymentCalculatorSection.gold;
    final eligibleProperties = plan.isGlobal
        ? properties
        : properties.where((p) => plan.propertyIds.contains(p.id)).toList();

    final depositMin = [
      plan.minDepositAmount,
      state.propertyPrice * (plan.depositPercentMin / 100),
      0.0,
    ].reduce((a, b) => a > b ? a : b);
    final depositMaxRaw = plan.maxDepositAmount == null
        ? state.propertyPrice
        : plan.maxDepositAmount!.clamp(depositMin, state.propertyPrice);
    final depositMax = depositMaxRaw <= depositMin
        ? depositMin + 1
        : depositMaxRaw.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.calculator, color: gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                settings.overline.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: gold,
                  fontSize: 11,
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          settings.title,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: context.isMobile ? 30 : 40,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          settings.subtitle,
          style: GoogleFonts.manrope(
            color: HomePaymentCalculatorSection.muted,
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        if (plans.length > 1) ...[
          _SubtleDropdown<String>(
            label: 'Payment plan',
            value: state.planId,
            items: [
              for (final p in plans)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) {
              final next = plans.where((p) => p.id == id).firstOrNull;
              if (next != null) controller.selectPlan(next);
            },
          ),
          const SizedBox(height: 18),
        ],
        if (eligibleProperties.isNotEmpty) ...[
          _SubtleDropdown<String?>(
            label: 'Property (optional)',
            value: state.propertyId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Custom / slider price'),
              ),
              for (final p in eligibleProperties)
                DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(
                    '${p.title} · ${p.displayPrice}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null) {
                controller.selectProperty(null);
                return;
              }
              final property = eligibleProperties
                  .where((p) => p.id == id)
                  .firstOrNull;
              controller.selectProperty(property);
            },
          ),
          const SizedBox(height: 22),
        ],
        _AdjustableValue(
          icon: LucideIcons.home,
          label: 'Property Price',
          display: _moneyShort(state.propertyPrice),
          value: state.propertyPrice,
          min: settings.priceMin,
          max: settings.priceMax,
          markers: [
            _moneyShort(settings.priceMin),
            _moneyShort((settings.priceMin + settings.priceMax) / 2),
            _moneyShort(settings.priceMax),
          ],
          mode: _ManualInputMode.money,
          onChanged: controller.setPrice,
        ),
        _AdjustableValue(
          icon: LucideIcons.wallet,
          label: 'Deposit',
          display: _moneyShort(state.deposit.clamp(depositMin, depositMax)),
          value: state.deposit.clamp(depositMin, depositMax),
          min: depositMin,
          max: depositMax,
          markers: [
            _moneyShort(depositMin),
            _moneyShort((depositMin + depositMax) / 2),
            _moneyShort(depositMax),
          ],
          mode: _ManualInputMode.money,
          onChanged: controller.setDeposit,
        ),
        _AdjustableValue(
          icon: LucideIcons.calendarDays,
          label: 'Duration (months)',
          display: '${state.months.round()} months',
          value: state.months.clamp(
            plan.durationMonthsMin.toDouble(),
            plan.durationMonthsMax.toDouble(),
          ),
          min: plan.durationMonthsMin.toDouble(),
          max: plan.durationMonthsMax.toDouble(),
          divisions: (plan.durationMonthsMax - plan.durationMonthsMin).clamp(
            1,
            200,
          ),
          markers: [
            '${plan.durationMonthsMin} months',
            '${((plan.durationMonthsMin + plan.durationMonthsMax) / 2).round()} months',
            '${plan.durationMonthsMax} months',
          ],
          mode: _ManualInputMode.months,
          onChanged: controller.setMonths,
        ),
        _AdjustableValue(
          icon: LucideIcons.percent,
          label: 'Interest (%)',
          display: '${state.interestRate.toStringAsFixed(1)}%',
          value: state.interestRate.clamp(
            plan.interestRateMin,
            plan.interestRateMax,
          ),
          min: plan.interestRateMin,
          max: plan.interestRateMax <= plan.interestRateMin
              ? plan.interestRateMin + 1
              : plan.interestRateMax,
          markers: [
            '${plan.interestRateMin.toStringAsFixed(0)}%',
            '${((plan.interestRateMin + plan.interestRateMax) / 2).toStringAsFixed(0)}%',
            '${plan.interestRateMax.toStringAsFixed(0)}%',
          ],
          mode: _ManualInputMode.percent,
          onChanged: controller.setInterest,
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, color: gold, size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  settings.infoText,
                  style: GoogleFonts.manrope(
                    color: HomePaymentCalculatorSection.muted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 420.ms);
  }
}

class _SubtleDropdown<T> extends StatelessWidget {
  const _SubtleDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          dropdownColor: HomePaymentCalculatorSection.card,
          iconEnabledColor: Colors.white70,
          style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: HomePaymentCalculatorSection.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: HomePaymentCalculatorSection.gold.withValues(
                  alpha: 0.45,
                ),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: HomePaymentCalculatorSection.gold.withValues(
                  alpha: 0.45,
                ),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: HomePaymentCalculatorSection.gold,
              ),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

enum _ManualInputMode { money, months, percent }

class _AdjustableValue extends StatefulWidget {
  const _AdjustableValue({
    required this.icon,
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.markers,
    required this.mode,
    this.divisions,
  });

  final IconData icon;
  final String label;
  final String display;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final List<String> markers;
  final _ManualInputMode mode;
  final int? divisions;

  @override
  State<_AdjustableValue> createState() => _AdjustableValueState();
}

class _AdjustableValueState extends State<_AdjustableValue> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String? _error;
  bool _manualOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatEditable(widget.value));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _AdjustableValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _formatEditable(widget.value);
      _error = null;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit(format: true);
  }

  String _formatEditable(double value) {
    switch (widget.mode) {
      case _ManualInputMode.money:
        return NumberFormat('#,##0', 'en_NG').format(value.round());
      case _ManualInputMode.months:
        return value.round().toString();
      case _ManualInputMode.percent:
        return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    }
  }

  double? _parseValue(String raw) {
    var text = raw.trim().toLowerCase().replaceAll(',', '').replaceAll('₦', '');
    if (text.isEmpty) return null;

    switch (widget.mode) {
      case _ManualInputMode.money:
        var multiplier = 1.0;
        if (text.endsWith('m')) {
          multiplier = 1000000;
          text = text.substring(0, text.length - 1).trim();
        } else if (text.endsWith('k')) {
          multiplier = 1000;
          text = text.substring(0, text.length - 1).trim();
        }
        final parsed = double.tryParse(text);
        if (parsed == null) return null;
        return parsed * multiplier;
      case _ManualInputMode.months:
        text = text.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(text);
      case _ManualInputMode.percent:
        text = text.replaceAll('%', '').trim();
        return double.tryParse(text);
    }
  }

  String get _hint {
    switch (widget.mode) {
      case _ManualInputMode.money:
        return 'Type amount (e.g. 20M)';
      case _ManualInputMode.months:
        return 'Type months (e.g. 24)';
      case _ManualInputMode.percent:
        return 'Type interest % (e.g. 5.5)';
    }
  }

  String? get _prefix {
    switch (widget.mode) {
      case _ManualInputMode.money:
        return '₦ ';
      case _ManualInputMode.months:
        return null;
      case _ManualInputMode.percent:
        return null;
    }
  }

  String? get _suffix {
    switch (widget.mode) {
      case _ManualInputMode.money:
        return null;
      case _ManualInputMode.months:
        return ' months';
      case _ManualInputMode.percent:
        return ' %';
    }
  }

  void _applyParsed(double parsed, {required bool format}) {
    final safeMax = widget.max <= widget.min ? widget.min + 1 : widget.max;
    final clamped = parsed.clamp(widget.min, safeMax).toDouble();
    final rounded = widget.mode == _ManualInputMode.months
        ? clamped.roundToDouble()
        : clamped;
    setState(() {
      _error = parsed < widget.min
          ? 'Minimum is ${widget.markers.isNotEmpty ? widget.markers.first : _formatEditable(widget.min)}'
          : parsed > widget.max
          ? 'Maximum is ${widget.markers.length > 2 ? widget.markers.last : _formatEditable(widget.max)}'
          : null;
      if (format) {
        _controller.text = _formatEditable(rounded);
      }
    });
    widget.onChanged(rounded);
  }

  void _commit({bool format = true}) {
    final parsed = _parseValue(_controller.text);
    if (parsed == null) {
      setState(() => _error = 'Enter a valid value');
      if (format) {
        _controller.text = _formatEditable(widget.value);
      }
      return;
    }
    _applyParsed(parsed, format: format);
  }

  /// Live-update the results panel while the user types.
  void _onManualChanged(String raw) {
    final parsed = _parseValue(raw);
    if (parsed == null) {
      if (_error != null) setState(() => _error = null);
      return;
    }
    _applyParsed(parsed, format: false);
  }

  void _toggleManual() {
    setState(() {
      _manualOpen = !_manualOpen;
      if (_manualOpen) {
        _controller.text = _formatEditable(widget.value);
        _error = null;
      } else {
        _commit(format: true);
      }
    });
    if (_manualOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = HomePaymentCalculatorSection.gold;
    final safeMax = widget.max <= widget.min ? widget.min + 1 : widget.max;
    final clamped = widget.value.clamp(widget.min, safeMax).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.75)),
                ),
                child: Icon(widget.icon, color: gold, size: 15),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
              // Tap value to open compact manual-entry dropdown.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleManual,
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _manualOpen
                          ? gold.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: gold.withValues(alpha: _manualOpen ? 0.7 : 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.display,
                          style: GoogleFonts.manrope(
                            color: gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _manualOpen
                              ? LucideIcons.chevronUp
                              : LucideIcons.chevronDown,
                          size: 14,
                          color: gold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _manualOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: widget.mode != _ManualInputMode.months,
                      ),
                      textInputAction: TextInputAction.done,
                      onChanged: _onManualChanged,
                      onSubmitted: (_) {
                        _commit(format: true);
                        setState(() => _manualOpen = false);
                      },
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        prefixText: _prefix,
                        prefixStyle: GoogleFonts.manrope(
                          color: gold,
                          fontWeight: FontWeight.w700,
                        ),
                        suffixText: _suffix,
                        suffixStyle: GoogleFonts.manrope(
                          color: HomePaymentCalculatorSection.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: _hint,
                        hintStyle: GoogleFonts.manrope(
                          color: HomePaymentCalculatorSection.muted,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0F0F0F),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: gold.withValues(alpha: 0.85),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        errorText: _error,
                        helperText: 'Results update as you type',
                        helperStyle: GoogleFonts.manrope(
                          color: HomePaymentCalculatorSection.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          _DottedSlider(
            value: clamped,
            min: widget.min,
            max: safeMax,
            divisions: widget.divisions ?? 40,
            onChanged: (v) {
              final next = widget.mode == _ManualInputMode.months
                  ? v.roundToDouble()
                  : v;
              setState(() {
                _error = null;
                _controller.text = _formatEditable(next);
              });
              widget.onChanged(next);
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in widget.markers)
                Text(
                  m,
                  style: GoogleFonts.manrope(
                    color: HomePaymentCalculatorSection.muted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom slider matching the mockup: dotted inactive track + gold active fill.
class _DottedSlider extends StatelessWidget {
  const _DottedSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final gold = HomePaymentCalculatorSection.gold;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
        final thumbX = t * width;

        return SizedBox(
          height: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final local = (details.localPosition.dx / width).clamp(0.0, 1.0);
              onChanged(min + local * (max - min));
            },
            onTapDown: (details) {
              final local = (details.localPosition.dx / width).clamp(0.0, 1.0);
              onChanged(min + local * (max - min));
            },
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                CustomPaint(
                  size: Size(width, 28),
                  painter: _DottedTrackPainter(
                    progress: t,
                    gold: gold,
                    divisions: divisions.clamp(8, 60),
                  ),
                ),
                Positioned(
                  left: (thumbX - 8).clamp(0.0, width - 16),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: gold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.55),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DottedTrackPainter extends CustomPainter {
  _DottedTrackPainter({
    required this.progress,
    required this.gold,
    required this.divisions,
  });

  final double progress;
  final Color gold;
  final int divisions;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final activeW = size.width * progress;

    // Inactive dotted track
    final dotPaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.fill;
    final count = divisions;
    for (var i = 0; i <= count; i++) {
      final x = size.width * (i / count);
      if (x <= activeW + 1) continue;
      canvas.drawCircle(Offset(x, cy), 1.35, dotPaint);
    }

    // Active gold track
    if (activeW > 0) {
      final activePaint = Paint()
        ..color = gold
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, cy), Offset(activeW, cy), activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedTrackPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.gold != gold ||
      oldDelegate.divisions != divisions;
}

/// Sizes the estimate card to the inputs column without [IntrinsicHeight].
///
/// Sliders and text fields use [LayoutBuilder], which cannot report an
/// intrinsic height. Measuring the inputs after layout keeps both columns
/// equal and avoids that crash.
class _MatchedHeightRow extends StatefulWidget {
  const _MatchedHeightRow({required this.inputs, required this.estimate});

  final Widget inputs;
  final Widget Function(bool expand) estimate;

  @override
  State<_MatchedHeightRow> createState() => _MatchedHeightRowState();
}

class _MatchedHeightRowState extends State<_MatchedHeightRow> {
  double? _height;

  void _onHeight(double next) {
    if (!mounted || _height == next) return;
    setState(() => _height = next);
  }

  @override
  Widget build(BuildContext context) {
    final height = _height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 12,
          child: _HeightSource(onHeight: _onHeight, child: widget.inputs),
        ),
        const SizedBox(width: 32),
        Expanded(
          flex: 9,
          child: height == null
              ? widget.estimate(false)
              : SizedBox(
                  height: height,
                  width: double.infinity,
                  child: widget.estimate(true),
                ),
        ),
      ],
    );
  }
}

class _HeightSource extends SingleChildRenderObjectWidget {
  const _HeightSource({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHeightSource(onHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightSource renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderHeightSource extends RenderProxyBox {
  _RenderHeightSource(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final next = size.height;
    if (_reported == next) return;
    _reported = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_reported == next) onHeight(next);
    });
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({
    required this.settings,
    required this.estimate,
    required this.onApply,
    this.expand = false,
  });

  final CmsCalculatorSettings settings;
  final PaymentPlanEstimate estimate;
  final VoidCallback onApply;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );
    final gold = HomePaymentCalculatorSection.gold;

    final card = Container(
      width: double.infinity,
      height: expand ? double.infinity : null,
      padding: EdgeInsets.fromLTRB(30, expand ? 36 : 34, 30, expand ? 32 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2D46B),
            Color(0xFFE4B84B),
            Color(0xFFD4A017),
            Color(0xFFC49212),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE4B84B).withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: expand ? StackFit.expand : StackFit.loose,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -18,
            top: -4,
            child: IgnorePointer(
              child: Icon(
                LucideIcons.building2,
                size: 168,
                color: HomePaymentCalculatorSection.ink.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1408),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(LucideIcons.fileText, color: gold, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Your estimate',
                    style: GoogleFonts.playfairDisplay(
                      color: HomePaymentCalculatorSection.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: expand ? 28 : 24),
              _EstimateRow(
                icon: LucideIcons.calendarDays,
                label: 'Monthly payment',
                value: currency.format(estimate.monthlyPayment),
              ),
              _EstimateRow(
                icon: LucideIcons.calculator,
                label: 'Total cost',
                value: currency.format(estimate.totalRepayment),
              ),
              _EstimateRow(
                icon: LucideIcons.link,
                label: 'Instalments',
                value: '${estimate.durationMonths} months',
                showDivider: false,
              ),
              if (expand)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Align(
                      alignment: Alignment.center,
                      child: _PlanSummary(
                        estimate: estimate,
                        currency: currency,
                      ),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 18),
                _PlanSummary(estimate: estimate, currency: currency),
                const SizedBox(height: 22),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Material(
                  color: const Color(0xFF14110C),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onApply,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          settings.applyCtaLabel,
                          style: GoogleFonts.manrope(
                            color: gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(LucideIcons.arrowRight, color: gold, size: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final painted = expand ? SizedBox.expand(child: card) : card;
    return painted.animate().fadeIn(delay: 80.ms, duration: 480.ms);
  }
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: HomePaymentCalculatorSection.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: HomePaymentCalculatorSection.ink.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                key: ValueKey(value),
                style: GoogleFonts.manrope(
                  color: HomePaymentCalculatorSection.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: HomePaymentCalculatorSection.ink.withValues(alpha: 0.14),
          ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.estimate, required this.currency});

  final PaymentPlanEstimate estimate;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final ink = HomePaymentCalculatorSection.ink;
    final price = estimate.propertyPrice;
    final depositShare = price <= 0
        ? 0.0
        : (estimate.depositAmount / price * 100).clamp(0, 100).toDouble();
    final sentence = estimate.loanAmount <= 0
        ? 'Your deposit covers the full price. Nothing is left to finance.'
        : 'Pay ${currency.format(estimate.depositAmount)} now '
              '(${depositShare.toStringAsFixed(0)}%), then '
              '${currency.format(estimate.monthlyPayment)} each month.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PLAN SUMMARY',
            style: GoogleFonts.manrope(
              color: HomePaymentCalculatorSection.gold,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sentence,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryStat(
                label: 'Deposit',
                value: currency.format(estimate.depositAmount),
              ),
              _SummaryStat(
                label: 'Financed',
                value: currency.format(estimate.loanAmount),
              ),
              _SummaryStat(
                label: 'Interest',
                value: currency.format(estimate.totalInterest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.items});

  final List<CmsCalculatorTrustItem> items;

  @override
  Widget build(BuildContext context) {
    final gold = HomePaymentCalculatorSection.gold;
    final display = items.take(4).toList();
    if (display.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (var i = 0; i < display.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Icon(_trustIcon(display[i].iconName), color: gold, size: 18),
                const SizedBox(height: 8),
                Text(
                  display[i].label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: gold.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HomePaymentCalculatorSection.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HomePaymentCalculatorSection.gold.withValues(alpha: 0.25),
        ),
      ),
      child: Text(message, style: GoogleFonts.manrope(color: Colors.white70)),
    );
  }
}

String _moneyShort(double value) {
  if (value >= 1000000) {
    return '₦${(value / 1000000).toStringAsFixed(1)}M';
  }
  return NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  ).format(value);
}

IconData _trustIcon(String name) {
  switch (name.toLowerCase()) {
    case 'percent':
      return LucideIcons.percent;
    case 'clock':
      return LucideIcons.clock;
    case 'headset':
    case 'headphones':
      return LucideIcons.headphones;
    default:
      return LucideIcons.shieldCheck;
  }
}
