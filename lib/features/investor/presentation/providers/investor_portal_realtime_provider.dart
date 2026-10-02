import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live connection state for the investor portal realtime channel.
enum InvestorRealtimeConnection { offline, connecting, live, error }

/// Canonical tables the investor hub listens to (must stay in `supabase_realtime`
/// with `REPLICA IDENTITY FULL` for filtered UPDATE delivery).
const investorPortalRealtimeTables = <String>[
  'investors',
  'portfolio_holdings',
  'investment_distributions',
  'investor_wallets',
  'investor_payment_intents',
  'investment_receiving_accounts',
  'payments',
  'investor_documents',
  'investor_reports',
  'investor_statements',
  'investment_performance',
  'investor_notifications',
  'investor_alerts',
  'investor_activity_logs',
  'investor_referral_commissions',
  'investment_commitments',
  'investor_kyc_reviews',
  'investor_preferences',
  'investor_conversations',
  'investor_conversation_messages',
  'construction_progress_updates',
  'construction_update_media',
  'construction_projects',
  'project_phases',
  'project_milestones',
  'tickets',
  'ticket_messages',
];

/// Tables scoped by `investor_id` (filter + REPLICA IDENTITY FULL).
const investorPortalRealtimeInvestorScopedTables = <String>[
  'investment_distributions',
  'investor_wallets',
  'investor_payment_intents',
  'payments',
  'investor_documents',
  'investor_reports',
  'investor_statements',
  'investment_performance',
  'investor_notifications',
  'investor_alerts',
  'investor_activity_logs',
  'investor_referral_commissions',
  'investment_commitments',
  'investor_kyc_reviews',
  'investor_preferences',
  'investor_conversations',
];

/// Shell-kept hub — mirrors [clientPortalRealtimeHubProvider].
final investorPortalRealtimeHubProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  ref.watch(investorPortalRealtimeProvider);
});

/// Connection badge for chrome / dashboard.
final investorRealtimeConnectionProvider =
    StateProvider<InvestorRealtimeConnection>(
      (ref) => InvestorRealtimeConnection.offline,
    );

/// Last human-readable realtime event (cleared after a short delay).
final investorRealtimeEventProvider = StateProvider<String?>((ref) => null);

/// Invalidation groups — subscribe narrowly; refresh only what changed.
enum _InvestorRtBucket {
  record,
  dashboard,
  portfolio,
  payments,
  documents,
  reports,
  performance,
  construction,
  notifications,
  referrals,
  commitments,
  kyc,
  messages,
  conversationMeta,
  tickets,
  preferences,
  activity,
}

