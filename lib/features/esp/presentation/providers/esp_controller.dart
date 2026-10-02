import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/esp/domain/entities/esp_models.dart';
import 'package:hdhomesproject/features/esp/domain/services/esp_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final espServiceProvider = Provider<EspService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return EspService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final espSnapshotProvider = FutureProvider<EspCommandCenterSnapshot>((ref) {
  return ref.watch(espServiceProvider).loadCommandCenter();
});

final espRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('security-command-center');
  for (final table in const [
    'security_alerts',
    'threat_detections',
    'security_incidents',
    'security_events',
    'security_activity_logs',
    'security_notifications',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => ref.invalidate(espSnapshotProvider),
    );
  }
  channel.subscribe();
  ref.onDispose(() => unawaited(client.removeChannel(channel)));
});

enum EspCommandTab {
  overview,
  iam,
  mfa,
  threats,
  incidents,
  audit,
  privacy,
  secrets,
  backup,
  dr,
  analytics,
  ai;

  String get label => switch (this) {
    overview => 'Overview',
    iam => 'IAM',
    mfa => 'MFA',
    threats => 'Threats',
    incidents => 'Incidents',
    audit => 'Audit',
    privacy => 'Privacy',
    secrets => 'Secrets',
    backup => 'Backup',
    dr => 'DR',
    analytics => 'Analytics',
    ai => 'AI',
  };
}

class EspUiState {
  const EspUiState({
    this.searchQuery = '',
    this.severityFilter,
    this.selectedTab = EspCommandTab.overview,
    this.tickerIndex = 0,
  });
  final String searchQuery;
  final EspSeverity? severityFilter;
  final EspCommandTab selectedTab;
  final int tickerIndex;

  EspUiState copyWith({
    String? searchQuery,
    EspSeverity? severityFilter,
    bool clearSeverity = false,
    EspCommandTab? selectedTab,
    int? tickerIndex,
  }) => EspUiState(
    searchQuery: searchQuery ?? this.searchQuery,
    severityFilter: clearSeverity
        ? null
        : (severityFilter ?? this.severityFilter),
    selectedTab: selectedTab ?? this.selectedTab,
    tickerIndex: tickerIndex ?? this.tickerIndex,
  );
}

class EspController extends Notifier<EspUiState> {
  Timer? _ticker;

  @override
  EspUiState build() {
    // Never read state in build: ticker begins from EspUiState defaults.
    ref.watch(espRealtimeProvider);
    ref.onDispose(() => _ticker?.cancel());
    _ticker = Timer.periodic(const Duration(seconds: 4), (_) {
      state = state.copyWith(tickerIndex: state.tickerIndex + 1);
    });
    return const EspUiState();
  }

  void setTab(EspCommandTab value) =>
      state = state.copyWith(selectedTab: value);
  void setSearch(String value) => state = state.copyWith(searchQuery: value);
  void setSeverity(EspSeverity? value) => state = value == null
      ? state.copyWith(clearSeverity: true)
      : state.copyWith(severityFilter: value);
  Future<void> refresh() async => ref.invalidate(espSnapshotProvider);

  List<EspRecord> filter(List<EspRecord> records) {
    final q = state.searchQuery.trim().toLowerCase();
    return records.where((record) {
      if (state.severityFilter != null &&
          record.severity != state.severityFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return record.title.toLowerCase().contains(q) ||
          record.category.toLowerCase().contains(q) ||
          record.summary.toLowerCase().contains(q);
    }).toList();
  }
}

final espControllerProvider = NotifierProvider<EspController, EspUiState>(
  EspController.new,
);
