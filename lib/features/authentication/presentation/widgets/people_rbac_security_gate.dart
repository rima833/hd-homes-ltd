import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/widgets/feedback/app_dialogs.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/mfa_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/adaptive_security_engine.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/mfa_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Elevating role slugs that require stronger confirmation / step-up.
const elevatedRoleSlugs = <String>{
  'super_admin',
  'admin',
};

/// Returns true when the actor may proceed with a high-risk people/RBAC action.
///
/// Uses [AdaptiveSecurityEngine.requiresStepUp]. When step-up is required and
/// AAL2 is not satisfied, shows a blocking dialog (MFA enrollment / verify).
/// [StepUpAction.createAdmin] with AAL2 already satisfied is allowed after the
/// caller shows its own confirm dialog (engine always flags createAdmin).
Future<bool> ensurePeopleRbacStepUp({
  required BuildContext context,
  required WidgetRef ref,
  required StepUpAction action,
}) async {
  final session = ref.read(identitySessionProvider);
  final policy = MfaPolicyCatalog.forRole(session.primaryRole);
  final mfa = ref.read(mfaStatusProvider).valueOrNull;
  final aal2 = mfa?.aalSatisfied ?? false;

  var needs = AdaptiveSecurityEngine.requiresStepUp(
    action: action,
    policy: policy,
    aal2Satisfied: aal2,
  );

  // Soften createAdmin when the session already has AAL2 — explicit UI confirm
  // is enough; full re-challenge is not wired into desk actions yet.
  if (needs && action == StepUpAction.createAdmin && aal2) {
    needs = false;
  }

  if (!needs) return true;

  if (mfa != null && !mfa.enabled && policy.isEnforced) {
    await AppDialogs.confirm(
      context,
      title: 'MFA enrollment required',
      message:
          'This action is protected by step-up security. Enroll MFA in '
          'Security Center, then try again.',
      confirmLabel: 'OK',
    );
    return false;
  }

  await AppDialogs.confirm(
    context,
    title: 'Step-up verification required',
    message:
        'Recent multi-factor verification (AAL2) is required for this action. '
        'Open Security / MFA, complete verification, then retry.',
    confirmLabel: 'OK',
  );
  return false;
}

bool isElevatedRoleSlug(String slug) =>
    elevatedRoleSlugs.contains(slug.trim().toLowerCase());

/// Deep-link path for the observability desk.
String peopleRbacActivityLogsPath() => RoutePaths.dashboardActivityLogs;
