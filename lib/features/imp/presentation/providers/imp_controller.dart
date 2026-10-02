import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:hdhomesproject/features/imp/domain/services/imp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final impServiceProvider = Provider<ImpService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ImpService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final impSnapshotProvider = FutureProvider<ImpCommandCenterSnapshot>((
  ref,
) async {
  return ref.watch(impServiceProvider).loadCommandCenter();
});

final impDeskKpisProvider = FutureProvider<ImpDeskKpis>((ref) async {
  return ref.watch(impServiceProvider).loadDeskKpis();
});

typedef ImpInvestorDirectoryQuery = ({
  String search,
  String? investorType,
  InvestorLifecycleStatus? lifecycleStatus,
  KycStatus? kycStatus,
  String? assignedStaffId,
  int limit,
  int offset,
});

final impInvestorDirectoryProvider =
    FutureProvider.family<ImpInvestorPage, ImpInvestorDirectoryQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(impServiceProvider)
          .listInvestorsPage(
            search: query.search,
            investorType: query.investorType,
            lifecycleStatus: query.lifecycleStatus,
            kycStatus: query.kycStatus,
            assignedStaffId: query.assignedStaffId,
            limit: query.limit,
            offset: query.offset,
          );
    });

final impInvestorDetailProvider =
    FutureProvider.family<ImpInvestorDetail, String>((ref, investorId) {
      return ref.watch(impServiceProvider).loadInvestor360(investorId);
    });

final impWorkQueuesProvider = FutureProvider<ImpWorkQueues>((ref) {
  return ref.watch(impServiceProvider).loadWorkQueues();
});

final impInvestorManagersProvider = FutureProvider<List<ImpStaffOption>>((ref) {
  return ref.watch(impServiceProvider).listInvestorManagers();
});

final impPublishableDocumentsProvider =
    FutureProvider<List<({String id, String title})>>((ref) {
  return ref.watch(impServiceProvider).listPublishableDocuments();
});

final impWebsiteOpportunitiesProvider =
    FutureProvider<List<ImpWebsiteOpportunity>>((ref) {
  return ref.watch(impServiceProvider).listWebsiteOpportunities();
});

final impInvestorConstructionProvider =
    FutureProvider.family<ImpConstructionSnapshot, String>((ref, investorId) {
  return ref.watch(impServiceProvider).loadInvestorConstruction(investorId);
});

final impSupportInboxProvider = FutureProvider<ImpSupportInbox>((ref) {
  return ref.watch(impServiceProvider).loadSupportInbox();
});

final impRecentNotificationsProvider =
    FutureProvider<List<ImpNotificationRow>>((ref) {
  return ref.watch(impServiceProvider).listRecentNotifications();
});

final impRealtimeConnectedProvider = StateProvider<bool>((ref) => false);

/// Canonical tables the IMP command-center channel listens to.
const impCommandCenterRealtimeTables = <String>[
  'investors',
  'investor_kyc_reviews',
  'investment_opportunities',
  'investment_commitments',
  'portfolio_holdings',
  'investor_documents',
  'investor_conversations',
  'investor_conversation_messages',
  'investment_distributions',
  'investor_activity_logs',
  'investor_alerts',
  'investor_wallets',
  'investor_portfolios',
  'investor_preferences',
  'investor_tags',
  'investor_tag_assignments',
  'investor_command_events',
  'investor_tasks',
  'investor_payment_intents',
  'construction_progress_updates',
  'construction_projects',
  'tickets',
  'ticket_messages',
  'investor_notifications',
  'investor_reports',
  'investor_statements',
  'investor_referral_commissions',
  'website_investment_opportunities',
];

