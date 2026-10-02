import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/dxp/domain/entities/dxp_models.dart';
import 'package:hdhomesproject/features/dxp/domain/services/dxp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final dxpServiceProvider = Provider<DxpService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return DxpService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final dxpSnapshotProvider = FutureProvider<DxpCommandCenterSnapshot>((
  ref,
) async {
  return ref.watch(dxpServiceProvider).loadCommandCenter();
});

/// Published marketing landing for public `/lp/:slug`.
final publishedLandingBySlugProvider =
    FutureProvider.family<DxpLandingPage?, String>((ref, slug) async {
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref.watch(dxpServiceProvider).getPublishedLandingBySlug(slug);
    });

/// True only after Supabase confirms the Realtime channel subscription.
final dxpRealtimeConnectedProvider = StateProvider<bool>((ref) => false);

/// Invalidates snapshot when DXP live tables change (after SQL apply + Realtime).
final dxpRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) {
    deferProviderMutation(
      () => ref.read(dxpRealtimeConnectedProvider.notifier).state = false,
    );
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  void refreshSnapshot() =>
      deferProviderMutation(() => ref.invalidate(dxpSnapshotProvider));
  void refreshLandingPages() => deferProviderMutation(() {
    ref.invalidate(dxpSnapshotProvider);
    ref.invalidate(publishedLandingBySlugProvider);
  });

  final channel = client.channel('dxp-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'landing_pages',
      callback: (_) => refreshLandingPages(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'forms',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'form_submissions',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'campaigns',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'email_campaigns',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'content_calendar',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'marketing_activity_logs',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blogs',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pages',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'seo_metadata',
      callback: (_) => refreshSnapshot(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'crm_leads',
      callback: (_) => refreshSnapshot(),
    )
    ..subscribe((status, [error]) {
      deferProviderMutation(
        () => ref.read(dxpRealtimeConnectedProvider.notifier).state =
            status == RealtimeSubscribeStatus.subscribed,
      );
    });

  ref.onDispose(() {
    deferProviderMutation(() {
      ref.read(dxpRealtimeConnectedProvider.notifier).state = false;
    });
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
  calendar;

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
  };
}

class DxpUiState {
  const DxpUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = DxpCommandTab.overview,
    this.lastMessage,
  });

  final String searchQuery;
  final String? statusFilter;
  final DxpCommandTab selectedTab;
  final String? lastMessage;

  DxpUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    DxpCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
  }) {
    return DxpUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }
}

class DxpController extends Notifier<DxpUiState> {
  @override
  DxpUiState build() {
    ref.watch(dxpRealtimeProvider);
    return const DxpUiState();
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

final dxpControllerProvider = NotifierProvider<DxpController, DxpUiState>(
  DxpController.new,
);
