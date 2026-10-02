import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/auth/policies/dashboard_access_policy.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/dashboard/presentation/pages/executive_dashboard_page.dart';

/// Routes `/dashboard` to the correct home for Super Admin vs Admin.
///
/// Module staff (Sales, Finance, Marketing, Construction) are redirected by
/// [GoRouter] to their command center before this widget builds.
class RoleAwareDashboardPage extends ConsumerWidget {
  const RoleAwareDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(identitySessionProvider);
    final kind = DashboardAccessPolicy.kindFor(session);

    if (kind == StaffDashboardKind.moduleHome) {
      final home = DashboardAccessPolicy.homeRouteFor(session);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(home);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scope = kind == StaffDashboardKind.superAdminExecutive
        ? ExecutiveDashboardScope.superAdmin
        : ExecutiveDashboardScope.adminOperations;

    return ExecutiveDashboardPage(scope: scope);
  }
}
