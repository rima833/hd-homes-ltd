import 'dart:async';

import 'package:hdhomesproject/features/authentication/domain/entities/observability_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/organization_models.dart';
import 'package:hdhomesproject/features/authentication/domain/services/audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enterprise Organization & Staff Management — departments, teams, directory.
class OrganizationService {
  OrganizationService({
    required AuditService audit,
    SupabaseClient? client,
  })  : _audit = audit,
        _client = client;

  final AuditService _audit;
  final SupabaseClient? _client;

  /// In-memory seed for demo / offline when tables not yet migrated.
  final List<Department> _localDepartments = [];
  final List<OrgTeam> _localTeams = [];
  final List<Employee> _localEmployees = [];
  final List<BranchOffice> _localBranches = [];
  final List<Position> _localPositions = [];
  final Map<String, OnboardingProgress> _localOnboarding = {};

  bool get isConfigured => _client != null;

  Future<OrganizationSnapshot> loadSnapshot() async {
    final departments = await listDepartments();
    final teams = await listTeams();
    final employees = await listEmployees();
    final branches = await listBranches();
    final positions = await listPositions();
    final analytics = OrganizationEngine.computeAnalytics(
      employees: employees,
      departments: departments,
      branches: branches,
    );
    return OrganizationSnapshot(
      departments: departments,
      teams: teams,
      employees: employees,
      branches: branches,
      positions: positions,
      analytics: analytics,
    );
  }

  Future<List<Department>> listDepartments() async {
    final client = _client;
    if (client == null) return _ensureLocalSeed().departments;

    try {
      final rows = await client
          .from('departments')
          .select()
          .eq('status', 'active')
          .order('name');
      final list = (rows as List)
          .map((e) => Department.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isEmpty) return _ensureLocalSeed().departments;
      return list;
    } catch (_) {
      return _ensureLocalSeed().departments;
    }
  }

