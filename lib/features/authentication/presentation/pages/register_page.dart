import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/login_audience.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/registration_assistant.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/login_audience_provider.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/registration_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/account_type_cards.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/auth_cinematic_shell.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/password_strength_meter.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/registration_legal_agreements.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/registration_stepper_header.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/staff_invite_access_form.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Progressive Registration™ — cinematic multi-step onboarding.
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
    final session = ref.watch(identitySessionProvider);
    final acceptingInvite = useState(false);
    final acceptError = useState<String?>(null);

    // useEffect runs during build. Riverpod rejects provider writes then and
    // replaces this page with the generic error before the form can paint.
    useEffect(() {
      final typeId = initialAccountType;
      final referral = initialReferralCode;
      final token = invitationToken;
      final email = initialEmail;
      Future<void>(() {
        final type = RegistrationAccountType.fromId(typeId);
        if (type != null && type.enabled) {
          controller.selectAccountType(type);
        }
        final referralCode = referral?.trim() ?? '';
        final inviteToken = token?.trim() ?? '';
        final inviteEmail = email?.trim() ?? '';
        if (referralCode.isEmpty &&
            inviteToken.isEmpty &&
            inviteEmail.isEmpty) {
          return;
        }
        controller.updateDraft(
          (d) => d.copyWith(
            referralCode: referralCode.isEmpty
                ? d.referralCode
                : referralCode.toUpperCase(),
            invitationToken: inviteToken.isEmpty
                ? d.invitationToken
                : inviteToken,
            email: inviteEmail.isEmpty ? d.email : inviteEmail,
          ),
        );
      });
      return null;
    }, const []);

    final invitePreview = useState<Map<String, dynamic>?>(null);
    final inviteLookupDone = useState((invitationToken ?? '').trim().isEmpty);
    useEffect(() {
      final token = invitationToken?.trim();
      if (token == null || token.isEmpty) return null;
      Future<void>(() async {
        try {
          final preview = await ref
              .read(organizationServiceProvider)
              .previewAnyInvitation(token);
          invitePreview.value = preview;
          final role = preview?['role_slug'] as String?;
          final isPortalClient =
              preview?['valid'] == true &&
              preview?['kind'] == 'portal' &&
              (role == 'client' || role == 'investor');
          if (isPortalClient) {
            final type = RegistrationAccountType.fromId(role);
            if (type != null && type.enabled) {
              controller.selectAccountType(type);
            }
          } else if (preview?['valid'] == true) {
            final first = preview?['first_name']?.toString().trim() ?? '';
            final last = preview?['last_name']?.toString().trim() ?? '';
            final previewEmail = preview?['email']?.toString().trim() ?? '';
            controller.updateDraft((d) {
              var next = d;
              if (first.isNotEmpty && next.firstName.trim().isEmpty) {
                next = next.copyWith(firstName: first);
              }
              if (last.isNotEmpty && next.lastName.trim().isEmpty) {
                next = next.copyWith(lastName: last);
              }
              if (previewEmail.isNotEmpty) {
                next = next.copyWith(email: previewEmail);
              }
              if ((next.invitationToken ?? '').trim().isEmpty) {
                next = next.copyWith(invitationToken: token);
              }
              return next;
            });
          }
        } finally {
          inviteLookupDone.value = true;
        }
      });
      return null;
    }, [invitationToken]);

    final inviteKind = invitePreview.value?['kind'] as String? ?? 'staff';
    final inviteRole = (invitePreview.value?['role_slug'] as String? ?? '')
        .replaceAll('_', ' ');
    final inviteValid = invitePreview.value?['valid'] == true;
    final inviteStatus = invitePreview.value?['status']?.toString();
    final inviteEmail = (invitePreview.value?['email'] ?? initialEmail ?? '')
        .toString()
        .trim();
    final signedInEmail = (session.email ?? '').trim();
    final sameInvitee =
        signedInEmail.isNotEmpty &&
        inviteEmail.isNotEmpty &&
        signedInEmail.toLowerCase() == inviteEmail.toLowerCase();

    final inviteClosed = invitePreview.value != null && !inviteValid;
    final staffAccess = inviteValid && inviteKind != 'portal';
    final openingInvite =
        (invitationToken ?? '').trim().isNotEmpty && !inviteLookupDone.value;
    final brand = openingInvite
        ? (
            'Opening your invitation',
            'Checking this invitation before the staff form opens.',
          )
        : staffAccess
        ? (
            'Activate your staff access',
            'This form is for the invited staff role. It is separate from client and investor signup.',
          )
        : inviteClosed
        ? (
            inviteStatus == 'accepted'
                ? 'You are already on the team'
                : 'This invitation cannot be used',
            inviteStatus == 'accepted'
                ? 'This invitation was accepted. Sign in with the invited email to open your workspace.'
                : 'Ask an admin to send a new invitation.',
          )
        : switch (flow.step) {
            RegistrationStep.accountType => (
              'Begin your HD Homes journey',
              'Choose the experience that fits — buying a home or growing wealth.',
            ),
            RegistrationStep.personalInfo => (
              'Tell us a little about you',
              'We use this to personalize your dashboard and keep you informed.',
            ),
            RegistrationStep.credentials => (
              'Protect what matters',
              'A strong password keeps your properties, bookings, and documents safe.',
            ),
            RegistrationStep.legal => (
              'Clarity & trust',
              'Review the essentials. Marketing preferences stay optional.',
            ),
            RegistrationStep.review => (
              'You are almost there',
              'Confirm everything looks right — then we will send a quick email check.',
            ),
          };

    return AuthCinematicShell(
      headline: brand.$1,
      subtitle: brand.$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invitePreview.value != null && !inviteClosed) ...[
            _InviteBanner(
              valid: inviteValid,
              kind: inviteKind,
              role: inviteRole,
              email: invitePreview.value!['email']?.toString(),
              status: invitePreview.value!['status']?.toString(),
            ),
            const SizedBox(height: 16),
          ],
          if (session.isAuthenticated &&
              (invitationToken ?? '').trim().isNotEmpty) ...[
            _SignedInInvitePanel(
              inviteEmail: inviteEmail,
              signedInEmail: signedInEmail,
              sameInvitee: sameInvitee,
              inviteValid: inviteValid,
              inviteStatus: inviteStatus,
              busy: acceptingInvite.value,
              error: acceptError.value,
              onAccept: !sameInvitee || !inviteValid
                  ? null
                  : () async {
                      acceptingInvite.value = true;
                      acceptError.value = null;
                      try {
                        await ref
                            .read(organizationServiceProvider)
                            .acceptAnyInvitation(invitationToken!.trim());
                        await ref
                            .read(identitySessionProvider.notifier)
                            .refreshPermissions();
                        if (!context.mounted) return;
                        final role = AppRole.fromSlug(
                          invitePreview.value?['role_slug']?.toString(),
                        );
                        context.go(role?.defaultRoute ?? RoutePaths.dashboard);
                      } catch (e) {
                        acceptError.value = userFacingError(
                          e,
                          fallback:
                              'Could not accept this invitation. Please try again.',
                        );
                      } finally {
                        acceptingInvite.value = false;
                      }
                    },
              onSignOut: () async {
                await ref
                    .read(identitySessionProvider.notifier)
                    .signOut(reason: 'accept_staff_invite');
              },
              onContinue: () {
                final role = AppRole.fromSlug(
                  invitePreview.value?['role_slug']?.toString(),
                );
                context.go(role?.defaultRoute ?? RoutePaths.dashboard);
              },
            ),
          ] else if (inviteClosed) ...[
            _ClosedInvitePanel(
              status: inviteStatus,
              email: inviteEmail,
              onSignIn: () {
                final email = Uri.encodeComponent(inviteEmail);
                context.go(
                  email.isEmpty
                      ? RoutePaths.login
                      : '${RoutePaths.login}?email=$email',
                );
              },
            ),
          ] else if (openingInvite) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
          ] else if (staffAccess) ...[
            StaffInviteAccessForm(
              key: ValueKey('staff-$inviteEmail'),
              roleLabel: inviteRole,
              email: inviteEmail,
            ),
          ] else ...[
            RegistrationStepperHeader(
              current: flow.step,
              onStepTap: controller.goToStep,
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 340),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                final offset = Tween<Offset>(
                  begin: const Offset(0.03, 0.05),
                  end: Offset.zero,
                ).animate(anim);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(flow.step),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      RegistrationAssistant.tipForStep(
                        flow.step,
                        accountType: flow.draft.accountType,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (flow.errorMessage != null) ...[
                      _ErrorBanner(message: flow.errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    _StepBody(flow: flow, controller: controller),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _NavButtons(flow: flow, controller: controller),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                final token = (invitationToken ?? '').trim();
                if (token.isEmpty) {
                  context.go(RoutePaths.login);
                  return;
                }
                final email = Uri.encodeComponent(inviteEmail);
                context.go(
                  '${RoutePaths.login}?invite=${Uri.encodeComponent(token)}&email=$email',
                );
              },
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({
    required this.valid,
    required this.kind,
    required this.role,
    this.email,
    this.status,
  });

  final bool valid;
  final String kind;
  final String role;
  final String? email;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final text = valid
        ? kind == 'portal'
              ? 'Portal invite: join as $role${email != null ? ' ($email)' : ''}.'
              : 'Staff invite: join as $role${email != null ? ' ($email)' : ''}.'
        : 'This invite is ${status ?? 'invalid'}. Ask an admin for a new link.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.mail, size: 16, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedInInvitePanel extends StatelessWidget {
  const _SignedInInvitePanel({
    required this.inviteEmail,
    required this.signedInEmail,
    required this.sameInvitee,
    required this.inviteValid,
    required this.busy,
    required this.onSignOut,
    required this.onContinue,
    this.inviteStatus,
    this.error,
    this.onAccept,
  });

  final String inviteEmail;
  final String signedInEmail;
  final bool sameInvitee;
  final bool inviteValid;
  final String? inviteStatus;
  final bool busy;
  final String? error;
  final VoidCallback? onAccept;
  final VoidCallback onContinue;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final accepted = inviteStatus == 'accepted';
    final message = !inviteValid
        ? accepted
              ? sameInvitee
                    ? 'This invitation is already accepted. Continue to your workspace.'
                    : 'This invitation was already accepted for ${inviteEmail.isEmpty ? 'another email' : inviteEmail}. '
                          'Sign in with that email to open the workspace.'
              : 'This invitation is no longer pending. Ask an admin to send a new one.'
        : sameInvitee
        ? 'You are signed in as $signedInEmail. Accept to activate this staff role.'
        : 'This invitation is for ${inviteEmail.isEmpty ? 'another email' : inviteEmail}. '
              'You are signed in as ${signedInEmail.isEmpty ? 'a different account' : signedInEmail}. '
              'Sign out to open the registration form for the invited email.';
    final showContinue = accepted && sameInvitee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 16),
        if (sameInvitee && inviteValid)
          PrimaryButton(
            label: 'Accept invitation',
            isLoading: busy,
            onPressed: busy ? null : onAccept,
          )
        else if (showContinue)
          PrimaryButton(label: 'Continue to workspace', onPressed: onContinue)
        else
          PrimaryButton(
            label: accepted
                ? 'Sign in with invited email'
                : 'Sign out and use this invite',
            isLoading: busy,
            onPressed: busy
                ? null
                : () {
                    onSignOut();
                  },
          ),
      ],
    );
  }
}

