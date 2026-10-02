import 'dart:async';
import 'dart:convert';

import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/utils/app_logger.dart';
import 'package:hdhomesproject/core/email/email_config.dart';
import 'package:hdhomesproject/core/email/email_models.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
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
    final employeesRaw = await listEmployees();
    final branches = await listBranches();
    final positions = await listPositions();
    final invitations = await listStaffInvitations();
    final portalInvitations = await listPortalInvitations();

    final deptById = {for (final d in departments) d.id: d};
    final teamById = {for (final t in teams) t.id: t};
    final posById = {for (final p in positions) p.id: p};
    final branchById = {for (final b in branches) b.id: b};

    final employees = employeesRaw.map((e) {
      return Employee(
        id: e.id,
        employeeCode: e.employeeCode,
        displayName: e.displayName,
        status: e.status,
        firstName: e.firstName,
        lastName: e.lastName,
        userId: e.userId,
        email: e.email,
        phone: e.phone,
        departmentId: e.departmentId,
        departmentName: e.departmentName ??
            (e.departmentId == null ? null : deptById[e.departmentId!]?.name),
        teamId: e.teamId,
        teamName:
            e.teamName ?? (e.teamId == null ? null : teamById[e.teamId!]?.name),
        positionId: e.positionId,
        positionTitle: e.positionTitle ??
            (e.positionId == null ? null : posById[e.positionId!]?.title),
        managerId: e.managerId,
        managerName: e.managerName,
        branchId: e.branchId,
        branchName: e.branchName ??
            (e.branchId == null ? null : branchById[e.branchId!]?.name),
        joinedAt: e.joinedAt,
        avatarUrl: e.avatarUrl,
        roleSlug: e.roleSlug,
      );
    }).toList();

    final empById = {for (final e in employees) e.id: e};

    final deptCounts = <String, int>{};
    final teamCounts = <String, int>{};
    for (final e in employees) {
      final d = e.departmentId;
      if (d != null) deptCounts[d] = (deptCounts[d] ?? 0) + 1;
      final t = e.teamId;
      if (t != null) teamCounts[t] = (teamCounts[t] ?? 0) + 1;
    }

    final departmentsWithCounts = departments
        .map(
          (d) => Department(
            id: d.id,
            name: d.name,
            slug: d.slug,
            description: d.description,
            headEmployeeId: d.headEmployeeId,
            headEmployeeName: d.headEmployeeId == null
                ? null
                : empById[d.headEmployeeId!]?.displayName,
            status: d.status,
            teamCount: teams.where((t) => t.departmentId == d.id).length,
            memberCount: deptCounts[d.id] ?? 0,
          ),
        )
        .toList();

    final teamsWithCounts = teams
        .map(
          (t) => OrgTeam(
            id: t.id,
            name: t.name,
            departmentId: t.departmentId,
            description: t.description,
            teamLeadId: t.teamLeadId,
            teamLeadName: t.teamLeadId == null
                ? null
                : empById[t.teamLeadId!]?.displayName,
            branchId: t.branchId,
            status: t.status,
            memberCount: teamCounts[t.id] ?? 0,
            departmentName:
                t.departmentName ?? deptById[t.departmentId]?.name,
            createdAt: t.createdAt,
          ),
        )
        .toList();

    final analytics = OrganizationEngine.computeAnalytics(
      employees: employees,
      departments: departmentsWithCounts,
      branches: branches,
      pendingInvitations: invitations
              .where((i) => i.status == 'pending' || i.status == 'sent')
              .length +
          portalInvitations
              .where((i) => i.status == 'pending' || i.status == 'sent')
              .length,
    );
    return OrganizationSnapshot(
      departments: departmentsWithCounts,
      teams: teamsWithCounts,
      employees: employees,
      branches: branches,
      positions: positions,
      analytics: analytics,
      invitations: invitations,
      portalInvitations: portalInvitations,
    );
  }

  Future<List<Department>> listDepartments() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('departments')
          .select()
          .neq('status', 'archived')
          .order('name');
      return (rows as List)
          .map((e) => Department.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load departments.'),
        cause: e,
      );
    }
  }

  Future<List<OrgTeam>> listTeams({String? departmentId}) async {
    final client = _client;
    if (client == null) return const [];

    try {
      var query = client.from('teams').select().neq('status', 'archived');
      if (departmentId != null) {
        query = query.eq('department_id', departmentId);
      }
      final rows = await query.order('name');
      return (rows as List)
          .map((e) => OrgTeam.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load teams.'),
        cause: e,
      );
    }
  }

  static String slugify(String input) {
    final slug = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'unit' : slug;
  }

  Future<Department> createDepartment({
    required String name,
    String? description,
    String? headEmployeeId,
    String? actorId,
  }) async {
    final client = _client;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Department name is required.');
    }
    final slug = slugify(trimmed);
    if (client == null) {
      final dept = Department(
        id: 'local-dept-${_localDepartments.length + 1}',
        name: trimmed,
        slug: slug,
        description: description,
        headEmployeeId: headEmployeeId,
      );
      _localDepartments.add(dept);
      return dept;
    }

    try {
      final row = await client.from('departments').insert({
        'name': trimmed,
        'slug': slug,
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'head_employee_id': headEmployeeId,
        'status': 'active',
      }).select().single();
      await _auditOrg('department_created', actorId, {
        'department_id': row['id'],
        'name': trimmed,
      });
      return Department.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to create department.'),
        cause: e,
      );
    }
  }

  Future<Department> updateDepartment({
    required String departmentId,
    String? name,
    String? description,
    String? headEmployeeId,
    OrgEntityStatus? status,
    bool clearHead = false,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }

    try {
      final patch = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (name != null && name.trim().isNotEmpty) ...{
          'name': name.trim(),
          'slug': slugify(name),
        },
        if (description != null)
          'description':
              description.trim().isEmpty ? null : description.trim(),
        if (clearHead)
          'head_employee_id': null
        else if (headEmployeeId != null)
          'head_employee_id': headEmployeeId,
        if (status != null) 'status': status.slug,
      };

      final row = await client
          .from('departments')
          .update(patch)
          .eq('id', departmentId)
          .select()
          .single();
      await _auditOrg('department_updated', actorId, {
        'department_id': departmentId,
        'fields': patch.keys.toList(),
      });
      return Department.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to update department.'),
        cause: e,
      );
    }
  }

  Future<OrgTeam> createTeam({
    required String name,
    required String departmentId,
    String? description,
    String? teamLeadId,
    String? branchId,
    String? actorId,
  }) async {
    final client = _client;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Team name is required.');
    }
    if (!isValidUuid(departmentId)) {
      throw const ValidationException('Select a valid department.');
    }
    if (client == null) {
      final team = OrgTeam(
        id: 'local-team-${_localTeams.length + 1}',
        name: trimmed,
        departmentId: departmentId,
        description: description,
        teamLeadId: teamLeadId,
        branchId: branchId,
      );
      _localTeams.add(team);
      return team;
    }

    try {
      final row = await client.from('teams').insert({
        'name': trimmed,
        'slug': slugify(trimmed),
        'department_id': departmentId,
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'team_lead_id': teamLeadId,
        'branch_id': branchId,
        'status': 'active',
      }).select().single();
      await _auditOrg('team_created', actorId, {
        'team_id': row['id'],
        'department_id': departmentId,
      });
      return OrgTeam.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to create team.'),
        cause: e,
      );
    }
  }

  Future<OrgTeam> updateTeam({
    required String teamId,
    String? name,
    String? departmentId,
    String? description,
    String? teamLeadId,
    String? branchId,
    OrgEntityStatus? status,
    bool clearLead = false,
    bool clearBranch = false,
    String? actorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }

    try {
      final patch = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (name != null && name.trim().isNotEmpty) ...{
          'name': name.trim(),
          'slug': slugify(name),
        },
        if (departmentId != null) 'department_id': departmentId,
        if (description != null)
          'description':
              description.trim().isEmpty ? null : description.trim(),
        if (clearLead)
          'team_lead_id': null
        else if (teamLeadId != null)
          'team_lead_id': teamLeadId,
        if (clearBranch)
          'branch_id': null
        else if (branchId != null)
          'branch_id': branchId,
        if (status != null) 'status': status.slug,
      };

      final row = await client
          .from('teams')
          .update(patch)
          .eq('id', teamId)
          .select()
          .single();
      await _auditOrg('team_updated', actorId, {
        'team_id': teamId,
        'fields': patch.keys.toList(),
      });
      return OrgTeam.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to update team.'),
        cause: e,
      );
    }
  }

  /// Assign / reassign an employee to a department (and optional team).
  Future<Employee?> reassignEmployee({
    required String employeeId,
    String? departmentId,
    String? teamId,
    bool clearDepartment = false,
    bool clearTeam = false,
    String? actorId,
  }) async {
    String? resolvedDept = departmentId;
    if (teamId != null && !clearTeam) {
      final teams = await listTeams();
      for (final t in teams) {
        if (t.id == teamId) {
          resolvedDept = t.departmentId;
          break;
        }
      }
    }

    final updated = await updateStaffRecord(
      employeeId: employeeId,
      departmentId: resolvedDept,
      teamId: teamId,
      clearDepartment: clearDepartment,
      clearTeam: clearTeam || (clearDepartment && teamId == null),
      actorId: actorId,
    );

    final client = _client;
    if (client != null && teamId != null && !clearTeam) {
      try {
        await client.from('team_members').upsert({
          'team_id': teamId,
          'employee_id': employeeId,
          'role_in_team': 'member',
        }, onConflict: 'team_id,employee_id');
      } catch (_) {}
    }

    await _auditOrg('employee_reassigned', actorId, {
      'employee_id': employeeId,
      'department_id': resolvedDept,
      'team_id': teamId,
    });
    return updated;
  }

  Future<List<Employee>> listEmployees() async {
    final client = _client;
    if (client == null) return const [];

    try {
      // Flat select — nested embeds fail under some RLS/FK setups.
      final rows = await client
          .from('employees')
          .select()
          .eq('is_deleted', false)
          .order('employee_code');

      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        // Prefer HCM job_title when position join is unavailable.
        if ((map['position_title'] == null || '${map['position_title']}'.isEmpty) &&
            map['job_title'] != null) {
          map['position_title'] = map['job_title'];
        }
        return Employee.fromRow(map);
      }).toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load staff directory.'),
        cause: e,
      );
    }
  }

  Future<List<BranchOffice>> listBranches() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client.from('branch_offices').select().order('name');
      return (rows as List)
          .map((e) => BranchOffice.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load branches.'),
        cause: e,
      );
    }
  }

  Future<List<Position>> listPositions() async {
    final client = _client;
    if (client == null) return const [];

    try {
      final rows = await client.from('positions').select().order('level');
      return (rows as List)
          .map((e) => Position.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load positions.'),
        cause: e,
      );
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

  /// Today's attendance row for [employeeId] from the existing attendance system.
  Future<StaffAttendanceSummary> loadStaffAttendanceToday(
    String employeeId,
  ) async {
    final client = _client;
    if (client == null) {
      return StaffAttendanceSummary.empty(employeeId);
    }
    try {
      final today = DateTime.now().toUtc();
      final workDate =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final rows = await client
          .from('attendance_records')
          .select(
            'work_date, attendance_state, status, clock_in_at, clock_out_at, is_remote',
          )
          .eq('employee_id', employeeId)
          .eq('work_date', workDate)
          .order('updated_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) {
        return StaffAttendanceSummary.empty(employeeId);
      }
      return StaffAttendanceSummary.fromRow(
        employeeId,
        Map<String, dynamic>.from(list.first as Map),
      );
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load attendance.'),
        cause: e,
      );
    }
  }

  Future<Employee> upsertStaffRecord({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? jobTitle,
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
      final local = await _createLocalEmployee(
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
      return local.copyWith(
        firstName: firstName,
        lastName: lastName,
        positionTitle: jobTitle ?? local.positionTitle,
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
        if (jobTitle != null && jobTitle.trim().isNotEmpty)
          'job_title': jobTitle.trim(),
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
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to create staff record.'),
        cause: e,
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
      final updated = _localEmployees[idx].copyWith(status: status);
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
            // Keep legacy `status` column aligned (HCM / attendance filters).
            'status': switch (status) {
              StaffStatus.invited || StaffStatus.onboarding => 'pending',
              StaffStatus.inactive ||
              StaffStatus.suspended ||
              StaffStatus.terminated ||
              StaffStatus.resigned ||
              StaffStatus.retired ||
              StaffStatus.archived =>
                'inactive',
              _ => 'active',
            },
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
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to update staff status.'),
        cause: e,
      );
    }
  }

  Future<Employee?> updateStaffRecord({
    required String employeeId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? jobTitle,
    String? departmentId,
    String? teamId,
    String? managerId,
    String? branchId,
    String? actorId,
    bool clearDepartment = false,
    bool clearTeam = false,
    bool clearManager = false,
    bool clearBranch = false,
  }) async {
    final client = _client;
    if (client == null) {
      final idx = _localEmployees.indexWhere((e) => e.id == employeeId);
      if (idx < 0) return null;
      final prev = _localEmployees[idx];
      final nextFirst = firstName ?? prev.firstName ?? '';
      final nextLast = lastName ?? prev.lastName ?? '';
      final updated = prev.copyWith(
        firstName: firstName ?? prev.firstName,
        lastName: lastName ?? prev.lastName,
        displayName: '$nextFirst $nextLast'.trim().isEmpty
            ? prev.displayName
            : '$nextFirst $nextLast'.trim(),
        email: email ?? prev.email,
        phone: phone ?? prev.phone,
        positionTitle: jobTitle ?? prev.positionTitle,
        departmentId: clearDepartment ? null : (departmentId ?? prev.departmentId),
        departmentName: clearDepartment ? null : prev.departmentName,
        teamId: clearTeam ? null : (teamId ?? prev.teamId),
        teamName: clearTeam ? null : prev.teamName,
        managerId: clearManager ? null : (managerId ?? prev.managerId),
        managerName: clearManager ? null : prev.managerName,
        branchId: clearBranch ? null : (branchId ?? prev.branchId),
        branchName: clearBranch ? null : prev.branchName,
      );
      _localEmployees[idx] = updated;
      await _auditOrg('employee_updated', actorId, {'employee_id': employeeId});
      return updated;
    }

    try {
      final patch = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (actorId != null) 'updated_by': actorId,
        if (firstName != null) 'first_name': firstName.trim(),
        if (lastName != null) 'last_name': lastName.trim(),
        if (email != null) 'email': email.trim().isEmpty ? null : email.trim(),
        if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(),
        if (jobTitle != null)
          'job_title': jobTitle.trim().isEmpty ? null : jobTitle.trim(),
        if (clearDepartment)
          'department_id': null
        else if (departmentId != null)
          'department_id': departmentId,
        if (clearTeam)
          'team_id': null
        else if (teamId != null)
          'team_id': teamId,
        if (clearManager)
          'manager_id': null
        else if (managerId != null)
          'manager_id': managerId,
        if (clearBranch)
          'branch_id': null
        else if (branchId != null)
          'branch_id': branchId,
      };

      final row = await client
          .from('employees')
          .update(patch)
          .eq('id', employeeId)
          .select()
          .single();

      await _auditOrg('employee_updated', actorId, {
        'employee_id': employeeId,
        'fields': patch.keys.toList(),
      });

      return Employee.fromRow(Map<String, dynamic>.from(row));
    } catch (e) {
      throw DatabaseException('Unable to update staff record: $e');
    }
  }

  Future<Employee?> deactivateEmployee(
    String employeeId, {
    String? reason,
  }) async {
    final client = _client;
    if (client == null) {
      return updateStaffStatus(
        employeeId,
        StaffStatus.inactive,
        reason: reason,
      );
    }

    try {
      final result = await client.rpc(
        'deactivate_employee',
        params: {
          'p_employee_id': employeeId,
          if (reason != null && reason.trim().isNotEmpty) 'p_reason': reason.trim(),
        },
      );
      return Employee.fromRow(_asEmployeeRow(result));
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to deactivate employee.'),
        cause: e,
      );
    }
  }

  Future<Employee?> reactivateEmployee(String employeeId) async {
    final client = _client;
    if (client == null) {
      return updateStaffStatus(employeeId, StaffStatus.active);
    }

    try {
      final result = await client.rpc(
        'reactivate_employee',
        params: {'p_employee_id': employeeId},
      );
      return Employee.fromRow(_asEmployeeRow(result));
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to reactivate employee.'),
        cause: e,
      );
    }
  }

  Map<String, dynamic> _asEmployeeRow(dynamic result) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw const DatabaseException('Unexpected employee RPC response.');
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
    for (final table in [
      'employees',
      'teams',
      'departments',
      'leave_records',
      'staff_invitations',
      'portal_invitations',
    ]) {
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

  Future<List<StaffInvitation>> listStaffInvitations() async {
    final client = _client;
    if (client == null) return const [];
    try {
      // Never pull plaintext token for directory lists (Phase 2 hash-only storage).
      final rows = await client
          .from('staff_invitations')
          .select(
            'id, email, role_slug, first_name, last_name, phone, '
            'department_id, team_id, employee_id, invited_by, status, '
            'expires_at, accepted_at, accepted_user_id, created_at, revoked_at',
          )
          .order('created_at', ascending: false)
          .limit(200);
      return (rows as List)
          .map(
            (e) => StaffInvitation.fromRow(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load staff invitations.'),
        cause: e,
      );
    }
  }

  Future<StaffInvitation> inviteStaff({
    required String email,
    required String roleSlug,
    String? firstName,
    String? lastName,
    String? phone,
    String? departmentId,
    String? teamId,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const ValidationException('Enter a valid work email address.');
    }

    final params = <String, dynamic>{
      'p_email': trimmedEmail,
      'p_role_slug': roleSlug,
      'p_first_name':
          (firstName == null || firstName.trim().isEmpty) ? null : firstName.trim(),
      'p_last_name':
          (lastName == null || lastName.trim().isEmpty) ? null : lastName.trim(),
      'p_phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      'p_department_id': isValidUuid(departmentId) ? departmentId : null,
      'p_team_id': isValidUuid(teamId) ? teamId : null,
    };

    try {
      final result = await client.rpc('admin_invite_staff', params: params);
      final map = _parseRpcMap(result);
      await _auditOrg('staff_invited', client.auth.currentUser?.id, {
        'email': trimmedEmail,
        'role_slug': roleSlug,
        'invite_id': map['id'],
      });
      final invite = StaffInvitation.fromInviteResult(map);
      await _notifyInviteActor(
        actorId: client.auth.currentUser?.id,
        title: invite.status == 'accepted'
            ? 'Staff role assigned'
            : 'Staff invite created',
        body: invite.status == 'accepted'
            ? '${invite.email} already had an account — ${invite.roleLabel} was applied.'
            : 'Invite ready for ${invite.email} (${invite.roleLabel}). Copy the link to share.',
        inviteId: invite.id,
      );
      if (invite.status != 'accepted') {
        try {
          await _queueInviteEmail(
            templateSlug: EmailTemplateKeys.staffInvite,
            inviteEmail: invite.email,
            firstName: firstName,
            roleName: invite.roleLabel,
            pathBuilder: () async {
              var withToken = invite;
              if (withToken.token.isEmpty) {
                withToken = await revealStaffInviteToken(invite.id);
              }
              return inviteRegisterPath(withToken);
            },
          );
        } on DatabaseException catch (e) {
          await _notifyInviteActor(
            actorId: client.auth.currentUser?.id,
            title: 'Invite email not queued',
            body: e.message,
            inviteId: invite.id,
          );
        }
      }
      return invite;
    } catch (e, st) {
      AppLogger.error(
        'staff invite failed',
        error: e is PostgrestException
            ? '${e.code ?? ''} ${e.message}'.trim()
            : e,
        stackTrace: st,
      );
      throw DatabaseException(_inviteErrorMessage(e), cause: e);
    }
  }

  static bool isValidUuid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static Map<String, dynamic> _parseRpcMap(Object? result) {
    if (result == null) {
      throw const DatabaseException('Invite completed but no data was returned.');
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    if (result is String) {
      return Map<String, dynamic>.from(
        jsonDecode(result) as Map<String, dynamic>,
      );
    }
    throw DatabaseException(
      'Unexpected invite response (${result.runtimeType}).',
    );
  }

  Future<List<PortalInvitation>> listPortalInvitations() async {
    final client = _client;
    if (client == null) return const [];
    try {
      final rows = await client
          .from('portal_invitations')
          .select(
            'id, email, role_slug, first_name, last_name, phone, '
            'crm_client_id, investor_id, invited_by, status, '
            'expires_at, accepted_at, accepted_user_id, created_at, revoked_at',
          )
          .order('created_at', ascending: false)
          .limit(200);
      return (rows as List)
          .map(
            (e) =>
                PortalInvitation.fromRow(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      throw DatabaseException(
        userFacingError(e, fallback: 'Unable to load portal invitations.'),
        cause: e,
      );
    }
  }

  Future<PortalInvitation> invitePortalUser({
    required String email,
    required String roleSlug,
    String? firstName,
    String? lastName,
    String? phone,
    String? crmClientId,
    String? investorId,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const ValidationException('Enter a valid email address.');
    }
    if (roleSlug != 'client' && roleSlug != 'investor') {
      throw const ValidationException('Choose Client or Investor portal.');
    }

    final params = <String, dynamic>{
      'p_email': trimmedEmail,
      'p_role_slug': roleSlug,
    };
    if (firstName != null && firstName.trim().isNotEmpty) {
      params['p_first_name'] = firstName.trim();
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      params['p_last_name'] = lastName.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      params['p_phone'] = phone.trim();
    }
    if (isValidUuid(crmClientId)) {
      params['p_crm_client_id'] = crmClientId;
    }
    if (isValidUuid(investorId)) {
      params['p_investor_id'] = investorId;
    }

    try {
      final result =
          await client.rpc('admin_invite_portal_user', params: params);
      final map = _parseRpcMap(result);
      await _auditOrg('portal_invited', client.auth.currentUser?.id, {
        'email': trimmedEmail,
        'role_slug': roleSlug,
        'invite_id': map['id'],
        'crm_client_id': crmClientId,
        'investor_id': investorId,
      });
      final invite = PortalInvitation.fromInviteResult(map);
      await _notifyInviteActor(
        actorId: client.auth.currentUser?.id,
        title: invite.status == 'accepted'
            ? 'Portal access granted'
            : 'Portal invite created',
        body: invite.status == 'accepted'
            ? '${invite.email} already had an account — ${invite.roleLabel} was linked.'
            : 'Invite ready for ${invite.email} (${invite.roleLabel}). Copy the link to share.',
        inviteId: invite.id,
      );
      if (invite.status != 'accepted') {
        await _queueInviteEmail(
          templateSlug: EmailTemplateKeys.portalInvite,
          inviteEmail: invite.email,
          firstName: firstName,
          roleName: invite.roleLabel,
          pathBuilder: () async {
            var withToken = invite;
            if (withToken.token.isEmpty) {
              withToken = await revealPortalInviteToken(invite.id);
            }
            return portalInviteRegisterPath(withToken);
          },
        );
      }
      return invite;
    } catch (e) {
      throw DatabaseException(_portalInviteErrorMessage(e), cause: e);
    }
  }

  Future<void> revokePortalInvite(String inviteId) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      await client.rpc(
        'admin_revoke_portal_invite',
        params: {'p_invite_id': inviteId},
      );
      await _auditOrg('portal_invite_revoked', client.auth.currentUser?.id, {
        'invite_id': inviteId,
      });
    } catch (e) {
      throw DatabaseException(_portalInviteErrorMessage(e), cause: e);
    }
  }

  Future<PortalInvitation> revealPortalInviteToken(String inviteId) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      final result = await client.rpc(
        'admin_reveal_portal_invite_token',
        params: {'p_invite_id': inviteId},
      );
      final map = _parseRpcMap(result);
      final token = '${map['token'] ?? ''}';
      if (token.isEmpty) {
        throw const DatabaseException('Invite token could not be revealed.');
      }
      return PortalInvitation(
        id: '${map['id'] ?? inviteId}',
        email: '${map['email'] ?? ''}',
        roleSlug: '${map['role_slug'] ?? ''}',
        token: token,
        status: 'pending',
        expiresAt: map['expires_at'] == null
            ? null
            : DateTime.tryParse(map['expires_at'].toString())?.toUtc(),
      );
    } catch (e) {
      throw DatabaseException(_portalInviteErrorMessage(e), cause: e);
    }
  }

  Future<Map<String, dynamic>?> previewPortalInvitation(String token) async {
    final client = _client;
    if (client == null) return null;
    try {
      final result = await client.rpc(
        'preview_portal_invitation',
        params: {'p_token': token.trim()},
      );
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> acceptPortalInvitation(String token) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      final result = await client.rpc(
        'accept_portal_invitation',
        params: {'p_token': token.trim()},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      throw DatabaseException(_portalInviteErrorMessage(e), cause: e);
    }
  }

  /// Preview staff first, then portal — used by register banner.
  Future<Map<String, dynamic>?> previewAnyInvitation(String token) async {
    final staff = await previewStaffInvitation(token);
    if (staff != null) {
      return {...staff, 'kind': staff['kind'] ?? 'staff'};
    }
    return previewPortalInvitation(token);
  }

  Future<Map<String, dynamic>> acceptAnyInvitation(String token) async {
    final preview = await previewAnyInvitation(token);
    if (preview != null && preview['kind'] == 'portal') {
      return acceptPortalInvitation(token);
    }
    if (preview != null &&
        (preview['kind'] == 'staff' || preview['role_slug'] != null)) {
      return acceptStaffInvitation(token);
    }
    try {
      return await acceptStaffInvitation(token);
    } on DatabaseException {
      rethrow;
    } catch (e) {
      // Only fall through to portal when staff accept clearly is not applicable.
      final msg = e.toString().toLowerCase();
      if (msg.contains('invite_not_found') ||
          msg.contains('invite_email_mismatch') ||
          msg.contains('invite_expired') ||
          msg.contains('invite_not_pending')) {
        rethrow;
      }
      try {
        return await acceptPortalInvitation(token);
      } catch (_) {
        throw DatabaseException(_inviteErrorMessage(e), cause: e);
      }
    }
  }

  Future<void> revokeStaffInvite(String inviteId) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      await client.rpc(
        'admin_revoke_staff_invite',
        params: {'p_invite_id': inviteId},
      );
      await _auditOrg('staff_invite_revoked', client.auth.currentUser?.id, {
        'invite_id': inviteId,
      });
    } catch (e) {
      throw DatabaseException(_inviteErrorMessage(e), cause: e);
    }
  }

  /// Resend the branded invite email for an existing pending invitation.
  Future<StaffInvitation> resendStaffInvite(String inviteId) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      final result = await client.rpc(
        'admin_resend_staff_invite',
        params: {'p_invite_id': inviteId},
      );
      final map = _parseRpcMap(result);
      final invite = StaffInvitation.fromInviteResult({
        ...map,
        'id': map['id'] ?? inviteId,
      });
      var withToken = invite;
      if (withToken.token.isEmpty) {
        withToken = await revealStaffInviteToken(inviteId);
      }
      await _queueInviteEmail(
        templateSlug: EmailTemplateKeys.staffInvite,
        inviteEmail: withToken.email,
        firstName: withToken.firstName,
        roleName: withToken.roleLabel,
        pathBuilder: () async => inviteRegisterPath(withToken),
      );
      await _auditOrg('staff_invite_resent', client.auth.currentUser?.id, {
        'invite_id': inviteId,
        'email': withToken.email,
        'resend_count': map['resend_count'],
      });
      return withToken;
    } catch (e) {
      throw DatabaseException(_inviteErrorMessage(e), cause: e);
    }
  }

  /// Mint a fresh invite token (hash stored server-side; plaintext returned once).
  Future<StaffInvitation> revealStaffInviteToken(String inviteId) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      final result = await client.rpc(
        'admin_reveal_staff_invite_token',
        params: {'p_invite_id': inviteId},
      );
      final map = _parseRpcMap(result);
      final token = '${map['token'] ?? ''}';
      if (token.isEmpty) {
        throw const DatabaseException('Invite token could not be revealed.');
      }
      return StaffInvitation(
        id: '${map['id'] ?? inviteId}',
        email: '${map['email'] ?? ''}',
        roleSlug: '',
        token: token,
        status: 'pending',
        expiresAt: map['expires_at'] == null
            ? null
            : DateTime.tryParse(map['expires_at'].toString())?.toUtc(),
      );
    } catch (e) {
      throw DatabaseException(_inviteErrorMessage(e), cause: e);
    }
  }

  Future<void> _queueInviteEmail({
    required String templateSlug,
    required String inviteEmail,
    String? firstName,
    String? roleName,
    required Future<String> Function() pathBuilder,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final path = await pathBuilder();
      // Queued mail is delivered by the hosted worker, so the link must be
      // the public site even when this admin session is running locally.
      final emailConfig = EmailConfig(client);
      final cta = EmailConfig.composeActionUrl(
        await emailConfig.loadSiteUrl(),
        path,
      );
      await client.rpc(
        'queue_transactional_email',
        params: {
          'p_template_slug': templateSlug,
          'p_recipient_email': inviteEmail.trim().toLowerCase(),
          'p_variables': {
            'first_name': (firstName ?? '').trim().isEmpty
                ? 'there'
                : firstName!.trim(),
            'cta_url': cta,
            'role_name': roleName ?? '',
            'portal_name': roleName ?? '',
          },
          'p_payload': {'source': 'organization_invite'},
        },
      );
      // Best-effort drain — process-email-queue is verify_jwt=false.
      // Failures stay in the queue; the invite itself already succeeded.
      try {
        final response = await client.functions.invoke('process-email-queue');
        final data = response.data;
        if (data is Map && data['error'] != null) {
          AppLogger.error(
            'process-email-queue returned an error',
            error: data['error'],
          );
        }
      } catch (e, st) {
        AppLogger.error(
          'process-email-queue could not be reached',
          error: e,
          stackTrace: st,
        );
      }
    } catch (e) {
      throw DatabaseException(
        userFacingError(
          e,
          fallback:
              'Invitation was created but the email could not be queued. Copy the invite link to share.',
        ),
        cause: e,
      );
    }
  }

  Future<void> _notifyInviteActor({
    required String? actorId,
    required String title,
    required String body,
    required String inviteId,
  }) async {
    final client = _client;
    if (client == null || actorId == null) return;
    try {
      await client.from('notifications').insert({
        'user_id': actorId,
        'title': title,
        'body': body,
        'channel': 'in_app',
        'category': 'people',
        'type': 'staff_invite',
        'priority': 'normal',
        'action_url': '/dashboard/users',
        'metadata': {'invite_id': inviteId},
        'status': 'active',
        'delivery_status': 'delivered',
      });
    } catch (_) {
      // Non-blocking — invite still succeeds without inbox row.
    }
  }

  Future<Map<String, dynamic>?> previewStaffInvitation(String token) async {
    final client = _client;
    if (client == null) return null;
    try {
      final result = await client.rpc(
        'preview_staff_invitation',
        params: {'p_token': token.trim()},
      );
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } catch (e, st) {
      AppLogger.error(
        'staff invite preview failed',
        error: e is PostgrestException
            ? '${e.code ?? ''} ${e.message}'.trim()
            : e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<Map<String, dynamic>> acceptStaffInvitation(String token) async {
    final client = _client;
    if (client == null) {
      throw const DatabaseException('Supabase is not configured');
    }
    try {
      final result = await client.rpc(
        'accept_staff_invitation',
        params: {'p_token': token.trim()},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      throw DatabaseException(_inviteErrorMessage(e), cause: e);
    }
  }

  static String inviteRegisterPath(StaffInvitation invite) {
    final email = Uri.encodeComponent(invite.email);
    return '${RoutePaths.register}?invite=${invite.token}&email=$email';
  }

  static String inviteLoginPath(StaffInvitation invite) {
    final email = Uri.encodeComponent(invite.email);
    return '${RoutePaths.login}?invite=${invite.token}&email=$email';
  }

  static String portalInviteRegisterPath(PortalInvitation invite) {
    final email = Uri.encodeComponent(invite.email);
    final type = Uri.encodeComponent(invite.roleSlug);
    return '${RoutePaths.register}?invite=${invite.token}&email=$email&type=$type';
  }

  static String portalInviteLoginPath(PortalInvitation invite) {
    final email = Uri.encodeComponent(invite.email);
    return '${RoutePaths.login}?invite=${invite.token}&email=$email';
  }

  String _portalInviteErrorMessage(Object e) {
    if (e is AppException) return e.message;
    if (e is PostgrestException) return friendlyPostgrestMessage(e);
    final raw = e.toString().toLowerCase();
    if (raw.contains('forbidden_role_assignment')) {
      return 'You are not allowed to invite that portal type.';
    }
    if (raw.contains('invalid_email')) {
      return 'Enter a valid email address.';
    }
    if (raw.contains('crm_client_already_has_portal')) {
      return 'This CRM client already has portal access.';
    }
    if (raw.contains('investor_already_has_portal') ||
        raw.contains('investor_already_linked')) {
      return 'This investor already has portal access.';
    }
    if (raw.contains('invite_email_mismatch')) {
      return 'Email must match the CRM/IMP record.';
    }
    if (raw.contains('invite_expired')) {
      return 'This invite has expired. Create a new one.';
    }
    if (raw.contains('invite_not_found') || raw.contains('invite_not_pending')) {
      return 'This invite is no longer valid.';
    }
    if (raw.contains('forbidden') || raw.contains('not_authenticated')) {
      return 'You need permission to manage portal invites.';
    }
    if (raw.contains('pgrst202') || raw.contains('could not find the function')) {
      return 'Portal invite service is still syncing. Wait a moment and try again.';
    }
    return userFacingError(
      e,
      fallback: 'Unable to complete portal invite. Please try again.',
    );
  }

  String _inviteErrorMessage(Object e) {
    if (e is AppException) {
      return e.message;
    }
    if (e is PostgrestException) {
      final detail =
          '${e.message} ${e.code ?? ''} ${e.details ?? ''}'.toLowerCase();
      if (detail.contains('forbidden_role_assignment')) {
        return 'You are not allowed to assign that role. Super Admin assigns Admins; Admin assigns Sales, Finance, Marketing, and Construction.';
      }
      if (detail.contains('invalid_email')) {
        return 'Enter a valid work email address.';
      }
      if (detail.contains('invalid input syntax for type uuid')) {
        return 'Department or team selection is invalid. Refresh the page and try again.';
      }
      if (detail.contains('employees_employment_status_check') ||
          detail.contains('staff_invitations_role_check')) {
        return 'That role or staff status is not allowed. Choose another role and try again.';
      }
      final friendly = friendlyPostgrestMessage(e);
      if (friendly.contains('loading your data')) {
        return 'Unable to complete staff invite. Please try again.';
      }
      return friendly;
    }
    final raw = e.toString().toLowerCase();
    if (raw.contains('forbidden_role_assignment')) {
      return 'You are not allowed to assign that role. Super Admin assigns Admins; Admin assigns Sales, Finance, Marketing, and Construction.';
    }
    if (raw.contains('invalid_email')) {
      return 'Enter a valid work email address.';
    }
    if (raw.contains('invalid input syntax for type uuid')) {
      return 'Department or team selection is invalid. Refresh the page and try again.';
    }
    if (raw.contains('invite_email_mismatch')) {
      return 'Sign in with the invited email address to accept this invite.';
    }
    if (raw.contains('invite_expired')) {
      return 'This invite has expired. Ask an admin to send a new one.';
    }
    if (raw.contains('invite_not_found') || raw.contains('invite_not_pending')) {
      return 'This invite is no longer valid.';
    }
    if (raw.contains('forbidden') || raw.contains('not_authenticated')) {
      return 'You need admin permissions to manage staff invites.';
    }
    if (raw.contains('pgrst202') || raw.contains('could not find the function')) {
      return 'Staff invite service is still syncing. Wait a moment and try again.';
    }
    return userFacingError(e, fallback: 'Unable to complete staff invite. Please try again.');
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
    Map<String, dynamic> metadata, {
    String? entityType,
    String? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    final resolvedEntityType = entityType ??
        (metadata['employee_id'] != null
            ? 'employees'
            : metadata['department_id'] != null
                ? 'departments'
                : metadata['team_id'] != null
                    ? 'teams'
                    : metadata['invite_id'] != null
                        ? 'staff_invitations'
                        : 'organization');
    final resolvedEntityId = entityId ??
        metadata['employee_id']?.toString() ??
        metadata['department_id']?.toString() ??
        metadata['team_id']?.toString() ??
        metadata['invite_id']?.toString();

    unawaited(
      _audit.publish(
        AuditPublishRequest(
          action: action,
          module: 'organization',
          category: action.contains('invite') || action.contains('status')
              ? AuditEventCategory.security
              : AuditEventCategory.admin,
          userId: actorId,
          severity: AuditSeverity.notice,
          entityType: resolvedEntityType,
          entityId: resolvedEntityId,
          oldValues: oldValues,
          newValues: newValues ?? metadata,
          metadata: metadata,
        ),
      ),
    );
  }
}
