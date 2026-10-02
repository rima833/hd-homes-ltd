import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/construction/presentation/providers/construction_platform_providers.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/domain/entities/property_listings_insights.dart';
import 'package:hdhomesproject/features/cms/domain/services/cms_service.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Website CMS service provider — `null` client when Supabase isn't
/// configured, so pages can render a clear "not connected" empty state.
final cmsServiceProvider = Provider<CmsService>((ref) {
  final configured = ref.watch(supabaseConfiguredProvider);
  return CmsService(
    client: configured ? ref.watch(supabaseClientProvider) : null,
    mediaService: ref.watch(mediaServiceProvider),
  );
});

final cmsHomepageSectionsProvider = FutureProvider<List<CmsSectionRecord>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  final service = ref.watch(cmsServiceProvider);
  // Auto-seed missing keys and fill empty content so Admin always has
  // editable public copy without a manual sync click.
  try {
    return await service.ensureHomepageSections(fillEmptyContent: true);
  } catch (_) {
    return service.listHomepageSections();
  }
});

final cmsHeroProvider = FutureProvider.family<CmsHeroSection, String>((
  ref,
  pageKey,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) {
    return CmsHeroSection(pageKey: pageKey);
  }
  return ref.watch(cmsServiceProvider).getHero(pageKey: pageKey);
});

/// Published homepage hero for the public website (status = active only).
final publishedHomepageHeroProvider = FutureProvider<CmsHeroSection?>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  return ref.watch(cmsServiceProvider).getPublishedHero();
});

final cmsPagesProvider = FutureProvider<List<CmsPageRecord>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPages();
});

final cmsBannersProvider = FutureProvider<List<CmsBanner>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listBanners();
});

final cmsSeoProvider = FutureProvider<List<CmsSeoRecord>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.read(cmsServiceProvider).listSeo();
});

final cmsMediaFoldersProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listMediaFolders();
});

final cmsMediaProvider = FutureProvider.family<List<CmsMediaAsset>, String?>((
  ref,
  folder,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listMedia(folder: folder);
});

/// Property gallery images for admin management.
final propertyImagesProvider =
    FutureProvider.family<List<PropertyGalleryImage>, String>((
      ref,
      propertyId,
    ) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPropertyImages(propertyId);
    });

/// Realtime refresh for property gallery admin UI.
final propertyImagesRealtimeProvider = Provider.family<void, String>((
  ref,
  propertyId,
) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);

  void refresh() {
    Future.microtask(() {
      try {
        ref.invalidate(propertyImagesProvider(propertyId));
        ref.invalidate(publishedPropertyByIdProvider(propertyId));
        ref.invalidate(publishedPropertiesCatalogProvider);
      } catch (_) {}
    });
  }

  final channel = client.channel('property-gallery-$propertyId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_images',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'property_id',
        value: propertyId,
      ),
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) => refresh(),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Estate gallery images for admin management.
final estateImagesProvider =
    FutureProvider.family<List<EstateGalleryImage>, String>((
      ref,
      estateId,
    ) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listEstateImages(estateId);
    });

