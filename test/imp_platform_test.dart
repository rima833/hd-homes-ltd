import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/domain/services/imp_service.dart';

void main() {
  group('ImpDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = ImpDemo.snapshot();
      expect(snap.investors.length, greaterThanOrEqualTo(3));
      expect(snap.opportunities, isNotEmpty);
      expect(snap.commitments, isNotEmpty);
      expect(snap.holdings, isNotEmpty);
      expect(snap.distributions, isNotEmpty);
      expect(snap.wallets, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes expected labels and formats', () {
      final snap = ImpDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'AUM',
          'Active Investors',
          'Capital Raised',
          'Upcoming Payouts',
          'Avg Investment',
          'Open Opportunities',
        ]),
      );

      const aum = ImpKpi(label: 'AUM', value: 1425000000, unit: 'ngn');
      expect(aum.displayValue, contains('₦'));
      expect(aum.displayValue, contains('B'));

      const capital =
          ImpKpi(label: 'Capital Raised', value: 96000000, unit: 'ngn');
      expect(capital.displayValue, contains('M'));
    });

    test('aggregate KPIs produce positive AUM and open opportunities', () {
      final snap = ImpDemo.snapshot();
      final kpis = ImpDemo.aggregateKpis(
        investors: snap.investors,
        opportunities: snap.opportunities,
        distributions: snap.distributions,
        commitments: snap.commitments,
      );
      final aum = kpis.firstWhere((k) => k.label == 'AUM').value;
      final open =
          kpis.firstWhere((k) => k.label == 'Open Opportunities').value;
      expect(aum, greaterThan(0));
      expect(open, greaterThan(0));
    });

    test('projected return disclaimer present on opportunities', () {
      final snap = ImpDemo.snapshot();
      expect(snap.opportunities, isNotEmpty);
      for (final opp in snap.opportunities) {
        expect(opp.returnDisclaimer.toLowerCase(), contains('estimate'));
        expect(opp.projectedReturnLabel.toLowerCase(), contains('est'));
      }
    });
  });

  group('ImpService', () {
    test('offline client returns demo command center', () async {
      final service = ImpService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.investors, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(6));
    });

    test('generatePortfolioSummary stub is informative', () {
      final service = ImpService();
      final investor = ImpDemo.snapshot().investors.first;
      final summary = service.generatePortfolioSummary(investor);
      expect(summary, contains('AI Investment summary'));
      expect(summary.toLowerCase(), contains('hnwi'));
      expect(summary, contains(investor.aumDisplay));
    });

    test('computePortfolioValue sums holdings', () {
      final snap = ImpDemo.snapshot();
      final total = ImpService.computePortfolioValue(snap.holdings);
      expect(total, greaterThan(0));
      expect(total, equals(78000000 + 275000000));
    });
  });
}
