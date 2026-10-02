import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/auth/policies/admin_access_policy.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/rbac_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// UI element protection — hides [child] when permission is denied.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.ownershipRequired = false,
    this.resourceOwnerId,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;
  final bool ownershipRequired;
  final String? resourceOwnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isAllowed(
      ref,
      permission,
      ownershipRequired: ownershipRequired,
      resourceOwnerId: resourceOwnerId,
    )) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Shows [child] when the session has at least one of [permissions].
class PermissionGateAny extends ConsumerWidget {
  const PermissionGateAny({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
    this.ownershipRequired = false,
    this.resourceOwnerId,
  });

  final List<String> permissions;
  final Widget child;
  final Widget? fallback;
  final bool ownershipRequired;
  final String? resourceOwnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isAnyAllowed(
      ref,
      permissions,
      ownershipRequired: ownershipRequired,
      resourceOwnerId: resourceOwnerId,
    )) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

bool _isAllowed(
  WidgetRef ref,
  String permission, {
  bool ownershipRequired = false,
  String? resourceOwnerId,
}) {
  return evaluatePermission(
    ref,
    permission,
    ownershipRequired: ownershipRequired,
    resourceOwnerId: resourceOwnerId,
  ).decision ==
      PolicyDecision.allow;
}

bool _isAnyAllowed(
  WidgetRef ref,
  List<String> permissions, {
  bool ownershipRequired = false,
  String? resourceOwnerId,
}) {
  if (permissions.isEmpty) return false;
  return evaluatePermissionAny(
    ref,
    permissions,
    ownershipRequired: ownershipRequired,
    resourceOwnerId: resourceOwnerId,
  );
}

/// Fast path for nav/button gating — uses session grants + super-admin bypass.
bool hasPermissionAny(WidgetRef ref, List<String> permissions) {
  final session = ref.read(identitySessionProvider);
  return AdminAccessPolicy.canAny(session, permissions);
}

/// Access denied surface for protected routes / panels.
class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({
    super.key,
    this.reason = 'You do not have permission to view this resource.',
  });

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(reason, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Evaluate a permission against the current session.
PolicyEvaluation evaluatePermission(
  WidgetRef ref,
  String permission, {
  bool ownershipRequired = false,
  String? resourceOwnerId,
}) {
  final session = ref.read(identitySessionProvider);
  if (session.hasRole(AppRole.superAdmin)) {
    return PolicyEvaluation(
      decision: PolicyDecision.allow,
      permission: permission,
    );
  }
  return ref.read(rbacServiceProvider).authorize(
        permission: permission,
        context: AuthorizationContext(
          userId: session.userId,
          roles: session.roles,
          permissions: session.permissions,
          resourceOwnerId: resourceOwnerId,
        ),
        ownershipRequired: ownershipRequired,
      );
}

/// Allow when any listed permission passes policy evaluation.
bool evaluatePermissionAny(
  WidgetRef ref,
  List<String> permissions, {
  bool ownershipRequired = false,
  String? resourceOwnerId,
}) {
  for (final permission in permissions) {
    if (_isAllowed(
      ref,
      permission,
      ownershipRequired: ownershipRequired,
      resourceOwnerId: resourceOwnerId,
    )) {
      return true;
    }
  }
  return false;
}