/// Invalidates only the providers impacted by each IMP live table.
final impRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);

  void invalidateCore() {
    ref.invalidate(impSnapshotProvider);
    ref.invalidate(impDeskKpisProvider);
  }

  void invalidateDirectory() {
    ref.invalidate(impInvestorDirectoryProvider);
    ref.invalidate(impInvestorManagersProvider);
  }

  void invalidateDetail() => ref.invalidate(impInvestorDetailProvider);
  void invalidateQueues() => ref.invalidate(impWorkQueuesProvider);
  void invalidateConstruction() =>
      ref.invalidate(impInvestorConstructionProvider);
  void invalidateSupport() => ref.invalidate(impSupportInboxProvider);
  void invalidateNotifications() =>
      ref.invalidate(impRecentNotificationsProvider);
  void invalidateDocs() => ref.invalidate(impPublishableDocumentsProvider);
  void invalidateWebsite() => ref.invalidate(impWebsiteOpportunitiesProvider);

  void onTable(String table) {
    switch (table) {
      case 'investors':
      case 'investor_tags':
      case 'investor_tag_assignments':
      case 'investor_preferences':
        invalidateCore();
        invalidateDirectory();
        invalidateDetail();
        invalidateQueues();
      case 'investor_kyc_reviews':
        invalidateCore();
        invalidateDetail();
        invalidateQueues();
      case 'investment_opportunities':
        invalidateCore();
        invalidateWebsite();
      case 'investment_commitments':
      case 'investment_distributions':
      case 'investor_wallets':
        invalidateCore();
        invalidateDetail();
        invalidateQueues();
      case 'portfolio_holdings':
      case 'investor_portfolios':
        invalidateCore();
        invalidateDetail();
        invalidateQueues();
        invalidateConstruction();
      case 'investor_documents':
        invalidateDetail();
        invalidateDocs();
        invalidateCore();
      case 'investor_conversations':
      case 'investor_conversation_messages':
      case 'tickets':
      case 'ticket_messages':
        invalidateSupport();
        invalidateDetail();
      case 'investor_activity_logs':
      case 'investor_command_events':
        invalidateCore();
      case 'investor_alerts':
      case 'investor_tasks':
      case 'investor_payment_intents':
        invalidateCore();
        invalidateQueues();
      case 'construction_progress_updates':
      case 'construction_projects':
        invalidateConstruction();
      case 'investor_notifications':
        invalidateNotifications();
      case 'investor_reports':
      case 'investor_statements':
      case 'investor_referral_commissions':
        invalidateDetail();
        invalidateCore();
      case 'website_investment_opportunities':
        invalidateWebsite();
      default:
        invalidateCore();
    }
  }

  RealtimeChannel bind(RealtimeChannel channel, String table) {
    return channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => onTable(table),
    );
  }

  var channel = client.channel('imp-command-center');
  for (final table in impCommandCenterRealtimeTables) {
    channel = bind(channel, table);
  }
  channel.subscribe((status, [error]) {
    deferProviderMutation(() {
      ref.read(impRealtimeConnectedProvider.notifier).state =
          status == RealtimeSubscribeStatus.subscribed;
    });
  });

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    deferProviderMutation(() {
      ref.read(impRealtimeConnectedProvider.notifier).state = false;
    });
  });
});

enum ImpCommandTab {
  overview,
  investors,
  capital,
  payments,
  compliance,
  support,
  insights,
  investor360;

  String get label => switch (this) {
    ImpCommandTab.overview => 'Overview',
    ImpCommandTab.investors => 'Investors',
    ImpCommandTab.capital => 'Capital',
    ImpCommandTab.payments => 'Payments',
    ImpCommandTab.compliance => 'Compliance',
    ImpCommandTab.support => 'Support',
    ImpCommandTab.insights => 'Insights',
    ImpCommandTab.investor360 => '360° Investor',
  };
}

enum ImpCapitalSegment {
  investments,
  opportunities,
  portfolio,
  distributions;

  String get label => switch (this) {
    ImpCapitalSegment.investments => 'Investments',
    ImpCapitalSegment.opportunities => 'Capital Raise',
    ImpCapitalSegment.portfolio => 'Portfolio',
    ImpCapitalSegment.distributions => 'Distributions',
  };
}

enum ImpComplianceSegment {
  kyc,
  documents;

  String get label => switch (this) {
    ImpComplianceSegment.kyc => 'KYC',
    ImpComplianceSegment.documents => 'Documents',
  };
}

