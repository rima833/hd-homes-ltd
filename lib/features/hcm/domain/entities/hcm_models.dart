// Volume 4 Part 9 — Enterprise Human Capital Management (HCM) domain models.

const String kHcmAiDisclaimer =
    'AI-generated — editable / advisory. Talent insights are drafts for human '
    'review, not guarantees of hiring outcomes, attrition, or payroll results.';

enum EmploymentStatus {
  probation,
  confirmed,
  onLeave,
  suspended,
  terminated,
  active;

  String get label => switch (this) {
        EmploymentStatus.probation => 'Probation',
        EmploymentStatus.confirmed => 'Confirmed',
        EmploymentStatus.onLeave => 'On Leave',
        EmploymentStatus.suspended => 'Suspended',
        EmploymentStatus.terminated => 'Terminated',
        EmploymentStatus.active => 'Active',
      };

  String get slug => switch (this) {
        EmploymentStatus.onLeave => 'on_leave',
        _ => name,
      };

  static EmploymentStatus fromSlug(String? raw) {
    return switch ((raw ?? 'active').toLowerCase()) {
      'probation' => EmploymentStatus.probation,
      'confirmed' => EmploymentStatus.confirmed,
      'on_leave' || 'leave' => EmploymentStatus.onLeave,
      'suspended' => EmploymentStatus.suspended,
      'terminated' || 'exited' => EmploymentStatus.terminated,
      _ => EmploymentStatus.active,
    };
  }
}

enum ApplicantStage {
  applied,
  screening,
  interview,
  offer,
  hired,
  rejected,
  withdrawn;

  String get label => switch (this) {
        ApplicantStage.applied => 'Applied',
        ApplicantStage.screening => 'Screening',
        ApplicantStage.interview => 'Interview',
        ApplicantStage.offer => 'Offer',
        ApplicantStage.hired => 'Hired',
        ApplicantStage.rejected => 'Rejected',
        ApplicantStage.withdrawn => 'Withdrawn',
      };

  String get slug => name;

  static ApplicantStage fromSlug(String? raw) {
    return switch ((raw ?? 'applied').toLowerCase()) {
      'screening' => ApplicantStage.screening,
      'interview' => ApplicantStage.interview,
      'offer' => ApplicantStage.offer,
      'hired' => ApplicantStage.hired,
      'rejected' => ApplicantStage.rejected,
      'withdrawn' => ApplicantStage.withdrawn,
      _ => ApplicantStage.applied,
    };
  }
}

enum LeaveRequestStatus {
  draft,
  pending,
  approved,
  rejected,
  cancelled;

  String get label => switch (this) {
        LeaveRequestStatus.draft => 'Draft',
        LeaveRequestStatus.pending => 'Pending',
        LeaveRequestStatus.approved => 'Approved',
        LeaveRequestStatus.rejected => 'Rejected',
        LeaveRequestStatus.cancelled => 'Cancelled',
      };

  String get slug => name;

  static LeaveRequestStatus fromSlug(String? raw) {
    return switch ((raw ?? 'pending').toLowerCase()) {
      'draft' => LeaveRequestStatus.draft,
      'approved' => LeaveRequestStatus.approved,
      'rejected' => LeaveRequestStatus.rejected,
      'cancelled' || 'canceled' => LeaveRequestStatus.cancelled,
      _ => LeaveRequestStatus.pending,
    };
  }
}

enum AttendanceStatus {
  present,
  absent,
  late,
  remote,
  halfDay,
  onLeave,
  holiday;

  String get label => switch (this) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.late => 'Late',
        AttendanceStatus.remote => 'Remote',
        AttendanceStatus.halfDay => 'Half Day',
        AttendanceStatus.onLeave => 'On Leave',
        AttendanceStatus.holiday => 'Holiday',
      };

  String get slug => switch (this) {
        AttendanceStatus.halfDay => 'half_day',
        AttendanceStatus.onLeave => 'on_leave',
        _ => name,
      };

  static AttendanceStatus fromSlug(String? raw) {
    return switch ((raw ?? 'present').toLowerCase()) {
      'absent' => AttendanceStatus.absent,
      'late' => AttendanceStatus.late,
      'remote' => AttendanceStatus.remote,
      'half_day' || 'half-day' => AttendanceStatus.halfDay,
      'on_leave' => AttendanceStatus.onLeave,
      'holiday' => AttendanceStatus.holiday,
      _ => AttendanceStatus.present,
    };
  }
}

