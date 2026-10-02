import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_payment_engine_providers.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/consultation/presentation/providers/customer_consultation_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live connection state for the client portal realtime channel.
enum ClientRealtimeConnection { offline, connecting, live, error }

/// Canonical tables the client hub listens to.
const clientPortalRealtimeTables = <String>[
  'clients',
  'client_properties',
  'client_timeline',
  'client_documents',
  'client_property_applications',
  'client_payment_intents',
  'payments',
  'installments',
  'payment_charges',
  'finance_receipts',
  'payment_verifications',
  'payment_methods',
  'payment_settings',
  'company_receiving_accounts',
  'construction_progress_updates',
  'construction_update_media',
  'construction_projects',
  'property_inspections',
  'favorite_items',
  'client_referral_commissions',
  'client_preferences',
  'client_conversations',
  'client_conversation_messages',
  'tickets',
  'ticket_messages',
];

/// Tables scoped by `client_id` (filter + RLS on refetch).
const clientPortalRealtimeClientScopedTables = <String>[
  'client_properties',
  'client_timeline',
  'client_documents',
  'client_property_applications',
  'client_payment_intents',
  'payments',
  'installments',
  'payment_charges',
  'client_referral_commissions',
  'client_preferences',
  'client_conversations',
];

/// Shell-kept hub — portal RT + notifications + consultations.
final clientPortalRealtimeHubProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;

  ref.watch(clientPortalRealtimeProvider);
  ref.watch(notificationRealtimeProvider);
  ref.watch(clientConsultationsRealtimeProvider);
});

/// Connection badge for chrome / dashboard.
final clientRealtimeConnectionProvider =
    StateProvider<ClientRealtimeConnection>(
      (ref) => ClientRealtimeConnection.offline,
    );

/// Last human-readable realtime event (cleared after a short delay).
final clientRealtimeEventProvider = StateProvider<String?>((ref) => null);

enum _ClientRtBucket {
  record,
  dashboard,
  properties,
  applications,
  payments,
  documents,
  construction,
  inspections,
  saved,
  messages,
  conversationMeta,
  tickets,
  referrals,
  preferences,
  activity,
}