enum ImpInsightsSegment {
  reports,
  activity,
  alerts;

  String get label => switch (this) {
    ImpInsightsSegment.reports => 'Reports',
    ImpInsightsSegment.activity => 'Activity',
    ImpInsightsSegment.alerts => 'Alerts',
  };
}

class ImpUiState {
  const ImpUiState({
    this.searchQuery = '',
    this.typeFilter,
    this.lifecycleFilter,
    this.kycFilter,
    this.assignedStaffId,
    this.selectedTab = ImpCommandTab.overview,
    this.capitalSegment = ImpCapitalSegment.investments,
    this.complianceSegment = ImpComplianceSegment.kyc,
    this.insightsSegment = ImpInsightsSegment.alerts,
    this.selectedInvestorId,
    this.lastMessage,
    this.tickerIndex = 0,
    this.investorPageOffset = 0,
  });

  final String searchQuery;
  final String? typeFilter;
  final InvestorLifecycleStatus? lifecycleFilter;
  final KycStatus? kycFilter;
  final String? assignedStaffId;
  final ImpCommandTab selectedTab;
  final ImpCapitalSegment capitalSegment;
  final ImpComplianceSegment complianceSegment;
  final ImpInsightsSegment insightsSegment;
  final String? selectedInvestorId;
  final String? lastMessage;
  final int tickerIndex;
  final int investorPageOffset;

  ImpUiState copyWith({
    String? searchQuery,
    String? typeFilter,
    bool clearTypeFilter = false,
    InvestorLifecycleStatus? lifecycleFilter,
    bool clearLifecycleFilter = false,
    KycStatus? kycFilter,
    bool clearKycFilter = false,
    String? assignedStaffId,
    bool clearAssignedStaffId = false,
    ImpCommandTab? selectedTab,
    ImpCapitalSegment? capitalSegment,
    ImpComplianceSegment? complianceSegment,
    ImpInsightsSegment? insightsSegment,
    String? selectedInvestorId,
    bool clearSelectedInvestor = false,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
    int? investorPageOffset,
  }) {
    return ImpUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      lifecycleFilter: clearLifecycleFilter
          ? null
          : (lifecycleFilter ?? this.lifecycleFilter),
      kycFilter: clearKycFilter ? null : (kycFilter ?? this.kycFilter),
      assignedStaffId: clearAssignedStaffId
          ? null
          : (assignedStaffId ?? this.assignedStaffId),
      selectedTab: selectedTab ?? this.selectedTab,
      capitalSegment: capitalSegment ?? this.capitalSegment,
      complianceSegment: complianceSegment ?? this.complianceSegment,
      insightsSegment: insightsSegment ?? this.insightsSegment,
      selectedInvestorId: clearSelectedInvestor
          ? null
          : (selectedInvestorId ?? this.selectedInvestorId),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
      investorPageOffset: investorPageOffset ?? this.investorPageOffset,
    );
  }
}

class ImpController extends Notifier<ImpUiState> {
  Timer? _tickerTimer;

  @override
  ImpUiState build() {
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(impRealtimeProvider);
    _armTicker();
    return const ImpUiState();
  }