/// Realtime refresh for estate gallery admin UI.
final estateImagesRealtimeProvider = Provider.family<void, String>((
  ref,
  estateId,
) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);

  void refresh() {
    Future.microtask(() {
      try {
        ref.invalidate(estateImagesProvider(estateId));
        ref.invalidate(cmsEstatesProvider);
        ref.invalidate(publishedFeaturedEstatesProvider);
      } catch (_) {}
    });
  }

  final channel = client.channel('estate-gallery-$estateId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'estate_images',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'estate_id',
        value: estateId,
      ),
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) => refresh(),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final cmsBlogsProvider = FutureProvider<List<CmsBlogPost>>((ref) async {
  ref.watch(blogCmsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listBlogs();
});

final cmsBlogCategoriesProvider = FutureProvider<List<CmsBlogCategory>>((
  ref,
) async {
  ref.watch(blogCmsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listBlogCategories();
});

final cmsBlogAuthorsProvider = FutureProvider<List<CmsBlogAuthor>>((ref) async {
  ref.watch(blogCmsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listBlogAuthors();
});

final publishedBlogCategoriesProvider = FutureProvider<List<CmsBlogCategory>>((
  ref,
) async {
  ref.watch(blogCmsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedBlogCategories();
});

final publishedBlogAuthorsProvider = FutureProvider<List<CmsBlogAuthor>>((
  ref,
) async {
  ref.watch(blogCmsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listBlogAuthors();
});

/// Bumped by realtime (and admin saves) so blog list providers refetch.
final blogCmsTickProvider = StateProvider<int>((ref) => 0);

void bumpBlogCmsTick(Ref ref) {
  Future.microtask(() {
    try {
      ref.read(blogCmsTickProvider.notifier).state++;
    } catch (_) {}
  });
}

void bumpBlogCmsTickFromWidget(WidgetRef ref) {
  Future.microtask(() {
    try {
      ref.read(blogCmsTickProvider.notifier).state++;
    } catch (_) {}
  });
}

enum BlogCmsRealtimeState { offline, connecting, live, error }

final blogCmsRealtimeStateProvider = StateProvider<BlogCmsRealtimeState>(
  (ref) => BlogCmsRealtimeState.offline,
);

void _setBlogRealtime(Ref ref, BlogCmsRealtimeState value) {
  Future.microtask(() {
    try {
      ref.read(blogCmsRealtimeStateProvider.notifier).state = value;
    } catch (_) {}
  });
}

final blogCmsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) {
    _setBlogRealtime(ref, BlogCmsRealtimeState.offline);
    return;
  }
  final client = ref.watch(supabaseClientProvider);
  _setBlogRealtime(ref, BlogCmsRealtimeState.connecting);
  Timer? debounce;
  void refresh() {
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 400),
      () => bumpBlogCmsTick(ref),
    );
  }

  final token = client.auth.currentSession?.accessToken;
  if (token != null && token.isNotEmpty) {
    unawaited(client.realtime.setAuth(token));
  }

  final channel = client.channel('public:website-blog-cms')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blogs',
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blog_categories',
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blog_authors',
      callback: (_) => refresh(),
    )
    ..subscribe((status, _) {
      _setBlogRealtime(
        ref,
        switch (status) {
          RealtimeSubscribeStatus.subscribed => BlogCmsRealtimeState.live,
          RealtimeSubscribeStatus.timedOut ||
          RealtimeSubscribeStatus.channelError => BlogCmsRealtimeState.error,
          RealtimeSubscribeStatus.closed => BlogCmsRealtimeState.offline,
        },
      );
    });
  ref.onDispose(() {
    debounce?.cancel();
    _setBlogRealtime(ref, BlogCmsRealtimeState.offline);
    unawaited(client.removeChannel(channel));
  });
});

final cmsEstatesProvider = FutureProvider<List<CmsEstateSummary>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listEstates();
});

/// Published + featured estates for the public homepage.
final publishedFeaturedEstatesProvider = FutureProvider<List<CmsEstateSummary>>(
  (ref) async {
    if (!ref.watch(supabaseConfiguredProvider)) return [];
    return ref.watch(cmsServiceProvider).listPublishedFeaturedEstates();
  },
);

/// Published estates catalog (not featured-only) — public "Estates" listing.
final publishedEstatesCatalogProvider = FutureProvider<List<CmsEstateSummary>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedEstates();
});

