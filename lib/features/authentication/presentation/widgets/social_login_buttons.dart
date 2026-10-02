import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/auth_method_gateway.dart';

/// Social / alternate auth methods.
///
/// Hidden until OAuth providers are enabled — disabled buttons looked broken
/// on the public login screen at launch.
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = [
      LoginMethod.google,
      LoginMethod.apple,
      LoginMethod.microsoft,
    ].where(AuthMethodCapabilities.isEnabled);

    // Phase 1: email/password only — keep this widget mounted for future OAuth.
    if (enabled.isEmpty) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }
}
