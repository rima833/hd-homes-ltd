import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';

void main() {
  group('OrganizationEngine.formatEmployeeCode', () {
    test('pads sequence', () {
      expect(OrganizationEngine.formatEmployeeCode(12), 'HDH-EMP-0012');
      expect(OrganizationEngine.formatEmployeeCode(1), 'HDH-EMP-0001');
    });

    test('parses sequence', () {
      expect(OrganizationEngine.parseEmployeeSequence('HDH-EMP-0012'), 12);
    });
  });

  group('OrganizationEngine.computeAnalytics', () {
    test('counts active and leave', () {
      final employees = [
        const Employee(
          id: '1',
          employeeCode: 'HDH-EMP-0001',
          displayName: 'A',
          status: StaffStatus.active,
          departmentName: 'Sales',
          branchName: 'Lagos HQ',
        ),
        const Employee(
          id: '2',
          employeeCode: 'HDH-EMP-0002',
          displayName: 'B',
          status: StaffStatus.onLeave,
          departmentName: 'Sales',
          branchName: 'Lagos HQ',
        ),
        const Employee(
          id: '3',
          employeeCode: 'HDH-EMP-0003',
          displayName: 'C',
          status: StaffStatus.remote,
          departmentName: 'Finance',
          branchName: 'Lagos HQ',
          joinedAt: null,
        ),
      ];
      final analytics = OrganizationEngine.computeAnalytics(
        employees: employees,
        departments: const [
          Department(id: 'd1', name: 'Sales', slug: 'sales'),
          Department(id: 'd2', name: 'Finance', slug: 'finance'),
        ],
        branches: const [
          BranchOffice(id: 'b1', name: 'Lagos HQ', slug: 'lagos_hq'),
        ],
      );
      expect(analytics.totalEmployees, 3);
      expect(analytics.activeStaff, 2); // active + remote
      expect(analytics.onLeave, 1);
      expect(analytics.departmentsConfigured, 2);
      expect(analytics.byDepartment['Sales'], 2);
    });
  });

  group('OrganizationEngine.buildOrgChart', () {
    test('builds hierarchy from manager links', () {
      const md = Employee(
        id: 'md',
        employeeCode: 'HDH-EMP-0001',
        displayName: 'MD',
        status: StaffStatus.active,
      );
      const gm = Employee(
        id: 'gm',
        employeeCode: 'HDH-EMP-0002',
        displayName: 'GM',
        status: StaffStatus.active,
        managerId: 'md',
      );
      const sm = Employee(
        id: 'sm',
        employeeCode: 'HDH-EMP-0012',
        displayName: 'Godwin Okafor',
        status: StaffStatus.active,
        managerId: 'gm',
      );
      final chart = OrganizationEngine.buildOrgChart(const [md, gm, sm]);
      expect(chart.length, 1);
      expect(chart.first.employee.id, 'md');
      expect(chart.first.directReports.single.employee.id, 'gm');
      expect(
        chart.first.directReports.single.directReports.single.employee.displayName,
        'Godwin Okafor',
      );
    });
  });

  group('OrganizationEngine.reportingChain', () {
    test('walks up to executives', () {
      const md = Employee(
        id: 'md',
        employeeCode: 'HDH-EMP-0001',
        displayName: 'MD',
        status: StaffStatus.active,
      );
      const gm = Employee(
        id: 'gm',
        employeeCode: 'HDH-EMP-0002',
        displayName: 'GM',
        status: StaffStatus.active,
        managerId: 'md',
      );
      const sm = Employee(
        id: 'sm',
        employeeCode: 'HDH-EMP-0012',
        displayName: 'Sales',
        status: StaffStatus.active,
        managerId: 'gm',
      );
      final chain = OrganizationEngine.reportingChain(const [md, gm, sm], 'sm');
      expect(chain.map((e) => e.id).toList(), ['gm', 'md']);
    });
  });

  group('OrganizationEngine.onboarding', () {
    test('advances through checklist', () {
      var progress = const OnboardingProgress(
        employeeId: 'e1',
        completedSteps: {},
      );
      progress = OrganizationEngine.advanceOnboarding(progress);
      expect(progress.completedSteps, contains(OnboardingStep.createAccount));
      expect(progress.currentStep, OnboardingStep.assignDepartmentTeam);
    });
  });

  group('OrganizationEngine.searchDirectory', () {
    test('filters by query and status', () {
      const list = [
        Employee(
          id: '1',
          employeeCode: 'HDH-EMP-0012',
          displayName: 'Godwin Okafor',
          status: StaffStatus.active,
          email: 'godwin@hdhomesltd.com',
          departmentName: 'Sales & Marketing',
        ),
        Employee(
          id: '2',
          employeeCode: 'HDH-EMP-0008',
          displayName: 'Chiamaka Eze',
          status: StaffStatus.onLeave,
          departmentName: 'Finance',
        ),
      ];
      final found = OrganizationEngine.searchDirectory(
        list,
        query: 'godwin',
        status: StaffStatus.active,
      );
      expect(found.length, 1);
      expect(found.first.employeeCode, 'HDH-EMP-0012');
    });
  });

  group('DefaultDepartments', () {
    test('includes core HD Homes departments', () {
      expect(DefaultDepartments.entries.length, greaterThanOrEqualTo(10));
      expect(
        DefaultDepartments.entries.map((e) => e.slug),
        contains('sales_marketing'),
      );
    });
  });
}
