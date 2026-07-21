import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_assistant.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/registration_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/account_type_cards.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/password_strength_meter.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/registration_stepper_header.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Progressive Registration™ — multi-step onboarding (Volume 3 Part 2).
class RegisterPage extends HookConsumerWidget {
  const RegisterPage({
    super.key,
    this.initialAccountType,
    this.initialReferralCode,
    this.invitationToken,
    this.initialEmail,
  });

  final String? initialAccountType;
  final String? initialReferralCode;
  final String? invitationToken;
  final String? initialEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(registrationControllerProvider);
    final controller = ref.read(registrationControllerProvider.notifier);

    useEffect(() {
      final type = RegistrationAccountType.fromId(initialAccountType);
      if (type != null && type.enabled) {
        controller.selectAccountType(type);
      }
      if (initialReferralCode != null && initialReferralCode!.trim().isNotEmpty) {
        controller.updateDraft(
          (d) => d.copyWith(referralCode: initialReferralCode!.trim().toUpperCase()),
        );
      }
      if (invitationToken != null && invitationToken!.trim().isNotEmpty) {
        controller.updateDraft((d) => d.copyWith(invitationToken: invitationToken!.trim()));
      }
      if (initialEmail != null && initialEmail!.trim().isNotEmpty) {
        controller.updateDraft((d) => d.copyWith(email: initialEmail!.trim()));
      }
      return null;
    }, const []);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(AppTheme.logoAsset, height: 48),
                  const SizedBox(height: AppSpacing.xl),
                  RegistrationStepperHeader(
                    current: flow.step,
                    onStepTap: controller.goToStep,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    RegistrationAssistant.tipForStep(
                      flow.step,
                      accountType: flow.draft.accountType,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (flow.errorMessage != null) ...[
                    Material(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: AppRadius.cardBorder,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.base),
                        child: Text(flow.errorMessage!, style: const TextStyle(color: AppColors.error)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ],
                  _StepBody(flow: flow, controller: controller),
                  const SizedBox(height: AppSpacing.xl),
                  _NavButtons(flow: flow, controller: controller),
                  const SizedBox(height: AppSpacing.base),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.login),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context) {
    return switch (flow.step) {
      RegistrationStep.accountType => AccountTypeCards(
          selected: flow.draft.accountType,
          onSelected: controller.selectAccountType,
        ),
      RegistrationStep.personalInfo => _PersonalInfoStep(flow: flow, controller: controller),
      RegistrationStep.credentials => _CredentialsStep(flow: flow, controller: controller),
      RegistrationStep.legal => _LegalStep(flow: flow, controller: controller),
      RegistrationStep.review => _ReviewStep(flow: flow),
    };
  }
}

class _PersonalInfoStep extends StatelessWidget {
  const _PersonalInfoStep({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context) {
    final d = flow.draft;
    final errors = flow.fieldErrors;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            RegistrationAssistant.onboardingHint(d.accountType),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        _field(
          label: 'First name',
          initial: d.firstName,
          error: errors['firstName'],
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(firstName: v)),
        ),
        _field(
          label: 'Last name',
          initial: d.lastName,
          error: errors['lastName'],
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(lastName: v)),
        ),
        _field(
          label: 'Email',
          initial: d.email,
          error: errors['email'],
          keyboard: TextInputType.emailAddress,
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(email: v)),
        ),
        _field(
          label: 'Phone',
          initial: d.phone,
          error: errors['phone'],
          keyboard: TextInputType.phone,
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(phone: v)),
        ),
        _field(
          label: 'Country',
          initial: d.country,
          error: errors['country'],
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(country: v)),
        ),
        _field(
          label: 'State',
          initial: d.state,
          error: errors['state'],
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(state: v)),
        ),
        _field(
          label: 'City (optional)',
          initial: d.city,
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(city: v)),
        ),
        _field(
          label: 'Referral code (optional)',
          initial: d.referralCode,
          error: errors['referralCode'],
          onChanged: (v) => controller.updateDraft((draft) => draft.copyWith(referralCode: v)),
          onEditingComplete: controller.validateReferral,
        ),
        if (flow.referralValid == true)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Referral code accepted', style: TextStyle(color: Colors.green)),
          ),
        if (flow.referralValid == false)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Code format is valid — rewards activate when the referral program goes live.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _field({
    required String label,
    required String initial,
    required ValueChanged<String> onChanged,
    String? error,
    TextInputType? keyboard,
    VoidCallback? onEditingComplete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: TextFormField(
        initialValue: initial,
        decoration: InputDecoration(labelText: label, errorText: error),
        keyboardType: keyboard,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
      ),
    );
  }
}

