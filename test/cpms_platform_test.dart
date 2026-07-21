import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/domain/services/cpms_service.dart';

void main() {
  group('CpmsDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = CpmsDemo.snapshot();
      expect(snap.projects.length, greaterThanOrEqualTo(3));
      expect(snap.milestones, isNotEmpty);
      expect(snap.tasks, isNotEmpty);
      expect(snap.contractors, isNotEmpty);
      expect(snap.procurementRequests, isNotEmpty);
      expect(snap.changeOrders, isNotEmpty);
      expect(snap.budgetLines, isNotEmpty);
      expect(snap.qualityChecks, isNotEmpty);
      expect(snap.defects, isNotEmpty);
      expect(snap.safetyIncidents, isNotEmpty);
      expect(snap.siteDiaries, isNotEmpty);
      expect(snap.inspections, isNotEmpty);
      expect(snap.risks, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.progressIntelligence, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes expected labels and formats', () {
      final snap = CpmsDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Active Projects',
          'Avg Progress',
          'Delayed Sites',
          'Open Milestones',
          'Blocked Tasks',
          'Pending Change Orders',
          'Open Defects',
          'Open Safety Items',
          'Portfolio Budget',
        ]),
      );

      const budget =
          CpmsKpi(label: 'Portfolio Budget', value: 1850000000, unit: 'ngn');
      expect(budget.displayValue, contains('₦'));
      expect(budget.displayValue, contains('B'));
    });

    test('forecast disclaimer present on projects and snapshot', () {
      final snap = CpmsDemo.snapshot();
      expect(snap.forecastDisclaimer.toLowerCase(), contains('estimate'));
      for (final p in snap.projects) {
        expect(p.forecastDisclaimer.toLowerCase(), contains('estimate'));
      }
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('estimate'));
        expect(insight.confidencePct, isNotNull);
      }
    });
  });

  group('CpmsService', () {
    test('offline client returns demo command center', () async {
      final service = CpmsService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.projects, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
    });

    test('generateProgressSummary stub is informative', () {
      final service = CpmsService();
      final project = CpmsDemo.snapshot().projects.first;
      final summary = service.generateProgressSummary(project);
      expect(summary, contains('AI progress summary'));
      expect(summary, contains(project.name));
      expect(summary.toLowerCase(), contains('estimate'));
    });

    test('delay detection flags on_hold / slipped sites', () {
      final snap = CpmsDemo.snapshot();
      final delayed = CpmsService.detectDelayedProjects(snap.projects);
      expect(delayed, isNotEmpty);
      expect(
        delayed.any((p) => p.projectCode == 'CPMS-AJ-RD'),
        isTrue,
      );
      expect(delayed.first.delayDays, greaterThan(0));
    });
  });

  group('CpmsWizardDraft', () {
    test('wizard has seven steps and navigates within bounds', () {
      var draft = const CpmsWizardDraft();
      expect(draft.totalSteps, 7);
      expect(CpmsWizardDraft.stepTitles.length, 7);
      expect(draft.currentStepTitle, 'Basics');

      for (var i = 0; i < 6; i++) {
        draft = draft.next();
      }
      expect(draft.step, 6);
      expect(draft.currentStepTitle, 'Review');
      expect(draft.isComplete, isTrue);

      draft = draft.next();
      expect(draft.step, 6);

      draft = draft.previous();
      expect(draft.step, 5);
      expect(draft.currentStepTitle, 'Contractors');
    });
  });
}
