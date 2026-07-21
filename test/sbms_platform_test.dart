import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/sbms/domain/entities/sbms_models.dart';
import 'package:hdhomesproject/features/sbms/domain/services/sbms_service.dart';

void main() {
  group('SbmsDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = SbmsDemo.snapshot();
      expect(snap.deals.length, greaterThanOrEqualTo(2));
      expect(snap.stages, isNotEmpty);
      expect(snap.reservations, isNotEmpty);
      expect(snap.bookings, isNotEmpty);
      expect(snap.quotes, isNotEmpty);
      expect(snap.negotiations, isNotEmpty);
      expect(snap.contracts, isNotEmpty);
      expect(snap.installments, isNotEmpty);
      expect(snap.commissions, isNotEmpty);
      expect(snap.handovers, isNotEmpty);
      expect(snap.discountRequests, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.alerts, isNotEmpty);
      expect(snap.leaderboard, isNotEmpty);
      expect(snap.kpis, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.dealIntelligence, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes expected labels and formats', () {
      final snap = SbmsDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Total Sales',
          'Today Revenue',
          'Month Revenue',
          'Pending Reservations',
          'Active Negotiations',
          'Contracts Awaiting Signature',
          'Installments Due',
          'Pipeline Value',
        ]),
      );

      const total = SbmsKpi(label: 'Total Sales', value: 210000000, unit: 'ngn');
      expect(total.displayValue, contains('₦'));
      expect(total.displayValue, contains('M'));
    });

    test('aggregate KPIs produce positive pipeline and negotiations', () {
      final snap = SbmsDemo.snapshot();
      final kpis = SbmsDemo.aggregateKpis(
        deals: snap.deals,
        reservations: snap.reservations,
        contracts: snap.contracts,
        installments: snap.installments,
      );
      final pipeline =
          kpis.firstWhere((k) => k.label == 'Pipeline Value').value;
      final negotiations =
          kpis.firstWhere((k) => k.label == 'Active Negotiations').value;
      expect(pipeline, greaterThan(0));
      expect(negotiations, greaterThan(0));
    });

    test('quote and forecast estimate disclaimers present', () {
      final snap = SbmsDemo.snapshot();
      expect(snap.quotes, isNotEmpty);
      for (final q in snap.quotes) {
        expect(q.estimateDisclaimer.toLowerCase(), contains('estimate'));
      }
      expect(snap.forecastDisclaimer.toLowerCase(), contains('estimate'));
    });
  });

  group('SbmsService', () {
    test('offline client returns demo command center', () async {
      final service = SbmsService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.deals, isNotEmpty);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
    });

    test('generateDealSummary stub is informative', () {
      final service = SbmsService();
      final deal = SbmsDemo.snapshot().deals.first;
      final summary = service.generateDealSummary(deal);
      expect(summary, contains('AI Sales summary'));
      expect(summary, contains(deal.valueDisplay));
      expect(summary.toLowerCase(), contains('negotiation'));
    });

    test('reservation expiry semantics flag expiring-soon holds', () {
      final snap = SbmsDemo.snapshot();
      final expiring = snap.reservations
          .where((r) => r.reservationCode == 'RSV-EXP-001')
          .first;
      expect(expiring.status, ReservationStatus.reserved);
      expect(expiring.isExpiringSoon, isTrue);
      expect(expiring.isExpired, isFalse);

      final confirmed = snap.reservations
          .where((r) => r.reservationCode == 'RSV-CFM-002')
          .first;
      expect(confirmed.status, ReservationStatus.confirmed);
      expect(confirmed.isExpiringSoon, isFalse);

      final pipeline = SbmsService.computePipelineValue(snap.deals);
      expect(pipeline, greaterThan(0));
    });
  });
}
