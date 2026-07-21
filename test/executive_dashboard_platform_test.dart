import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:hdhomesproject/features/dashboard/domain/services/executive_dashboard_service.dart';

void main() {
  group('ExecutiveDashboardDemo', () {
    test('snapshot exposes core Mission Control surfaces', () {
      final snap = ExecutiveDashboardDemo.snapshot();
      expect(snap.kpis.length, greaterThanOrEqualTo(10));
      expect(snap.health.overallScore, inInclusiveRange(0, 100));
      expect(snap.insights, isNotEmpty);
      expect(snap.activity, isNotEmpty);
      expect(snap.quickActions, isNotEmpty);
      expect(snap.reportTypes.any((r) => r.id == 'briefing'), isTrue);
      expect(snap.forecasts.every((f) => f.disclaimer.isNotEmpty), isTrue);
    });

    test('KPI display formats NGN values', () {
      const kpi = KpiCard(
        metricKey: 'revenue_today',
        label: "Today's Revenue",
        value: 18500000,
        unit: 'ngn',
      );
      expect(kpi.displayValue, contains('₦'));
      expect(kpi.displayValue, contains('M'));
    });

    test('quick actions honour required permissions', () {
      const action = QuickActionItem(
        id: 'x',
        label: 'Add',
        routeOrKey: '/dashboard/properties',
        requiredPermission: 'create_property',
      );
      expect(action.allowedFor({}), isFalse);
      expect(action.allowedFor({'create_property'}), isTrue);
    });
  });

  group('ExecutiveDashboardService', () {
    test('offline client returns demo briefing text', () {
      final service = ExecutiveDashboardService();
      final snap = ExecutiveDashboardDemo.snapshot();
      final briefing = service.buildBriefing(snap);
      expect(briefing, contains('Executive Briefing'));
      expect(briefing, contains('Health:'));
    });

    test('queueReport works without Supabase', () async {
      final service = ExecutiveDashboardService();
      final result = await service.queueReport(
        reportType: 'sales',
        format: 'pdf',
        userId: 'test',
      );
      expect(result['status'], 'ready');
      expect(result['format'], 'pdf');
    });
  });
}
