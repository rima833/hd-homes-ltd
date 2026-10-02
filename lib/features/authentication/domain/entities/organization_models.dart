import 'package:flutter/material.dart';

const Object _unset = Object();

/// Employment / staff lifecycle status.
enum StaffStatus {
  invited,
  onboarding,
  active,
  onLeave,
  remote,
  suspended,
  probation,
  inactive,
  resigned,
  terminated,
  retired,
  archived;

  String get slug => switch (this) {
        StaffStatus.onLeave => 'on_leave',
        _ => name,
      };

  String get label => switch (this) {
        StaffStatus.invited => 'Invited',
        StaffStatus.onboarding => 'Onboarding',
        StaffStatus.active => 'Active',
        StaffStatus.onLeave => 'On Leave',
        StaffStatus.remote => 'Remote',
        StaffStatus.suspended => 'Suspended',
        StaffStatus.probation => 'Probation',
        StaffStatus.inactive => 'Inactive',
        StaffStatus.resigned => 'Resigned',
        StaffStatus.terminated => 'Terminated',
        StaffStatus.retired => 'Retired',
        StaffStatus.archived => 'Archived',
      };

  bool get isOperational =>
      this == StaffStatus.active ||
      this == StaffStatus.remote ||
      this == StaffStatus.probation ||
      this == StaffStatus.onboarding;

  bool get isDeactivated =>
      this == StaffStatus.inactive ||
      this == StaffStatus.resigned ||
      this == StaffStatus.terminated ||
      this == StaffStatus.retired ||
      this == StaffStatus.archived;

  Color get color => switch (this) {
        StaffStatus.invited => const Color(0xFFCA8A04),
        StaffStatus.onboarding => const Color(0xFFDB2777),
        StaffStatus.active => const Color(0xFF16A34A),
        StaffStatus.onLeave => const Color(0xFF2563EB),
        StaffStatus.remote => const Color(0xFF0891B2),
        StaffStatus.suspended => const Color(0xFFD97706),
        StaffStatus.probation => const Color(0xFF7C3AED),
        StaffStatus.inactive ||
        StaffStatus.resigned ||
        StaffStatus.terminated ||
        StaffStatus.retired ||
        StaffStatus.archived =>
          const Color(0xFF64748B),
      };

  static StaffStatus fromSlug(String? raw) {
    return switch ((raw ?? 'active').toLowerCase()) {
      'invited' || 'pending_invite' || 'pending' => StaffStatus.invited,
      'onboarding' || 'pending_onboarding' => StaffStatus.onboarding,
      'on_leave' || 'onleave' => StaffStatus.onLeave,
      'remote' => StaffStatus.remote,
      'suspended' => StaffStatus.suspended,
      'probation' => StaffStatus.probation,
      'inactive' || 'deactivated' => StaffStatus.inactive,
      'resigned' => StaffStatus.resigned,
      'terminated' => StaffStatus.terminated,
      'retired' => StaffStatus.retired,
      'archived' => StaffStatus.archived,
      'confirmed' || 'active' => StaffStatus.active,
      _ => StaffStatus.active,
    };
  }
}

enum OrgEntityStatus {
  active,
  inactive,
  archived;

  String get slug => name;

  static OrgEntityStatus fromSlug(String? raw) {
    return switch ((raw ?? 'active').toLowerCase()) {
      'inactive' => OrgEntityStatus.inactive,
      'archived' => OrgEntityStatus.archived,
      _ => OrgEntityStatus.active,
    };
  }
}

enum OnboardingStep {
  createAccount,
  assignDepartmentTeam,
  assignRolePermissions,
  sendWelcomeCredentials,
  completeProfile,
  enableMfa,
  activateAccount;

  String get slug => switch (this) {
        OnboardingStep.createAccount => 'create_account',
        OnboardingStep.assignDepartmentTeam => 'assign_department_team',
        OnboardingStep.assignRolePermissions => 'assign_role_permissions',
        OnboardingStep.sendWelcomeCredentials => 'send_welcome_credentials',
        OnboardingStep.completeProfile => 'complete_profile',
        OnboardingStep.enableMfa => 'enable_mfa',
        OnboardingStep.activateAccount => 'activate_account',
      };