  void _armTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query, investorPageOffset: 0);
  }

  void setTypeFilter(String? typeSlug) {
    if (typeSlug == null) {
      state = state.copyWith(clearTypeFilter: true, investorPageOffset: 0);
    } else {
      state = state.copyWith(typeFilter: typeSlug, investorPageOffset: 0);
    }
  }

  void setLifecycleFilter(InvestorLifecycleStatus? status) {
    if (status == null) {
      state = state.copyWith(clearLifecycleFilter: true, investorPageOffset: 0);
    } else {
      state = state.copyWith(lifecycleFilter: status, investorPageOffset: 0);
    }
  }

  void setKycFilter(KycStatus? status) {
    if (status == null) {
      state = state.copyWith(clearKycFilter: true, investorPageOffset: 0);
    } else {
      state = state.copyWith(kycFilter: status, investorPageOffset: 0);
    }
  }

  void setAssignedStaffFilter(String? staffId) {
    if (staffId == null) {
      state = state.copyWith(clearAssignedStaffId: true, investorPageOffset: 0);
    } else {
      state = state.copyWith(assignedStaffId: staffId, investorPageOffset: 0);
    }
  }

  void setInvestorPageOffset(int offset) {
    state = state.copyWith(investorPageOffset: offset < 0 ? 0 : offset);
  }

  void setTab(ImpCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setCapitalSegment(ImpCapitalSegment segment) {
    state = state.copyWith(
      selectedTab: ImpCommandTab.capital,
      capitalSegment: segment,
    );
  }

  void setComplianceSegment(ImpComplianceSegment segment) {
    state = state.copyWith(
      selectedTab: ImpCommandTab.compliance,
      complianceSegment: segment,
    );
  }

  void setInsightsSegment(ImpInsightsSegment segment) {
    state = state.copyWith(
      selectedTab: ImpCommandTab.insights,
      insightsSegment: segment,
    );
  }

  void openPayments() => setTab(ImpCommandTab.payments);
  void openSupport() => setTab(ImpCommandTab.support);
  void openInvestments() => setCapitalSegment(ImpCapitalSegment.investments);
  void openOpportunities() =>
      setCapitalSegment(ImpCapitalSegment.opportunities);
  void openKyc() => setComplianceSegment(ImpComplianceSegment.kyc);
  void openDocuments() => setComplianceSegment(ImpComplianceSegment.documents);
  void openAlerts() => setInsightsSegment(ImpInsightsSegment.alerts);
  void openReports() => setInsightsSegment(ImpInsightsSegment.reports);
  void openActivity() => setInsightsSegment(ImpInsightsSegment.activity);

  /// Select for directory preview without leaving the Investors tab.
  void previewInvestor(String? investorId) {
    if (investorId == null) {
      state = state.copyWith(clearSelectedInvestor: true);
    } else {
      state = state.copyWith(selectedInvestorId: investorId);
    }
  }

  void selectInvestor(String? investorId) {
    if (investorId == null) {
      state = state.copyWith(clearSelectedInvestor: true);
    } else {
      state = state.copyWith(
        selectedInvestorId: investorId,
        selectedTab: ImpCommandTab.investor360,
      );
    }
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(impSnapshotProvider);
    ref.invalidate(impDeskKpisProvider);
    ref.invalidate(impInvestorDirectoryProvider);
    ref.invalidate(impInvestorDetailProvider);
    ref.invalidate(impWorkQueuesProvider);
    ref.invalidate(impInvestorManagersProvider);
    ref.invalidate(impPublishableDocumentsProvider);
    ref.invalidate(impWebsiteOpportunitiesProvider);
    ref.invalidate(impInvestorConstructionProvider);
    ref.invalidate(impSupportInboxProvider);
    ref.invalidate(impRecentNotificationsProvider);
  }

  List<ImpInvestor> filteredInvestors(ImpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.investors.where((inv) {
      if (state.typeFilter != null &&
          inv.investorType.slug != state.typeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return inv.fullName.toLowerCase().contains(q) ||
          inv.investorCode.toLowerCase().contains(q) ||
          (inv.email?.toLowerCase().contains(q) ?? false) ||
          (inv.company?.toLowerCase().contains(q) ?? false) ||
          inv.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<ImpOpportunity> filteredOpportunities(ImpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return snap.opportunities;
    return snap.opportunities.where((o) {
      return o.title.toLowerCase().contains(q) ||
          o.code.toLowerCase().contains(q) ||
          (o.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  ImpInvestor? selectedInvestor(ImpCommandCenterSnapshot snap) {
    final id = state.selectedInvestorId;
    if (id == null) {
      return snap.investors.isEmpty ? null : snap.investors.first;
    }
    for (final inv in snap.investors) {
      if (inv.id == id) return inv;
    }
    return snap.investors.isEmpty ? null : snap.investors.first;
  }
}

final impControllerProvider = NotifierProvider<ImpController, ImpUiState>(
  ImpController.new,
);
