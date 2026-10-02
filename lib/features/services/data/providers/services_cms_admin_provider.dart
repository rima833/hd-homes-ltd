import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bumped by realtime (and admin saves) so list providers refetch without cycles.
final servicesCmsTickProvider = StateProvider<int>((ref) => 0);

void bumpServicesCmsTick(Ref ref) {
  ref.read(servicesCmsTickProvider.notifier).state++;
}

void bumpServicesCmsTickFromWidget(WidgetRef ref) {
  ref.read(servicesCmsTickProvider.notifier).state++;
}

final servicesCmsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:website-services-cms')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_service_categories',
      callback: (_) => bumpServicesCmsTick(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_service_items',
      callback: (_) => bumpServicesCmsTick(ref),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_service_case_studies',
      callback: (_) => bumpServicesCmsTick(ref),
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final cmsWebsiteServiceCategoriesProvider =
    FutureProvider<List<CmsWebsiteServiceCategory>>((ref) async {
      ref.watch(servicesCmsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteServiceCategories();
    });

final cmsWebsiteServiceItemsProvider =
    FutureProvider<List<CmsWebsiteServiceItem>>((ref) async {
      ref.watch(servicesCmsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteServiceItems();
    });

final cmsWebsiteServiceCaseStudiesProvider =
    FutureProvider<List<CmsWebsiteServiceCaseStudy>>((ref) async {
      ref.watch(servicesCmsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteServiceCaseStudies();
    });

final publishedWebsiteServiceCategoriesProvider =
    FutureProvider<List<CmsWebsiteServiceCategory>>((ref) async {
      ref.watch(servicesCmsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref
          .watch(cmsServiceProvider)
          .listPublishedWebsiteServiceCategories();
    });

final publishedWebsiteServiceItemsProvider =
    FutureProvider<List<CmsWebsiteServiceItem>>((ref) async {
      ref.watch(servicesCmsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedWebsiteServiceItems();
    });

final publishedWebsiteServiceCaseStudiesProvider =
    FutureProvider<List<CmsWebsiteServiceCaseStudy>>((ref) async {
      ref.watch(servicesCmsTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref
          .watch(cmsServiceProvider)
          .listPublishedWebsiteServiceCaseStudies();
    });