/// Client portal Postgres realtime — filtered, debounced, auth-bound, disposed.
///
/// Payment-engine tables are included here so a second channel is not needed
/// (avoids invalidate storms). Uses [select] on client id so record refetches
/// do not tear down the channel.
final clientPortalRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();

  void setConnection(ClientRealtimeConnection value) {
    deferProviderMutation(
      () => ref.read(clientRealtimeConnectionProvider.notifier).state = value,
    );
  }

  if (!ref.watch(supabaseConfiguredProvider)) {
    setConnection(ClientRealtimeConnection.offline);
    return;
  }

  final userId = ref.watch(identitySessionProvider.select((s) => s.userId));
  if (userId == null || userId.isEmpty) {
    setConnection(ClientRealtimeConnection.offline);
    return;
  }

  final clientId = ref.watch(
    clientRecordProvider.select((async) => async.valueOrNull?.id),
  );
  final waitingForRecord = ref.watch(
    clientRecordProvider.select(
      (async) => async.isLoading && async.valueOrNull == null,
    ),
  );

  if (waitingForRecord) {
    setConnection(ClientRealtimeConnection.connecting);
    return;
  }
  if (clientId == null || clientId.isEmpty) {
    setConnection(ClientRealtimeConnection.offline);
    return;
  }

  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('client-portal-$userId');
  Timer? debounce;
  Timer? eventClear;
  final pending = <_ClientRtBucket>{};

  void emitEvent(String? label) {
    if (label == null || label.isEmpty) return;
    deferProviderMutation(
      () => ref.read(clientRealtimeEventProvider.notifier).state = label,
    );
    eventClear?.cancel();
    eventClear = Timer(const Duration(seconds: 4), () {
      try {
        final current = ref.read(clientRealtimeEventProvider);
        if (current == label) {
          ref.read(clientRealtimeEventProvider.notifier).state = null;
        }
      } catch (_) {}
    });
  }

  void flush() {
    final buckets = Set<_ClientRtBucket>.from(pending);
    pending.clear();
    if (buckets.isEmpty) return;

    deferProviderMutation(() {
      try {
        if (buckets.contains(_ClientRtBucket.record)) {
          ref.invalidate(clientRecordProvider);
        }
        if (buckets.contains(_ClientRtBucket.dashboard) ||
            buckets.contains(_ClientRtBucket.properties) ||
            buckets.contains(_ClientRtBucket.payments) ||
            buckets.contains(_ClientRtBucket.activity) ||
            buckets.contains(_ClientRtBucket.applications)) {
          ref.invalidate(clientDashboardProvider);
        }
        if (buckets.contains(_ClientRtBucket.properties)) {
          ref.invalidate(clientPropertiesProvider);
          ref.invalidate(clientPropertyDetailProvider);
        }
        if (buckets.contains(_ClientRtBucket.applications)) {
          ref.invalidate(clientApplicationsProvider);
          ref.invalidate(clientApplicationDetailProvider);
          ref.invalidate(clientApplicationDocumentsProvider);
          ref.invalidate(clientApplicationTimelineProvider);
          ref.invalidate(clientApplicationPropertyOptionsProvider);
          ref.invalidate(applicationPaymentPlansProvider);
          ref.invalidate(applicationRequiredDocumentTypesProvider);
        }
        if (buckets.contains(_ClientRtBucket.payments)) {
          ref.invalidate(clientPaymentsProvider);
          ref.invalidate(clientPaymentSummaryProvider);
          ref.invalidate(clientPaymentMethodsProvider);
          ref.invalidate(clientReceivingAccountsProvider);
          ref.invalidate(clientPaymentIntentsProvider);
          ref.invalidate(clientPaymentChargesProvider);
          ref.invalidate(clientFinanceReceiptsProvider);
          ref.invalidate(clientPaymentHistoryProvider);
        }
        if (buckets.contains(_ClientRtBucket.documents)) {
          ref.invalidate(clientDocumentsProvider);
          ref.invalidate(clientApplicationDocumentsProvider);
        }
        if (buckets.contains(_ClientRtBucket.construction)) {
          ref.invalidate(clientConstructionProvider);
        }
        if (buckets.contains(_ClientRtBucket.inspections)) {
          ref.invalidate(clientInspectionsProvider);
        }
        if (buckets.contains(_ClientRtBucket.saved)) {
          ref.invalidate(clientSavedPropertiesProvider);
          ref.invalidate(clientSavedPropertyIdsProvider);
        }
        if (buckets.contains(_ClientRtBucket.referrals)) {
          ref.invalidate(clientReferralsProvider);
        }
        if (buckets.contains(_ClientRtBucket.preferences)) {
          ref.invalidate(clientPreferencesProvider);
        }
        if (buckets.contains(_ClientRtBucket.messages)) {
          ref.invalidate(clientConversationsProvider);
          ref.invalidate(clientConversationMessagesProvider);
          ref.invalidate(clientConversationDetailProvider);
          ref.read(clientMessagesTickProvider.notifier).state++;
        }
        if (buckets.contains(_ClientRtBucket.conversationMeta)) {
          // Typing updates the conversation row. Refresh the list and
          // header only — do not reload the open thread on each keystroke.
          ref.invalidate(clientConversationsProvider);
          ref.invalidate(clientConversationDetailProvider);
        }
        if (buckets.contains(_ClientRtBucket.tickets)) {
          ref.invalidate(clientTicketsProvider);
          ref.read(clientTicketMessagesTickProvider.notifier).state++;
        }
      } catch (_) {}
    });
  }

  void schedule(Set<_ClientRtBucket> buckets, {String? eventLabel}) {
    pending.addAll(buckets);
    emitEvent(eventLabel);
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), flush);
  }

  void listen(
    String table,
    Set<_ClientRtBucket> buckets, {
    String? eventLabel,
    String? filterColumn,
    String? filterValue,
  }) {
    assert(
      clientPortalRealtimeTables.contains(table),
      'Realtime table $table missing from clientPortalRealtimeTables',
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

  void listenClient(
    String table,
    Set<_ClientRtBucket> buckets, {
    String? eventLabel,
  }) {
    assert(
      clientPortalRealtimeClientScopedTables.contains(table),
      'Table $table is not client-scoped',
    );
    listen(
      table,
      buckets,
      eventLabel: eventLabel,
      filterColumn: 'client_id',
      filterValue: clientId,
    );
  }

  // Identity on clients row (this user only).
  listen(
    'clients',
    {_ClientRtBucket.record, _ClientRtBucket.dashboard},
    filterColumn: 'user_id',
    filterValue: userId,
  );

  // Properties / journey
  listenClient('client_properties', {
    _ClientRtBucket.properties,
    _ClientRtBucket.dashboard,
    _ClientRtBucket.construction,
  }, eventLabel: 'Properties updated');
  listenClient('client_timeline', {
    _ClientRtBucket.activity,
    _ClientRtBucket.dashboard,
    _ClientRtBucket.applications,
  }, eventLabel: 'Activity updated');
  listenClient('client_property_applications', {
    _ClientRtBucket.applications,
    _ClientRtBucket.properties,
    _ClientRtBucket.dashboard,
  }, eventLabel: 'Application updated');

  // Documents
  listenClient('client_documents', {
    _ClientRtBucket.documents,
    _ClientRtBucket.applications,
  }, eventLabel: 'New document available');

  // Payments / finance (merged former payment-engine channel)
  listenClient('client_payment_intents', {
    _ClientRtBucket.payments,
    _ClientRtBucket.dashboard,
  }, eventLabel: 'Payment status updated');
  listenClient('payments', {
    _ClientRtBucket.payments,
    _ClientRtBucket.dashboard,
  }, eventLabel: 'Payment updated');
  listenClient('installments', {
    _ClientRtBucket.payments,
    _ClientRtBucket.dashboard,
  }, eventLabel: 'Installment updated');
  listenClient('payment_charges', {_ClientRtBucket.payments});
  // Receipts / verifications lack client_id — RLS scopes refetch.
  listen('finance_receipts', {_ClientRtBucket.payments});
  listen('payment_verifications', {_ClientRtBucket.payments});
  listen('payment_methods', {_ClientRtBucket.payments});
  listen('payment_settings', {_ClientRtBucket.payments});
  listen('company_receiving_accounts', {_ClientRtBucket.payments});

  // Construction (CPMS) — no client_id; RLS scopes refetch.
  // Do not subscribe to legacy construction_updates / website tables.
  listen('construction_progress_updates', {
    _ClientRtBucket.construction,
  }, eventLabel: 'New construction update');
  listen('construction_update_media', {_ClientRtBucket.construction});
  listen('construction_projects', {_ClientRtBucket.construction});

  // Inspections — no client_id; visitor/profile scoped on refetch.
  listen('property_inspections', {
    _ClientRtBucket.inspections,
  }, eventLabel: 'Inspection updated');

  // Saved marketplace items
  listen(
    'favorite_items',
    {_ClientRtBucket.saved},
    filterColumn: 'user_id',
    filterValue: userId,
  );

  listenClient('client_referral_commissions', {
    _ClientRtBucket.referrals,
  }, eventLabel: 'Referral updated');
  listenClient('client_preferences', {_ClientRtBucket.preferences});

  // Messaging
  listenClient('client_conversations', {
    _ClientRtBucket.conversationMeta,
  });
  listen(
    'client_conversation_messages',
    {_ClientRtBucket.messages},
    eventLabel: 'New message',
    filterColumn: 'client_id',
    filterValue: clientId,
  );

  // Support
  listen(
    'tickets',
    {_ClientRtBucket.tickets},
    eventLabel: 'Support ticket updated',
    filterColumn: 'user_id',
    filterValue: userId,
  );
  listen(
    'ticket_messages',
    {_ClientRtBucket.tickets},
    eventLabel: 'Support reply',
    filterColumn: 'owner_user_id',
    filterValue: userId,
  );

  setConnection(ClientRealtimeConnection.connecting);
  channel.subscribe((status, [error]) {
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        setConnection(ClientRealtimeConnection.live);
      case RealtimeSubscribeStatus.timedOut:
      case RealtimeSubscribeStatus.channelError:
        setConnection(ClientRealtimeConnection.error);
      case RealtimeSubscribeStatus.closed:
        setConnection(ClientRealtimeConnection.offline);
    }
  });

  ref.onDispose(() {
    debounce?.cancel();
    eventClear?.cancel();
    setConnection(ClientRealtimeConnection.offline);
    unawaited(client.removeChannel(channel));
  });
});
