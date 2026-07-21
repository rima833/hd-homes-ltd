import 'package:hdhomesproject/features/sbms/domain/entities/sbms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Sales Command Center snapshot from Supabase (falls back to demo).
class SbmsService {
  SbmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<SbmsCommandCenterSnapshot> loadCommandCenter() async {
    final demo = SbmsDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      List<SbmsPipelineStage> stages = demo.stages;
      try {
        final stageRows = await client
            .from('sales_pipeline_stages')
            .select()
            .order('sort_order', ascending: true);
        if (stageRows.isNotEmpty) {
          stages = stageRows
              .map(
                (e) => SbmsPipelineStage.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      final orderRows = await client
          .from('sales_orders')
          .select('*, crm_clients(full_name), sales_pipeline_stages(slug, name)')
          .order('updated_at', ascending: false)
          .limit(100);

      final deals = <SbmsDeal>[];
      for (final row in orderRows) {
        final map = Map<String, dynamic>.from(row as Map);
        if ((map['title'] as String?)?.isNotEmpty != true &&
            (map['order_code'] as String?)?.isNotEmpty != true) {
          continue;
        }
        deals.add(SbmsDeal.fromJson(map));
      }

      if (deals.isEmpty) return demo;

      List<SbmsReservation> reservations = demo.reservations;
      try {
        final rows = await client
            .from('sales_reservations')
            .select('*, crm_clients(full_name), properties(title, slug)')
            .order('updated_at', ascending: false)
            .limit(100);
        if (rows.isNotEmpty) {
          reservations = rows
              .map(
                (e) => SbmsReservation.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsBooking> bookings = demo.bookings;
      try {
        final rows = await client
            .from('sales_bookings')
            .select('*, crm_clients(full_name)')
            .order('scheduled_at', ascending: true)
            .limit(100);
        if (rows.isNotEmpty) {
          bookings = rows
              .map(
                (e) =>
                    SbmsBooking.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsQuote> quotes = demo.quotes;
      try {
        final rows = await client
            .from('sales_quotes')
            .select('*, crm_clients(full_name), sales_quote_items(*)')
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          quotes = rows
              .map(
                (e) => SbmsQuote.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsNegotiation> negotiations = demo.negotiations;
      try {
        final rows = await client
            .from('sales_negotiations')
            .select()
            .order('occurred_at', ascending: false)
            .limit(100);
        if (rows.isNotEmpty) {
          negotiations = rows
              .map(
                (e) => SbmsNegotiation.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsContract> contracts = demo.contracts;
      try {
        final rows = await client
            .from('sales_contracts')
            .select('*, crm_clients(full_name)')
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          contracts = rows
              .map(
                (e) =>
                    SbmsContract.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsInstallment> installments = demo.installments;
      try {
        final rows = await client
            .from('sales_installments')
            .select()
            .order('due_date', ascending: true)
            .limit(100);
        if (rows.isNotEmpty) {
          installments = rows
              .map(
                (e) => SbmsInstallment.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsCommission> commissions = demo.commissions;
      try {
        final rows = await client
            .from('sales_commissions')
            .select()
            .order('updated_at', ascending: false)
            .limit(100);
        if (rows.isNotEmpty) {
          commissions = rows
              .map(
                (e) => SbmsCommission.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsHandover> handovers = demo.handovers;
      try {
        final rows = await client
            .from('sales_handovers')
            .select('*, crm_clients(full_name)')
            .order('updated_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          handovers = rows
              .map(
                (e) =>
                    SbmsHandover.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsDiscountRequest> discountRequests = demo.discountRequests;
      try {
        final rows = await client
            .from('sales_discount_requests')
            .select('*, sales_discounts(name)')
            .order('created_at', ascending: false)
            .limit(50);
        if (rows.isNotEmpty) {
          discountRequests = rows
              .map(
                (e) => SbmsDiscountRequest.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsActivity> activities = demo.activities;
      try {
        final rows = await client
            .from('sales_activity_logs')
            .select()
            .order('occurred_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          activities = rows
              .map(
                (e) =>
                    SbmsActivity.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsAlert> alerts = demo.alerts;
      try {
        final rows = await client
            .from('sales_notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (rows.isNotEmpty) {
          alerts = rows
              .map(
                (e) => SbmsAlert.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      } catch (_) {}

      List<SbmsLeaderboardRow> leaderboard = demo.leaderboard;
      try {
        final rows = await client
            .from('sales_leaderboards')
            .select()
            .order('rank', ascending: true)
            .limit(20);
        if (rows.isNotEmpty) {
          leaderboard = rows
              .map(
                (e) => SbmsLeaderboardRow.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      return SbmsCommandCenterSnapshot(
        kpis: SbmsDemo.aggregateKpis(
          deals: deals,
          reservations: reservations,
          contracts: contracts,
          installments: installments,
        ),
        stages: stages,
        deals: deals,
        reservations: reservations,
        bookings: bookings,
        quotes: quotes,
        negotiations: negotiations,
        contracts: contracts,
        installments: installments,
        commissions: commissions,
        handovers: handovers,
        discountRequests: discountRequests,
        activities: activities,
        alerts: alerts,
        leaderboard: leaderboard,
        aiInsights: demo.aiInsights,
        dealIntelligence: demo.dealIntelligence,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  /// Stub AI summary for a Digital Deal Room selection.
  String generateDealSummary(SbmsDeal deal) {
    final stage = deal.stageName ?? deal.stageSlug ?? deal.status.label;
    return 'AI Sales summary: ${deal.title} · $stage · '
        '${deal.valueDisplay} (${deal.probabilityPct.toStringAsFixed(0)}% prob). '
        '${deal.aiSummary ?? 'Review reservation, quote, and contract checkpoints this week.'}';
  }

  static double computePipelineValue(List<SbmsDeal> deals) =>
      SbmsDemo.computePipelineValue(deals);
}
