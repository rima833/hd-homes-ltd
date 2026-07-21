import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/services/cshop_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cshopServiceProvider = Provider<CshopService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CshopService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final cshopSnapshotProvider =
    FutureProvider<CshopCommandCenterSnapshot>((ref) async {
  return ref.watch(cshopServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when CSHOP live tables change (after SQL apply + Realtime).
final cshopRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('cshop-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tickets',
      callback: (_) => ref.invalidate(cshopSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'live_chat_messages',
      callback: (_) => ref.invalidate(cshopSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_activity_logs',
      callback: (_) => ref.invalidate(cshopSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'support_notifications',
      callback: (_) => ref.invalidate(cshopSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'whatsapp_messages',
      callback: (_) => ref.invalidate(cshopSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum CshopCommandTab {
  overview,
  tickets,
  inbox,
  liveChat,
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
        CshopCommandTab.email => 'Email',
        CshopCommandTab.whatsapp => 'WhatsApp',
        CshopCommandTab.knowledge => 'Knowledge',
        CshopCommandTab.sla => 'SLA',
        CshopCommandTab.agents => 'Agents',
        CshopCommandTab.analytics => 'Analytics',
        CshopCommandTab.ai => 'AI',
        CshopCommandTab.feedback => 'Feedback',
      };
}

class CshopUiState {
  const CshopUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.channelFilter,
    this.selectedTab = CshopCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final String? channelFilter;
  final CshopCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

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
  }) {
    return CshopUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      channelFilter:
          clearChannelFilter ? null : (channelFilter ?? this.channelFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
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
      if (state.statusFilter != null && t.status != state.statusFilter) {
        return false;
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

final cshopControllerProvider =
    NotifierProvider<CshopController, CshopUiState>(CshopController.new);
