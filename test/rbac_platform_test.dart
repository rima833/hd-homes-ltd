import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/app_role.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';

void main() {
  group('PermissionCatalog', () {
    test('normalizes dotted and legacy slugs', () {
      expect(
        PermissionCatalog.normalize('properties.view'),
        'view_properties',
      );
      expect(
        PermissionCatalog.normalize('view_properties'),
        'view_properties',
      );
    });

    test('aliases include both forms', () {
      final aliases = PermissionCatalog.aliasesOf('properties.delete');
      expect(aliases, contains('properties.delete'));
      expect(aliases, contains('delete_property'));
    });
  });

  group('PolicyEngine', () {
    test('super admin always allowed', () {
      final result = PolicyEngine.evaluate(
        permission: 'roles.manage',
        context: const AuthorizationContext(
          roles: [AppRole.superAdmin],
          permissions: {},
        ),
      );
      expect(result.decision, PolicyDecision.allow);
      expect(result.reason, 'super_admin');
    });

    test('denies missing permission', () {
      final result = PolicyEngine.evaluate(
        permission: 'properties.delete',
        context: const AuthorizationContext(
          roles: [AppRole.client],
          permissions: {'view_properties'},
        ),
      );
      expect(result.decision, PolicyDecision.deny);
    });

    test('allows granted legacy permission via dotted request', () {
      final result = PolicyEngine.evaluate(
        permission: 'properties.view',
        context: const AuthorizationContext(
          roles: [AppRole.client],
          permissions: {'view_properties'},
        ),
      );
      expect(result.decision, PolicyDecision.allow);
    });

    test('ownership mismatch is conditional', () {
      final result = PolicyEngine.evaluate(
        permission: 'properties.edit',
        context: const AuthorizationContext(
          userId: 'u1',
          roles: [AppRole.salesTeam],
          permissions: {'edit_property'},
          resourceOwnerId: 'u2',
        ),
        ownershipRequired: true,
      );
      expect(result.decision, PolicyDecision.conditional);
      expect(result.reason, 'ownership_mismatch');
    });

    test('large refund requires approval', () {
      final result = PolicyEngine.evaluate(
        permission: 'finance.refund',
        context: const AuthorizationContext(
          roles: [AppRole.finance],
          permissions: {'manage_refunds'},
          amount: 750000,
        ),
        approvalPolicies: const [
          ApprovalPolicy(
            id: '1',
            name: 'Large Refund',
            actionType: ApprovalActionType.largeRefund,
            approverRoleSlug: 'finance',
            thresholdAmount: 500000,
          ),
        ],
      );
      expect(result.decision, PolicyDecision.conditional);
      expect(result.requiresApproval, isTrue);
    });

    test('break-glass bypasses checks', () {
      final result = PolicyEngine.evaluate(
        permission: 'settings.update',
        context: const AuthorizationContext(
          roles: [AppRole.salesTeam],
          permissions: {},
          breakGlassActive: true,
        ),
      );
      expect(result.decision, PolicyDecision.allow);
      expect(result.reason, 'break_glass');
    });
  });

  group('PermissionMatrix', () {
    test('cell key lookup', () {
      const matrix = PermissionMatrix(
        roles: [],
        permissions: [],
        cells: {'admin|view_properties': true},
      );
      expect(matrix.isGranted('admin', 'view_properties'), isTrue);
      expect(matrix.isGranted('client', 'view_properties'), isFalse);
    });
  });

  group('PolicyEngine.expandGroupPermissions', () {
    test('unions group members', () {
      const groups = [
        PermissionGroup(
          id: '1',
          name: 'Sales',
          slug: 'sales_management',
          permissionSlugs: {'view_properties', 'manage_crm'},
        ),
      ];
      final expanded = PolicyEngine.expandGroupPermissions(
        groups,
        ['sales_management'],
      );
      expect(expanded, containsAll(['view_properties', 'manage_crm']));
    });
  });
}