class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context) {
    final errors = flow.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: flow.draft.password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: errors['password'],
          ),
          onChanged: (v) => controller.updateDraft((d) => d.copyWith(password: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        PasswordStrengthMeter(password: flow.draft.password),
        const SizedBox(height: AppSpacing.base),
        TextFormField(
          initialValue: flow.draft.confirmPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: errors['confirmPassword'],
          ),
          onChanged: (v) => controller.updateDraft((d) => d.copyWith(confirmPassword: v)),
        ),
      ],
    );
  }
}

class _LegalStep extends StatelessWidget {
  const _LegalStep({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context) {
    final d = flow.draft;
    return Column(
      children: [
        CheckboxListTile(
          value: d.acceptTerms,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(acceptTerms: v ?? false)),
          title: Text('I agree to the Terms & Conditions (${LegalDocumentVersions.terms})'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: d.acceptPrivacy,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(acceptPrivacy: v ?? false)),
          title: Text('I agree to the Privacy Policy (${LegalDocumentVersions.privacy})'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: d.acceptCookies,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(acceptCookies: v ?? false)),
          title: Text('I agree to the Cookie Policy (${LegalDocumentVersions.cookies})'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const Divider(),
        CheckboxListTile(
          value: d.marketingOptIn,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(marketingOptIn: v ?? false)),
          title: const Text('Send me marketing communications'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: d.productUpdatesOptIn,
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(productUpdatesOptIn: v ?? false)),
          title: const Text('Product updates'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: d.newsletterOptIn,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(newsletterOptIn: v ?? false)),
          title: const Text('Newsletter subscription'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.flow});

  final RegistrationFlowState flow;

  @override
  Widget build(BuildContext context) {
    final d = flow.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review & create', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.base),
            _row('Account type', d.accountType?.title ?? '—'),
            _row('Name', '${d.firstName} ${d.lastName}'.trim()),
            _row('Email', d.email),
            _row('Phone', d.phone),
            _row('Location', [d.city, d.state, d.country].where((e) => e.trim().isNotEmpty).join(', ')),
            if (d.referralCode.trim().isNotEmpty) _row('Referral', d.referralCode.toUpperCase()),
            _row('Legal', 'Terms, Privacy & Cookies accepted'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _NavButtons extends ConsumerWidget {
  const _NavButtons({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirst = flow.step == RegistrationStep.accountType;
    final isLast = flow.step == RegistrationStep.review;

    return Row(
      children: [
        if (!isFirst)
          Expanded(
            child: PrimaryButton(
              label: 'Back',
              variant: ButtonVariant.secondary,
              onPressed: flow.isSubmitting ? null : controller.previousStep,
            ),
          ),
        if (!isFirst) const SizedBox(width: AppSpacing.base),
        Expanded(
          child: PrimaryButton(
            label: isLast ? 'Create Account' : 'Continue',
            expand: true,
            isLoading: flow.isSubmitting,
            onPressed: flow.isSubmitting
                ? null
                : () async {
                    if (!isLast) {
                      controller.nextStep();
                      return;
                    }
                    final result = await controller.submit();
                    if (!context.mounted || result == null) return;
                    if (result.needsEmailVerification) {
                      context.go(
                        '${RoutePaths.verifyEmail}?email=${Uri.encodeComponent(result.email)}'
                        '&type=${result.accountType.id}',
                      );
                    } else {
                      context.go(
                        '${RoutePaths.welcome}?type=${result.accountType.id}',
                      );
                    }
                  },
          ),
        ),
      ],
    );
  }
}
