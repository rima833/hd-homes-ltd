import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final dxpServiceProvider = Provider<DxpService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return DxpService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final dxpSnapshotProvider =
    FutureProvider<DxpCommandCenterSnapshot>((ref) async {
  return ref.watch(dxpServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when DXP live tables change (after SQL apply + Realtime).
final dxpRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('dxp-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'landing_pages',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'forms',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'form_submissions',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'campaigns',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'email_campaigns',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'content_calendar',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'marketing_activity_logs',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blogs',
      callback: (_) => ref.invalidate(dxpSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum DxpCommandTab {
  overview,
  pages,
  landing,
  blog,
  media,
  campaigns,
  forms,
  seo,
  calendar,
  ai;

  String get label => switch (this) {
        DxpCommandTab.overview => 'Overview',
        DxpCommandTab.pages => 'Pages',
        DxpCommandTab.landing => 'Landing',
        DxpCommandTab.blog => 'Blog',
        DxpCommandTab.media => 'Media',
        DxpCommandTab.campaigns => 'Campaigns',
        DxpCommandTab.forms => 'Forms',
        DxpCommandTab.seo => 'SEO',
        DxpCommandTab.calendar => 'Calendar',
        DxpCommandTab.ai => 'AI Studio',
      };
}

class DxpUiState {
  const DxpUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = DxpCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final DxpCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  DxpUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    DxpCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return DxpUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class DxpController extends Notifier<DxpUiState> {
  Timer? _tickerTimer;

  @override
  DxpUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(dxpRealtimeProvider);
    _armTicker();
    return const DxpUiState();
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

  void setTab(DxpCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(dxpSnapshotProvider);
  }

  List<DxpCampaign> filteredCampaigns(DxpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.campaigns.where((c) {
      if (state.statusFilter != null && c.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.channel.toLowerCase().contains(q) ||
          (c.campaignCode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<DxpLandingPage> filteredLanding(DxpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.landingPages.where((p) {
      if (state.statusFilter != null && p.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          p.slug.toLowerCase().contains(q);
    }).toList();
  }

  List<DxpBlogPost> filteredBlogs(DxpCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.blogPosts.where((b) {
      if (state.statusFilter != null && b.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return b.title.toLowerCase().contains(q) ||
          b.slug.toLowerCase().contains(q);
    }).toList();
  }
}

final dxpControllerProvider =
    NotifierProvider<DxpController, DxpUiState>(DxpController.new);
