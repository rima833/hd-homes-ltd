import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/callback/domain/entities/callback_models.dart';
import 'package:hdhomesproject/features/callback/presentation/providers/callback_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class CallbackLux {
  static const Color bg = Color(0xFF0B0C0E);
  static const Color surface = Color(0xFF171B22);
  static const Color elevated = Color(0xFF1D2330);
  static const Color gold = Color(0xFFD8A63C);
  static const Color goldLight = Color(0xFFF0C76A);
  static const Color muted = Color(0xFF9AA0AB);
  static const Color border = Color(0xFF2A3140);
  static const double radius = 16;
}

/// Premium HD Homes callback request form — wired to Supabase.
class CallbackRequestForm extends ConsumerStatefulWidget {
  const CallbackRequestForm({super.key});

  @override
  ConsumerState<CallbackRequestForm> createState() =>
      _CallbackRequestFormState();
}

class _CallbackRequestFormState extends ConsumerState<CallbackRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();

  String? _preferredTime;
  String? _departmentId;
  String? _priorityId;
  var _submitting = false;
  String? _error;
  CallbackSubmitResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(identitySessionProvider).profile;
      if (profile != null) {
        _name.text = profile.displayName;
        if (profile.phone != null) _phone.text = profile.phone!;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userId = ref.read(identitySessionProvider).userId;
      final profile = ref.read(identitySessionProvider).profile;
      final result = await ref.read(callbackServiceProvider).submit(
            fullName: _name.text,
            phone: _phone.text,
            reason: _reason.text,
            preferredTime: _preferredTime,
            departmentId: _departmentId,
            priorityId: _priorityId,
            email: profile?.email,
            visitorProfileId: userId,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingError(
          e,
          fallback: 'We couldn\'t submit your callback request. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(callbackSettingsProvider);
    final deptsAsync = ref.watch(callbackDepartmentsProvider);
    final prioritiesAsync = ref.watch(callbackPrioritiesProvider);
    final hoursAsync = ref.watch(callbackWorkingHoursProvider);

    if (_result != null) {
      return _SuccessPanel(
        result: _result!,
        settings: settingsAsync.valueOrNull,
        onReset: () {
          _name.clear();
          _phone.clear();
          _reason.clear();
          setState(() {
            _result = null;
            _preferredTime = null;
            _departmentId = null;
            _priorityId = null;
          });
        },
      );
    }

    return settingsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: CallbackLux.gold),
        ),
      ),
      error: (e, _) => Text(
        userFacingError(e, fallback: 'Unable to load callback form.'),
      ),
      data: (settings) {
        if (settings == null || !settings.isEnabled) {
          return _UnavailableCard(
            message: settings?.afterHoursMessage ??
                'Callback requests are temporarily unavailable.',
          );
        }

        final depts = deptsAsync.valueOrNull ?? const <CallbackDepartment>[];
        final priorities =
            prioritiesAsync.valueOrNull ?? const <CallbackPriority>[];
        final hours = hoursAsync.valueOrNull ?? const <CallbackWorkingHour>[];
        final availableNow =
            settings.showAvailableNow &&
                ref.read(callbackServiceProvider).isWithinBusinessHours(hours);

        // Default priority to Normal when loaded
        if (_priorityId == null && priorities.isNotEmpty) {
          for (final p in priorities) {
            if (p.slug == 'normal') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _priorityId == null) {
                  setState(() => _priorityId = p.id);
                }
              });
              break;
            }
          }
        }

        return Column(
          children: [
            Text(
              'CALLBACK',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: CallbackLux.gold,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              settings.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                settings.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CallbackLux.muted, height: 1.5),
              ),
            ),
            const SizedBox(height: 8),
            if (settings.showAvailableNow)
              Text(
                availableNow ? 'Available now' : settings.afterHoursMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: availableNow ? AppColors.success : CallbackLux.muted,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CallbackLux.surface,
                borderRadius: BorderRadius.circular(CallbackLux.radius),
                border: Border.all(color: CallbackLux.gold.withValues(alpha: 0.35)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 1280;
                        final fields = [
                          _LuxField(
                            label: 'Your Name',
                            required: true,
                            icon: LucideIcons.user,
                            controller: _name,
                            hint: 'Enter your full name',
                            validator: (v) =>
                                (v == null || v.trim().length < 2)
                                    ? 'Required'
                                    : null,
                          ),
                          _LuxField(
                            label: 'Phone Number',
                            required: true,
                            icon: LucideIcons.phone,
                            controller: _phone,
                            hint: 'Enter your phone number',
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final digits = v.replaceAll(RegExp(r'\D'), '');
                              if (digits.length < 10 || digits.length > 15) {
                                return 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          _LuxDropdown<String>(
                            label: 'Best Time to Call',
                            icon: LucideIcons.clock,
                            value: _preferredTime,
                            hint: 'Select preferred time',
                            items: [
                              for (final t in settings.preferredTimeOptions)
                                DropdownMenuItem(value: t, child: Text(t)),
                            ],
                            onChanged: (v) =>
                                setState(() => _preferredTime = v),
                          ),
                          _LuxDropdown<String>(
                            label: 'Department',
                            icon: LucideIcons.briefcase,
                            value: _departmentId,
                            hint: 'Select department',
                            items: [
                              for (final d in depts)
                                DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _departmentId = v),
                          ),
                          _LuxDropdown<String>(
                            label: 'Priority',
                            icon: LucideIcons.flag,
                            value: _priorityId,
                            hint: 'Select priority',
                            items: [
                              for (final p in priorities)
                                DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                            ],
                            onChanged: (v) => setState(() => _priorityId = v),
                          ),
                        ];

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < fields.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(child: fields[i]),
                              ],
                            ],
                          );
                        }
                        if (c.maxWidth >= 640) {
                          return Wrap(
                            spacing: 12,
                            runSpacing: 14,
                            children: [
                              for (final f in fields)
                                SizedBox(
                                  width: (c.maxWidth - 12) / 2,
                                  child: f,
                                ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (final f in fields) ...[
                              f,
                              const SizedBox(height: 14),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _LuxField(
                      label: 'Reason for Callback',
                      required: true,
                      icon: LucideIcons.messageSquare,
                      controller: _reason,
                      hint: 'Tell us briefly how we can assist you...',
                      maxLines: 3,
                      validator: (v) =>
                          (v == null || v.trim().length < 3) ? 'Required' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _submitting ? null : _submit,
                            child: Center(
                              child: _submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(LucideIcons.phone, size: 18, color: Colors.black),
                                        const SizedBox(width: 10),
                                        Text(
                                          _submitting
                                              ? 'Submitting Request...'
                                              : '${settings.ctaText} →',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _TrustRow(settings: settings),
          ],
        );
      },
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({
    required this.result,
    required this.onReset,
    this.settings,
  });

  final CallbackSubmitResult result;
  final VoidCallback onReset;
  final CallbackSettings? settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CallbackLux.surface,
        borderRadius: BorderRadius.circular(CallbackLux.radius),
        border: Border.all(color: CallbackLux.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 48),
          const SizedBox(height: 16),
          Text(
            settings?.successTitle ?? 'Callback request received',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            settings?.successMessage ??
                'Thank you. Our team has received your request and will contact you shortly.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: CallbackLux.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          _InfoLine(label: 'Reference', value: result.reference),
          if (result.department != null)
            _InfoLine(label: 'Department', value: result.department!),
          if (result.priority != null)
            _InfoLine(label: 'Priority', value: result.priority!),
          _InfoLine(
            label: 'Expected response',
            value: 'Within ${result.responseHours} hours',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onReset,
            child: const Text('Back to website'),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: CallbackLux.muted)),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CallbackLux.surface,
        borderRadius: BorderRadius.circular(CallbackLux.radius),
        border: Border.all(color: CallbackLux.border),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.phoneOff, color: CallbackLux.gold, size: 36),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CallbackLux.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.settings});
  final CallbackSettings settings;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.shieldCheck, settings.trustSecurity),
      (LucideIcons.clock, settings.trustResponse),
      (LucideIcons.headphones, settings.trustExpert),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, size: 14, color: CallbackLux.gold),
              const SizedBox(width: 8),
              Text(
                item.$2,
                style: const TextStyle(color: CallbackLux.muted, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }
}

class _LuxField extends StatelessWidget {
  const _LuxField({
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: CallbackLux.gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CallbackLux.muted, fontSize: 12),
              ),
            ),
            if (required)
              const Text(' *', style: TextStyle(color: CallbackLux.gold)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: CallbackLux.muted, fontSize: 13),
            filled: true,
            fillColor: CallbackLux.elevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CallbackLux.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CallbackLux.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CallbackLux.gold),
            ),
          ),
        ),
      ],
    );
  }
}

class _LuxDropdown<T> extends StatelessWidget {
  const _LuxDropdown({
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
  });

  final String label;
  final IconData icon;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: CallbackLux.gold),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CallbackLux.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          dropdownColor: CallbackLux.elevated,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: CallbackLux.muted, fontSize: 13),
            filled: true,
            fillColor: CallbackLux.elevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CallbackLux.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CallbackLux.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CallbackLux.gold),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