/// Realtime invalidation for public estate catalog consumers (estates, gallery).
final publishedEstatesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('published-estates-catalog')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'estates',
      callback: (_) {
        ref.invalidate(publishedEstatesCatalogProvider);
        ref.invalidate(publishedFeaturedEstatesProvider);
        ref.invalidate(cmsEstatesProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'estate_images',
      callback: (_) {
        ref.invalidate(publishedEstatesCatalogProvider);
        ref.invalidate(publishedFeaturedEstatesProvider);
        ref.invalidate(cmsEstatesProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) {
        ref.invalidate(publishedEstatesCatalogProvider);
        ref.invalidate(publishedFeaturedEstatesProvider);
        ref.invalidate(cmsEstatesProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final cmsFeaturedPropertiesProvider =
    FutureProvider.family<List<CmsPropertyFeatured>, String?>((
      ref,
      search,
    ) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref
          .watch(cmsServiceProvider)
          .listFeaturedProperties(search: search);
    });

/// Published + featured properties for the public homepage.
final publishedFeaturedPropertiesProvider =
    FutureProvider<List<CmsPropertyFeatured>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedFeaturedProperties();
    });

/// Published properties catalog (not featured-only) — public "Properties"
/// marketplace.
final publishedPropertiesCatalogProvider =
    FutureProvider<List<CmsPropertyFeatured>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedProperties();
    });

/// Realtime invalidation for public property catalog consumers (home search,
/// marketplace, detail pages).
final publishedPropertiesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('published-properties-catalog')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'properties',
      callback: (_) {
        ref.invalidate(publishedPropertiesCatalogProvider);
        ref.invalidate(publishedFeaturedPropertiesProvider);
        ref.invalidate(publishedPropertyByIdProvider);
        ref.invalidate(cmsFeaturedPropertiesProvider);
        ref.invalidate(propertyListingsInsightsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_locations',
      callback: (_) {
        ref.invalidate(publishedPropertiesCatalogProvider);
        ref.invalidate(cmsFeaturedPropertiesProvider);
        ref.invalidate(propertyListingsInsightsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_pricing',
      callback: (_) {
        ref.invalidate(publishedPropertiesCatalogProvider);
        ref.invalidate(publishedPropertyByIdProvider);
        ref.invalidate(cmsFeaturedPropertiesProvider);
        ref.invalidate(propertyListingsInsightsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_images',
      callback: (_) {
        ref.invalidate(publishedPropertiesCatalogProvider);
        ref.invalidate(publishedFeaturedPropertiesProvider);
        ref.invalidate(publishedPropertyByIdProvider);
        ref.invalidate(cmsFeaturedPropertiesProvider);
        ref.invalidate(propertyListingsInsightsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) {
        ref.invalidate(publishedPropertiesCatalogProvider);
        ref.invalidate(publishedFeaturedPropertiesProvider);
        ref.invalidate(publishedPropertyByIdProvider);
        ref.invalidate(cmsFeaturedPropertiesProvider);
        ref.invalidate(propertyListingsInsightsProvider);
        ref.invalidate(publishedEstatesCatalogProvider);
        ref.invalidate(publishedFeaturedEstatesProvider);
        ref.invalidate(cmsEstatesProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_amenities',
      callback: (_) {
        ref.invalidate(publishedPropertiesCatalogProvider);
        ref.invalidate(cmsFeaturedPropertiesProvider);
        ref.invalidate(propertyListingsInsightsProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Single published property for public detail / Quick View (UUID or slug).
final publishedPropertyByIdProvider =
    FutureProvider.family<CmsPropertyFeatured?, String>((ref, idOrSlug) async {
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref.watch(cmsServiceProvider).getPublishedPropertyById(idOrSlug);
    });

final cmsTestimonialsProvider = FutureProvider<List<CmsTestimonial>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listTestimonials();
});

final cmsAwardsProvider = FutureProvider<List<CmsAward>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listAwards();
});

final cmsPartnersProvider = FutureProvider<List<CmsPartner>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPartners();
});

final cmsCompanyStatsProvider = FutureProvider<List<CmsCompanyStat>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listCompanyStats();
});

final cmsClientJourneyStepsProvider =
    FutureProvider<List<CmsClientJourneyStep>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listClientJourneySteps();
    });

final cmsJourneyBenefitsProvider = FutureProvider<List<CmsJourneyBenefit>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listJourneyBenefits();
});