class _ClosedInvitePanel extends StatelessWidget {
  const _ClosedInvitePanel({
    required this.email,
    required this.onSignIn,
    this.status,
  });

  final String? status;
  final String email;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final accepted = status == 'accepted';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          accepted
              ? 'The account for ${email.isEmpty ? 'this invitation' : email} is already active. Sign in to open the workspace.'
              : 'This invite is ${status ?? 'invalid'}. Ask an admin for a new link.',
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        if (accepted) ...[
          const SizedBox(height: 16),
          PrimaryButton(label: 'Sign in', onPressed: onSignIn),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
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
      RegistrationStep.personalInfo => _PersonalInfoStep(
        flow: flow,
        controller: controller,
      ),
      RegistrationStep.credentials => _CredentialsStep(
        flow: flow,
        controller: controller,
      ),
      RegistrationStep.legal => _LegalStep(flow: flow, controller: controller),
      RegistrationStep.review => _ReviewStep(flow: flow),
    };
  }
}

class _PersonalInfoStep extends HookConsumerWidget {
  const _PersonalInfoStep({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = flow.draft;
    final errors = flow.fieldErrors;
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final audience = ref.watch(loginAudienceHintProvider).valueOrNull;
    // Controllers are created once. Rebuilding from draft.initialValue throws
    // as soon as the invitee types, which replaced this page with the generic error.
    final firstName = useTextEditingController(text: d.firstName);
    final lastName = useTextEditingController(text: d.lastName);
    final email = useTextEditingController(text: d.email);
    final phone = useTextEditingController(text: d.phone);
    final country = useTextEditingController(text: d.country);
    final state = useTextEditingController(text: d.state);
    final city = useTextEditingController(text: d.city);
    final referral = useTextEditingController(text: d.referralCode);
    final emailLocked = (d.invitationToken ?? '').trim().isNotEmpty;

    useEffect(() {
      if (!emailLocked) return null;
      final next = d.email;
      Future<void>(() {
        if (email.text != next) email.text = next;
      });
      return null;
    }, [d.email, emailLocked]);

    Widget field({
      required String label,
      required TextEditingController textController,
      required ValueChanged<String> onChanged,
      String? error,
      TextInputType? keyboard,
      bool readOnly = false,
      VoidCallback? onEditingComplete,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: textController,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: label, errorText: error),
          keyboardType: keyboard,
          onChanged: readOnly ? null : onChanged,
          onEditingComplete: onEditingComplete,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          RegistrationAssistant.onboardingHint(d.accountType),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white60),
        ),
        const SizedBox(height: 14),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(
                  label: 'First name',
                  textController: firstName,
                  error: errors['firstName'],
                  onChanged: (v) =>
                      controller.updateDraft((x) => x.copyWith(firstName: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  label: 'Last name',
                  textController: lastName,
                  error: errors['lastName'],
                  onChanged: (v) =>
                      controller.updateDraft((x) => x.copyWith(lastName: v)),
                ),
              ),
            ],
          )
        else ...[
          field(
            label: 'First name',
            textController: firstName,
            error: errors['firstName'],
            onChanged: (v) =>
                controller.updateDraft((x) => x.copyWith(firstName: v)),
          ),
          field(
            label: 'Last name',
            textController: lastName,
            error: errors['lastName'],
            onChanged: (v) =>
                controller.updateDraft((x) => x.copyWith(lastName: v)),
          ),
        ],
        field(
          label: 'Email',
          textController: email,
          error: errors['email'],
          keyboard: TextInputType.emailAddress,
          readOnly: emailLocked,
          onChanged: (v) {
            controller.updateDraft((x) => x.copyWith(email: v));
            ref.read(loginEmailHintProvider.notifier).setEmail(v);
          },
        ),
        if (audience != null) ...[
          LoginAudienceHint(audience: audience),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(
                '${RoutePaths.login}?email=${Uri.encodeComponent(d.email.trim())}',
              ),
              child: const Text('Already registered? Sign in instead'),
            ),
          ),
        ],
        field(
          label: 'Phone',
          textController: phone,
          error: errors['phone'],
          keyboard: TextInputType.phone,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(phone: v)),
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(
                  label: 'Country',
                  textController: country,
                  error: errors['country'],
                  onChanged: (v) =>
                      controller.updateDraft((x) => x.copyWith(country: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  label: 'State',
                  textController: state,
                  error: errors['state'],
                  onChanged: (v) =>
                      controller.updateDraft((x) => x.copyWith(state: v)),
                ),
              ),
            ],
          )
        else ...[
          field(
            label: 'Country',
            textController: country,
            error: errors['country'],
            onChanged: (v) =>
                controller.updateDraft((x) => x.copyWith(country: v)),
          ),
          field(
            label: 'State',
            textController: state,
            error: errors['state'],
            onChanged: (v) =>
                controller.updateDraft((x) => x.copyWith(state: v)),
          ),
        ],
        field(
          label: 'City (optional)',
          textController: city,
          onChanged: (v) => controller.updateDraft((x) => x.copyWith(city: v)),
        ),
        field(
          label: 'Referral code (optional)',
          textController: referral,
          error: errors['referralCode'],
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(referralCode: v)),
          onEditingComplete: controller.validateReferral,
        ),
        if (flow.referralValid == true)
          const Text(
            'Referral code accepted',
            style: TextStyle(color: Colors.greenAccent),
          ),
        if (flow.referralValid == false)
          Text(
            'Code format is valid — rewards activate when the referral program goes live.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
      ],
    );
  }
}

