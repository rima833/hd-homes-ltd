import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/domain/services/crm_service.dart';

void main() {
  group('CrmDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = CrmDemo.snapshot();
      expect(snap.clients.length, greaterThanOrEqualTo(3));
      expect(snap.leads, isNotEmpty);
      expect(snap.tasks, isNotEmpty);
      expect(snap.appointments, isNotEmpty);
      expect(snap.timeline, isNotEmpty);
      expect(snap.stages, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.leadIntelligence, isNotEmpty);
      expect(snap.relationshipGraph, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes expected labels and formats', () {
      final snap = CrmDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'New Leads',
          'Pipeline Value',
          'Conversion Rate',
          'Tasks Due',
          'Avg Health',
          'Hot Leads',
        ]),
      );

      const pipeline = CrmKpi(
        label: 'Pipeline Value',
        value: 145000000,
        unit: 'ngn',
      );
      expect(pipeline.displayValue, contains('₦'));
      expect(pipeline.displayValue, contains('M'));

      const rate = CrmKpi(
        label: 'Conversion Rate',
        value: 68.5,
        unit: 'percent',
      );
      expect(rate.displayValue, '68.5%');
    });

    test('aggregate KPIs produce positive pipeline and hot leads', () {
      final snap = CrmDemo.snapshot();
      final kpis = CrmDemo.aggregateKpis(
        clients: snap.clients,
        leads: snap.leads,
        tasks: snap.tasks,
      );
      final pipeline =
          kpis.firstWhere((k) => k.label == 'Pipeline Value').value;
      final hot = kpis.firstWhere((k) => k.label == 'Hot Leads').value;
      expect(pipeline, greaterThan(0));
      expect(hot, greaterThan(0));
    });

    test('health labels map from score bands', () {
      expect(CrmHealthLabel.fromScore(95), CrmHealthLabel.vip);
      expect(CrmHealthLabel.fromScore(85), CrmHealthLabel.excellent);
      expect(CrmHealthLabel.fromScore(70), CrmHealthLabel.healthy);
      expect(CrmHealthLabel.fromScore(45), CrmHealthLabel.atRisk);
      expect(CrmHealthLabel.fromScore(10), CrmHealthLabel.critical);
    });
  });

  group('CrmService', () {
    test('offline client returns demo command center', () async {
      final service = CrmService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.clients, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(6));
    });

    test('generateClientSummary stub is informative', () {
      final service = CrmService();
      final client = CrmDemo.snapshot().clients.first;
      final summary = service.generateClientSummary(client);
      expect(summary, contains('AI CRM summary'));
      expect(summary.toLowerCase(), contains('vip'));
    });

    test('computeHealthScore clamps to 0–100', () {
      expect(
        CrmService.computeHealthScore(
          engagement: 100,
          recency: 100,
          pipeline: 100,
          referrals: 100,
        ),
        100,
      );
      expect(CrmService.computeHealthScore(engagement: -10), 0);
      expect(
        CrmService.labelForScore(92),
        CrmHealthLabel.vip,
      );
    });
  });
}
