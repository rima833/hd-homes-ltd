import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';

void main() {
  group('ImpMetrics', () {
    test('derives command-center KPIs from supplied live records only', () {
      const investors = [
        ImpInvestor(
          id: 'investor-1',
          investorCode: 'INV-1',
          fullName: 'Investor One',
          lifecycleStatus: InvestorLifecycleStatus.active,
          aum: 12000000,
        ),
        ImpInvestor(
          id: 'investor-2',
          investorCode: 'INV-2',
          fullName: 'Investor Two',
          lifecycleStatus: InvestorLifecycleStatus.prospect,
          aum: 3000000,
        ),
      ];
      const opportunities = [
        ImpOpportunity(
          id: 'opportunity-1',
          code: 'OPP-1',
          title: 'Live opportunity',
          amountRaised: 5000000,
          targetRaise: 10000000,
        ),
      ];
      const commitments = [
        ImpCommitment(
          id: 'commitment-1',
          investorId: 'investor-1',
          opportunityId: 'opportunity-1',
          amount: 4000000,
        ),
      ];
      final distributions = [
        ImpDistribution(
          id: 'distribution-1',
          investorId: 'investor-1',
          amount: 250000,
          status: DistributionStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30),
        ),
      ];

      final byLabel = {
        for (final kpi in ImpMetrics.aggregateKpis(
          investors: investors,
          opportunities: opportunities,
          distributions: distributions,
          commitments: commitments,
        ))
          kpi.label: kpi.value,
      };

      expect(byLabel['AUM'], 15000000);
      expect(byLabel['Active Investors'], 1);
      expect(byLabel['Capital Raised'], 5000000);
      expect(byLabel['Upcoming Payouts'], 250000);
      expect(byLabel['Avg Investment'], 4000000);
      expect(byLabel['Open Opportunities'], 1);
    });

    test('returns honest zero values for an empty live workspace', () {
      final kpis = ImpMetrics.aggregateKpis(
        investors: const [],
        opportunities: const [],
        distributions: const [],
        commitments: const [],
      );

      expect(kpis, hasLength(6));
      expect(kpis.every((kpi) => kpi.value == 0), isTrue);
      expect(ImpMetrics.computePortfolioValue(const []), 0);
    });
  });
}
