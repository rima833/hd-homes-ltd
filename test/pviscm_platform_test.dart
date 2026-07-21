import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/pviscm/domain/entities/pviscm_models.dart';
import 'package:hdhomesproject/features/pviscm/domain/services/pviscm_service.dart';
import 'package:hdhomesproject/features/pviscm/presentation/providers/pviscm_controller.dart';

void main() {
  group('PviscmDemo', () {
    test('snapshot is non-empty across command-center surfaces', () {
      final snap = PviscmDemo.snapshot();
      expect(snap.kpis, isNotEmpty);
      expect(snap.vendors, isNotEmpty);
      expect(snap.requisitions, isNotEmpty);
      expect(snap.rfqs, isNotEmpty);
      expect(snap.purchaseOrders, isNotEmpty);
      expect(snap.goodsReceipts, isNotEmpty);
      expect(snap.inventory, isNotEmpty);
      expect(snap.warehouses, isNotEmpty);
      expect(snap.shipments, isNotEmpty);
      expect(snap.approvals, isNotEmpty);
      expect(snap.aiInsights, isNotEmpty);
      expect(snap.activities, isNotEmpty);
      expect(snap.reports, isNotEmpty);
      expect(snap.fromRemote, isFalse);
    });

    test('KPI strip includes procurement command-center labels', () {
      final snap = PviscmDemo.snapshot();
      expect(
        snap.kpis.map((k) => k.label),
        containsAll([
          'Open PRs',
          'Active Vendors',
          'Open POs',
          'Low Stock',
          'In Transit',
          'Pending Approvals',
          'Open Spend',
        ]),
      );
    });

    test('AI insights carry editable advisory disclaimer', () {
      final snap = PviscmDemo.snapshot();
      expect(snap.aiDisclaimer.toLowerCase(), contains('ai-generated'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('editable'));
      expect(snap.aiDisclaimer.toLowerCase(), contains('advisory'));
      for (final insight in snap.aiInsights) {
        expect(insight.disclaimer.toLowerCase(), contains('ai-generated'));
        expect(insight.editable, isTrue);
        expect(insight.confidencePct, isNotNull);
      }
    });

    test('procurement chain spans PR RFQ PO GRN and low-stock inventory', () {
      final snap = PviscmDemo.snapshot();
      expect(snap.vendors.length, greaterThanOrEqualTo(3));
      expect(snap.warehouses.length, greaterThanOrEqualTo(2));
      expect(snap.requisitions.any((r) => r.status == 'approved'), isTrue);
      expect(snap.rfqs.any((r) => r.status == 'awarded'), isTrue);
      expect(snap.purchaseOrders.any((p) => p.status == 'issued'), isTrue);
      expect(snap.goodsReceipts, isNotEmpty);
      expect(snap.inventory.any((i) => i.isLowStock), isTrue);
      expect(snap.shipments.any((s) => s.status == 'in_transit'), isTrue);
      expect(snap.approvals.any((a) => a.status == 'pending'), isTrue);
    });
  });

  group('PviscmService', () {
    test('offline client returns demo command center', () async {
      final service = PviscmService();
      final snap = await service.loadCommandCenter();
      expect(snap.fromRemote, isFalse);
      expect(snap.kpis.length, greaterThanOrEqualTo(7));
      expect(snap.vendors, isNotEmpty);
    });

    test('AI intelligence briefing stub includes disclaimer and signals', () {
      final service = PviscmService();
      final snap = PviscmDemo.snapshot();
      final briefing = service.generateIntelligenceBriefing(snap);
      expect(briefing.toLowerCase(), contains('procurement'));
      expect(briefing.toLowerCase(), contains('advisory'));
      expect(briefing.toLowerCase(), contains('stock'));
    });

    test('procurement signals flag stock approvals and transit', () {
      final snap = PviscmDemo.snapshot();
      final signals = PviscmService.detectProcurementSignals(snap);
      expect(signals, isNotEmpty);
      expect(
        signals.any((s) => s.toLowerCase().contains('stock')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('approval')),
        isTrue,
      );
      expect(
        signals.any((s) => s.toLowerCase().contains('transit')),
        isTrue,
      );
    });
  });

  group('PviscmController contract', () {
    test('tabs cover required procurement surfaces without state-in-build', () {
      expect(PviscmCommandTab.values.map((t) => t.name), containsAll([
        'overview',
        'vendors',
        'requisitions',
        'rfqs',
        'purchaseOrders',
        'receiving',
        'inventory',
        'warehouses',
        'logistics',
        'approvals',
        'analytics',
        'ai',
      ]));
      const initial = PviscmUiState();
      expect(initial.selectedTab, PviscmCommandTab.overview);
      expect(initial.tickerIndex, 0);
      expect(initial.copyWith(tickerIndex: 1).tickerIndex, 1);
    });
  });
}
