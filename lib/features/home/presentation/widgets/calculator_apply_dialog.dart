import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/home/data/providers/payment_calculator_provider.dart';
import 'package:hdhomesproject/features/home/domain/payment_plan_math.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

Future<void> openCalculatorApplyDialog(
  BuildContext context,
  WidgetRef ref, {
  required CmsCalculatorSettings settings,
  required CmsCalculatorPaymentPlan plan,
  required PaymentCalculatorState state,
  required PaymentPlanEstimate estimate,
}) async {
  final controller = ref.read(paymentCalculatorControllerProvider.notifier);
  final validation = controller.validateForApply();
  if (validation != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(validation)));
    return;
  }

  final submitted = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) => _CalculatorApplyDialog(
      settings: settings,
      plan: plan,
      state: state,
      estimate: estimate,
    ),
  );

  if (submitted == true && context.mounted) {
    ref.invalidate(myCalculatorApplicationsProvider);
    final signedIn = ref.read(isAuthenticatedProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          signedIn
              ? 'Application submitted. HD Homes will reply under this calculator.'
              : 'Application submitted. HD Homes will contact you. Sign in with this email to read their reply here.',
        ),
      ),
    );
  }
}

class _CalculatorApplyDialog extends ConsumerStatefulWidget {
  const _CalculatorApplyDialog({
    required this.settings,
    required this.plan,
    required this.state,
    required this.estimate,
  });

  final CmsCalculatorSettings settings;
  final CmsCalculatorPaymentPlan plan;
  final PaymentCalculatorState state;
  final PaymentPlanEstimate estimate;

  @override
  ConsumerState<_CalculatorApplyDialog> createState() =>
      _CalculatorApplyDialogState();
}

class _CalculatorApplyDialogState
    extends ConsumerState<_CalculatorApplyDialog> {
  static const _gold = Color(0xFFD4AF37);
  static const _card = Color(0xFF161616);
  static const _muted = Color(0xFF8A8A8A);
  static const _ink = Color(0xFF1A1408);

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _occupation = TextEditingController();
  final _message = TextEditingController();
  var _contact = 'phone';
  var _submitting = false;
  String? _error;
  var _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final profile = ref.read(currentUserProvider);
    if (profile == null) return;
    _name.text = profile.displayName == profile.email
        ? ''
        : profile.displayName;
    _email.text = profile.email;
    _phone.text = profile.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _occupation.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final fullName = _name.text.trim();
    final mail = _email.text.trim();
    if (fullName.length < 2 || !mail.contains('@')) {
      setState(() => _error = 'Name and a valid email are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (!ref.read(supabaseConfiguredProvider)) {
        throw StateError(
          'Supabase is not configured. Application cannot be saved.',
        );
      }
      final estimate = widget.estimate;
      await ref
          .read(cmsServiceProvider)
          .submitCalculatorApplication(
            planId: widget.plan.id,
            propertyId: widget.state.propertyId,
            fullName: fullName,
            email: mail,
            phone: _phone.text.trim(),
            city: _city.text.trim(),
            preferredContact: _contact,
            occupation: _occupation.text.trim(),
            message: _message.text.trim(),
            propertyPrice: estimate.propertyPrice,
            depositAmount: estimate.depositAmount,
            durationMonths: estimate.durationMonths,
            interestRate: estimate.interestRate,
            loanAmount: estimate.loanAmount,
            monthlyPayment: estimate.monthlyPayment,
            totalRepayment: estimate.totalRepayment,
            totalInterest: estimate.totalInterest,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingError(
          e,
          fallback: 'We could not submit your application. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimate = widget.estimate;
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final money = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    );

    return Dialog(
      backgroundColor: _card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      color: _gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.settings.applyCtaLabel,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.plan.name,
                          style: GoogleFonts.manrope(
                            color: _muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(
                      LucideIcons.x,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PlanSummary(estimate: estimate, money: money),
                    const SizedBox(height: 18),
                    Text(
                      'Your details',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HD Homes reviews this on the public calculator, in Buying Tools, and in Investment Tools. Sign in with this email to read their reply under the calculator.',
                      style: GoogleFonts.manrope(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field(_name, 'Full name', icon: LucideIcons.user),
                    const SizedBox(height: 10),
                    if (wide)
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _email,
                              'Email',
                              icon: LucideIcons.mail,
                              keyboard: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              _phone,
                              'Phone',
                              icon: LucideIcons.phone,
                              keyboard: TextInputType.phone,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _field(
                        _email,
                        'Email',
                        icon: LucideIcons.mail,
                        keyboard: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        _phone,
                        'Phone',
                        icon: LucideIcons.phone,
                        keyboard: TextInputType.phone,
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (wide)
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _city,
                              'City',
                              icon: LucideIcons.mapPin,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              _occupation,
                              'Occupation',
                              icon: LucideIcons.briefcase,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _field(_city, 'City', icon: LucideIcons.mapPin),
                      const SizedBox(height: 10),
                      _field(
                        _occupation,
                        'Occupation',
                        icon: LucideIcons.briefcase,
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Preferred contact',
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _contactChip('phone', 'Phone', LucideIcons.phone),
                        _contactChip('email', 'Email', LucideIcons.mail),
                        _contactChip(
                          'whatsapp',
                          'WhatsApp',
                          LucideIcons.messageCircle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _message,
                      'What are you looking for?',
                      hint: 'Unit type, timeline, or questions for the team',
                      maxLines: 3,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A1515),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE57373)),
                        ),
                        child: Text(
                          _error!,
                          style: GoogleFonts.manrope(
                            color: const Color(0xFFFFCDD2),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.manrope(color: Colors.white70),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      _submitting ? 'Submitting…' : 'Submit application',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactChip(String value, String label, IconData icon) {
    final selected = _contact == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      avatar: Icon(icon, size: 14, color: selected ? _ink : _gold),
      labelStyle: GoogleFonts.manrope(
        color: selected ? _ink : Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      showCheckmark: false,
      selectedColor: _gold,
      backgroundColor: const Color(0xFF101010),
      side: BorderSide(
        color: selected ? _gold : Colors.white.withValues(alpha: 0.1),
      ),
      onSelected: _submitting ? null : (_) => setState(() => _contact = value),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 16, color: _gold.withValues(alpha: 0.9)),
        labelStyle: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
        hintStyle: GoogleFonts.manrope(color: _muted, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF101010),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _gold),
        ),
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.estimate, required this.money});

  final PaymentPlanEstimate estimate;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Monthly', money.format(estimate.monthlyPayment)),
      ('Deposit', money.format(estimate.depositAmount)),
      ('Duration', '${estimate.durationMonths} months'),
      (
        'Rate',
        '${estimate.interestRate.toStringAsFixed(estimate.interestRate == estimate.interestRate.roundToDouble() ? 0 : 1)}%',
      ),
      ('Price', money.format(estimate.propertyPrice)),
      ('Financed', money.format(estimate.loanAmount)),
      ('Total repayment', money.format(estimate.totalRepayment)),
      ('Total interest', money.format(estimate.totalInterest)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$1,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF8A8A8A),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.$2,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