  Future<List<OrgTeam>> listTeams({String? departmentId}) async {
    final client = _client;
    if (client == null) {
      final seed = _ensureLocalSeed();
      if (departmentId == null) return seed.teams;
      return seed.teams.where((t) => t.departmentId == departmentId).toList();
    }

    try {
      var query = client.from('teams').select(
            '*, departments(name)',
          );
      if (departmentId != null) {
        query = query.eq('department_id', departmentId);
      }
      final rows = await query.order('name');
      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final dept = map['departments'];
        if (dept is Map) {
          map['department_name'] = dept['name'];
        }
        map['member_count'] = map['member_count'] ?? 0;
        return OrgTeam.fromRow(map);
      }).toList();
    } catch (_) {
      final seed = _ensureLocalSeed();
      if (departmentId == null) return seed.teams;
      return seed.teams.where((t) => t.departmentId == departmentId).toList();
    }
  }

  Future<List<Employee>> listEmployees() async {
    final client = _client;
    if (client == null) return _ensureLocalSeed().employees;

    try {
      final rows = await client.from('employees').select('''
            *,
            departments(name),
            teams(name),
            positions(title),
            branch_offices(name)
          ''').eq('is_deleted', false).order('employee_code');

      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final dept = map['departments'];
        final team = map['teams'];
        final pos = map['positions'];
        final branch = map['branch_offices'];
        if (dept is Map) map['department_name'] = dept['name'];
        if (team is Map) map['team_name'] = team['name'];
        if (pos is Map) map['position_title'] = pos['title'];
        if (branch is Map) map['branch_name'] = branch['name'];
        return Employee.fromRow(map);
      }).toList();
    } catch (_) {
      return _ensureLocalSeed().employees;
    }
  }

  Future<List<BranchOffice>> listBranches() async {
    final client = _client;
    if (client == null) return _ensureLocalSeed().branches;

    try {
      final rows = await client.from('branch_offices').select().order('name');
      final list = (rows as List)
          .map((e) => BranchOffice.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isEmpty) return _ensureLocalSeed().branches;
      return list;
    } catch (_) {
      return _ensureLocalSeed().branches;
    }
  }

  Future<List<Position>> listPositions() async {
    final client = _client;
    if (client == null) return _ensureLocalSeed().positions;

    try {
      final rows = await client.from('positions').select().order('level');
      return (rows as List)
          .map((e) => Position.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return _ensureLocalSeed().positions;
    }
  }

  Future<Employee?> getEmployee(String id) async {
    final all = await listEmployees();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<OrgChartNode>> loadOrgChart() async {
    final employees = await listEmployees();
    return OrganizationEngine.buildOrgChart(employees);
  }

  Future<StaffAnalytics> loadAnalytics() async {
    final snap = await loadSnapshot();
    return snap.analytics;
  }

  Future<Employee> upsertStaffRecord({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? departmentId,
    String? teamId,
    String? positionId,
    String? managerId,
    String? branchId,
    String? userId,
    StaffStatus status = StaffStatus.probation,
    String? actorId,
  }) async {
    final client = _client;
    final code = await _nextEmployeeCode();

    if (client == null) {
      return _createLocalEmployee(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        departmentId: departmentId,
        teamId: teamId,
        positionId: positionId,
        managerId: managerId,
        branchId: branchId,
        userId: userId,
        status: status,
        actorId: actorId,
        code: code,
      );
    }

    try {
      final inserted = await client.from('employees').insert({
        'employee_code': code,
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'department_id': departmentId,
        'team_id': teamId,
        'position_id': positionId,
        'manager_id': managerId,
        'branch_id': branchId,
        'employment_status': status.slug,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      }).select().single();

      final employee = Employee.fromRow(Map<String, dynamic>.from(inserted));

      if (teamId != null) {
        try {
          await client.from('team_members').upsert({
            'team_id': teamId,
            'employee_id': employee.id,
            'role_in_team': 'member',
          });
        } catch (_) {}
      }

      await client.from('employment_history').insert({
        'employee_id': employee.id,
        'event_type': 'hired',
        'notes': 'Staff record created',
        'metadata': {'employee_code': code},
      });

      await _auditOrg('employee_created', actorId, {
        'employee_id': employee.id,
        'employee_code': code,
      });

      return employee;
    } catch (_) {
      return _createLocalEmployee(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        departmentId: departmentId,
        teamId: teamId,
        positionId: positionId,
        managerId: managerId,
        branchId: branchId,
        userId: userId,
        status: status,
        actorId: actorId,
        code: code,
      );
    }
  }

  Future<Employee> _createLocalEmployee({
    required String firstName,
    required String lastName,
    required String code,
    String? email,
    String? phone,
    String? departmentId,
    String? teamId,
    String? positionId,
    String? managerId,
    String? branchId,
    String? userId,
    StaffStatus status = StaffStatus.probation,
    String? actorId,
  }) async {
    final id = 'local-${_localEmployees.length + 1}';
    final employee = Employee(
      id: id,
      employeeCode: code,
      displayName: '$firstName $lastName'.trim(),
      status: status,
      userId: userId,
      email: email,
      phone: phone,
      departmentId: departmentId,
      teamId: teamId,
      positionId: positionId,
      managerId: managerId,
      branchId: branchId,
      joinedAt: DateTime.now().toUtc(),
    );
    _localEmployees.add(employee);
    _localOnboarding[id] = OnboardingProgress(
      employeeId: id,
      completedSteps: {OnboardingStep.createAccount},
      currentStep: OnboardingStep.assignDepartmentTeam,
    );
    await _auditOrg('employee_created', actorId, {
      'employee_code': code,
      'name': employee.displayName,
    });
    return employee;
  }

  Future<Employee?> updateStaffStatus(
    String employeeId,
    StaffStatus status, {
    String? actorId,
    String? reason,
  }) async {
    final client = _client;
    if (client == null) {
      final idx = _localEmployees.indexWhere((e) => e.id == employeeId);
      if (idx < 0) return null;
      final prev = _localEmployees[idx];
      final updated = Employee(
        id: prev.id,
        employeeCode: prev.employeeCode,
        displayName: prev.displayName,
        status: status,
        userId: prev.userId,
        email: prev.email,
        phone: prev.phone,
        departmentId: prev.departmentId,
        departmentName: prev.departmentName,
        teamId: prev.teamId,
        teamName: prev.teamName,
        positionId: prev.positionId,
        positionTitle: prev.positionTitle,
        managerId: prev.managerId,
        managerName: prev.managerName,
        branchId: prev.branchId,
        branchName: prev.branchName,
        joinedAt: prev.joinedAt,
        avatarUrl: prev.avatarUrl,
        roleSlug: prev.roleSlug,
      );
      _localEmployees[idx] = updated;
      await _auditOrg('staff_status_changed', actorId, {
        'employee_id': employeeId,
        'status': status.slug,
        if (reason != null) 'reason': reason,
      });
      return updated;
    }

    try {
      final row = await client
          .from('employees')
          .update({
            'employment_status': status.slug,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', employeeId)
          .select()
          .single();

      await client.from('employment_history').insert({
        'employee_id': employeeId,
        'event_type': 'status_change',
        'notes': reason ?? status.label,
        'metadata': {'status': status.slug},
      });

      if (status == StaffStatus.onLeave) {
        try {
          await client.from('leave_records').insert({
            'employee_id': employeeId,
            'leave_type': 'general',
            'starts_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'active',
          });
        } catch (_) {}
      }

      await _auditOrg('staff_status_changed', actorId, {
        'employee_id': employeeId,
        'status': status.slug,
      });

      return Employee.fromRow(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<OnboardingProgress> loadOnboarding(String employeeId) async {
    final local = _localOnboarding[employeeId];
    if (local != null) return local;

    final client = _client;
    if (client == null) {
      return OnboardingProgress(
        employeeId: employeeId,
        completedSteps: const {},
      );
    }

    try {
      final rows = await client
          .from('staff_onboarding')
          .select()
          .eq('employee_id', employeeId);
      final completed = <OnboardingStep>{};
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        if (map['completed'] == true) {
          completed.add(OnboardingStep.fromSlug(map['step'] as String?));
        }
      }
      final remaining = OnboardingStep.values
          .where((s) => !completed.contains(s))
          .toList();
      return OnboardingProgress(
        employeeId: employeeId,
        completedSteps: completed,
        currentStep: remaining.isEmpty
            ? OnboardingStep.activateAccount
            : remaining.first,
      );
    } catch (_) {
      return OnboardingProgress(
        employeeId: employeeId,
        completedSteps: const {},
      );
    }
  }

  Future<OnboardingProgress> completeOnboardingStep(
    String employeeId,
    OnboardingStep step, {
    String? actorId,
  }) async {
    final current = await loadOnboarding(employeeId);
    final next = OrganizationEngine.advanceOnboarding(
      OnboardingProgress(
        employeeId: employeeId,
        completedSteps: {...current.completedSteps, step},
        currentStep: step,
      ),
    );
    _localOnboarding[employeeId] = next;

    final client = _client;
    if (client != null) {
      try {
        await client.from('staff_onboarding').upsert({
          'employee_id': employeeId,
          'step': step.slug,
          'completed': true,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }

    await _auditOrg('onboarding_step_completed', actorId, {
      'employee_id': employeeId,
      'step': step.slug,
    });

    if (next.isComplete) {
      await updateStaffStatus(
        employeeId,
        StaffStatus.active,
        actorId: actorId,
        reason: 'Onboarding complete',
      );
    }

    return next;
  }

  RealtimeChannel? subscribeOrgChanges(void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    final channel = client.channel('organization-hub');
    for (final table in ['employees', 'teams', 'departments', 'leave_records']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    channel.subscribe();
    return channel;
  }

  Future<String> _nextEmployeeCode() async {
    final client = _client;
    if (client == null) {
      final maxSeq = _localEmployees
          .map((e) => OrganizationEngine.parseEmployeeSequence(e.employeeCode))
          .fold<int>(0, (a, b) => a > b ? a : b);
      return OrganizationEngine.formatEmployeeCode(maxSeq + 1);
    }

    try {
      final rows = await client
          .from('employees')
          .select('employee_code')
          .order('employee_code', ascending: false)
          .limit(1);
      if ((rows as List).isEmpty) {
        return OrganizationEngine.formatEmployeeCode(1);
      }
      final code = (rows.first as Map)['employee_code'] as String? ?? '';
      final seq = OrganizationEngine.parseEmployeeSequence(code);
      return OrganizationEngine.formatEmployeeCode(seq + 1);
    } catch (_) {
      return OrganizationEngine.formatEmployeeCode(_localEmployees.length + 1);
    }
  }

  Future<void> _auditOrg(
    String action,
    String? actorId,
    Map<String, dynamic> metadata,
  ) async {
    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: action,
          module: 'organization',
          category: AuditEventCategory.admin,
          userId: actorId,
          severity: AuditSeverity.notice,
          metadata: metadata,
        ),
      ),
    );
  }

  OrganizationSnapshot _ensureLocalSeed() {
    if (_localBranches.isEmpty) {
      _localBranches.add(
        const BranchOffice(
          id: 'branch-lagos',
          name: 'Lagos Headquarters',
          slug: 'lagos_hq',
          address: 'Victoria Island, Lagos',
          city: 'Lagos',
          phone: '+234 800 000 0000',
          isPrimary: true,
          staffCount: 3,
        ),
      );
    }

    if (_localDepartments.isEmpty) {
      for (var i = 0; i < DefaultDepartments.entries.length; i++) {
        final d = DefaultDepartments.entries[i];
        _localDepartments.add(
          Department(
            id: 'dept-$i',
            name: d.name,
            slug: d.slug,
            description: d.description,
            teamCount: d.slug == 'sales_marketing' ? 3 : 0,
            memberCount: d.slug == 'sales_marketing' ? 3 : 0,
          ),
        );
      }
    }

    if (_localPositions.isEmpty) {
      _localPositions.addAll(const [
        Position(
          id: 'pos-md',
          title: 'Managing Director',
          slug: 'managing_director',
          level: 10,
        ),
        Position(
          id: 'pos-gm',
          title: 'General Manager',
          slug: 'general_manager',
          level: 9,
        ),
        Position(
          id: 'pos-sm',
          title: 'Sales Manager',
          slug: 'sales_manager',
          level: 7,
        ),
        Position(
          id: 'pos-fm',
          title: 'Finance Manager',
          slug: 'finance_manager',
          level: 7,
        ),
        Position(
          id: 'pos-ao',
          title: 'Account Officer',
          slug: 'account_officer',
          level: 4,
        ),
        Position(
          id: 'pos-cm',
          title: 'Construction Manager',
          slug: 'construction_manager',
          level: 7,
        ),
        Position(
          id: 'pos-se',
          title: 'Site Engineer',
          slug: 'site_engineer',
          level: 4,
        ),
      ]);
    }

    if (_localTeams.isEmpty) {
      final sales = _localDepartments.firstWhere(
        (d) => d.slug == 'sales_marketing',
        orElse: () => _localDepartments.first,
      );
      _localTeams.addAll([
        OrgTeam(
          id: 'team-property-sales',
          name: 'Property Sales Team',
          departmentId: sales.id,
          description: 'Lead conversion and property transactions',
          memberCount: 12,
          departmentName: sales.name,
          branchId: _localBranches.first.id,
          createdAt: DateTime.utc(2024, 1, 10),
        ),
        OrgTeam(
          id: 'team-digital-marketing',
          name: 'Digital Marketing Team',
          departmentId: sales.id,
          description: 'Campaigns, SEO, and social media',
          memberCount: 5,
          departmentName: sales.name,
          branchId: _localBranches.first.id,
          createdAt: DateTime.utc(2024, 2, 1),
        ),
        OrgTeam(
          id: 'team-investor-acq',
          name: 'Investor Acquisition Team',
          departmentId: sales.id,
          description: 'Investor outreach and onboarding',
          memberCount: 4,
          departmentName: sales.name,
          branchId: _localBranches.first.id,
          createdAt: DateTime.utc(2024, 3, 5),
        ),
      ]);
    }

    if (_localEmployees.isEmpty) {
      final sales = _localDepartments.firstWhere(
        (d) => d.slug == 'sales_marketing',
        orElse: () => _localDepartments.first,
      );
      final finance = _localDepartments.firstWhere(
        (d) => d.slug == 'finance_accounts',
        orElse: () => _localDepartments.first,
      );
      final construction = _localDepartments.firstWhere(
        (d) => d.slug == 'construction_operations',
        orElse: () => _localDepartments.first,
      );
      final branch = _localBranches.first;

      const md = Employee(
        id: 'emp-md',
        employeeCode: 'HDH-EMP-0001',
        displayName: 'Managing Director',
        status: StaffStatus.active,
        email: 'md@hdhomesltd.com',
        departmentId: 'dept-0',
        departmentName: 'Executive Management',
        positionId: 'pos-md',
        positionTitle: 'Managing Director',
        branchId: 'branch-lagos',
        branchName: 'Lagos Headquarters',
        joinedAt: null,
      );

      final gm = Employee(
        id: 'emp-gm',
        employeeCode: 'HDH-EMP-0002',
        displayName: 'Ada Okonkwo',
        status: StaffStatus.active,
        email: 'ada.okonkwo@hdhomesltd.com',
        departmentId: 'dept-0',
        departmentName: 'Executive Management',
        positionId: 'pos-gm',
        positionTitle: 'General Manager',
        managerId: md.id,
        managerName: md.displayName,
        branchId: branch.id,
        branchName: branch.name,
        joinedAt: DateTime.utc(2023, 6, 1),
      );

      final salesMgr = Employee(
        id: 'emp-godwin',
        employeeCode: 'HDH-EMP-0012',
        displayName: 'Godwin Okafor',
        status: StaffStatus.active,
        email: 'godwin@hdhomesltd.com',
        phone: '+234 801 234 5678',
        departmentId: sales.id,
        departmentName: sales.name,
        teamId: 'team-property-sales',
        teamName: 'Property Sales Team',
        positionId: 'pos-sm',
        positionTitle: 'Sales Manager',
        managerId: gm.id,
        managerName: gm.displayName,
        branchId: branch.id,
        branchName: branch.name,
        joinedAt: DateTime.utc(2024, 3, 12),
      );

      final financeMgr = Employee(
        id: 'emp-finance',
        employeeCode: 'HDH-EMP-0008',
        displayName: 'Chiamaka Eze',
        status: StaffStatus.active,
        email: 'chiamaka.eze@hdhomesltd.com',
        departmentId: finance.id,
        departmentName: finance.name,
        positionId: 'pos-fm',
        positionTitle: 'Finance Manager',
        managerId: gm.id,
        managerName: gm.displayName,
        branchId: branch.id,
        branchName: branch.name,
        joinedAt: DateTime.utc(2023, 11, 2),
      );

      final accountOfficer = Employee(
        id: 'emp-ao',
        employeeCode: 'HDH-EMP-0015',
        displayName: 'Ibrahim Musa',
        status: StaffStatus.remote,
        email: 'ibrahim.musa@hdhomesltd.com',
        departmentId: finance.id,
        departmentName: finance.name,
        positionId: 'pos-ao',
        positionTitle: 'Account Officer',
        managerId: financeMgr.id,
        managerName: financeMgr.displayName,
        branchId: branch.id,
        branchName: branch.name,
        joinedAt: DateTime.utc(2025, 1, 20),
      );

      final constructionMgr = Employee(
        id: 'emp-cm',
        employeeCode: 'HDH-EMP-0006',
        displayName: 'Tunde Balogun',
        status: StaffStatus.active,
        email: 'tunde.balogun@hdhomesltd.com',
        departmentId: construction.id,
        departmentName: construction.name,
        positionId: 'pos-cm',
        positionTitle: 'Construction Manager',
        managerId: gm.id,
        managerName: gm.displayName,
        branchId: branch.id,
        branchName: branch.name,
        joinedAt: DateTime.utc(2023, 8, 15),
      );

      final siteEngineer = Employee(
        id: 'emp-se',
        employeeCode: 'HDH-EMP-0018',
        displayName: 'Ngozi Adeyemi',
        status: StaffStatus.onLeave,
        email: 'ngozi.adeyemi@hdhomesltd.com',
        departmentId: construction.id,
        departmentName: construction.name,
        positionId: 'pos-se',
        positionTitle: 'Site Engineer',
        managerId: constructionMgr.id,
        managerName: constructionMgr.displayName,
        branchId: branch.id,
        branchName: branch.name,
        joinedAt: DateTime.utc(2024, 9, 1),
      );

      _localEmployees.addAll([
        Employee(
          id: md.id,
          employeeCode: md.employeeCode,
          displayName: md.displayName,
          status: md.status,
          email: md.email,
          departmentId: _localDepartments.first.id,
          departmentName: _localDepartments.first.name,
          positionId: md.positionId,
          positionTitle: md.positionTitle,
          branchId: branch.id,
          branchName: branch.name,
          joinedAt: DateTime.utc(2020, 1, 1),
        ),
        gm,
        salesMgr,
        financeMgr,
        accountOfficer,
        constructionMgr,
        siteEngineer,
      ]);
    }

    final analytics = OrganizationEngine.computeAnalytics(
      employees: _localEmployees,
      departments: _localDepartments,
      branches: _localBranches,
    );

    return OrganizationSnapshot(
      departments: List.unmodifiable(_localDepartments),
      teams: List.unmodifiable(_localTeams),
      employees: List.unmodifiable(_localEmployees),
      branches: List.unmodifiable(_localBranches),
      positions: List.unmodifiable(_localPositions),
      analytics: analytics,
    );
  }
}