final cmsOfficeLocationsProvider = FutureProvider<List<CmsOfficeLocation>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listOfficeLocations();
});

final publishedClientJourneyStepsProvider =
    FutureProvider<List<CmsClientJourneyStep>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedClientJourneySteps();
    });

final publishedJourneyBenefitsProvider =
    FutureProvider<List<CmsJourneyBenefit>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedJourneyBenefits();
    });

final publishedOfficeLocationsProvider =
    FutureProvider<List<CmsOfficeLocation>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedOfficeLocations();
    });

final cmsWebsiteInvestmentOpportunitiesProvider =
    FutureProvider<List<CmsWebsiteInvestmentOpportunity>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteInvestmentOpportunities();
    });

final publishedWebsiteInvestmentOpportunitiesProvider =
    FutureProvider<List<CmsWebsiteInvestmentOpportunity>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref
          .watch(cmsServiceProvider)
          .listPublishedWebsiteInvestmentOpportunities();
    });

final cmsWebsiteInvestmentCategoriesProvider =
    FutureProvider<List<CmsWebsiteInvestmentCategory>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteInvestmentCategories();
    });

final publishedWebsiteInvestmentCategoriesProvider =
    FutureProvider<List<CmsWebsiteInvestmentCategory>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref
          .watch(cmsServiceProvider)
          .listPublishedWebsiteInvestmentCategories();
    });

final cmsWebsiteMarketInsightsProvider =
    FutureProvider<List<CmsWebsiteMarketInsight>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteMarketInsights();
    });

final publishedWebsiteMarketInsightsProvider =
    FutureProvider<List<CmsWebsiteMarketInsight>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedWebsiteMarketInsights();
    });

final publishedWebsiteInvestmentBySlugProvider =
    FutureProvider.family<CmsWebsiteInvestmentOpportunity?, String>((
      ref,
      slug,
    ) async {
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref
          .watch(cmsServiceProvider)
          .getPublishedWebsiteInvestmentBySlug(slug);
    });

final cmsWebsiteConstructionUpdatesProvider =
    FutureProvider<List<CmsWebsiteConstructionUpdate>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listWebsiteConstructionUpdates();
    });

final publishedWebsiteConstructionUpdatesProvider =
    FutureProvider<List<CmsWebsiteConstructionUpdate>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref
          .watch(cmsServiceProvider)
          .listPublishedWebsiteConstructionUpdates();
    });

final publishedWebsiteConstructionBySlugProvider =
    FutureProvider.family<CmsWebsiteConstructionUpdate?, String>((
      ref,
      slug,
    ) async {
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref
          .watch(cmsServiceProvider)
          .getPublishedWebsiteConstructionBySlug(slug);
    });

final cmsDigitalCompanyProfileProvider =
    FutureProvider<CmsDigitalCompanyProfile?>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref.watch(cmsServiceProvider).getDigitalCompanyProfile();
    });

final publishedDigitalCompanyProfileProvider =
    FutureProvider<CmsDigitalCompanyProfile?>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref.watch(cmsServiceProvider).getPublishedDigitalCompanyProfile();
    });

final cmsTeamProvider = FutureProvider<List<CmsTeamMember>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listTeam();
});

final cmsFaqsProvider = FutureProvider<List<CmsFaq>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listFaqs();
});

final cmsMenuSectionsProvider = FutureProvider<List<CmsSectionRecord>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listMenuSections();
});

final cmsFooterSectionsProvider = FutureProvider<List<CmsSectionRecord>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listFooterSections();
});

final cmsCompanySettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return {};
  final bundle = await ref.watch(adminPlatformSettingsProvider.future);
  return bundle.toCompanyCompatibilityMap();
});

// ─── Public website published providers ───────────────────────────────────

