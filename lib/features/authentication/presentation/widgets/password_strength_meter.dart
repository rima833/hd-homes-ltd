import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_validator.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  Color _color(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => AppColors.gray,
        PasswordStrength.weak => AppColors.error,
        PasswordStrength.fair => Colors.orange,
        PasswordStrength.good => AppColors.gold,
        PasswordStrength.strong => Colors.green,
        PasswordStrength.excellent => const Color(0xFF0D9488),
      };

  String _label(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => 'Enter a password',
        PasswordStrength.weak => 'Weak',
        PasswordStrength.fair => 'Fair',
        PasswordStrength.good => 'Good',
        PasswordStrength.strong => 'Strong',
        PasswordStrength.excellent => 'Excellent',
      };

  double _value(PasswordStrength strength) => switch (strength) {
        PasswordStrength.empty => 0,
        PasswordStrength.weak => 0.2,
        PasswordStrength.fair => 0.4,
        PasswordStrength.good => 0.6,
        PasswordStrength.strong => 0.8,
        PasswordStrength.excellent => 1,
      };

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrengthEvaluator.evaluate(password);
    final checks = PasswordStrengthEvaluator.checklist(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _value(strength),
                color: _color(strength),
                backgroundColor: AppColors.gray.withValues(alpha: 0.25),
                minHeight: 6,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(_label(strength), style: TextStyle(color: _color(strength), fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...checks.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  e.value ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: e.value ? Colors.green : AppColors.gray,
                ),
                const SizedBox(width: 6),
                Text(e.key, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
