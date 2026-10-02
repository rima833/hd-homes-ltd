import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/utils/provider_lifecycle.dart';
import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:hdhomesproject/features/biadw/domain/services/biadw_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final biadwServiceProvider = Provider<BiadwService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return BiadwService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
  );
});

final biadwLastSyncProvider = StateProvider<DateTime?>((ref) => null);

final biadwSnapshotProvider = FutureProvider<BiadwCommandCenterSnapshot>((
  ref,
) async {
  final snapshot = await ref.watch(biadwServiceProvider).loadCommandCenter();
  deferProviderMutation(
    () => ref.read(biadwLastSyncProvider.notifier).state = snapshot.loadedAt,
  );
  return snapshot;
});

final biadwRealtimeConnectedProvider = StateProvider<bool>((ref) => false);

/// Canonical source tables read by `get_admin_operational_analytics`.
const biadwOperationalSourceTables = <String>[
  'crm_leads',
  'clients',
  'payments',
  'client_property_applications',
  'property_inspections',
  'construction_projects',
  'tickets',
  'properties',
  'investors',
];

/// Keeps the operational snapshot current when any RPC source table changes.
final biadwRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) {
    deferProviderMutation(
      () => ref.read(biadwRealtimeConnectedProvider.notifier).state = false,
    );
    return;
  }

  final client = ref.watch(supabaseClientProvider);
  Timer? debounce;
  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      deferProviderMutation(() => ref.invalidate(biadwSnapshotProvider));
    });
  }

  var channel = client.channel('admin-operational-analytics');
  for (final table in biadwOperationalSourceTables) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => refresh(),
    );
  }

  final token = client.auth.currentSession?.accessToken;
  if (token != null && token.isNotEmpty) {
    unawaited(client.realtime.setAuth(token));
  }
  channel.subscribe((status, [error]) {
    deferProviderMutation(
      () => ref.read(biadwRealtimeConnectedProvider.notifier).state =
          status == RealtimeSubscribeStatus.subscribed,
    );
  });

  ref.onDispose(() {
    debounce?.cancel();
    deferProviderMutation(
      () => ref.read(biadwRealtimeConnectedProvider.notifier).state = false,
    );
    unawaited(client.removeChannel(channel));
  });
});

enum BiadwCommandTab {
  overview,
  searchInsights,
  personalization;

  String get label => switch (this) {
    BiadwCommandTab.overview => 'Overview',
    BiadwCommandTab.searchInsights => 'Search Insights',
    BiadwCommandTab.personalization => 'Personalization',
  };
}

class BiadwController extends Notifier<BiadwCommandTab> {
  @override
  BiadwCommandTab build() {
    ref.watch(biadwRealtimeProvider);
    return BiadwCommandTab.overview;
  }

  void setTab(BiadwCommandTab tab) => state = tab;

  void refresh() => ref.invalidate(biadwSnapshotProvider);
}

final biadwControllerProvider =
    NotifierProvider<BiadwController, BiadwCommandTab>(BiadwController.new);
