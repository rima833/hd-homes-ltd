import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/registration_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/password_strength_meter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Staff invitation acceptance. Not the client or investor registration wizard.
class StaffInviteAccessForm extends HookConsumerWidget {
  const StaffInviteAccessForm({
    super.key,
    required this.roleLabel,
    required this.email,
  });

  final String roleLabel;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(registrationControllerProvider);
    final controller = ref.read(registrationControllerProvider.notifier);
    final d = flow.draft;
    final errors = flow.fieldErrors;
    final firstName = useTextEditingController(text: d.firstName);
    final lastName = useTextEditingController(text: d.lastName);
    final phone = useTextEditingController(text: d.phone);
    final password = useTextEditingController(text: d.password);
    final confirm = useTextEditingController(text: d.confirmPassword);
    final accepted = d.acceptTerms && d.acceptPrivacy && d.acceptCookies;

    Future<void> submit() async {
      controller.updateDraft(
        (draft) => draft.copyWith(
          firstName: firstName.text,
          lastName: lastName.text,
          email: email.trim().isEmpty ? draft.email : email.trim(),
          phone: phone.text,
          password: password.text,
          confirmPassword: confirm.text,
        ),
      );
      final result = await controller.submitStaffInvite();
      if (!context.mounted || result == null) return;
      if (result.needsEmailVerification) {
        context.go(
          '${RoutePaths.verifyEmail}?email=${Uri.encodeComponent(result.email)}&type=staff',
        );
      } else {
        context.go('${RoutePaths.welcome}?type=staff');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Staff access',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          roleLabel.trim().isEmpty
              ? 'Create your staff password to open your workspace.'
              : 'You are invited as ${roleLabel.trim()}. Create your staff password to open your workspace.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white60, height: 1.4),
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: firstName,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'First name',
            errorText: errors['firstName'],
          ),
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(firstName: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: lastName,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Last name',
            errorText: errors['lastName'],
          ),
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(lastName: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: email,
          readOnly: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Work email',
            errorText: errors['email'],
            prefixIcon: const Icon(LucideIcons.mail, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phone,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone',
            errorText: errors['phone'],
          ),
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(phone: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: password,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: errors['password'],
            prefixIcon: const Icon(LucideIcons.lock, size: 18),
          ),
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(password: v)),
        ),
        const SizedBox(height: 10),
        PasswordStrengthMeter(password: flow.draft.password),
        const SizedBox(height: 12),
        TextFormField(
          controller: confirm,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: errors['confirmPassword'],
            prefixIcon: const Icon(LucideIcons.shieldCheck, size: 18),
          ),
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(confirmPassword: v)),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: accepted,
          onChanged: flow.isSubmitting
              ? null
              : (value) {
                  final on = value ?? false;
                  controller.updateDraft(
                    (x) => x.copyWith(
                      acceptTerms: on,
                      acceptPrivacy: on,
                      acceptCookies: on,
                    ),
                  );
                },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.gold,
          checkColor: AppColors.deepBlack,
          title: const Text(
            'I accept the Terms, Privacy Policy, and Cookie Policy',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        if (flow.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            flow.errorMessage!,
            style: const TextStyle(color: AppColors.error, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Create staff access',
          expand: true,
          isLoading: flow.isSubmitting,
          onPressed: flow.isSubmitting ? null : submit,
        ),
      ],
    );
  }
}