final publishedHomepageSectionsProvider =
    FutureProvider<List<CmsSectionRecord>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedHomepageSections();
    });

final publishedTestimonialsProvider = FutureProvider<List<CmsTestimonial>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedTestimonials();
});

final publishedAwardsProvider = FutureProvider<List<CmsAward>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedAwards();
});

final publishedPartnersHomeProvider = FutureProvider<List<CmsPartner>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedPartners(forHome: true);
});

final publishedPartnersAboutProvider = FutureProvider<List<CmsPartner>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedPartners(forAbout: true);
});

/// Live refresh when partners change in Supabase.
final partnersRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:partners')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'partners',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsPartnersProvider);
            ref.invalidate(publishedPartnersHomeProvider);
            ref.invalidate(publishedPartnersAboutProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final publishedCompanyStatsHomeProvider = FutureProvider<List<CmsCompanyStat>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedCompanyStats(forHome: true);
});

final publishedCompanyStatsAboutProvider = FutureProvider<List<CmsCompanyStat>>(
  (ref) async {
    if (!ref.watch(supabaseConfiguredProvider)) return [];
    return ref
        .watch(cmsServiceProvider)
        .listPublishedCompanyStats(forAbout: true);
  },
);

final companyStatsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:company_statistics')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'company_statistics',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsCompanyStatsProvider);
            ref.invalidate(publishedCompanyStatsHomeProvider);
            ref.invalidate(publishedCompanyStatsAboutProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for client journey steps + benefits.
final clientJourneyRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:client-journey')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'client_journey_steps',
      callback: (_) {
        ref.invalidate(cmsClientJourneyStepsProvider);
        ref.invalidate(publishedClientJourneyStepsProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'journey_benefits',
      callback: (_) {
        ref.invalidate(cmsJourneyBenefitsProvider);
        ref.invalidate(publishedJourneyBenefitsProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for office locations.
final officeLocationsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:office-locations')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'office_locations',
      callback: (_) {
        ref.invalidate(cmsOfficeLocationsProvider);
        ref.invalidate(publishedOfficeLocationsProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for digital company profile.
final digitalCompanyProfileRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:digital-company-profile')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'digital_company_profile',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsDigitalCompanyProfileProvider);
            ref.invalidate(publishedDigitalCompanyProfileProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for website investment opportunities.
final websiteInvestmentOpportunitiesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  late final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return;
  }
  final channel = client.channel('public:website-investment-opps')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_investment_opportunities',
      callback: (_) {
        ref.invalidate(cmsWebsiteInvestmentOpportunitiesProvider);
        ref.invalidate(publishedWebsiteInvestmentOpportunitiesProvider);
        ref.invalidate(publishedWebsiteInvestmentBySlugProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for website investment categories.
final websiteInvestmentCategoriesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  late final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return;
  }
  final channel = client.channel('public:website-investment-categories')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_investment_categories',
      callback: (_) {
        ref.invalidate(cmsWebsiteInvestmentCategoriesProvider);
        ref.invalidate(publishedWebsiteInvestmentCategoriesProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for website market insights.
final websiteMarketInsightsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  late final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return;
  }
  final channel = client.channel('public:website-market-insights')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_market_insights',
      callback: (_) {
        ref.invalidate(cmsWebsiteMarketInsightsProvider);
        ref.invalidate(publishedWebsiteMarketInsightsProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Live refresh for website construction updates.
final websiteConstructionUpdatesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:website-construction-updates')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_construction_updates',
      callback: (_) {
        ref.invalidate(cmsWebsiteConstructionUpdatesProvider);
        ref.invalidate(publishedWebsiteConstructionUpdatesProvider);
        ref.invalidate(publicConstructionProjectsProvider);
        ref.invalidate(publicConstructionProjectBySlugProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'construction_update_media',
      callback: (_) {
        ref.invalidate(cmsWebsiteConstructionUpdatesProvider);
        ref.invalidate(publishedWebsiteConstructionUpdatesProvider);
        ref.invalidate(publicConstructionProjectsProvider);
        ref.invalidate(publicConstructionProjectBySlugProvider);
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) {
        ref.invalidate(cmsWebsiteConstructionUpdatesProvider);
        ref.invalidate(publishedWebsiteConstructionUpdatesProvider);
        ref.invalidate(publicConstructionProjectsProvider);
        ref.invalidate(publicConstructionProjectBySlugProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final publishedFaqsProvider = FutureProvider<List<CmsFaq>>((ref) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedFaqs(limit: 40);
});

final publishedTeamTickProvider = StateProvider<int>((ref) => 0);

final publishedTeamProvider = FutureProvider<List<CmsTeamMember>>((ref) async {
  ref.watch(publishedTeamTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedTeam();
});

/// Live refresh when public team metadata on `employees` changes.
final teamRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = Supabase.instance.client;
  final channel = client.channel('public:employees-team')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'employees',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsTeamProvider);
            ref.read(publishedTeamTickProvider.notifier).state++;
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final publishedActiveBannersProvider = FutureProvider<List<CmsBanner>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listActiveBanners();
});

final publishedBlogsProvider = FutureProvider<List<CmsBlogPost>>((ref) async {
  ref.watch(blogCmsTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedBlogs();
});

final publishedMenuSectionsProvider = FutureProvider<List<CmsSectionRecord>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedMenuSections();
});

final publishedFooterSectionsProvider = FutureProvider<List<CmsSectionRecord>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listPublishedFooterSections();
});

final publishedSeoByPathProvider = FutureProvider.family<CmsSeoRecord?, String>(
  (ref, path) async {
    if (!ref.watch(supabaseConfiguredProvider)) return null;
    return ref.watch(cmsServiceProvider).getSeoByPath(path);
  },
);

final publishedCompanySettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return {};
  final bundle = await ref.watch(publishedPlatformSettingsProvider.future);
  return bundle.toCompanyCompatibilityMap();
});

final publishedPagesTickProvider = StateProvider<int>((ref) => 0);

final publishedPagesRealtimeStatusProvider = StateProvider<bool>((ref) => false);

final publishedPageBySlugProvider =
    FutureProvider.family<CmsPageRecord?, String>((ref, slug) async {
      ref.watch(publishedPagesTickProvider);
      if (!ref.watch(supabaseConfiguredProvider)) return null;
      return ref.watch(cmsServiceProvider).getPublishedPageBySlug(slug);
    });

/// Published non-hub CMS pages for Trust → Legal document center.
final publishedLegalPagesProvider = FutureProvider<List<CmsPageRecord>>((
  ref,
) async {
  ref.watch(publishedPagesTickProvider);
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  final pages = await ref.watch(cmsServiceProvider).listPublishedPages();
  return pages
      .where(
        (page) => page.slug.isNotEmpty && !kPublicHubSlugs.contains(page.slug),
      )
      .toList();
});

/// Soft realtime for public CMS pages (About, hubs, legal pages…).
final publishedPagesRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('public-cms-pages')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'pages',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsPagesProvider);
            ref.read(publishedPagesTickProvider.notifier).state++;
          } catch (_) {}
        });
      },
    )
    ..subscribe((status, [error]) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      Future.microtask(() {
        try {
          ref.read(publishedPagesRealtimeStatusProvider.notifier).state = live;
        } catch (_) {}
      });
    });
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    Future.microtask(() {
      try {
        ref.read(publishedPagesRealtimeStatusProvider.notifier).state = false;
      } catch (_) {}
    });
  });
});

