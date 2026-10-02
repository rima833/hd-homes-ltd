import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/construction/domain/entities/construction_platform_models.dart';
import 'package:hdhomesproject/features/construction/domain/services/construction_platform_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final constructionPlatformServiceProvider =
    Provider<ConstructionPlatformService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return ConstructionPlatformService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
    mediaService: ref.watch(mediaServiceProvider),
  );
});

final publicConstructionProjectsProvider =
    FutureProvider<List<ConstructionProjectPublic>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(constructionPlatformServiceProvider).listPublicProjects();
});

final publicConstructionProjectBySlugProvider =
    FutureProvider.family<ConstructionProjectPublic?, String>((ref, slug) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref
      .watch(constructionPlatformServiceProvider)
      .getPublicProjectBySlug(slug);
});

/// Admin feed of unified construction progress updates (draft + published).
final adminConstructionUpdatesProvider =
    FutureProvider.family<List<ConstructionProgressUpdate>, String?>(
        (ref, projectId) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(constructionPlatformServiceProvider).listAllUpdates(
        projectId: projectId,
        publishedOnly: false,
      );
});

/// Realtime hub — invalidates public construction providers on DB changes.
final constructionPlatformRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;

  void invalidateAll() {
    ref.invalidate(publicConstructionProjectsProvider);
    // Family providers re-fetch when slug pages are open.
    ref.invalidate(publicConstructionProjectBySlugProvider);
    ref.invalidate(adminConstructionUpdatesProvider);
  }

  final channel = client.channel('public:construction-platform')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_projects',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_progress_updates',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_update_media',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_construction_updates',
      callback: (_) => invalidateAll(),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});
