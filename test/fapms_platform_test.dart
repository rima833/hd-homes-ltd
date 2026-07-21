import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hdhomesproject/features/fapms/domain/services/fapms_service.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';

void main() {
  group('FapmsDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = FapmsDemo.snapshot();
      expect(snap.invoices.length, greaterThanOrEqualTo(3));
      expect(snap.paymentTxs, isNotEmpty);
      expect(snap.expenses, isNotEmpty);
      expect(snap.budgets, isNotEmpty);
      expect(snap.budgetLines, isNotEmpty);
      expect(snap.budgetVariances, isNotEmpty);
      expect(snap.bankAccounts, isNotEmpty);
      expect(snap.bankTxs, isNotEmpty);
      expect(snap.journals, isNotEmpty);
      expect(snap.arRows, isNotEmpty);
      expect(snap.apRows, isNotEmpty);
      expect(snap.cashFlow, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes expected labels and formats money', () {
      final snap = FapmsDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Cash on Hand',
          'Open AR',
          'Open AP',
          'Overdue Invoices',
          'Gateway Captured',
          'Pending Approvals',
          'Invoice Volume',
          'Collections Health',
        ]),
      );

      const cash = FapmsKpi(label: 'Cash on Hand', value: 428500000, unit: 'ngn');
      expect(cash.displayValue, contains('₦'));
      expect(cash.displayValue, contains('M'));
    });

    test('cash flow projection disclaimer is present', () {
      final snap = FapmsDemo.snapshot();
      expect(
        snap.projectionDisclaimer.toUpperCase(),
        contains('PROJECTION'),
      );
      expect(snap.projectionDisclaimer.toLowerCase(), contains('estimate'));
      for (final point in snap.cashFlow) {
        expect(point.isProjection, isTrue);
        expect(point.disclaimer.toUpperCase(), contains('PROJECTION'));
      }
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('estimate'));
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('aging buckets roll up AR and AP rows', () {
      final snap = FapmsDemo.snapshot();
      expect(snap.arBuckets.length, AgingBucketKind.values.length);
      expect(snap.apBuckets.length, AgingBucketKind.values.length);

      final arTotal = snap.arBuckets.fold<double>(0, (s, b) => s + b.amount);
      final arRowsTotal =
          snap.arRows.fold<double>(0, (s, r) => s + r.amountDue);
      expect(arTotal, arRowsTotal);

      expect(
        snap.arBuckets.any((b) => b.kind == AgingBucketKind.d1_30 && b.count > 0),
        isTrue,
      );
      expect(
        snap.apBuckets.any((b) => b.kind == AgingBucketKind.d31_60 && b.count > 0),
        isTrue,
      );
    });
  });

  group('FapmsService', () {
    test('offline client returns demo command center', () async {
      final service = FapmsService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.invoices, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
    });

    test('AI financial briefing stub includes disclaimer and KPIs', () {
      final service = FapmsService();
      final snap = FapmsDemo.snapshot();
      final briefing = service.generateFinancialBriefing(snap);
      expect(briefing, contains('AI financial briefing'));
      expect(briefing.toUpperCase(), contains('PROJECTION'));
      expect(briefing.toLowerCase(), contains('overdue'));
    });

    test('anomaly detection flags overdue and budget watch items', () {
      final snap = FapmsDemo.snapshot();
      final anomalies = FapmsService.detectAnomalies(snap);
      expect(anomalies, isNotEmpty);
      expect(
        anomalies.any((a) => a.toLowerCase().contains('overdue')),
        isTrue,
      );
      expect(
        anomalies.any((a) => a.toLowerCase().contains('budget')),
        isTrue,
      );
    });
  });

  group('FapmsController contract', () {
    test('tabs cover required command-center surfaces without state-in-build', () {
      // Conceptual guard: tabs match deliverable; Notifier.build must return
      // initial FapmsUiState without reading `state` (see fapms_controller.dart).
      expect(FapmsCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'ledger',
        'ar',
        'ap',
        'invoices',
        'payments',
        'banking',
        'budgets',
        'expenses',
        'approvals',
        'ai',
      ]));
      const initial = FapmsUiState();
      expect(initial.selectedTab, FapmsCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