class _CredentialsStep extends HookWidget {
  const _CredentialsStep({required this.flow, required this.controller});

  final RegistrationFlowState flow;
  final RegistrationController controller;

  @override
  Widget build(BuildContext context) {
    final errors = flow.fieldErrors;
    final password = useTextEditingController(text: flow.draft.password);
    final confirm = useTextEditingController(text: flow.draft.confirmPassword);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              controller.updateDraft((d) => d.copyWith(password: v)),
        ),
        const SizedBox(height: 10),
        PasswordStrengthMeter(password: flow.draft.password),
        const SizedBox(height: 14),
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
              controller.updateDraft((d) => d.copyWith(confirmPassword: v)),
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
    Widget optTile({
      required bool value,
      required String title,
      required ValueChanged<bool> onChanged,
    }) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: value
              ? AppColors.gold.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.gold.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.gold,
          checkColor: AppColors.deepBlack,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Required policies',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        RegistrationLegalCheckbox(
          doc: RegistrationLegalDoc.terms,
          value: d.acceptTerms,
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(acceptTerms: v)),
        ),
        RegistrationLegalCheckbox(
          doc: RegistrationLegalDoc.privacy,
          value: d.acceptPrivacy,
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(acceptPrivacy: v)),
        ),
        RegistrationLegalCheckbox(
          doc: RegistrationLegalDoc.cookies,
          value: d.acceptCookies,
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(acceptCookies: v)),
        ),
        const RegistrationExtraPolicies(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(color: Colors.white12),
        ),
        const Text(
          'Optional preferences',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        optTile(
          value: d.marketingOptIn,
          title: 'Send me marketing communications',
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(marketingOptIn: v)),
        ),
        optTile(
          value: d.productUpdatesOptIn,
          title: 'Product updates',
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(productUpdatesOptIn: v)),
        ),
        optTile(
          value: d.newsletterOptIn,
          title: 'Newsletter subscription',
          onChanged: (v) =>
              controller.updateDraft((x) => x.copyWith(newsletterOptIn: v)),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.12),
            const Color(0xFF1A1D26),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Review & create',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Account type', d.accountType?.title ?? '—'),
          _row('Name', '${d.firstName} ${d.lastName}'.trim()),
          _row('Email', d.email),
          _row('Phone', d.phone),
          _row(
            'Location',
            [
              d.city,
              d.state,
              d.country,
            ].where((e) => e.trim().isNotEmpty).join(', '),
          ),
          if (d.referralCode.trim().isNotEmpty)
            _row('Referral', d.referralCode.toUpperCase()),
          _row('Legal', 'Terms, Privacy & Cookies accepted'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
            loadingLabel: isLast ? 'Creating account…' : 'Continue',
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
                    final isStaffInvite = (flow.draft.invitationToken ?? '')
                        .trim()
                        .isNotEmpty;
                    final typeId = isStaffInvite
                        ? 'staff'
                        : result.accountType.id;
                    if (result.needsEmailVerification) {
                      context.go(
                        '${RoutePaths.verifyEmail}?email=${Uri.encodeComponent(result.email)}'
                        '&type=$typeId',
                      );
                    } else {
                      context.go('${RoutePaths.welcome}?type=$typeId');
                    }
                  },
          ),
        ),
      ],
    );
  }
}
