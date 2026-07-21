import 'package:hdhomesproject/features/hcm/domain/entities/hcm_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads HR Command Center snapshot from Supabase (falls back to demo).
class HcmService {
  HcmService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<HcmCommandCenterSnapshot> loadCommandCenter() async {
    final demo = HcmDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<HcmEmployee> employees = demo.employees;
      try {
        final rows = await client.from('employees').select('''
              id, employee_code, display_employee_id, first_name, last_name,
              email, work_email, job_title, employment_type, employment_status,
              location_label, salary_grade, hire_date, joined_at,
              departments(name)
            ''').eq('is_deleted', false).order('updated_at', ascending: false).limit(100);
        if (rows.isNotEmpty) {
          employees = rows
              .map(
                (e) => HcmEmployee.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      if (employees.isEmpty) return demo;

      List<HcmVacancy> vacancies = demo.vacancies;
      try {
        final rows = await client
            .from('job_postings')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          vacancies = rows
              .map(
                (e) => HcmVacancy.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {
        try {
          final rows = await client
              .from('job_requisitions')
              .select()
              .order('updated_at', ascending: false)
              .limit(40);
          if (rows.isNotEmpty) {
            vacancies = rows
                .map(
                  (e) =>
                      HcmVacancy.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
          }
        } catch (_) {}
      }

      List<HcmApplicant> applicants = demo.applicants;
      try {
        final rows = await client
            .from('applicants')
            .select()
            .order('updated_at', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          applicants = rows
              .map(
                (e) =>
                    HcmApplicant.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<HcmAttendance> attendance = demo.attendance;
      try {
        final rows = await client
            .from('attendance_records')
            .select()
            .order('work_date', ascending: false)
            .limit(80);
        if (rows.isNotEmpty) {
          final byId = {for (final e in employees) e.id: e.fullName};
          attendance = rows.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            map['employee_name'] = byId[map['employee_id'] as String?];
            return HcmAttendance.fromJson(map);
          }).toList();
        }
      } catch (_) {}

      List<HcmLeaveRequest> leave = demo.leaveRequests;
      try {
        final rows = await client
            .from('leave_requests')
            .select()
            .order('created_at', ascending: false)
            .limit(60);
        if (rows.isNotEmpty) {
          final byId = {for (final e in employees) e.id: e.fullName};
          leave = rows.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            map['employee_name'] = byId[map['employee_id'] as String?];
            return HcmLeaveRequest.fromJson(map);
          }).toList();
        }
      } catch (_) {}

      List<HcmTraining> trainings = demo.trainings;
      try {
        final rows = await client.from('training_enrollments').select('''
              id, status, enrolled_at, employee_id,
              training_courses(title, code)
            ''').limit(40);
        if (rows.isNotEmpty) {
          final byId = {for (final e in employees) e.id: e.fullName};
          trainings = rows.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final course = map['training_courses'];
            if (course is Map) {
              map['course_title'] = course['title'];
              map['course_code'] = course['code'];
            }
            map['employee_name'] = byId[map['employee_id'] as String?];
            return HcmTraining.fromJson(map);
          }).toList();
        }
      } catch (_) {}

      List<HcmAsset> assets = demo.assets;
      try {
        final rows = await client
            .from('employee_assets')
            .select()
            .order('updated_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          final byId = {for (final e in employees) e.id: e.fullName};
          assets = rows.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            map['employee_name'] = byId[map['employee_id'] as String?];
            return HcmAsset.fromJson(map);
          }).toList();
        }
      } catch (_) {}

      List<HcmAnnouncement> announcements = demo.announcements;
      try {
        final rows = await client
            .from('hr_announcements')
            .select()
            .order('published_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          announcements = rows
              .map(
                (e) => HcmAnnouncement.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<HcmPerformanceCycle> cycles = demo.performanceCycles;
      try {
        final rows = await client
            .from('performance_cycles')
            .select()
            .order('starts_on', ascending: false)
            .limit(10);
        if (rows.isNotEmpty) {
          cycles = rows
              .map(
                (e) => HcmPerformanceCycle.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<HcmActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('hr_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) =>
                    HcmActivity.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<HcmAlert> alerts = demo.alerts;
      try {
        final rows = await client
            .from('hr_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        if (rows.isNotEmpty) {
          alerts = rows
              .map(
                (e) => HcmAlert.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      return HcmCommandCenterSnapshot(
        kpis: HcmDemo.aggregateKpis(
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
        activities: activities,
        alerts: alerts,
        aiInsights: demo.aiInsights,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  String generateTalentBriefing(HcmCommandCenterSnapshot snap) {
    final pending = snap.leaveRequests
        .where((l) => l.status == LeaveRequestStatus.pending)
        .length;
    final open = snap.vacancies.where((v) => v.status == 'open').length;
    final pipeline = snap.applicants.length;
    return 'AI Talent Intelligence briefing (editable / advisory)\n'
        '• Headcount ${snap.employees.length} · Open roles $open · Pipeline $pipeline\n'
        '• Pending leave approvals: $pending\n'
        '• ${snap.aiDisclaimer}';
  }

  static List<String> detectWorkforceSignals(HcmCommandCenterSnapshot snap) {
    final signals = <String>[];
    final late = snap.attendance
        .where((a) => a.status == AttendanceStatus.late)
        .length;
    if (late > 0) {
      signals.add('$late late clock-in(s) today — coach punctuality.');
    }
    final pending = snap.leaveRequests
        .where((l) => l.status == LeaveRequestStatus.pending)
        .length;
    if (pending > 0) {
      signals.add('$pending leave request(s) awaiting approval.');
    }
    final probation = snap.employees
        .where((e) => e.status == EmploymentStatus.probation)
        .length;
    if (probation > 0) {
      signals.add('$probation employee(s) on probation — confirm checkpoints.');
    }
    final interview = snap.applicants
        .where((a) => a.stage == ApplicantStage.interview)
        .length;
    if (interview > 0) {
      signals.add('$interview candidate(s) in interview — clear decision SLA.');
    }
    if (signals.isEmpty) {
      signals.add('Workforce signals stable — no urgent HR actions queued.');
    }
    return signals;
  }
}