  String get label => switch (this) {
        OnboardingStep.createAccount => 'Create employee account',
        OnboardingStep.assignDepartmentTeam => 'Assign department & team',
        OnboardingStep.assignRolePermissions => 'Assign role & permissions',
        OnboardingStep.sendWelcomeCredentials => 'Send welcome credentials',
        OnboardingStep.completeProfile => 'Complete profile setup',
        OnboardingStep.enableMfa => 'Enable MFA (if required)',
        OnboardingStep.activateAccount => 'Activate account',
      };

  int get order => index + 1;

  static OnboardingStep fromSlug(String? raw) {
    return OnboardingStep.values.firstWhere(
      (s) => s.slug == (raw ?? '').toLowerCase(),
      orElse: () => OnboardingStep.createAccount,
    );
  }
}

/// Catalog of default HD Homes departments.
abstract final class DefaultDepartments {
  static const entries = <({String slug, String name, String description})>[
    (
      slug: 'executive_management',
      name: 'Executive Management',
      description: 'Leadership, strategy, and corporate governance',
    ),
    (
      slug: 'sales_marketing',
      name: 'Sales & Marketing',
      description: 'Property sales, campaigns, and brand growth',
    ),
    (
      slug: 'finance_accounts',
      name: 'Finance & Accounts',
      description: 'Payments, accounting, and financial controls',
    ),
    (
      slug: 'construction_operations',
      name: 'Construction & Operations',
      description: 'Site delivery, project operations, and logistics',
    ),
    (
      slug: 'architecture_design',
      name: 'Architecture & Design',
      description: 'Design, drawings, and spatial planning',
    ),
    (
      slug: 'survey_land',
      name: 'Survey & Land Services',
      description: 'Land survey, title, and site assessment',
    ),
    (
      slug: 'customer_support',
      name: 'Customer Support',
      description: 'Client care, tickets, and service recovery',
    ),
    (
      slug: 'human_resources',
      name: 'Human Resources',
      description: 'People operations, leave, and staffing',
    ),
    (
      slug: 'legal_compliance',
      name: 'Legal & Compliance',
      description: 'Contracts, KYC oversight, and regulatory affairs',
    ),
    (
      slug: 'technology_systems',
      name: 'Technology & Systems',
      description: 'Platform engineering, security, and IT',
    ),
    (
      slug: 'investor_relations',
      name: 'Investor Relations',
      description: 'Investor onboarding, reporting, and retention',
    ),
  ];
}

