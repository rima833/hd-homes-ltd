import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_method_gateway.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Future-ready social / alternate auth method buttons (disabled until enabled).
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  static const _methods = [
    LoginMethod.google,
    LoginMethod.apple,
    LoginMethod.microsoft,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Text(
                'Or continue with',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: _methods.map((method) {
            return Tooltip(
              message: AuthMethodCapabilities.comingSoonLabel(method),
              child: OutlinedButton.icon(
                onPressed: null,
                icon: Icon(_iconFor(method), size: 18),
                label: Text(method.label),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _iconFor(LoginMethod method) => switch (method) {
        LoginMethod.google => LucideIcons.chrome,
        LoginMethod.apple => LucideIcons.apple,
        LoginMethod.microsoft => LucideIcons.monitor,
        _ => LucideIcons.logIn,
      };
}
