import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/hcm/domain/entities/hcm_models.dart';
import 'package:hdhomesproject/features/hcm/domain/services/hcm_service.dart';
import 'package:hdhomesproject/features/hcm/presentation/providers/hcm_controller.dart';

void main() {
  group('HcmDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = HcmDemo.snapshot();
      expect(snap.employees.length, greaterThanOrEqualTo(3));
      expect(snap.vacancies, isNotEmpty);
      expect(snap.applicants, isNotEmpty);
      expect(snap.attendance, isNotEmpty);
      expect(snap.leaveRequests, isNotEmpty);
      expect(snap.trainings, isNotEmpty);
      expect(snap.assets, isNotEmpty);
      expect(snap.announcements, isNotEmpty);
      expect(snap.performanceCycles, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes workforce labels', () {
      final snap = HcmDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Headcount',
          'Open Roles',
          'Pipeline',
          'Present Today',
          'Pending Leave',
          'Late Rate',
          'In Training',
        ]),
      );
      expect(snap.employees.map((e) => e.jobTitle), containsAll([
        'People Operations Manager',
        'Sales Executive',
        'Site Supervisor',
      ]));
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = HcmDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('leave and recruitment pipeline statuses are present', () {
      final snap = HcmDemo.snapshot();
      expect(
        snap.leaveRequests.any((l) => l.status == LeaveRequestStatus.pending),
        isTrue,
      );
      expect(
        snap.applicants.any((a) => a.stage == ApplicantStage.interview),
        isTrue,
      );
      expect(
        snap.applicants.any((a) => a.stage == ApplicantStage.screening),
        isTrue,
      );
      expect(
        snap.attendance.any((a) => a.status == AttendanceStatus.late),
        isTrue,
      );
      expect(
        snap.vacancies.any((v) => v.status == 'open'),
        isTrue,
      );
    });
  });

  group('HcmService', () {
    test('offline client returns demo command center', () async {
      final service = HcmService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.employees, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
    });

    test('AI talent briefing stub includes disclaimer and pipeline', () {
      final service = HcmService();
      final snap = HcmDemo.snapshot();
      final briefing = service.generateTalentBriefing(snap);
      expect(briefing.toLowerCase(), contains('talent'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('pipeline'));
    });

    test('workforce signals flag leave and late attendance', () {
      final snap = HcmDemo.snapshot();
      final signals = HcmService.detectWorkforceSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('leave')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('late')),
        isTrue,
      );
    });
  });

  group('HcmController contract', () {
    test('tabs cover required command-center surfaces without state-in-build', () {
      expect(HcmCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'directory',
        'recruitment',
        'attendance',
        'leave',
        'performance',
        'training',
        'assets',
        'announcements',
        'ai',
      ]));
      const initial = HcmUiState();
      expect(initial.selectedTab, HcmCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
