import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/domain/services/cpms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cpmsServiceProvider = Provider<CpmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CpmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final cpmsSnapshotProvider = FutureProvider<CpmsCommandCenterSnapshot>((
  ref,
) async {
  return ref.watch(cpmsServiceProvider).loadCommandCenter();
});

final cpmsRealtimeStatusProvider = StateProvider<bool>((ref) => false);

/// Invalidates snapshot when CPMS live tables change (after SQL apply + Realtime).
final cpmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  deferProviderMutation(
    () => ref.read(cpmsRealtimeStatusProvider.notifier).state = false,
  );

  void bump() {
    deferProviderMutation(() {
      ref.invalidate(cpmsSnapshotProvider);
      ref.read(cpmsRealtimeStatusProvider.notifier).state = true;
    });
  }

  final channel = client.channel('cpms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_projects',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_milestones',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_tasks',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_change_orders',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_defects',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_contractors',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_budget_lines',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_procurement_requests',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_quality_checks',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_inspections',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_risk_register',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_notifications',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_safety_incidents',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_site_diaries',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_activity_logs',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_construction_updates',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_updates',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_photos',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_progress_updates',
      callback: (_) => bump(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_update_media',
      callback: (_) => bump(),
    )
    ..subscribe((status, [error]) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      deferProviderMutation(() {
        ref.read(cpmsRealtimeStatusProvider.notifier).state = live;
      });
    });

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    deferProviderMutation(() {
      ref.read(cpmsRealtimeStatusProvider.notifier).state = false;
    });
  });
});

enum CpmsCommandTab {
  overview,
  projects,
  liveFeed,
  milestones,
  tasks,
  procurement,
  budget,
  quality,
  safety,
  diary,
  ai,
  wizard;

  String get label => switch (this) {
    CpmsCommandTab.overview => 'Overview',
    CpmsCommandTab.projects => 'Projects',
    CpmsCommandTab.liveFeed => 'Updates',
    CpmsCommandTab.milestones => 'Milestones',
    CpmsCommandTab.tasks => 'Tasks',
    CpmsCommandTab.procurement => 'Procurement',
    CpmsCommandTab.budget => 'Budget',
    CpmsCommandTab.quality => 'Quality',
    CpmsCommandTab.safety => 'Safety',
    CpmsCommandTab.diary => 'Site Diary',
    CpmsCommandTab.ai => 'AI Twin',
    CpmsCommandTab.wizard => 'Wizard',
  };
}

class CpmsUiState {
  const CpmsUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = CpmsCommandTab.overview,
    this.selectedProjectId,
    this.wizard = const CpmsWizardDraft(),
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final CpmsCommandTab selectedTab;
  final String? selectedProjectId;
  final CpmsWizardDraft wizard;
  final String? lastMessage;
  final int tickerIndex;

  CpmsUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    CpmsCommandTab? selectedTab,
    String? selectedProjectId,
    bool clearSelectedProject = false,
    CpmsWizardDraft? wizard,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return CpmsUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      selectedProjectId: clearSelectedProject
          ? null
          : (selectedProjectId ?? this.selectedProjectId),
      wizard: wizard ?? this.wizard,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class CpmsController extends Notifier<CpmsUiState> {
  Timer? _tickerTimer;

  @override
  CpmsUiState build() {
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(cpmsRealtimeProvider);
    _armTicker();
    return const CpmsUiState();
  }

  void _armTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
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

  void setTab(CpmsCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectProject(String? projectId) {
    if (projectId == null) {
      state = state.copyWith(clearSelectedProject: true);
    } else {
      state = state.copyWith(
        selectedProjectId: projectId,
        selectedTab: CpmsCommandTab.projects,
      );
    }
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  void updateWizard(CpmsWizardDraft draft) {
    state = state.copyWith(wizard: draft);
  }

  void wizardNext() {
    state = state.copyWith(wizard: state.wizard.next());
  }

  void wizardPrevious() {
    state = state.copyWith(wizard: state.wizard.previous());
  }

  void wizardReset() {
    state = state.copyWith(wizard: const CpmsWizardDraft());
  }

  Future<void> refresh() async {
    ref.invalidate(cpmsSnapshotProvider);
  }

  List<CpmsProject> filteredProjects(CpmsCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.projects.where((p) {
      if (state.statusFilter != null && p.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.projectCode.toLowerCase().contains(q) ||
          (p.locationLabel?.toLowerCase().contains(q) ?? false) ||
          (p.managerLabel?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  CpmsProject? selectedProject(CpmsCommandCenterSnapshot snap) {
    final id = state.selectedProjectId;
    if (id == null) {
      return snap.projects.isEmpty ? null : snap.projects.first;
    }
    for (final p in snap.projects) {
      if (p.id == id) return p;
    }
    return snap.projects.isEmpty ? null : snap.projects.first;
  }

  bool tabUsesProjectScope(CpmsCommandTab tab) => switch (tab) {
    CpmsCommandTab.liveFeed ||
    CpmsCommandTab.milestones ||
    CpmsCommandTab.tasks ||
    CpmsCommandTab.procurement ||
    CpmsCommandTab.budget ||
    CpmsCommandTab.quality ||
    CpmsCommandTab.safety ||
    CpmsCommandTab.diary => true,
    _ => false,
  };

  void setProjectScope(String? projectId) {
    if (projectId == null) {
      state = state.copyWith(clearSelectedProject: true);
    } else {
      state = state.copyWith(selectedProjectId: projectId);
    }
  }

  List<T> scopedByProject<T>(List<T> items, String? Function(T) projectId) {
    final id = state.selectedProjectId;
    if (id == null) return items;
    return items.where((item) => projectId(item) == id).toList();
  }

  List<CpmsBudgetSummary> scopedBudgetSummaries(
    CpmsCommandCenterSnapshot snap,
  ) {
    final summaries = snap.budgetSummaries();
    final id = state.selectedProjectId;
    if (id == null) return summaries;
    return summaries.where((s) => s.projectId == id).toList();
  }
}

final cpmsControllerProvider = NotifierProvider<CpmsController, CpmsUiState>(
  CpmsController.new,
);