class HcmKpi {
  const HcmKpi({
    required this.label,
    required this.value,
    this.unit = 'count',
  });

  final String label;
  final double value;
  final String unit;

  String get displayValue {
    if (unit == 'percent') {
      return value == value.roundToDouble()
          ? '${value.toStringAsFixed(0)}%'
          : '${value.toStringAsFixed(1)}%';
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}

class HcmEmployee {
  const HcmEmployee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    this.displayEmployeeId,
    this.jobTitle,
    this.departmentName,
    this.email,
    this.employmentType = 'full_time',
    this.status = EmploymentStatus.active,
    this.locationLabel,
    this.salaryGrade,
    this.hireDate,
  });

  final String id;
  final String employeeCode;
  final String fullName;
  final String? displayEmployeeId;
  final String? jobTitle;
  final String? departmentName;
  final String? email;
  final String employmentType;
  final EmploymentStatus status;
  final String? locationLabel;
  final String? salaryGrade;
  final DateTime? hireDate;

  String get directoryLabel =>
      displayEmployeeId ?? employeeCode;

  factory HcmEmployee.fromJson(Map<String, dynamic> json) {
    final first = json['first_name'] as String? ?? '';
    final last = json['last_name'] as String? ?? '';
    final dept = json['departments'];
    String? deptName;
    if (dept is Map) {
      deptName = dept['name'] as String?;
    } else if (json['department_name'] != null) {
      deptName = json['department_name'] as String?;
    }
    return HcmEmployee(
      id: json['id'] as String,
      employeeCode: json['employee_code'] as String? ?? '',
      displayEmployeeId: json['display_employee_id'] as String?,
      fullName: ('$first $last').trim().isEmpty
          ? (json['full_name'] as String? ?? 'Unknown')
          : '$first $last'.trim(),
      jobTitle: json['job_title'] as String?,
      departmentName: deptName,
      email: json['email'] as String? ?? json['work_email'] as String?,
      employmentType: json['employment_type'] as String? ?? 'full_time',
      status: EmploymentStatus.fromSlug(json['employment_status'] as String?),
      locationLabel: json['location_label'] as String?,
      salaryGrade: json['salary_grade'] as String?,
      hireDate: DateTime.tryParse(
        json['hire_date'] as String? ?? json['joined_at'] as String? ?? '',
      ),
    );
  }
}

class HcmVacancy {
  const HcmVacancy({
    required this.id,
    required this.title,
    this.requisitionCode,
    this.departmentName,
    this.status = 'open',
    this.locationLabel,
    this.headcount = 1,
    this.channel,
  });

  final String id;
  final String title;
  final String? requisitionCode;
  final String? departmentName;
  final String status;
  final String? locationLabel;
  final int headcount;
  final String? channel;

  factory HcmVacancy.fromJson(Map<String, dynamic> json) {
    return HcmVacancy(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Vacancy',
      requisitionCode: json['requisition_code'] as String?,
      departmentName: json['department_name'] as String?,
      status: json['status'] as String? ?? 'open',
      locationLabel: json['location_label'] as String?,
      headcount: (json['headcount'] as num?)?.toInt() ?? 1,
      channel: json['channel'] as String?,
    );
  }
}

class HcmApplicant {
  const HcmApplicant({
    required this.id,
    required this.fullName,
    this.email,
    this.stage = ApplicantStage.applied,
    this.source,
    this.score,
    this.postingTitle,
  });

  final String id;
  final String fullName;
  final String? email;
  final ApplicantStage stage;
  final String? source;
  final double? score;
  final String? postingTitle;

  factory HcmApplicant.fromJson(Map<String, dynamic> json) {
    return HcmApplicant(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Applicant',
      email: json['email'] as String?,
      stage: ApplicantStage.fromSlug(json['stage'] as String?),
      source: json['source'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      postingTitle: json['posting_title'] as String?,
    );
  }
}

class HcmAttendance {
  const HcmAttendance({
    required this.id,
    required this.employeeId,
    required this.workDate,
    this.employeeName,
    this.status = AttendanceStatus.present,
    this.clockInAt,
    this.clockOutAt,
  });

  final String id;
  final String employeeId;
  final DateTime workDate;
  final String? employeeName;
  final AttendanceStatus status;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;