/// Views, inquiries, inspections, and performance for Property Listings.
final propertyListingsInsightsProvider =
    FutureProvider<PropertyListingsInsights>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) {
        return const PropertyListingsInsights();
      }
      return ref.watch(cmsServiceProvider).loadPropertyListingsInsights();
    });

/// Keeps listings insights fresh when engagement / inspection tables change.
final propertyListingsRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('property-listings-insights')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_views',
      callback: (_) => ref.invalidate(propertyListingsInsightsProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_analytics_daily',
      callback: (_) => ref.invalidate(propertyListingsInsightsProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_inspections',
      callback: (_) => ref.invalidate(propertyListingsInsightsProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'property_scores',
      callback: (_) => ref.invalidate(propertyListingsInsightsProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'leads',
      callback: (_) => ref.invalidate(propertyListingsInsightsProvider),
    )
    ..subscribe();

  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final cmsBrowseCategoriesProvider = FutureProvider<List<CmsBrowseCategory>>((
  ref,
) async {
  if (!ref.watch(supabaseConfiguredProvider)) return [];
  return ref.watch(cmsServiceProvider).listBrowseCategories();
});

final publishedBrowseCategoriesProvider =
    FutureProvider<List<CmsBrowseCategory>>((ref) async {
      if (!ref.watch(supabaseConfiguredProvider)) return [];
      return ref.watch(cmsServiceProvider).listPublishedBrowseCategories();
    });

final browseCategoriesRealtimeProvider = Provider<void>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('website-browse-categories')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'website_browse_categories',
      callback: (_) {
        ref.invalidate(cmsBrowseCategoriesProvider);
        ref.invalidate(publishedBrowseCategoriesProvider);
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// SEO metadata + company profile (stored in `seo_metadata`).
final cmsSeoRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-seo')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'seo_metadata',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsSeoProvider);
            ref.invalidate(cmsCompanySettingsProvider);
            ref.invalidate(publishedCompanySettingsProvider);
            ref.invalidate(publishedSeoByPathProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Testimonials realtime.
final testimonialsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-testimonials')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'testimonials',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsTestimonialsProvider);
            ref.invalidate(publishedTestimonialsProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Awards realtime.
final awardsRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-awards')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'awards',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsAwardsProvider);
            ref.invalidate(publishedAwardsProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Banners realtime.
final bannersRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-banners')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'banners',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsBannersProvider);
            ref.invalidate(publishedActiveBannersProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Menus realtime.
final menusRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-menus')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'cms_sections',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsMenuSectionsProvider);
            ref.invalidate(publishedMenuSectionsProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// Footer realtime.
final footerRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-footer')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'cms_sections',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsFooterSectionsProvider);
            ref.invalidate(publishedFooterSectionsProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

/// FAQ realtime.
final faqRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);
  final channel = client.channel('admin-cms-faq')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'faqs',
      callback: (_) {
        Future.microtask(() {
          try {
            ref.invalidate(cmsFaqsProvider);
            ref.invalidate(publishedFaqsProvider);
          } catch (_) {}
        });
      },
    )
    ..subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
  });
});

final cmsMediaRealtimeStatusProvider = StateProvider<bool>((ref) => false);

/// Media library folders and assets. Listens to base tables only —
/// `media_library` is a view and cannot carry realtime events.
final cmsMediaRealtimeProvider = Provider<void>((ref) {
  ref.keepAlive();
  if (!ref.watch(supabaseConfiguredProvider)) return;
  final client = ref.watch(supabaseClientProvider);

  void refresh() {
    Future.microtask(() {
      try {
        ref.invalidate(cmsMediaFoldersProvider);
        ref.invalidate(cmsMediaProvider);
      } catch (_) {}
    });
  }

  final channel = client.channel('admin-cms-media')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media',
      callback: (_) => refresh(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'media_folders',
      callback: (_) => refresh(),
    )
    ..subscribe((status, [error]) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      Future.microtask(() {
        try {
          ref.read(cmsMediaRealtimeStatusProvider.notifier).state = live;
        } catch (_) {}
      });
    });
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    Future.microtask(() {
      try {
        ref.read(cmsMediaRealtimeStatusProvider.notifier).state = false;
      } catch (_) {}
    });
  });
});