/// Investor portal Postgres realtime — filtered, debounced, auth-bound, disposed.
///
/// Uses [select] on investor id so KYC/profile refetches do not tear down the
/// channel (avoids reconnect storms when we invalidate [investorRecordProvider]).
final investorPortalRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();

  void setConnection(InvestorRealtimeConnection value) {
    deferProviderMutation(
      () => ref.read(investorRealtimeConnectionProvider.notifier).state = value,
    );
  }

  if (!ref.watch(supabaseConfiguredProvider)) {
    setConnection(InvestorRealtimeConnection.offline);
    return;
  }

  final userId = ref.watch(identitySessionProvider.select((s) => s.userId));
  if (userId == null || userId.isEmpty) {
    setConnection(InvestorRealtimeConnection.offline);
    return;
  }

  // Only rebuild the channel when the resolved investor id changes.
  final investorId = ref.watch(
    investorRecordProvider.select((async) => async.valueOrNull?.id),
  );
  final waitingForRecord = ref.watch(
    investorRecordProvider.select(
      (async) => async.isLoading && async.valueOrNull == null,
    ),
  );

  if (waitingForRecord) {
    setConnection(InvestorRealtimeConnection.connecting);
    return;
  }
  if (investorId == null || investorId.isEmpty) {
    setConnection(InvestorRealtimeConnection.offline);
    return;
  }

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('investor-portal-$userId');
  Timer? debounce;
  Timer? eventClear;
  final pending = <_InvestorRtBucket>{};

  void emitEvent(String? label) {
    if (label == null || label.isEmpty) return;
    deferProviderMutation(
      () => ref.read(investorRealtimeEventProvider.notifier).state = label,
    );
    eventClear?.cancel();
    eventClear = Timer(const Duration(seconds: 4), () {
      try {
        final current = ref.read(investorRealtimeEventProvider);
        if (current == label) {
          ref.read(investorRealtimeEventProvider.notifier).state = null;
        }
      } catch (_) {}
    });
  }

  void flush() {
    final buckets = Set<_InvestorRtBucket>.from(pending);
    pending.clear();
    if (buckets.isEmpty) return;

    deferProviderMutation(() {
      try {
        if (buckets.contains(_InvestorRtBucket.record)) {
          ref.invalidate(investorRecordProvider);
          ref.invalidate(investorKycBundleProvider);
        }
        if (buckets.contains(_InvestorRtBucket.dashboard) ||
            buckets.contains(_InvestorRtBucket.portfolio) ||
            buckets.contains(_InvestorRtBucket.payments) ||
            buckets.contains(_InvestorRtBucket.notifications) ||
            buckets.contains(_InvestorRtBucket.activity)) {
          ref.invalidate(investorDashboardProvider);
        }
        if (buckets.contains(_InvestorRtBucket.portfolio)) {
          ref.invalidate(investorHoldingsProvider);
          ref.invalidate(investorHoldingDetailProvider);
          ref.invalidate(investorAnalyticsSnapshotProvider);
        }
        if (buckets.contains(_InvestorRtBucket.payments)) {
          ref.invalidate(investorPaymentsProvider);
          ref.invalidate(investorAnalyticsSnapshotProvider);
        }
        if (buckets.contains(_InvestorRtBucket.documents)) {
          ref.invalidate(investorDocumentsProvider);
        }
        if (buckets.contains(_InvestorRtBucket.reports)) {
          ref.invalidate(investorReportsProvider);
        }
        if (buckets.contains(_InvestorRtBucket.performance)) {
          ref.invalidate(investorPerformanceProvider);
          ref.invalidate(investorAnalyticsSnapshotProvider);
        }
        if (buckets.contains(_InvestorRtBucket.construction)) {
          ref.invalidate(investorConstructionProvider);
        }
        if (buckets.contains(_InvestorRtBucket.notifications)) {
          ref.invalidate(investorNotificationsProvider);
          ref.invalidate(investorUnreadCountProvider);
        }
        if (buckets.contains(_InvestorRtBucket.referrals)) {
          ref.invalidate(investorReferralsProvider);
          ref.invalidate(investorRecordProvider);
        }
        if (buckets.contains(_InvestorRtBucket.commitments)) {
          ref.invalidate(investorCommitmentsProvider);
          ref.invalidate(investorDashboardProvider);
        }
        if (buckets.contains(_InvestorRtBucket.kyc)) {
          ref.invalidate(investorKycBundleProvider);
          ref.invalidate(investorRecordProvider);
          ref.invalidate(investorDashboardProvider);
        }
        if (buckets.contains(_InvestorRtBucket.preferences)) {
          ref.invalidate(investorPreferencesProvider);
        }
        if (buckets.contains(_InvestorRtBucket.messages)) {
          ref.invalidate(investorConversationsProvider);
          ref.invalidate(investorConversationMessagesProvider);
          ref.read(investorMessagesTickProvider.notifier).state++;
        }
        if (buckets.contains(_InvestorRtBucket.conversationMeta)) {
          ref.invalidate(investorConversationsProvider);
        }
        if (buckets.contains(_InvestorRtBucket.tickets)) {
          ref.invalidate(investorTicketsProvider);
          ref.read(investorTicketsTickProvider.notifier).state++;
        }
      } catch (_) {}
    });
  }

  void schedule(Set<_InvestorRtBucket> buckets, {String? eventLabel}) {
    pending.addAll(buckets);
    emitEvent(eventLabel);
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), flush);
  }

  void listen(
    String table,
    Set<_InvestorRtBucket> buckets, {
    String? eventLabel,
    String? filterColumn,
    String? filterValue,
  }) {
    assert(
      investorPortalRealtimeTables.contains(table),
      'Realtime table $table missing from investorPortalRealtimeTables',
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      filter: filterColumn != null && filterValue != null
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: filterColumn,
              value: filterValue,
            )
          : null,
      callback: (_) => schedule(buckets, eventLabel: eventLabel),
    );
  }

  void listenInvestor(
    String table,
    Set<_InvestorRtBucket> buckets, {
    String? eventLabel,
  }) {
    assert(
      investorPortalRealtimeInvestorScopedTables.contains(table),
      'Table $table is not investor-scoped',
    );
    listen(
      table,
      buckets,
      eventLabel: eventLabel,
      filterColumn: 'investor_id',
      filterValue: investorId,
    );
  }

  // Identity / KYC fields on investors row (this user only).
  listen(
    'investors',
    {_InvestorRtBucket.record, _InvestorRtBucket.dashboard},
    filterColumn: 'user_id',
    filterValue: userId,
  );

  // Portfolio — holdings lack investor_id; scoped by RLS on refetch.
  listen('portfolio_holdings', {
    _InvestorRtBucket.portfolio,
    _InvestorRtBucket.dashboard,
    _InvestorRtBucket.construction,
  }, eventLabel: 'Portfolio updated');

  // Payments / finance (no global finance_receipts — covered via payments/intents)
  listenInvestor('investment_distributions', {
    _InvestorRtBucket.payments,
    _InvestorRtBucket.dashboard,
  }, eventLabel: 'Distributions updated');
  listenInvestor('investor_wallets', {
    _InvestorRtBucket.payments,
    _InvestorRtBucket.dashboard,
  });
  listenInvestor('investor_payment_intents', {
    _InvestorRtBucket.payments,
    _InvestorRtBucket.dashboard,
  }, eventLabel: 'Payment status updated');
  listen('investment_receiving_accounts', {_InvestorRtBucket.payments});
  listenInvestor('payments', {
    _InvestorRtBucket.payments,
    _InvestorRtBucket.dashboard,
  });

  // Documents / reports / analytics
  listenInvestor('investor_documents', {
    _InvestorRtBucket.documents,
  }, eventLabel: 'New document available');
  listenInvestor('investor_reports', {_InvestorRtBucket.reports});
  listenInvestor('investor_statements', {_InvestorRtBucket.reports});
  listenInvestor('investment_performance', {
    _InvestorRtBucket.performance,
    _InvestorRtBucket.dashboard,
  });

  // Notifications / activity / referrals / prefs
  listenInvestor('investor_notifications', {
    _InvestorRtBucket.notifications,
    _InvestorRtBucket.dashboard,
  }, eventLabel: 'New notification');
  listenInvestor('investor_alerts', {_InvestorRtBucket.notifications});
  listenInvestor('investor_activity_logs', {
    _InvestorRtBucket.activity,
    _InvestorRtBucket.dashboard,
  });
  listenInvestor('investor_referral_commissions', {
    _InvestorRtBucket.referrals,
  }, eventLabel: 'Referral updated');
  listenInvestor('investment_commitments', {
    _InvestorRtBucket.commitments,
  }, eventLabel: 'Capital commitment updated');
  listenInvestor('investor_kyc_reviews', {
    _InvestorRtBucket.kyc,
  }, eventLabel: 'KYC status updated');
  listenInvestor('investor_preferences', {_InvestorRtBucket.preferences});

  // Construction (CPMS) — no investor_id; RLS scopes refetch.
  // Do not subscribe to legacy construction_updates / construction_photos.
  listen('construction_progress_updates', {
    _InvestorRtBucket.construction,
  }, eventLabel: 'New construction update');
  listen('construction_update_media', {_InvestorRtBucket.construction});
  listen('construction_projects', {_InvestorRtBucket.construction});
  listen('project_phases', {
    _InvestorRtBucket.construction,
  }, eventLabel: 'Construction phase update');
  listen('project_milestones', {_InvestorRtBucket.construction});

  // Messaging
  listenInvestor('investor_conversations', {
    _InvestorRtBucket.conversationMeta,
  });
  // Messages lack investor_id; tick refreshes open threads (RLS on refetch).
  listen(
    'investor_conversation_messages',
    {_InvestorRtBucket.messages},
    eventLabel: 'New message',
    filterColumn: 'investor_id',
    filterValue: investorId,
  );

  // Support — tickets owned by auth user.
  listen(
    'tickets',
    {_InvestorRtBucket.tickets},
    eventLabel: 'Support ticket updated',
    filterColumn: 'user_id',
    filterValue: userId,
  );
  listen(
    'ticket_messages',
    {_InvestorRtBucket.tickets},
    eventLabel: 'Support reply',
    filterColumn: 'owner_user_id',
    filterValue: userId,
  );

  setConnection(InvestorRealtimeConnection.connecting);
  channel.subscribe((status, [error]) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        setConnection(InvestorRealtimeConnection.live);
      case RealtimeSubscribeStatus.timedOut:
      case RealtimeSubscribeStatus.channelError:
        setConnection(InvestorRealtimeConnection.error);
      case RealtimeSubscribeStatus.closed:
        setConnection(InvestorRealtimeConnection.offline);
    }
  });

  ref.onDispose(() {
    debounce?.cancel();
    eventClear?.cancel();
    setConnection(InvestorRealtimeConnection.offline);
    unawaited(client.removeChannel(channel));
  });
});