  factory HcmAttendance.fromJson(Map<String, dynamic> json) {
    return HcmAttendance(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String?,
      workDate: DateTime.tryParse(json['work_date'] as String? ?? '') ??
          DateTime.now(),
      status: AttendanceStatus.fromSlug(json['status'] as String?),
      clockInAt: DateTime.tryParse(json['clock_in_at'] as String? ?? ''),
      clockOutAt: DateTime.tryParse(json['clock_out_at'] as String? ?? ''),
    );
  }
}

class HcmLeaveRequest {
  const HcmLeaveRequest({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.leaveType = 'annual',
    required this.startsOn,
    required this.endsOn,
    this.daysCount = 1,
    this.status = LeaveRequestStatus.pending,
    this.reason,
  });

  final String id;
  final String employeeId;
  final String? employeeName;
  final String leaveType;
  final DateTime startsOn;
  final DateTime endsOn;
  final double daysCount;
  final LeaveRequestStatus status;
  final String? reason;

  factory HcmLeaveRequest.fromJson(Map<String, dynamic> json) {
    return HcmLeaveRequest(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String? ?? '',
      employeeName: json['employee_name'] as String?,
      leaveType: json['leave_type'] as String? ?? 'annual',
      startsOn: DateTime.tryParse(json['starts_on'] as String? ?? '') ??
          DateTime.now(),
      endsOn: DateTime.tryParse(json['ends_on'] as String? ?? '') ??
          DateTime.now(),
      daysCount: (json['days_count'] as num?)?.toDouble() ?? 1,
      status: LeaveRequestStatus.fromSlug(json['status'] as String?),
      reason: json['reason'] as String?,
    );
  }
}

class HcmTraining {
  const HcmTraining({
    required this.id,
    required this.courseTitle,
    this.courseCode,
    this.employeeName,
    this.status = 'enrolled',
    this.enrolledAt,
  });

  final String id;
  final String courseTitle;
  final String? courseCode;
  final String? employeeName;
  final String status;
  final DateTime? enrolledAt;

  factory HcmTraining.fromJson(Map<String, dynamic> json) {
    return HcmTraining(
      id: json['id'] as String,
      courseTitle: json['course_title'] as String? ??
          json['title'] as String? ??
          'Course',
      courseCode: json['course_code'] as String? ?? json['code'] as String?,
      employeeName: json['employee_name'] as String?,
      status: json['status'] as String? ?? 'enrolled',
      enrolledAt: DateTime.tryParse(json['enrolled_at'] as String? ?? ''),
    );
  }
}

class HcmAsset {
  const HcmAsset({
    required this.id,
    required this.assetTag,
    required this.name,
    this.assetType = 'device',
    this.employeeName,
    this.status = 'assigned',
  });

  final String id;
  final String assetTag;
  final String name;
  final String assetType;
  final String? employeeName;
  final String status;

  factory HcmAsset.fromJson(Map<String, dynamic> json) {
    return HcmAsset(
      id: json['id'] as String,
      assetTag: json['asset_tag'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetType: json['asset_type'] as String? ?? 'device',
      employeeName: json['employee_name'] as String?,
      status: json['status'] as String? ?? 'assigned',
    );
  }
}

class HcmAnnouncement {
  const HcmAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.audience = 'all_staff',
    this.status = 'published',
    this.publishedAt,
    this.authorLabel,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final String status;
  final DateTime? publishedAt;
  final String? authorLabel;

  factory HcmAnnouncement.fromJson(Map<String, dynamic> json) {
    return HcmAnnouncement(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      audience: json['audience'] as String? ?? 'all_staff',
      status: json['status'] as String? ?? 'published',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      authorLabel: json['author_label'] as String?,
    );
  }
}

class HcmAiInsight {
  const HcmAiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'talent',
    this.confidencePct,
    this.disclaimer = kHcmAiDisclaimer,
    this.editable = true,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final double? confidencePct;
  final String disclaimer;
  final bool editable;
}

class HcmActivity {
  const HcmActivity({
    required this.id,
    required this.summary,
    this.action = '',
    this.actorLabel,
    this.occurredAt,
  });

  final String id;
  final String summary;
  final String action;
  final String? actorLabel;
  final DateTime? occurredAt;

  factory HcmActivity.fromJson(Map<String, dynamic> json) {
    return HcmActivity(
      id: json['id'] as String,
      summary: json['summary'] as String? ?? '',
      action: json['action'] as String? ?? '',
      actorLabel: json['actor_label'] as String?,
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? ''),
    );
  }
}

class HcmAlert {
  const HcmAlert({
    required this.id,
    required this.title,
    this.body,
    this.severity = 'info',
    this.category,
  });

  final String id;
  final String title;
  final String? body;
  final String severity;
  final String? category;