class BranchOffice {
  const BranchOffice({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.city,
    this.phone,
    this.isPrimary = false,
    this.status = OrgEntityStatus.active,
    this.staffCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? address;
  final String? city;
  final String? phone;
  final bool isPrimary;
  final OrgEntityStatus status;
  final int staffCount;

  factory BranchOffice.fromRow(Map<String, dynamic> row) {
    return BranchOffice(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Branch',
      slug: row['slug'] as String? ?? '',
      address: row['address'] as String?,
      city: row['city'] as String?,
      phone: row['phone'] as String?,
      isPrimary: row['is_primary'] as bool? ?? false,
      status: OrgEntityStatus.fromSlug(row['status'] as String?),
      staffCount: (row['staff_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Department {
  const Department({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.headEmployeeId,
    this.headEmployeeName,
    this.status = OrgEntityStatus.active,
    this.teamCount = 0,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? headEmployeeId;
  final String? headEmployeeName;
  final OrgEntityStatus status;
  final int teamCount;
  final int memberCount;

  factory Department.fromRow(Map<String, dynamic> row) {
    return Department(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Department',
      slug: row['slug'] as String? ?? '',
      description: row['description'] as String?,
      headEmployeeId: row['head_employee_id'] as String?,
      headEmployeeName: row['head_employee_name'] as String?,
      status: OrgEntityStatus.fromSlug(row['status'] as String?),
      teamCount: (row['team_count'] as num?)?.toInt() ?? 0,
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrgTeam {
  const OrgTeam({
    required this.id,
    required this.name,
    required this.departmentId,
    this.description,
    this.teamLeadId,
    this.teamLeadName,
    this.branchId,
    this.status = OrgEntityStatus.active,
    this.memberCount = 0,
    this.departmentName,
    this.createdAt,
  });

  final String id;
  final String name;
  final String departmentId;
  final String? description;
  final String? teamLeadId;
  final String? teamLeadName;
  final String? branchId;
  final OrgEntityStatus status;
  final int memberCount;
  final String? departmentName;
  final DateTime? createdAt;

  factory OrgTeam.fromRow(Map<String, dynamic> row) {
    return OrgTeam(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Team',
      departmentId: row['department_id'] as String? ?? '',
      description: row['description'] as String?,
      teamLeadId: row['team_lead_id'] as String?,
      teamLeadName: row['team_lead_name'] as String?,
      branchId: row['branch_id'] as String?,
      status: OrgEntityStatus.fromSlug(row['status'] as String?),
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      departmentName: row['department_name'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String).toUtc()
          : null,
    );
  }
}

class Position {
  const Position({
    required this.id,
    required this.title,
    required this.slug,
    this.departmentId,
    this.level = 1,
    this.description,
  });

  final String id;
  final String title;
  final String slug;
  final String? departmentId;
  final int level;
  final String? description;

  factory Position.fromRow(Map<String, dynamic> row) {
    return Position(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'Position',
      slug: row['slug'] as String? ?? '',
      departmentId: row['department_id'] as String?,
      level: (row['level'] as num?)?.toInt() ?? 1,
      description: row['description'] as String?,
    );
  }
}

class Employee {
  const Employee({
    required this.id,
    required this.employeeCode,
    required this.displayName,
    required this.status,
    this.firstName,
    this.lastName,
    this.userId,
    this.email,
    this.phone,
    this.departmentId,
    this.departmentName,
    this.teamId,
    this.teamName,
    this.positionId,
    this.positionTitle,
    this.managerId,
    this.managerName,
    this.branchId,
    this.branchName,
    this.joinedAt,
    this.avatarUrl,
    this.roleSlug,
  });

  final String id;
  final String employeeCode;
  final String displayName;
  final StaffStatus status;
  final String? firstName;
  final String? lastName;
  final String? userId;
  final String? email;
  final String? phone;
  final String? departmentId;
  final String? departmentName;
  final String? teamId;
  final String? teamName;
  final String? positionId;
  final String? positionTitle;
  final String? managerId;
  final String? managerName;
  final String? branchId;
  final String? branchName;
  final DateTime? joinedAt;
  final String? avatarUrl;
  final String? roleSlug;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'HD';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Employee copyWith({
    String? id,
    String? employeeCode,
    String? displayName,
    StaffStatus? status,
    String? firstName,
    String? lastName,
    String? userId,
    String? email,
    String? phone,
    Object? departmentId = _unset,
    Object? departmentName = _unset,
    Object? teamId = _unset,
    Object? teamName = _unset,
    String? positionId,
    String? positionTitle,
    Object? managerId = _unset,
    Object? managerName = _unset,
    Object? branchId = _unset,
    Object? branchName = _unset,
    DateTime? joinedAt,
    String? avatarUrl,
    String? roleSlug,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      departmentId: identical(departmentId, _unset)
          ? this.departmentId
          : departmentId as String?,
      departmentName: identical(departmentName, _unset)
          ? this.departmentName
          : departmentName as String?,
      teamId: identical(teamId, _unset) ? this.teamId : teamId as String?,
      teamName: identical(teamName, _unset) ? this.teamName : teamName as String?,
      positionId: positionId ?? this.positionId,
      positionTitle: positionTitle ?? this.positionTitle,
      managerId:
          identical(managerId, _unset) ? this.managerId : managerId as String?,
      managerName: identical(managerName, _unset)
          ? this.managerName
          : managerName as String?,
      branchId:
          identical(branchId, _unset) ? this.branchId : branchId as String?,
      branchName: identical(branchName, _unset)
          ? this.branchName
          : branchName as String?,
      joinedAt: joinedAt ?? this.joinedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roleSlug: roleSlug ?? this.roleSlug,
    );
  }

  factory Employee.fromRow(Map<String, dynamic> row) {
    final first = row['first_name'] as String? ?? '';
    final last = row['last_name'] as String? ?? '';
    final preferred = row['preferred_name'] as String?;
    final composed = [
      if (preferred != null && preferred.isNotEmpty) preferred else first,
      last,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    final jobTitle = row['position_title'] as String? ??
        row['job_title'] as String?;

    return Employee(
      id: row['id'] as String,
      employeeCode: row['employee_code'] as String? ?? 'HDH-EMP-????',
      displayName: composed.isNotEmpty
          ? composed
          : (row['display_name'] as String? ?? 'Staff member'),
      status: StaffStatus.fromSlug(row['employment_status'] as String?),
      firstName: first.isEmpty ? null : first,
      lastName: last.isEmpty ? null : last,
      userId: row['user_id'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      departmentId: row['department_id'] as String?,
      departmentName: row['department_name'] as String?,
      teamId: row['team_id'] as String?,
      teamName: row['team_name'] as String?,
      positionId: row['position_id'] as String?,
      positionTitle: jobTitle,
      managerId: row['manager_id'] as String?,
      managerName: row['manager_name'] as String?,
      branchId: row['branch_id'] as String?,
      branchName: row['branch_name'] as String?,
      joinedAt: row['joined_at'] != null
          ? DateTime.parse(row['joined_at'] as String).toUtc()
          : null,
      avatarUrl: row['avatar_url'] as String?,
      roleSlug: row['role_slug'] as String?,
    );
  }
}

class OrgChartNode {
  const OrgChartNode({
    required this.employee,
    this.directReports = const [],
  });

  final Employee employee;
  final List<OrgChartNode> directReports;
}

class StaffAnalytics {
  const StaffAnalytics({
    required this.totalEmployees,
    required this.activeStaff,
    required this.departmentsConfigured,
    required this.onLeave,
    required this.newHiresThisMonth,
    required this.byDepartment,
    required this.byBranch,
    required this.byStatus,
    this.pendingInvitations = 0,
  });

  final int totalEmployees;
  final int activeStaff;
  final int departmentsConfigured;
  final int onLeave;
  final int newHiresThisMonth;
  final Map<String, int> byDepartment;
  final Map<String, int> byBranch;
  final Map<StaffStatus, int> byStatus;
  final int pendingInvitations;

  double get activeRate =>
      totalEmployees == 0 ? 0 : (activeStaff / totalEmployees) * 100;
}

class OnboardingProgress {
  const OnboardingProgress({
    required this.employeeId,
    required this.completedSteps,
    this.currentStep = OnboardingStep.createAccount,
  });

  final String employeeId;
  final Set<OnboardingStep> completedSteps;
  final OnboardingStep currentStep;

  double get percentComplete =>
      completedSteps.length / OnboardingStep.values.length;

  bool get isComplete =>
      completedSteps.length >= OnboardingStep.values.length;

  List<OnboardingStep> get remaining => OnboardingStep.values
      .where((s) => !completedSteps.contains(s))
      .toList();
}

/// Today's attendance snapshot for a staff member (from attendance_records).
class StaffAttendanceSummary {
  const StaffAttendanceSummary({
    required this.employeeId,
    this.workDate,
    this.stateLabel = 'No record',
    this.clockInAt,
    this.clockOutAt,
    this.isRemote = false,
    this.hasRecord = false,
  });

  final String employeeId;
  final DateTime? workDate;
  final String stateLabel;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final bool isRemote;
  final bool hasRecord;

  factory StaffAttendanceSummary.empty(String employeeId) {
    return StaffAttendanceSummary(employeeId: employeeId);
  }

  factory StaffAttendanceSummary.fromRow(
    String employeeId,
    Map<String, dynamic> row,
  ) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    final state = '${row['attendance_state'] ?? row['status'] ?? ''}'
        .trim()
        .toLowerCase();
    final label = switch (state) {
      'working' || 'clocked_in' || 'after_break' => 'Clocked in',
      'on_break' => 'On break',
      'completed' || 'clocked_out' => 'Clocked out',
      'not_started' => 'Not started',
      'absent' => 'Absent',
      'remote' => 'Remote',
      '' => 'No record',
      _ => state.replaceAll('_', ' '),
    };
    final remote = row['is_remote'] == true || state == 'remote';
    return StaffAttendanceSummary(
      employeeId: employeeId,
      workDate: parse(row['work_date']),
      stateLabel: remote && label == 'Clocked in' ? 'Remote' : label,
      clockInAt: parse(row['clock_in_at']),
      clockOutAt: parse(row['clock_out_at']),
      isRemote: remote,
      hasRecord: true,
    );
  }
}

class OrganizationSnapshot {
  const OrganizationSnapshot({
    required this.departments,
    required this.teams,
    required this.employees,
    required this.branches,
    required this.positions,
    required this.analytics,
    this.invitations = const [],
    this.portalInvitations = const [],
  });

  final List<Department> departments;
  final List<OrgTeam> teams;
  final List<Employee> employees;
  final List<BranchOffice> branches;
  final List<Position> positions;
  final StaffAnalytics analytics;
  final List<StaffInvitation> invitations;
  final List<PortalInvitation> portalInvitations;
}

/// Pending / accepted staff invite created by Super Admin or Admin.
class StaffInvitation {
  const StaffInvitation({
    required this.id,
    required this.email,
    required this.roleSlug,
    required this.token,
    required this.status,
    this.firstName,
    this.lastName,
    this.phone,
    this.departmentId,
    this.teamId,
    this.employeeId,
    this.invitedBy,
    this.expiresAt,
    this.acceptedAt,
    this.acceptedUserId,
    this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String email;
  final String roleSlug;
  final String token;
  final String status;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? departmentId;
  final String? teamId;
  final String? employeeId;
  final String? invitedBy;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedUserId;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  String get roleLabel => switch (roleSlug) {
        'admin' => 'Admin',
        'sales_team' => 'Sales Team',
        'finance' => 'Finance',
        'marketing' => 'Marketing',
        'construction_manager' => 'Construction Manager',
        _ => roleSlug.replaceAll('_', ' '),
      };

  bool get hasUsableToken => token.trim().isNotEmpty;

  bool get isPending => status == 'pending';

  bool isExpiredAt([DateTime? now]) {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore((now ?? DateTime.now()).toUtc());
  }

  /// Display status — pending invites past expiry read as expired.
  String effectiveStatus([DateTime? now]) {
    if (status == 'pending' && isExpiredAt(now)) return 'expired';
    return status;
  }

  bool get isActionablePending =>
      isPending && !isExpiredAt();

  StaffInvitation copyWith({
    String? token,
    String? status,
  }) {
    return StaffInvitation(
      id: id,
      email: email,
      roleSlug: roleSlug,
      token: token ?? this.token,
      status: status ?? this.status,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      departmentId: departmentId,
      teamId: teamId,
      employeeId: employeeId,
      invitedBy: invitedBy,
      expiresAt: expiresAt,
      acceptedAt: acceptedAt,
      acceptedUserId: acceptedUserId,
      createdAt: createdAt,
      revokedAt: revokedAt,
    );
  }

  factory StaffInvitation.fromRow(Map<String, dynamic> row) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    return StaffInvitation(
      id: '${row['id']}',
      email: '${row['email'] ?? ''}',
      roleSlug: '${row['role_slug'] ?? ''}',
      token: '${row['token'] ?? ''}',
      status: '${row['status'] ?? 'pending'}',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      phone: row['phone'] as String?,
      departmentId: row['department_id']?.toString(),
      teamId: row['team_id']?.toString(),
      employeeId: row['employee_id']?.toString(),
      invitedBy: row['invited_by']?.toString(),
      expiresAt: parse(row['expires_at']),
      acceptedAt: parse(row['accepted_at']),
      acceptedUserId: row['accepted_user_id']?.toString(),
      createdAt: parse(row['created_at']),
      revokedAt: parse(row['revoked_at']),
    );
  }

  factory StaffInvitation.fromInviteResult(Map<String, dynamic> row) {
    return StaffInvitation.fromRow({
      ...row,
      'role_slug': row['role_slug'],
      'token': row['token'],
      'status': row['status'] ?? 'pending',
    });
  }
}

/// Client / Investor portal invite (no shared passwords).
class PortalInvitation {
  const PortalInvitation({
    required this.id,
    required this.email,
    required this.roleSlug,
    required this.token,
    required this.status,
    this.firstName,
    this.lastName,
    this.phone,
    this.crmClientId,
    this.investorId,
    this.invitedBy,
    this.expiresAt,
    this.acceptedAt,
    this.acceptedUserId,
    this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String email;
  final String roleSlug;
  final String token;
  final String status;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? crmClientId;
  final String? investorId;
  final String? invitedBy;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? acceptedUserId;
  final DateTime? createdAt;
  final DateTime? revokedAt;

  String get roleLabel => switch (roleSlug) {
        'client' => 'Client Portal',
        'investor' => 'Investor Portal',
        _ => roleSlug.replaceAll('_', ' '),
      };

  bool get hasUsableToken => token.trim().isNotEmpty;

  bool get isPending => status == 'pending';

  bool isExpiredAt([DateTime? now]) {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore((now ?? DateTime.now()).toUtc());
  }

  String effectiveStatus([DateTime? now]) {
    if (status == 'pending' && isExpiredAt(now)) return 'expired';
    return status;
  }

  bool get isActionablePending => isPending && !isExpiredAt();

  PortalInvitation copyWith({String? token, String? status}) {
    return PortalInvitation(
      id: id,
      email: email,
      roleSlug: roleSlug,
      token: token ?? this.token,
      status: status ?? this.status,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      crmClientId: crmClientId,
      investorId: investorId,
      invitedBy: invitedBy,
      expiresAt: expiresAt,
      acceptedAt: acceptedAt,
      acceptedUserId: acceptedUserId,
      createdAt: createdAt,
      revokedAt: revokedAt,
    );
  }

  factory PortalInvitation.fromRow(Map<String, dynamic> row) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    return PortalInvitation(
      id: '${row['id']}',
      email: '${row['email'] ?? ''}',
      roleSlug: '${row['role_slug'] ?? ''}',
      token: '${row['token'] ?? ''}',
      status: '${row['status'] ?? 'pending'}',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      phone: row['phone'] as String?,
      crmClientId: row['crm_client_id']?.toString(),
      investorId: row['investor_id']?.toString(),
      invitedBy: row['invited_by']?.toString(),
      expiresAt: parse(row['expires_at']),
      acceptedAt: parse(row['accepted_at']),
      acceptedUserId: row['accepted_user_id']?.toString(),
      createdAt: parse(row['created_at']),
      revokedAt: parse(row['revoked_at']),
    );
  }

  factory PortalInvitation.fromInviteResult(Map<String, dynamic> row) {
    return PortalInvitation.fromRow({
      ...row,
      'role_slug': row['role_slug'],
      'token': row['token'],
      'status': row['status'] ?? 'pending',
    });
  }
}

/// Pure helpers — hierarchy, employee codes, onboarding sequence.
abstract final class OrganizationEngine {
  static String formatEmployeeCode(int sequence) {
    final padded = sequence.toString().padLeft(4, '0');
    return 'HDH-EMP-$padded';
  }

  static int parseEmployeeSequence(String code) {
    final match = RegExp(r'HDH-EMP-(\d+)', caseSensitive: false).firstMatch(code);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }

  static StaffAnalytics computeAnalytics({
    required List<Employee> employees,
    required List<Department> departments,
    required List<BranchOffice> branches,
    DateTime? now,
    int pendingInvitations = 0,
  }) {
    final n = now ?? DateTime.now().toUtc();
    final monthStart = DateTime.utc(n.year, n.month, 1);
    final byDept = <String, int>{};
    final byBranch = <String, int>{};
    final byStatus = <StaffStatus, int>{};

    for (final e in employees) {
      final dept = e.departmentName ?? 'Unassigned';
      byDept[dept] = (byDept[dept] ?? 0) + 1;
      final branch = e.branchName ?? 'Unassigned';
      byBranch[branch] = (byBranch[branch] ?? 0) + 1;
      byStatus[e.status] = (byStatus[e.status] ?? 0) + 1;
    }

    final active = employees.where((e) => e.status.isOperational).length;
    final onLeave =
        employees.where((e) => e.status == StaffStatus.onLeave).length;
    final hires = employees.where((e) {
      final j = e.joinedAt;
      return j != null && !j.isBefore(monthStart);
    }).length;

    return StaffAnalytics(
      totalEmployees: employees.length,
      activeStaff: active,
      departmentsConfigured: departments.length,
      onLeave: onLeave,
      newHiresThisMonth: hires,
      byDepartment: byDept,
      byBranch: byBranch,
      byStatus: byStatus,
      pendingInvitations: pendingInvitations,
    );
  }

  /// Build reporting tree from flat employee list (managerId links).
  static List<OrgChartNode> buildOrgChart(List<Employee> employees) {
    final byId = {for (final e in employees) e.id: e};
    final children = <String, List<Employee>>{};
    final roots = <Employee>[];

    for (final e in employees) {
      final managerId = e.managerId;
      if (managerId == null || !byId.containsKey(managerId)) {
        roots.add(e);
      } else {
        children.putIfAbsent(managerId, () => []).add(e);
      }
    }

    OrgChartNode build(Employee e) {
      final reports = (children[e.id] ?? const [])
          .map(build)
          .toList(growable: false);
      return OrgChartNode(employee: e, directReports: reports);
    }

    roots.sort((a, b) => a.displayName.compareTo(b.displayName));
    return roots.map(build).toList(growable: false);
  }

  static List<Employee> directReports(
    List<Employee> employees,
    String managerId,
  ) {
    return employees.where((e) => e.managerId == managerId).toList();
  }

  static List<Employee> reportingChain(
    List<Employee> employees,
    String employeeId,
  ) {
    final byId = {for (final e in employees) e.id: e};
    final chain = <Employee>[];
    var current = byId[employeeId];
    final seen = <String>{};
    while (current?.managerId != null) {
      final mid = current!.managerId!;
      if (!seen.add(mid)) break;
      final manager = byId[mid];
      if (manager == null) break;
      chain.add(manager);
      current = manager;
    }
    return chain;
  }

  static OnboardingProgress advanceOnboarding(OnboardingProgress current) {
    final nextIncomplete = OnboardingStep.values
        .where((s) => !current.completedSteps.contains(s))
        .toList();
    if (nextIncomplete.isEmpty) return current;
    final completed = {...current.completedSteps, nextIncomplete.first};
    final remaining = OnboardingStep.values
        .where((s) => !completed.contains(s))
        .toList();
    return OnboardingProgress(
      employeeId: current.employeeId,
      completedSteps: completed,
      currentStep:
          remaining.isEmpty ? OnboardingStep.activateAccount : remaining.first,
    );
  }

  static List<Employee> searchDirectory(
    List<Employee> source, {
    String? query,
    String? departmentId,
    String? teamId,
    String? roleSlug,
    StaffStatus? status,
    String? branchId,
  }) {
    final q = query?.trim().toLowerCase();
    final role = roleSlug?.trim().toLowerCase();
    return source.where((e) {
      if (departmentId != null && e.departmentId != departmentId) return false;
      if (teamId != null && e.teamId != teamId) return false;
      if (role != null &&
          role.isNotEmpty &&
          (e.roleSlug ?? '').toLowerCase() != role) {
        return false;
      }
      if (status != null && e.status != status) return false;
      if (branchId != null && e.branchId != branchId) return false;
      if (q != null && q.isNotEmpty) {
        final hay =
            '${e.displayName} ${e.email} ${e.employeeCode} ${e.phone} ${e.positionTitle} ${e.departmentName} ${e.teamName} ${e.roleSlug}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }
}
