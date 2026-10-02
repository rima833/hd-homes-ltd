import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/smart_login_router.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/organization_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Post-invite staff profile completion before entering the workspace.
class StaffOnboardingPage extends HookConsumerWidget {
  const StaffOnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(identitySessionProvider);
    final profile = session.profile;
    final step = useState(0);
    final first = useTextEditingController(text: profile?.firstName ?? '');
    final last = useTextEditingController(text: profile?.lastName ?? '');
    final phone = useTextEditingController(text: profile?.phone ?? '');
    final busy = useState(false);
    final error = useState<String?>(null);
    final staffAsync = ref.watch(organizationSnapshotProvider);

    final employee = staffAsync.asData?.value.employees
        .where((e) => e.userId == session.userId || e.id == profile?.employeeId)
        .firstOrNull;

    Future<void> complete() async {
      if (first.text.trim().isEmpty || last.text.trim().isEmpty) {
        error.value = 'First and last name are required.';
        step.value = 0;
        return;
      }
      busy.value = true;
      error.value = null;
      try {
        final client = ref.read(organizationServiceProvider);
        if (employee != null) {
          await client.updateStaffRecord(
            employeeId: employee.id,
            firstName: first.text.trim(),
            lastName: last.text.trim(),
            phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
            actorId: session.userId,
          );
          await client.completeOnboardingStep(
            employee.id,
            OnboardingStep.completeProfile,
            actorId: session.userId,
          );
          await client.updateStaffStatus(
            employee.id,
            StaffStatus.active,
            actorId: session.userId,
            reason: 'Staff onboarding completed',
          );
        }
        ref.invalidate(organizationSnapshotProvider);
        await ref.read(identitySessionProvider.notifier).reloadProfile();
        if (!context.mounted) return;
        final refreshed = ref.read(identitySessionProvider);
        final dest = SmartLoginRouter.destinationForRole(
          refreshed.profile?.primaryRole,
        );
        context.go(dest);
      } catch (e) {
        error.value = userFacingError(
          e,
          fallback: 'Unable to complete onboarding.',
        );
      } finally {
        busy.value = false;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(LucideIcons.building2, color: AppColors.gold, size: 36),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to HD Homes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    step.value == 0
                        ? 'Step 1 · Personal information'
                        : step.value == 1
                            ? 'Step 2 · Work information'
                            : 'Step 3 · Ready',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF8B929E)),
                  ),
                  const SizedBox(height: 24),
                  if (error.value != null) ...[
                    Text(
                      error.value!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (step.value == 0) ...[
                    TextField(
                      controller: first,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        labelStyle: TextStyle(color: Color(0xFF8B929E)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: last,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        labelStyle: TextStyle(color: Color(0xFF8B929E)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        labelStyle: TextStyle(color: Color(0xFF8B929E)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile?.email ?? session.email ?? '',
                      style: const TextStyle(color: Color(0xFF8B929E), fontSize: 12),
                    ),
                  ] else if (step.value == 1) ...[
                    _readonly('Department', employee?.departmentName ?? 'Assigned by admin'),
                    _readonly('Team', employee?.teamName ?? 'Assigned by admin'),
                    _readonly('Job title', employee?.positionTitle ?? '—'),
                    _readonly('Role', employee?.roleSlug?.replaceAll('_', ' ') ?? profile?.primaryRole?.displayName ?? '—'),
                    const SizedBox(height: 8),
                    const Text(
                      'These values were assigned by your administrator and cannot be elevated here.',
                      style: TextStyle(color: Color(0xFF8B929E), fontSize: 12),
                    ),
                  ] else ...[
                    const Icon(LucideIcons.checkCircle2, color: AppColors.gold, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Your HD Homes staff account is ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Continue to your authorized workspace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8B929E)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (step.value > 0)
                        TextButton(
                          onPressed: busy.value
                              ? null
                              : () => step.value = step.value - 1,
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      if (step.value < 2)
                        PrimaryButton(
                          label: 'Continue',
                          onPressed: busy.value
                              ? null
                              : () {
                                  if (step.value == 0 &&
                                      (first.text.trim().isEmpty ||
                                          last.text.trim().isEmpty)) {
                                    error.value =
                                        'First and last name are required.';
                                    return;
                                  }
                                  error.value = null;
                                  step.value = step.value + 1;
                                },
                        )
                      else
                        PrimaryButton(
                          label: busy.value ? 'Finishing…' : 'Continue to Workspace',
                          onPressed: busy.value ? null : complete,
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.securityCenter),
                    child: const Text('Security settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readonly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B929E), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