  factory HcmAlert.fromJson(Map<String, dynamic> json) {
    return HcmAlert(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      severity: json['severity'] as String? ?? 'info',
      category: json['category'] as String?,
    );
  }
}

class HcmPerformanceCycle {
  const HcmPerformanceCycle({
    required this.id,
    required this.name,
    this.status = 'active',
    this.startsOn,
    this.endsOn,
  });

  final String id;
  final String name;
  final String status;
  final DateTime? startsOn;
  final DateTime? endsOn;

  factory HcmPerformanceCycle.fromJson(Map<String, dynamic> json) {
    return HcmPerformanceCycle(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Cycle',
      status: json['status'] as String? ?? 'active',
      startsOn: DateTime.tryParse(json['starts_on'] as String? ?? ''),
      endsOn: DateTime.tryParse(json['ends_on'] as String? ?? ''),
    );
  }
}

class HcmCommandCenterSnapshot {
  const HcmCommandCenterSnapshot({
    required this.kpis,
    required this.employees,
    required this.vacancies,
    required this.applicants,
    required this.attendance,
    required this.leaveRequests,
    required this.trainings,
    required this.assets,
    required this.announcements,
    required this.performanceCycles,
    required this.activities,
    required this.alerts,
    required this.aiInsights,
    this.fromRemote = false,
    this.loadedAt,
    this.aiDisclaimer = kHcmAiDisclaimer,
  });

  final List<HcmKpi> kpis;
  final List<HcmEmployee> employees;
  final List<HcmVacancy> vacancies;
  final List<HcmApplicant> applicants;
  final List<HcmAttendance> attendance;
  final List<HcmLeaveRequest> leaveRequests;
  final List<HcmTraining> trainings;
  final List<HcmAsset> assets;
  final List<HcmAnnouncement> announcements;
  final List<HcmPerformanceCycle> performanceCycles;
  final List<HcmActivity> activities;
  final List<HcmAlert> alerts;
  final List<HcmAiInsight> aiInsights;
  final bool fromRemote;
  final DateTime? loadedAt;
  final String aiDisclaimer;
}

abstract final class HcmDemo {
  static HcmCommandCenterSnapshot snapshot() {
    final now = DateTime.now();
    final employees = _employees(now);
    final vacancies = _vacancies();
    final applicants = _applicants();
    final attendance = _attendance(now, employees);
    final leave = _leave(now, employees);
    final trainings = _trainings(now, employees);
    final assets = _assets(employees);
    final announcements = _announcements(now);
    final cycles = _cycles();
    return HcmCommandCenterSnapshot(
      kpis: aggregateKpis(
        employees: employees,
        vacancies: vacancies,
        applicants: applicants,
        attendance: attendance,
        leaveRequests: leave,
        trainings: trainings,
      ),
      employees: employees,
      vacancies: vacancies,
      applicants: applicants,
      attendance: attendance,
      leaveRequests: leave,
      trainings: trainings,
      assets: assets,
      announcements: announcements,
      performanceCycles: cycles,
      activities: _activities(now),
      alerts: _alerts(),
      aiInsights: _aiInsights(),
      fromRemote: false,
      loadedAt: now,
    );
  }

  static List<HcmKpi> aggregateKpis({
    required List<HcmEmployee> employees,
    required List<HcmVacancy> vacancies,
    required List<HcmApplicant> applicants,
    required List<HcmAttendance> attendance,
    required List<HcmLeaveRequest> leaveRequests,
    required List<HcmTraining> trainings,
  }) {
    final headcount = employees.length.toDouble();
    final openRoles =
        vacancies.where((v) => v.status == 'open').length.toDouble();
    final pipeline = applicants
        .where(
          (a) =>
              a.stage != ApplicantStage.rejected &&
              a.stage != ApplicantStage.withdrawn,
        )
        .length
        .toDouble();
    final presentToday = attendance
        .where(
          (a) =>
              a.status == AttendanceStatus.present ||
              a.status == AttendanceStatus.late ||
              a.status == AttendanceStatus.remote,
        )
        .length
        .toDouble();
    final pendingLeave = leaveRequests
        .where((l) => l.status == LeaveRequestStatus.pending)
        .length
        .toDouble();
    final lateRate = attendance.isEmpty
        ? 0.0
        : (attendance.where((a) => a.status == AttendanceStatus.late).length /
                attendance.length) *
            100;
    final inTraining =
        trainings.where((t) => t.status != 'completed').length.toDouble();

    return [
      HcmKpi(label: 'Headcount', value: headcount),
      HcmKpi(label: 'Open Roles', value: openRoles),
      HcmKpi(label: 'Pipeline', value: pipeline),
      HcmKpi(label: 'Present Today', value: presentToday),
      HcmKpi(label: 'Pending Leave', value: pendingLeave),
      HcmKpi(label: 'Late Rate', value: lateRate, unit: 'percent'),
      HcmKpi(label: 'In Training', value: inTraining),
      HcmKpi(
        label: 'Probation',
        value: employees
            .where((e) => e.status == EmploymentStatus.probation)
            .length
            .toDouble(),
      ),
    ];
  }

