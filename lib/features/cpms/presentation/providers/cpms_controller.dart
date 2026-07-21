import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/domain/services/cpms_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final cpmsServiceProvider = Provider<CpmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CpmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final cpmsSnapshotProvider =
    FutureProvider<CpmsCommandCenterSnapshot>((ref) async {
  return ref.watch(cpmsServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when CPMS live tables change (after SQL apply + Realtime).
final cpmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('cpms-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_projects',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_milestones',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_tasks',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_change_orders',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_safety_incidents',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_site_diaries',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'project_activity_logs',
      callback: (_) => ref.invalidate(cpmsSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum CpmsCommandTab {
  overview,
  projects,
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
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
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
}

final cpmsControllerProvider =
    NotifierProvider<CpmsController, CpmsUiState>(CpmsController.new);
