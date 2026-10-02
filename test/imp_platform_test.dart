import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/domain/services/imp_service.dart';

void main() {
  group('ImpMetrics', () {
    test('KPI strip includes expected labels and formats', () {
      final kpis = ImpMetrics.aggregateKpis(
        investors: const [],
        opportunities: const [],
        distributions: const [],
        commitments: const [],
      );
      expect(
        kpis.map((k) => k.label),
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

      const capital = ImpKpi(
        label: 'Capital Raised',
        value: 96000000,
        unit: 'ngn',
      );
      expect(capital.displayValue, contains('M'));
    });

    test('aggregate KPIs use supplied records without synthetic fallback', () {
      const investors = [
        ImpInvestor(
          id: 'investor-1',
          investorCode: 'INV-1',
          fullName: 'Investor One',
          lifecycleStatus: InvestorLifecycleStatus.active,
          aum: 12000000,
        ),
      ];
      const opportunities = [
        ImpOpportunity(
          id: 'opportunity-1',
          code: 'OPP-1',
          title: 'Production opportunity',
          targetRaise: 10000000,
          amountRaised: 5000000,
        ),
      ];
      final kpis = ImpMetrics.aggregateKpis(
        investors: investors,
        opportunities: opportunities,
        distributions: const [],
        commitments: const [],
      );
      final aum = kpis.firstWhere((k) => k.label == 'AUM').value;
      final open = kpis
          .firstWhere((k) => k.label == 'Open Opportunities')
          .value;
      expect(aum, 12000000);
      expect(open, 1);
    });

    test('projected return disclaimer present on opportunities', () {
      const opportunity = ImpOpportunity(
        id: 'opportunity-1',
        code: 'OPP-1',
        title: 'Production opportunity',
        projectedReturnPct: 12,
      );
      expect(opportunity.returnDisclaimer.toLowerCase(), contains('estimate'));
      expect(opportunity.projectedReturnLabel.toLowerCase(), contains('est'));
    });
  });

  group('ImpService production behavior', () {
    test('offline client fails instead of returning fabricated data', () async {
      final service = ImpService();
      await expectLater(service.loadCommandCenter(), throwsStateError);
    });

    test('deferred AI summary does not fabricate advice', () {
      final service = ImpService();
      const investor = ImpInvestor(
        id: 'investor-1',
        investorCode: 'INV-1',
        fullName: 'Investor One',
      );
      final summary = service.generatePortfolioSummary(investor);
      expect(summary, isEmpty);
    });

    test('computePortfolioValue sums holdings', () {
      const holdings = [
        ImpHolding(
          id: 'holding-1',
          portfolioId: 'portfolio-1',
          label: 'Holding one',
          currentValue: 78000000,
        ),
        ImpHolding(
          id: 'holding-2',
          portfolioId: 'portfolio-1',
          label: 'Holding two',
          currentValue: 275000000,
        ),
      ];
      expect(
        ImpService.computePortfolioValue(holdings),
        equals(78000000 + 275000000),
      );
    });
  });
}
