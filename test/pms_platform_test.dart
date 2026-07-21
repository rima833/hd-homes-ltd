import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/pms_service.dart';

void main() {
  group('PmsDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = PmsDemo.snapshot();
      expect(snap.properties.length, greaterThanOrEqualTo(4));
      expect(snap.kpis, isNotEmpty);
      expect(snap.inspections, isNotEmpty);
      expect(snap.lifecycle, isNotEmpty);
      expect(snap.approvalsPending, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.inventoryIntelligence, isNotEmpty);
      expect(snap.estateTwin.estateName, contains('Victoria Crest'));
      expect(snap.estateTwin.hierarchySample, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI formatting for NGN pipeline and score units', () {
      const pipeline = PmsInventoryKpi(
        label: 'Pipeline Value',
        value: 18500000,
        unit: 'ngn',
      );
      expect(pipeline.displayValue, contains('₦'));
      expect(pipeline.displayValue, contains('M'));

      const score = PmsInventoryKpi(
        label: 'Avg Performance Score',
        value: 82.5,
        unit: 'score',
      );
      expect(score.displayValue, '82.5');
    });

    test('wizard draft defaults are ready for step 0', () {
      const draft = PmsWizardDraft();
      expect(draft.step, 0);
      expect(draft.estateName, 'Victoria Crest');
      expect(draft.publishStatus, PublishWorkflowStatus.draft);
      expect(draft.inventoryStatus, InventoryStatus.available);
      expect(PmsWizardDraft.amenityCatalog, isNotEmpty);
    });

    test('aggregate KPIs count inventory statuses', () {
      final props = PmsDemo.snapshot().properties;
      final kpis = PmsDemo.aggregateKpis(props);
      expect(kpis.map((k) => k.label), containsAll([
        'Available',
        'Reserved',
        'Sold',
        'Under Contract',
        'Avg Performance Score',
        'Pipeline Value',
      ]));
      final available = kpis.firstWhere((k) => k.label == 'Available').value;
      expect(available, greaterThan(0));
    });
  });

  group('PmsService', () {
    test('offline client returns demo command center', () async {
      final service = PmsService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.properties, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(6));
    });

    test('generateAiSummary stub is informative', () {
      final service = PmsService();
      final property = PmsDemo.snapshot().properties.first;
      final summary = service.generateAiSummary(property);
      expect(summary, contains('AI summary'));
      expect(summary, contains(property.inventoryStatus.label.toLowerCase()));
    });

    test('computePerformanceScore clamps to 0–100', () {
      expect(
        PmsService.computePerformanceScore(
          demand: 100,
          conversion: 100,
          mediaQuality: 100,
          investorInterest: 100,
        ),
        100,
      );
      expect(
        PmsService.computePerformanceScore(demand: -10),
        0,
      );
    });
  });
}