  static List<HcmEmployee> _employees(DateTime now) => [
        HcmEmployee(
          id: 'a9100001-0000-4000-8000-000000000001',
          employeeCode: 'HDH-EMP-1001',
          displayEmployeeId: 'EMP-1001',
          fullName: 'Amaka Okoro',
          jobTitle: 'People Operations Manager',
          departmentName: 'Human Resources',
          email: 'amaka.okoro@hdhomes.demo',
          status: EmploymentStatus.confirmed,
          locationLabel: 'Lagos HQ',
          salaryGrade: 'G6',
          hireDate: DateTime(2022, 3, 1),
        ),
        HcmEmployee(
          id: 'a9100001-0000-4000-8000-000000000002',
          employeeCode: 'HDH-EMP-1002',
          displayEmployeeId: 'EMP-1002',
          fullName: 'Tunde Adewale',
          jobTitle: 'Sales Executive',
          departmentName: 'Sales & Marketing',
          email: 'tunde.adewale@hdhomes.demo',
          status: EmploymentStatus.confirmed,
          locationLabel: 'Lagos HQ',
          salaryGrade: 'G4',
          hireDate: DateTime(2023, 6, 15),
        ),
        HcmEmployee(
          id: 'a9100001-0000-4000-8000-000000000003',
          employeeCode: 'HDH-EMP-1003',
          displayEmployeeId: 'EMP-1003',
          fullName: 'Chinedu Eze',
          jobTitle: 'Site Supervisor',
          departmentName: 'Construction & Operations',
          email: 'chinedu.eze@hdhomes.demo',
          status: EmploymentStatus.probation,
          locationLabel: 'Ikeja Site',
          salaryGrade: 'G5',
          hireDate: DateTime(2025, 11, 1),
        ),
      ];

  static List<HcmVacancy> _vacancies() => const [
        HcmVacancy(
          id: 'a9100004-0000-4000-8000-000000000002',
          title: 'Digital Marketing Specialist — HD Homes',
          requisitionCode: 'REQ-2026-014',
          departmentName: 'Sales & Marketing',
          status: 'open',
          locationLabel: 'Lagos HQ',
          channel: 'careers_site',
        ),
      ];

  static List<HcmApplicant> _applicants() => const [
        HcmApplicant(
          id: 'a9100005-0000-4000-8000-000000000001',
          fullName: 'Fatima Bello',
          email: 'fatima.bello@example.com',
          stage: ApplicantStage.screening,
          source: 'linkedin',
          score: 78,
          postingTitle: 'Digital Marketing Specialist',
        ),
        HcmApplicant(
          id: 'a9100005-0000-4000-8000-000000000002',
          fullName: 'Ibrahim Yusuf',
          email: 'ibrahim.yusuf@example.com',
          stage: ApplicantStage.interview,
          source: 'referral',
          score: 84,
          postingTitle: 'Digital Marketing Specialist',
        ),
      ];

  static List<HcmAttendance> _attendance(
    DateTime now,
    List<HcmEmployee> employees,
  ) {
    final day = DateTime(now.year, now.month, now.day);
    return [
      HcmAttendance(
        id: 'a9100006-0000-4000-8000-000000000001',
        employeeId: employees[0].id,
        employeeName: employees[0].fullName,
        workDate: day,
        status: AttendanceStatus.present,
        clockInAt: day.add(const Duration(hours: 8, minutes: 5)),
      ),
      HcmAttendance(
        id: 'a9100006-0000-4000-8000-000000000002',
        employeeId: employees[1].id,
        employeeName: employees[1].fullName,
        workDate: day,
        status: AttendanceStatus.late,
        clockInAt: day.add(const Duration(hours: 8, minutes: 22)),
      ),
      HcmAttendance(
        id: 'a9100006-0000-4000-8000-000000000003',
        employeeId: employees[2].id,
        employeeName: employees[2].fullName,
        workDate: day,
        status: AttendanceStatus.present,
        clockInAt: day.add(const Duration(hours: 7, minutes: 5)),
      ),
    ];
  }

