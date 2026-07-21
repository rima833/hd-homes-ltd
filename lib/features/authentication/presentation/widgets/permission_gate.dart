import 'package:flutter/material.dart';
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
    final session = ref.watch(identitySessionProvider);
    final evaluation = ref.watch(rbacServiceProvider).authorize(
          permission: permission,
          context: AuthorizationContext(
            userId: session.userId,
            roles: session.roles,
            permissions: session.permissions,
            resourceOwnerId: resourceOwnerId,
          ),
          ownershipRequired: ownershipRequired,
        );

    if (evaluation.decision == PolicyDecision.allow) return child;
    return fallback ?? const SizedBox.shrink();
  }
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
