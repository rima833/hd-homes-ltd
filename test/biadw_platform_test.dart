import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:hdhomesproject/features/biadw/presentation/pages/bi_command_center_page.dart';
import 'package:hdhomesproject/features/biadw/presentation/providers/biadw_controller.dart';

void main() {
  group('BiadwCommandCenterSnapshot', () {
    test('parses an operational RPC response without fallback values', () {
      final snapshot = BiadwCommandCenterSnapshot.fromJson({
        'loaded_at': '2026-09-09T09:00:00Z',
        'period_days': 30,
        'kpis': [
          {
            'key': 'crm_leads',
            'label': 'CRM Leads',
            'value': 12,
            'unit': 'count',
          },
          {
            'key': 'revenue_mtd',
            'label': 'Revenue MTD',
            'value': 1250000,
            'unit': 'currency',
          },
        ],
        'daily_series': [
          {
            'date': '2026-09-09',
            'leads': 3,
            'revenue': 500000,
            'applications': 2,
          },
        ],
        'lead_statuses': [
          {'label': 'Qualified', 'value': 4},
        ],
        'modules': [
          {
            'key': 'sales',
            'label': 'Sales',
            'value': 12,
            'detail': 'Live CRM leads',
          },
        ],
        'recent_activity': [
          {
            'type': 'lead',
            'label': 'Lead captured',
            'occurred_at': '2026-09-09T08:55:00Z',
          },
        ],
      });

      expect(snapshot.periodDays, 30);
      expect(snapshot.kpis.first.value, 12);
      expect(snapshot.kpis.last.displayValue, '₦1.3M');
      expect(snapshot.dailySeries.single.applications, 2);
      expect(snapshot.recentActivity.single.label, 'Lead captured');
      expect(snapshot.isEmpty, isFalse);
    });

    test('keeps a genuinely empty RPC response empty', () {
      final snapshot = BiadwCommandCenterSnapshot.fromJson({
        'loaded_at': '2026-09-09T09:00:00Z',
        'period_days': 7,
      });

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.kpis, isEmpty);
      expect(snapshot.modules, isEmpty);
    });
  });

  group('BiCommandCenterPage responsive layout', () {
    for (final size in const [
      Size(1440, 900),
      Size(768, 700),
      Size(390, 700),
    ]) {
      testWidgets('renders without overflow at ${size.width}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              biadwSnapshotProvider.overrideWith((ref) async => _snapshot),
              biadwRealtimeConnectedProvider.overrideWith((ref) => true),
              biadwLastSyncProvider.overrideWith(
                (ref) => DateTime.utc(2026, 9, 9, 9),
              ),
            ],
            child: const MaterialApp(home: BiCommandCenterPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Admin Analytics'), findsOneWidget);
        expect(find.text('CRM Leads'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

final _snapshot = BiadwCommandCenterSnapshot(
  loadedAt: DateTime.utc(2026, 9, 9, 9),
  periodDays: 30,
  kpis: const [
    BiadwKpi(key: 'crm_leads', label: 'CRM Leads', value: 12, unit: 'count'),
    BiadwKpi(
      key: 'revenue_mtd',
      label: 'Revenue MTD',
      value: 1250000,
      unit: 'currency',
    ),
  ],
  dailySeries: [
    BiadwDailyPoint(
      date: DateTime.utc(2026, 9, 8),
      leads: 2,
      revenue: 250000,
      applications: 1,
    ),
    BiadwDailyPoint(
      date: DateTime.utc(2026, 9, 9),
      leads: 3,
      revenue: 500000,
      applications: 2,
    ),
  ],
  leadStatuses: const [
    BiadwLeadStatus(label: 'Qualified', value: 4),
    BiadwLeadStatus(label: 'New', value: 8),
  ],
  modules: const [
    BiadwModuleMetric(
      key: 'sales',
      label: 'Sales',
      value: 12,
      detail: 'Live CRM leads',
    ),
  ],
  recentActivity: [
    BiadwActivity(
      type: 'lead',
      label: 'Lead captured',
      occurredAt: DateTime.utc(2026, 9, 9, 8, 55),
    ),
  ],
);
