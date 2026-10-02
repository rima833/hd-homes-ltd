import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';

void main() {
  group('Investor portal routes', () {
    test('all investor modules have route paths', () {
      expect(RoutePaths.investor, '/investor');
      expect(RoutePaths.investorPortfolio, '/investor/portfolio');
      expect(RoutePaths.investorAnalytics, '/investor/analytics');
      expect(RoutePaths.investorConstruction, '/investor/construction');
      expect(RoutePaths.investorReports, '/investor/reports');
      expect(RoutePaths.investorPayments, '/investor/payments');
      expect(RoutePaths.investorDocuments, '/investor/documents');
      expect(RoutePaths.investorReferrals, '/investor/referrals');
      expect(RoutePaths.investorMessages, '/investor/messages');
      expect(RoutePaths.investorNotifications, '/investor/notifications');
      expect(RoutePaths.investorSupport, '/investor/support');
      expect(RoutePaths.investorSettings, '/investor/settings');
      expect(RoutePaths.investorMore, '/investor/more');
      expect(RoutePaths.investorTools, '/investor/tools');
    });

    test('holding detail route is nested under portfolio', () {
      expect(
        RoutePaths.investorHoldingDetail('hold-456'),
        '/investor/portfolio/hold-456',
      );
    });
  });

  group('InvestorHolding model', () {
    test('parses nested property join', () {
      final holding = InvestorHolding.fromJson({
        'id': 'h-1',
        'portfolio_id': 'pf-1',
        'property_id': 'prop-1',
        'label': 'Fallback Label',
        'cost_basis': 50000000,
        'current_value': 62000000,
        'units': 2.5,
        'properties': {
          'title': 'Abuja Growth Fund',
          'slug': 'abuja-growth',
          'property_locations': [
            {'city': 'Abuja', 'state': 'FCT'},
          ],
          'property_images': [
            {'url': 'https://example.com/fund.jpg', 'is_cover': true},
          ],
        },
      });
      expect(holding.label, 'Abuja Growth Fund');
      expect(holding.location, 'Abuja, FCT');
      expect(holding.imageUrl, 'https://example.com/fund.jpg');
      expect(holding.formattedCurrentValue, contains('62'));
      expect(holding.gainLossPct, greaterThan(0));
    });

    test('falls back to holding label when join missing', () {
      final holding = InvestorHolding.fromJson({
        'id': 'h-2',
        'portfolio_id': 'pf-1',
        'label': 'Private Equity Tranche A',
        'cost_basis': 10000000,
        'current_value': 10500000,
      });
      expect(holding.label, 'Private Equity Tranche A');
      expect(holding.imageUrl, isNull);
    });
  });

  group('InvestorDashboardSnapshot', () {
    test('formats currency totals', () {
      const snap = InvestorDashboardSnapshot(
        investor: InvestorRecord(id: 'inv-1'),
        portfolioValue: 75000000,
        totalDistributions: 3500000,
        pendingDistributions: 500000,
      );
      expect(snap.formattedPortfolioValue, contains('75'));
      expect(snap.formattedTotalDistributions, contains('3'));
      expect(snap.formattedPendingDistributions, contains('500'));
    });
  });

  group('InvestorReferralSummary', () {
    test('defaults to empty state', () {
      const summary = InvestorReferralSummary();
      expect(summary.referralCode, '');
      expect(summary.pendingEarnings, 0);
      expect(summary.commissions, isEmpty);
    });
  });
}
