import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/staff_portal_conversation.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:hdhomesproject/features/cshop/domain/services/cshop_service.dart';
import 'package:hdhomesproject/features/cshop/domain/services/support_repository.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supportRepositoryProvider = Provider<SupportRepository?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return SupabaseSupportRepository(ref.watch(supabaseClientProvider));
});

final supportConfigurationProvider =
    FutureProvider<SupportConfigurationSnapshot?>((ref) async {
      final repository = ref.watch(supportRepositoryProvider);
      if (repository == null) return null;
      final client = ref.watch(supabaseClientProvider);
      final channel = client.channel('support-configuration')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_settings',
          callback: (_) => ref.invalidateSelf(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_operating_hours',
          callback: (_) => ref.invalidateSelf(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_holidays',
          callback: (_) => ref.invalidateSelf(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_quick_replies',
          callback: (_) => ref.invalidateSelf(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_assignment_rules',
          callback: (_) => ref.invalidateSelf(),
        )
        ..subscribe();
      ref.onDispose(() => unawaited(client.removeChannel(channel)));
      return repository.loadConfiguration();
    });

final supportTicketEventsProvider = FutureProvider.autoDispose
    .family<List<SupportTicketEvent>, String>((ref, ticketId) async {
      final repository = ref.watch(supportRepositoryProvider);
      if (repository == null) return const [];
      final client = ref.watch(supabaseClientProvider);
      final channel = client.channel('support-ticket-events-$ticketId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_ticket_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (_) => ref.invalidateSelf(),
        )
        ..subscribe((status, [error]) {
          deferProviderMutation(() {
            final current = ref.read(supportRealtimeHealthProvider);
            if (status == RealtimeSubscribeStatus.subscribed &&
                !current.isConnected) {
              ref
                  .read(supportRealtimeHealthProvider.notifier)
                  .state = SupportRealtimeHealth(
                connection: SupportRealtimeConnection.connected,
                changedAt: DateTime.now(),
              );
            } else if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              ref
                  .read(supportRealtimeHealthProvider.notifier)
                  .state = SupportRealtimeHealth(
                connection: SupportRealtimeConnection.error,
                message: 'The selected ticket lost its realtime connection.',
                changedAt: DateTime.now(),
              );
            }
          });
        });
      ref.onDispose(() => unawaited(client.removeChannel(channel)));
      return repository.listTicketEvents(ticketId);
    });

final supportTicketLinksProvider = FutureProvider.autoDispose
    .family<List<SupportTicketLink>, String>((ref, ticketId) async {
      final repository = ref.watch(supportRepositoryProvider);
      if (repository == null) return const [];
      final client = ref.watch(supabaseClientProvider);
      final channel = client.channel('support-ticket-links-$ticketId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_ticket_links',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (_) => ref.invalidateSelf(),
        )
        ..subscribe();
      ref.onDispose(() => unawaited(client.removeChannel(channel)));
      return repository.listTicketLinks(ticketId);
    });

enum SupportRealtimeConnection {
  disabled,
  connecting,
  connected,
  disconnected,
  error,
}

class SupportRealtimeHealth {
  const SupportRealtimeHealth({
    required this.connection,
    this.message,
    this.changedAt,
  });

  final SupportRealtimeConnection connection;
  final String? message;
  final DateTime? changedAt;

  bool get isConnected => connection == SupportRealtimeConnection.connected;
}

final supportRealtimeHealthProvider = StateProvider<SupportRealtimeHealth>(
  (ref) => const SupportRealtimeHealth(
    connection: SupportRealtimeConnection.disabled,
  ),
);

final cshopServiceProvider = Provider<CshopService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CshopService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final cshopSnapshotProvider = FutureProvider<CshopCommandCenterSnapshot>((
  ref,
) async {
  return ref.watch(cshopServiceProvider).loadCommandCenter();
});

final supportTicketCategoriesProvider = FutureProvider<List<SupportCategory>>((
  ref,
) async {
  return ref.watch(cshopServiceProvider).listTicketCategories();
});

final supportTicketPropertiesProvider =
    FutureProvider<List<SupportPropertyOption>>((ref) async {
      return ref.watch(cshopServiceProvider).listTicketProperties();
    });

/// Unified Support desk queue: client + investor portal conversations.
final staffPortalConversationsProvider =
    FutureProvider<List<StaffPortalConversation>>((ref) async {
      List<ClientConversation> clients = const [];
      List<InvestorConversation> investors = const [];
      try {
        clients = await ref
            .read(clientServiceProvider)
            .listStaffConversations()
            .timeout(const Duration(seconds: 12));
      } catch (_) {}
      try {
        investors = await ref
            .read(investorServiceProvider)
            .listStaffConversations()
            .timeout(const Duration(seconds: 12));
      } catch (_) {}

      final merged = <StaffPortalConversation>[
        ...clients.map(StaffPortalConversation.fromClient),
        ...investors.map(StaffPortalConversation.fromInvestor),
      ];
      merged.sort((a, b) {
        final aAt = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
      return merged;
    });

final staffPortalMessagesProvider =
    FutureProvider.family<List<StaffPortalMessage>, String>((
      ref,
      selectionKey,
    ) async {
      final parsed = StaffPortalConversation.parseSelectionKey(selectionKey);
      if (parsed == null) return [];
      final (kind, id) = parsed;
      final userId = ref.watch(identitySessionProvider).userId;
      if (userId == null) return [];

      if (kind == StaffPortalKind.client) {
        final rows = await ref
            .watch(clientServiceProvider)
            .listMessages(id, userId: userId);
        return rows
            .map(
              (m) => StaffPortalMessage(
                id: m.id,
                body: m.body,
                createdAt: m.createdAt,
                isMine: m.isMine,
                isRead: m.isRead,
                senderName: m.senderName,
              ),
            )
            .toList();
      }

      final rows = await ref
          .watch(investorServiceProvider)
          .listMessages(id, userId: userId);
      return rows
          .map(
            (m) => StaffPortalMessage(
              id: m.id,
              body: m.body,
              createdAt: m.createdAt,
              isMine: m.isMine,
              isRead: m.readAt != null,
              senderName: m.senderName,
            ),
          )
          .toList();
    });

/// Live peer-typing timestamps keyed by `client:<id>` / `investor:<id>`.
/// Updated from realtime without refetching the conversation list.
final portalPeerTypingAtProvider = StateProvider<Map<String, DateTime?>>(
  (ref) => const {},
);

/// Dedicated lightweight channel for Portal Messages (client + investor).
/// Separated from the heavy CSHOP mega-channel so message delivery stays reliable.
final portalMessagesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  var disposed = false;
  Timer? clientDebounce;
  Timer? investorDebounce;
  var clientRefreshList = false;
  var clientRefreshMessages = false;
  var clientTypingOnly = true;
  PostgresChangePayload? clientPayload;
  var investorRefreshList = false;
  var investorRefreshMessages = false;
  var investorTypingOnly = true;
  PostgresChangePayload? investorPayload;

  void bump({
    required bool investor,
    required bool includeMessages,
    PostgresChangePayload? payload,
  }) {
    if (investor) {
      if (!includeMessages) {
        investorRefreshList = true;
        investorPayload = payload;
        if (!_portalPayloadIsTypingOnly(
          payload: payload,
          investor: true,
          cached: ref.read(staffPortalConversationsProvider).valueOrNull,
        )) {
          investorTypingOnly = false;
        }
      } else {
        investorRefreshList = true;
        investorRefreshMessages = true;
        investorTypingOnly = false;
      }
    } else {
      if (!includeMessages) {
        clientRefreshList = true;
        clientPayload = payload;
        if (!_portalPayloadIsTypingOnly(
          payload: payload,
          investor: false,
          cached: ref.read(staffPortalConversationsProvider).valueOrNull,
        )) {
          clientTypingOnly = false;
        }
      } else {
        clientRefreshList = true;
        clientRefreshMessages = true;
        clientTypingOnly = false;
      }
    }

    final previous = investor ? investorDebounce : clientDebounce;
    previous?.cancel();
    final timer = Timer(const Duration(milliseconds: 450), () {
      if (disposed) return;
      final refreshList = investor ? investorRefreshList : clientRefreshList;
      final refreshMessages = investor
          ? investorRefreshMessages
          : clientRefreshMessages;
      final typingOnly = investor ? investorTypingOnly : clientTypingOnly;
      final rowPayload = investor ? investorPayload : clientPayload;
      if (investor) {
        investorRefreshList = false;
        investorRefreshMessages = false;
        investorTypingOnly = true;
        investorPayload = null;
      } else {
        clientRefreshList = false;
        clientRefreshMessages = false;
        clientTypingOnly = true;
        clientPayload = null;
      }
      try {
        final current = ref.read(staffPortalConversationsProvider);
        if (refreshList) {
          if (!current.hasValue) {
            // A typing or row echo must not cancel the first fetch.
          } else if (typingOnly && rowPayload != null) {
            _patchPortalPeerTyping(
              ref,
              payload: rowPayload,
              investor: investor,
            );
          } else {
            ref.invalidate(staffPortalConversationsProvider);
          }
        }
        if (refreshMessages) {
          ref.invalidate(staffPortalMessagesProvider);
        }
      } catch (_) {}
    });
    if (investor) {
      investorDebounce = timer;
    } else {
      clientDebounce = timer;
    }
  }

  final channel = client.channel('cshop-portal-messages')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_conversations',
      callback: (payload) =>
          bump(investor: false, includeMessages: false, payload: payload),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_conversation_messages',
      callback: (_) => bump(investor: false, includeMessages: true),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_conversations',
      callback: (payload) =>
          bump(investor: true, includeMessages: false, payload: payload),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_conversation_messages',
      callback: (_) => bump(investor: true, includeMessages: true),
    )
    ..subscribe();

  ref.onDispose(() {
    disposed = true;
    clientDebounce?.cancel();
    investorDebounce?.cancel();
    unawaited(client.removeChannel(channel));
  });
});

bool _portalPayloadIsTypingOnly({
  required PostgresChangePayload? payload,
  required bool investor,
  required List<StaffPortalConversation>? cached,
}) {
  if (payload == null || cached == null) return false;
  final row = payload.newRecord;
  final id = row['id']?.toString();
  if (id == null || id.isEmpty) return false;
  final kind = investor ? StaffPortalKind.investor : StaffPortalKind.client;
  StaffPortalConversation? match;
  for (final conversation in cached) {
    if (conversation.id == id && conversation.kind == kind) {
      match = conversation;
      break;
    }
  }
  if (match == null) return false;

  final status = row['status'] as String?;
  if (status != null && status != match.status) return false;

  if (row.containsKey('last_message_preview')) {
    final preview = row['last_message_preview'] as String?;
    if (preview != match.lastMessagePreview) return false;
  }

  if (row.containsKey('last_message_at') && row['last_message_at'] != null) {
    final next = DateTime.tryParse(row['last_message_at'].toString());
    final previous = match.lastMessageAt;
    if (next == null ||
        previous == null ||
        next.toUtc().difference(previous.toUtc()).inSeconds.abs() > 1) {
      return false;
    }
  }

  final unreadRaw = row['staff_unread_count'] ?? row['unread_count'];
  if (unreadRaw is num && unreadRaw.toInt() != match.unreadCount) {
    return false;
  }
  return true;
}

void _patchPortalPeerTyping(
  Ref ref, {
  required PostgresChangePayload payload,
  required bool investor,
}) {
  final row = payload.newRecord;
  final id = row['id']?.toString();
  if (id == null || id.isEmpty) return;
  final key = '${investor ? 'investor' : 'client'}:$id';
  DateTime? at;
  final meta = row['metadata'];
  if (meta is Map) {
    final raw = meta[investor ? 'investor_typing_at' : 'client_typing_at'];
    if (raw != null && raw.toString().isNotEmpty && raw.toString() != 'null') {
      at = DateTime.tryParse(raw.toString());
    }
  }
  final next = Map<String, DateTime?>.from(
    ref.read(portalPeerTypingAtProvider),
  );
  next[key] = at;
  ref.read(portalPeerTypingAtProvider.notifier).state = next;
}

/// Invalidates snapshot when queue-level CSHOP tables change.
/// Message bodies use session/ticket-scoped providers (quieter).
final cshopRealtimeProvider = Provider<void>((ref) {
  // Keep portal message delivery on its own channel.
  ref.watch(portalMessagesRealtimeProvider);
  if (!ref.watch(supabaseConfiguredProvider)) {
    Future.microtask(() {
      ref
          .read(supportRealtimeHealthProvider.notifier)
          .state = SupportRealtimeHealth(
        connection: SupportRealtimeConnection.disabled,
        message: 'Supabase is not configured.',
        changedAt: DateTime.now(),
      );
    });
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  var disposed = false;
  Timer? refreshDebounce;
  void refreshSnapshot() {
    refreshDebounce?.cancel();
    refreshDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!disposed) ref.invalidate(cshopSnapshotProvider);
    });
  }

  void updateHealth(SupportRealtimeConnection connection, {String? message}) {
    deferProviderMutation(() {
      if (disposed) return;
      ref
          .read(supportRealtimeHealthProvider.notifier)
          .state = SupportRealtimeHealth(
        connection: connection,
        message: message,
        changedAt: DateTime.now(),
      );
    });
  }

  updateHealth(SupportRealtimeConnection.connecting);
  final channel = client.channel('cshop-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tickets',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'live_chat_sessions',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'live_chat_messages',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_assignments',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_activity_logs',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_notifications',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_agents',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_categories',
      callback: (_) {
        ref.invalidate(supportTicketCategoriesProvider);
        refreshSnapshot();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'properties',
      callback: (_) {
        ref.invalidate(supportTicketPropertiesProvider);
        refreshSnapshot();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_knowledge_articles',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_escalations',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'whatsapp_messages',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_conversations',
      callback: (_) {
        refreshSnapshot();
        try {
          ref.invalidate(staffClientConversationsProvider);
          ref.read(clientMessagesTickProvider.notifier).state++;
        } catch (_) {}
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_conversation_messages',
      callback: (_) {
        try {
          ref.invalidate(staffClientConversationsProvider);
          ref.read(clientMessagesTickProvider.notifier).state++;
        } catch (_) {}
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_conversations',
      callback: (_) {
        refreshSnapshot();
        try {
          ref.read(investorMessagesTickProvider.notifier).state++;
        } catch (_) {}
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'investor_conversation_messages',
      callback: (_) {
        try {
          ref.read(investorMessagesTickProvider.notifier).state++;
        } catch (_) {}
      },
    )
    ..subscribe((status, [error]) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          updateHealth(SupportRealtimeConnection.connected);
        case RealtimeSubscribeStatus.channelError:
          updateHealth(
            SupportRealtimeConnection.error,
            message: 'Support realtime connection failed.',
          );
        case RealtimeSubscribeStatus.timedOut:
          updateHealth(
            SupportRealtimeConnection.error,
            message: 'Support realtime connection timed out.',
          );
        case RealtimeSubscribeStatus.closed:
          updateHealth(
            SupportRealtimeConnection.disconnected,
            message: 'Support realtime connection closed.',
          );
      }
    });

  ref.onDispose(() {
    disposed = true;
    refreshDebounce?.cancel();
    unawaited(client.removeChannel(channel));
    deferProviderMutation(
      () => ref.read(supportRealtimeHealthProvider.notifier).state =
          SupportRealtimeHealth(
            connection: SupportRealtimeConnection.disconnected,
            changedAt: DateTime.now(),
          ),
    );
  });
});

/// Admin: ticket thread messages (realtime, ticket-scoped).
final adminTicketMessagesProvider = FutureProvider.autoDispose
    .family<List<CshopTicketMessage>, String>((ref, ticketId) async {
      if (!ref.watch(supabaseConfiguredProvider)) return const [];
      final service = ref.watch(cshopServiceProvider);
      final client = ref.watch(supabaseClientProvider);
      final channel = client.channel('admin-ticket-$ticketId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: ticketId,
          ),
          callback: (_) => ref.invalidateSelf(),
        )
        ..subscribe();
      ref.onDispose(() {
        unawaited(client.removeChannel(channel));
      });
      return service.listTicketMessages(ticketId);
    });

enum CshopCommandTab {
  overview,
  tickets,
  inbox,
  liveChat,
  clientMessages,
  email,
  whatsapp,
  knowledge,
  sla,
  agents,
  analytics,
  ai,
  feedback;

  String get label => switch (this) {
    CshopCommandTab.overview => 'Overview',
    CshopCommandTab.tickets => 'Tickets',
    CshopCommandTab.inbox => 'Inbox',
    CshopCommandTab.liveChat => 'Live Chat',
    CshopCommandTab.clientMessages => 'Portal Messages',
    CshopCommandTab.email => 'Email',
    CshopCommandTab.whatsapp => 'WhatsApp',
    CshopCommandTab.knowledge => 'Knowledge',
    CshopCommandTab.sla => 'SLA',
    CshopCommandTab.agents => 'Agents',
    CshopCommandTab.analytics => 'Analytics',
    CshopCommandTab.ai => 'AI',
    CshopCommandTab.feedback => 'Feedback',
  };

  /// Primary desks shown in the Support shell.
  static const primary = <CshopCommandTab>[
    CshopCommandTab.tickets,
    CshopCommandTab.liveChat,
    CshopCommandTab.clientMessages,
  ];

  /// Secondary read-only / ops views (overflow menu).
  static List<CshopCommandTab> get more {
    final tabs = <CshopCommandTab>[
      CshopCommandTab.overview,
      CshopCommandTab.inbox,
      CshopCommandTab.knowledge,
      CshopCommandTab.sla,
      CshopCommandTab.agents,
      CshopCommandTab.analytics,
      CshopCommandTab.feedback,
    ];
    if (kAiFeaturesEnabled) tabs.add(CshopCommandTab.ai);
    return tabs;
  }
}

class CshopUiState {
  const CshopUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.channelFilter,
    this.selectedTab = CshopCommandTab.tickets,
    this.lastMessage,
    this.tickerIndex = 0,
    this.selectedTicketId,
    this.selectedLiveChatSessionId,
    this.selectedClientConversationId,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? channelFilter;
  final CshopCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;
  final String? selectedTicketId;
  final String? selectedLiveChatSessionId;
  final String? selectedClientConversationId;

  CshopUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? channelFilter,
    bool clearChannelFilter = false,
    CshopCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
    String? selectedTicketId,
    bool clearSelectedTicket = false,
    String? selectedLiveChatSessionId,
    bool clearSelectedLiveChat = false,
    String? selectedClientConversationId,
    bool clearSelectedClientConversation = false,
  }) {
    return CshopUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      channelFilter: clearChannelFilter
          ? null
          : (channelFilter ?? this.channelFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
      selectedTicketId: clearSelectedTicket
          ? null
          : (selectedTicketId ?? this.selectedTicketId),
      selectedLiveChatSessionId: clearSelectedLiveChat
          ? null
          : (selectedLiveChatSessionId ?? this.selectedLiveChatSessionId),
      selectedClientConversationId: clearSelectedClientConversation
          ? null
          : (selectedClientConversationId ?? this.selectedClientConversationId),
    );
  }
}

