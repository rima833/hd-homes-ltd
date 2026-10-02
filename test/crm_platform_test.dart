import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:hdhomesproject/features/crm/domain/services/crm_service.dart';

void main() {
  group('CrmDemo', () {
    test('snapshot is non-empty for offline fixture only', () {
      final snap = CrmDemo.snapshot();
      expect(snap.clients.length, greaterThanOrEqualTo(3));
      expect(snap.leads, isNotEmpty);
      expect(snap.tasks, isNotEmpty);
      expect(snap.stages, isNotEmpty);
      expect(snap.fromRemote, isFalse);
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
    test('offline client returns empty live snapshot (no demo mix)', () async {
      final service = CrmService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.clients, isEmpty);
      expect(snap.leads, isEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(6));
      expect(snap.inspections, isEmpty);
      expect(snap.applications, isEmpty);
    });

    test('clientSummary is operational', () {
      final service = CrmService();
      final client = CrmDemo.snapshot().clients.first;
      final summary = service.clientSummary(client);
      expect(summary.toLowerCase(), contains('budget'));
      expect(summary, isNot(contains('AI CRM summary')));
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
