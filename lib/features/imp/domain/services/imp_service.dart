import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Investor Command Center snapshot from Supabase (falls back to demo).
class ImpService {
  ImpService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<ImpCommandCenterSnapshot> loadCommandCenter() async {
    final demo = ImpDemo.snapshot();
    final client = _client;
    if (client == null) return demo;

    try {
      final investorRows = await client
          .from('investors')
          .select()
          .order('updated_at', ascending: false)
          .limit(100);

      final investors = <ImpInvestor>[];
      for (final row in investorRows) {
        final map = Map<String, dynamic>.from(row as Map);
        if ((map['full_name'] as String?)?.isNotEmpty != true &&
            (map['investor_code'] as String?)?.isNotEmpty != true) {
          continue;
        }
        investors.add(ImpInvestor.fromJson(map));
      }

      if (investors.isEmpty) return demo;

      // Attach tags when available.
      try {
        final tagRows = await client.from('investor_tag_assignments').select(
              'investor_id, investor_tags(slug)',
            );
        final byInvestor = <String, List<String>>{};
        for (final row in tagRows) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['investor_id']?.toString();
          final tagRel = map['investor_tags'];
          final slug = tagRel is Map ? tagRel['slug'] as String? : null;
          if (id == null || slug == null) continue;
          byInvestor.putIfAbsent(id, () => []).add(slug);
        }
        for (var i = 0; i < investors.length; i++) {
          final tags = byInvestor[investors[i].id];
          if (tags == null || tags.isEmpty) continue;
          final inv = investors[i];
          investors[i] = ImpInvestor(
            id: inv.id,
            investorCode: inv.investorCode,
            fullName: inv.fullName,
            email: inv.email,
            phone: inv.phone,
            company: inv.company,
            investorType: inv.investorType,
            lifecycleStatus: inv.lifecycleStatus,
            kycStatus: inv.kycStatus,
            riskLevel: inv.riskLevel,
            nationality: inv.nationality,
            preferredCurrency: inv.preferredCurrency,
            aum: inv.aum,
            totalCommitted: inv.totalCommitted,
            aiSummary: inv.aiSummary,
            tags: tags,
            preferredLocations: inv.preferredLocations,
          );
        }
      } catch (_) {}

      List<ImpOpportunity> opportunities = demo.opportunities;
      try {
        final oppRows = await client
            .from('investment_opportunities')
            .select()
            .order('updated_at', ascending: false)
            .limit(50);
        if (oppRows.isNotEmpty) {
          opportunities = oppRows
              .map(
                (e) => ImpOpportunity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<ImpCommitment> commitments = demo.commitments;
      try {
        final cmtRows = await client
            .from('investment_commitments')
            .select(
              '*, investors(full_name), investment_opportunities(title)',
            )
            .order('committed_at', ascending: false)
            .limit(100);
        if (cmtRows.isNotEmpty) {
          commitments = cmtRows
              .map(
                (e) => ImpCommitment.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<ImpHolding> holdings = demo.holdings;
      try {
        final holdRows = await client
            .from('portfolio_holdings')
            .select('*, investor_portfolios(investor_id, investors(full_name))')
            .limit(100);
        if (holdRows.isNotEmpty) {
          holdings = holdRows.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final pf = map['investor_portfolios'];
            if (pf is Map) {
              map['investor_id'] = pf['investor_id']?.toString();
              final inv = pf['investors'];
              if (inv is Map) {
                map['investor_name'] = inv['full_name'];
              }
            }
            return ImpHolding.fromJson(map);
          }).toList();
        }
      } catch (_) {}

      List<ImpDistribution> distributions = demo.distributions;
      try {
        final distRows = await client
            .from('investment_distributions')
            .select(
              '*, investors(full_name), investment_opportunities(title)',
            )
            .order('scheduled_at', ascending: true)
            .limit(100);
        if (distRows.isNotEmpty) {
          distributions = distRows
              .map(
                (e) => ImpDistribution.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<ImpWallet> wallets = demo.wallets;
      try {
        final walletRows = await client
            .from('investor_wallets')
            .select('*, investors(full_name)')
            .limit(100);
        if (walletRows.isNotEmpty) {
          wallets = walletRows
              .map(
                (e) => ImpWallet.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<ImpActivity> activities = demo.activities;
      try {
        final actRows = await client
            .from('investor_activity_logs')
            .select('*, investors(full_name)')
            .order('occurred_at', ascending: false)
            .limit(40);
        if (actRows.isNotEmpty) {
          activities = actRows
              .map(
                (e) => ImpActivity.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      List<ImpAlert> alerts = demo.alerts;
      try {
        final alertRows = await client
            .from('investor_alerts')
            .select()
            .order('created_at', ascending: false)
            .limit(40);
        if (alertRows.isNotEmpty) {
          alerts = alertRows
              .map(
                (e) => ImpAlert.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      } catch (_) {}

      return ImpCommandCenterSnapshot(
        kpis: ImpDemo.aggregateKpis(
          investors: investors,
          opportunities: opportunities,
          distributions: distributions,
          commitments: commitments,
        ),
        investors: investors,
        opportunities: opportunities,
        commitments: commitments,
        holdings: holdings,
        distributions: distributions,
        wallets: wallets,
        activities: activities,
        alerts: alerts,
        aiInsights: demo.aiInsights,
        fromRemote: true,
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      return demo;
    }
  }

  /// Stub AI summary for an investor 360° workspace.
  String generatePortfolioSummary(ImpInvestor investor) {
    final type = investor.investorType.label.toLowerCase();
    final status = investor.lifecycleStatus.label.toLowerCase();
    final kyc = investor.kycStatus.label;
    final locs = investor.preferredLocations.isEmpty
        ? 'Nigeria'
        : investor.preferredLocations.join(', ');

    return 'AI Investment summary: $type ($status) focused on $locs. '
        'AUM ${investor.aumDisplay} · committed ${formatImpMoney(investor.totalCommitted)}. '
        'KYC $kyc · risk ${investor.riskLevel.label}. '
        '${investor.aiSummary ?? 'Recommend reviewing open opportunities and upcoming distributions.'}';
  }

  static double computePortfolioValue(List<ImpHolding> holdings) =>
      ImpDemo.computePortfolioValue(holdings);

  static double computeAum(List<ImpInvestor> investors) =>
      investors.fold<double>(0, (s, i) => s + i.aum);
}
