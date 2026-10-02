import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/app_theme.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/media/data/providers/media_cms_provider.dart';
import 'package:hdhomesproject/features/media/presentation/pages/media_center_hub_page.dart';
import 'package:hdhomesproject/features/media/presentation/pages/media_experience_page.dart';

void main() {
  test('buildMediaGalleryCatalog maps published estate and property photos', () {
    final catalog = buildMediaGalleryCatalog(
      estates: const [
        CmsEstateSummary(
          id: 'e1',
          name: 'Lekki Gardens',
          slug: 'lekki-gardens',
          city: 'Lagos',
          coverImageUrl: 'https://cdn.example/estate-cover.jpg',
          galleryUrls: ['https://cdn.example/estate-cover.jpg', 'https://cdn.example/estate-2.jpg'],
          isPublished: true,
          isFeatured: true,
        ),
      ],
      properties: const [
        CmsPropertyFeatured(
          id: 'p1',
          title: '4 Bedroom Duplex',
          slug: '4-bedroom-duplex',
          estateName: 'Lekki Gardens',
          coverImageUrl: 'https://cdn.example/prop-cover.jpg',
          galleryUrls: ['https://cdn.example/prop-cover.jpg'],
          isPublished: true,
          isFeatured: true,
        ),
      ],
    );

    expect(catalog.map((e) => e.slug), [
      'estate-lekki-gardens',
      'property-4-bedroom-duplex',
    ]);
    expect(catalog.first.galleryImages.length, 3);
    expect(catalog.first.imageUrl, 'https://cdn.example/estate-cover.jpg');
    expect(catalog.last.listingPath, '/properties/4-bedroom-duplex');
  });

  test('buildMediaGalleryCatalog skips listings with no photos', () {
    final catalog = buildMediaGalleryCatalog(
      estates: const [
        CmsEstateSummary(id: 'e1', name: 'Empty Estate', slug: 'empty'),
      ],
      properties: const [
        CmsPropertyFeatured(id: 'p1', title: 'No Photos', slug: 'no-photos'),
      ],
    );
    expect(catalog, isEmpty);
  });

  testWidgets('Media center hub uses live showrooms instead of mock albums',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          publishedEstatesCatalogProvider.overrideWith((ref) async => []),
          publishedPropertiesCatalogProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: MediaCenterHubPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Experience Properties Before You Visit'),
      findsOneWidget,
    );
    expect(find.text('Published galleries'), findsOneWidget);
    expect(find.textContaining('No published estate or property photos yet'), findsOneWidget);
    expect(find.text('Press & brand kit'), findsNothing);
    expect(find.text('Horizon Gardens Estate'), findsNothing);
  });

  testWidgets('Media experience page shows live photos for a published listing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          publishedEstatesCatalogProvider.overrideWith(
            (ref) async => const [
              CmsEstateSummary(
                id: 'e1',
                name: 'Lekki Gardens',
                slug: 'lekki-gardens',
                description: 'A published estate album.',
                coverImageUrl: 'https://cdn.example/cover.jpg',
                galleryUrls: ['https://cdn.example/cover.jpg'],
                isPublished: true,
              ),
            ],
          ),
          publishedPropertiesCatalogProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: MediaExperiencePage(slug: 'estate-lekki-gardens'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lekki Gardens'), findsWidgets);
    expect(find.text('HD image gallery'), findsOneWidget);
    expect(find.text('Virtual property tour'), findsNothing);
    expect(find.textContaining('VR & AR'), findsNothing);
  });

  testWidgets('Media experience page shows not found for unknown slug',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseConfiguredProvider.overrideWith((ref) => false),
          publishedEstatesCatalogProvider.overrideWith((ref) async => []),
          publishedPropertiesCatalogProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: MediaExperiencePage(slug: 'unknown-slug')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Media experience not found'), findsOneWidget);
  });
}