  static List<HcmLeaveRequest> _leave(
    DateTime now,
    List<HcmEmployee> employees,
  ) =>
      [
        HcmLeaveRequest(
          id: 'a9100007-0000-4000-8000-000000000011',
          employeeId: employees[1].id,
          employeeName: employees[1].fullName,
          leaveType: 'annual',
          startsOn: now.add(const Duration(days: 10)),
          endsOn: now.add(const Duration(days: 11)),
          daysCount: 2,
          status: LeaveRequestStatus.pending,
          reason: 'Family event',
        ),
      ];

  static List<HcmTraining> _trainings(
    DateTime now,
    List<HcmEmployee> employees,
  ) =>
      [
        HcmTraining(
          id: 'a9100009-0000-4000-8000-000000000011',
          courseTitle: 'Site HSE Essentials',
          courseCode: 'TRN-HSE-101',
          employeeName: employees[2].fullName,
          status: 'in_progress',
          enrolledAt: now.subtract(const Duration(days: 3)),
        ),
      ];

  static List<HcmAsset> _assets(List<HcmEmployee> employees) => [
        HcmAsset(
          id: 'a910000a-0000-4000-8000-000000000001',
          assetTag: 'HDH-LAP-2048',
          name: 'Dell Latitude 5540',
          assetType: 'laptop',
          employeeName: employees[1].fullName,
          status: 'assigned',
        ),
      ];

  static List<HcmAnnouncement> _announcements(DateTime now) => [
        HcmAnnouncement(
          id: 'a910000c-0000-4000-8000-000000000001',
          title: 'Q3 People Town Hall',
          body:
              'Join the workforce briefing on Friday at 10:00 WAT covering performance cycle timelines.',
          audience: 'all_staff',
          status: 'published',
          publishedAt: now,
          authorLabel: 'People Ops',
        ),
      ];

  static List<HcmPerformanceCycle> _cycles() => [
        HcmPerformanceCycle(
          id: 'a9100008-0000-4000-8000-000000000001',
          name: 'H2 2026 Performance Cycle',
          status: 'active',
          startsOn: DateTime(2026, 7, 1),
          endsOn: DateTime(2026, 12, 31),
        ),
      ];

  static List<HcmActivity> _activities(DateTime now) => [
        HcmActivity(
          id: 'a910000d-0000-4000-8000-000000000001',
          action: 'leave.request',
          summary: 'Leave request pending for Tunde Adewale (2 days annual)',
          actorLabel: 'System',
          occurredAt: now.subtract(const Duration(hours: 2)),
        ),
        HcmActivity(
          id: 'a910000d-0000-4000-8000-000000000002',
          action: 'recruitment.applicant',
          summary: 'Ibrahim Yusuf moved to interview stage',
          actorLabel: 'Amaka Okoro',
          occurredAt: now.subtract(const Duration(hours: 5)),
        ),
      ];

  static List<HcmAlert> _alerts() => const [
        HcmAlert(
          id: 'a910000e-0000-4000-8000-000000000001',
          title: 'Leave approval needed',
          body: '1 pending leave request requires manager action.',
          severity: 'warning',
          category: 'leave',
        ),
        HcmAlert(
          id: 'alert-probation',
          title: 'Probation checkpoint',
          body: 'Chinedu Eze is in probation — schedule confirmation review.',
          severity: 'info',
          category: 'employees',
        ),
      ];

  static List<HcmAiInsight> _aiInsights() => const [
        HcmAiInsight(
          id: 'ai-attrition',
          title: 'Attrition watch — sales bench',
          body:
              'Sales tenure mix suggests moderate flight risk if Q3 commission acceleration slips. Advisory only.',
          category: 'attrition',
          confidencePct: 62,
        ),
        HcmAiInsight(
          id: 'ai-hiring',
          title: 'Hiring funnel velocity',
          body:
              'Interview stage density is healthy for REQ-2026-014; prioritize completion within 10 days.',
          category: 'recruitment',
          confidencePct: 71,
        ),
        HcmAiInsight(
          id: 'ai-capacity',
          title: 'Site capacity signal',
          body:
              'Construction attendance is strong; training completion for HSE will unlock overtime eligibility.',
          category: 'workforce',
          confidencePct: 58,
        ),
      ];
}
