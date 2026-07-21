import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/hcm/domain/entities/hcm_models.dart';
import 'package:hdhomesproject/features/hcm/domain/services/hcm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final hcmServiceProvider = Provider<HcmService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return HcmService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final hcmSnapshotProvider =
    FutureProvider<HcmCommandCenterSnapshot>((ref) async {
  return ref.watch(hcmServiceProvider).loadCommandCenter();
});

/// Invalidates snapshot when HCM live tables change (after SQL apply + Realtime).
final hcmRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('hcm-command-center')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'attendance_records',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'leave_requests',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'job_postings',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'interviews',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hr_announcements',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hr_activity_logs',
      callback: (_) => ref.invalidate(hcmSnapshotProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

enum HcmCommandTab {
  overview,
  directory,
  recruitment,
  attendance,
  leave,
  performance,
  training,
  assets,
  announcements,
  ai;

  String get label => switch (this) {
        HcmCommandTab.overview => 'Overview',
        HcmCommandTab.directory => 'Directory',
        HcmCommandTab.recruitment => 'Recruitment',
        HcmCommandTab.attendance => 'Attendance',
        HcmCommandTab.leave => 'Leave',
        HcmCommandTab.performance => 'Performance',
        HcmCommandTab.training => 'Training',
        HcmCommandTab.assets => 'Assets',
        HcmCommandTab.announcements => 'Announcements',
        HcmCommandTab.ai => 'AI / CHRO',
      };
}

class HcmUiState {
  const HcmUiState({
    this.searchQuery = '',
    this.statusFilter,
    this.selectedTab = HcmCommandTab.overview,
    this.lastMessage,
    this.tickerIndex = 0,
  });

  final String searchQuery;
  final String? statusFilter;
  final HcmCommandTab selectedTab;
  final String? lastMessage;
  final int tickerIndex;

  HcmUiState copyWith({
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    HcmCommandTab? selectedTab,
    String? lastMessage,
    bool clearMessage = false,
    int? tickerIndex,
  }) {
    return HcmUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      selectedTab: selectedTab ?? this.selectedTab,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      tickerIndex: tickerIndex ?? this.tickerIndex,
    );
  }
}

class HcmController extends Notifier<HcmUiState> {
  Timer? _tickerTimer;

  @override
  HcmUiState build() {
    // CRITICAL: never read `state` here — arm ticker from initial constants only.
    ref.onDispose(() => _tickerTimer?.cancel());
    ref.watch(hcmRealtimeProvider);
    _armTicker();
    return const HcmUiState();
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

  void setTab(HcmCommandTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setMessage(String message) {
    state = state.copyWith(lastMessage: message);
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  Future<void> refresh() async {
    ref.invalidate(hcmSnapshotProvider);
  }

  List<HcmEmployee> filteredEmployees(HcmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.employees.where((e) {
      if (state.statusFilter != null && e.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.fullName.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q) ||
          (e.jobTitle?.toLowerCase().contains(q) ?? false) ||
          (e.departmentName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<HcmApplicant> filteredApplicants(HcmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.applicants.where((a) {
      if (state.statusFilter != null && a.stage.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return a.fullName.toLowerCase().contains(q) ||
          (a.email?.toLowerCase().contains(q) ?? false) ||
          (a.source?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<HcmLeaveRequest> filteredLeave(HcmCommandCenterSnapshot snap) {
    final q = state.searchQuery.trim().toLowerCase();
    return snap.leaveRequests.where((l) {
      if (state.statusFilter != null && l.status.slug != state.statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return (l.employeeName?.toLowerCase().contains(q) ?? false) ||
          l.leaveType.toLowerCase().contains(q) ||
          (l.reason?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

final hcmControllerProvider =
    NotifierProvider<HcmController, HcmUiState>(HcmController.new);