class CshopController extends Notifier<CshopUiState> {
  Timer? _tickerTimer;

  @override
  CshopUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(cshopRealtimeProvider);
    _armTicker();
    return const CshopUiState();
  }

  void _armTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      // Tickers may update state only inside Timer callbacks.
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? statusSlug) {
    if (statusSlug == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: statusSlug);
    }
  }

  void setChannelFilter(String? channel) {
    if (channel == null) {
      state = state.copyWith(clearChannelFilter: true);
    } else {
      state = state.copyWith(channelFilter: channel);
    }
  }

  void setTab(CshopCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectTicket(String? ticketId) {
    if (ticketId == null) {
      state = state.copyWith(clearSelectedTicket: true);
    } else {
      state = state.copyWith(selectedTicketId: ticketId);
    }
  }

  void selectLiveChatSession(String? sessionId) {
    if (sessionId == null) {
      state = state.copyWith(clearSelectedLiveChat: true);
    } else {
      state = state.copyWith(selectedLiveChatSessionId: sessionId);
    }
  }

  void selectClientConversation(String? conversationId) {
    if (conversationId == null) {
      state = state.copyWith(clearSelectedClientConversation: true);
    } else {
      state = state.copyWith(selectedClientConversationId: conversationId);
    }
  }

  /// Open Tickets / Live Chat / Portal Messages from a unified inbox row.
  void openInboxThread(CshopInboxThread thread) {
    final entityId = thread.entityId;
    if (entityId == null || entityId.isEmpty) return;

    if (thread.isTicket) {
      state = state.copyWith(
        selectedTab: CshopCommandTab.tickets,
        selectedTicketId: entityId,
      );
      return;
    }
    if (thread.isLiveChat) {
      state = state.copyWith(
        selectedTab: CshopCommandTab.liveChat,
        selectedLiveChatSessionId: entityId,
      );
      return;
    }
    if (thread.isPortalMessage) {
      final entityId = thread.entityId;
      if (entityId == null || entityId.isEmpty) return;
      final kind = thread.isPortalInvestor ? 'investor' : 'client';
      state = state.copyWith(
        selectedTab: CshopCommandTab.clientMessages,
        selectedClientConversationId: '$kind:$entityId',
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
    ref.invalidate(cshopSnapshotProvider);
  }

  List<CshopTicket> filteredTickets(CshopCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.tickets.where((t) {
      final statusFilter = state.statusFilter;
      if (statusFilter != null) {
        if (statusFilter == 'open') {
          if (t.status != 'open' && t.status != 'new') return false;
        } else if (t.status != statusFilter) {
          return false;
        }
      }
      if (state.channelFilter != null && t.channel != state.channelFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.subject.toLowerCase().contains(q) ||
          (t.ticketNumber?.toLowerCase().contains(q) ?? false) ||
          (t.customerName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<CshopInboxThread> filteredInbox(CshopCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.inbox.where((t) {
      if (state.channelFilter != null && t.channel != state.channelFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return t.title.toLowerCase().contains(q) ||
          (t.customerName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<CshopKnowledgeArticle> filteredKnowledge(
    CshopCommandCenterSnapshot snap,
  ) {
    final q = state.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return snap.knowledge;
    return snap.knowledge
        .where(
          (a) =>
              a.title.toLowerCase().contains(q) ||
              a.body.toLowerCase().contains(q) ||
              a.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }
}

final cshopControllerProvider = NotifierProvider<CshopController, CshopUiState>(
  CshopController.new,
);
