import 'package:flutter_test/flutter_test.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/media_delivery.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_health.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/portal_feature_gates.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/controllers/platform_settings_edit_controller.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';

void main() {
  test('platform settings bundle maps to company compatibility keys', () {
    final bundle = PlatformSettingsBundle.fromRecords([
      PlatformSettingRecord.fromJson({
        'key': 'company',
        'value': {
          'name': 'HD Homes Limited',
          'tagline': 'Quality housing',
        },
        'category': 'general',
        'is_public': true,
      }),
      PlatformSettingRecord.fromJson({
        'key': 'contact',
        'value': {
          'email': 'hello@hdhomes.ng',
          'phone': '+2348012345678',
          'whatsapp': '+2348012345678',
          'address': 'Lagos',
        },
        'category': 'general',
        'is_public': true,
      }),
      PlatformSettingRecord.fromJson({
        'key': 'social',
        'value': {
          'facebook_url': 'https://facebook.com/hdhomes',
        },
        'category': 'branding',
        'is_public': true,
      }),
      PlatformSettingRecord.fromJson({
        'key': 'website_features',
        'value': {
          'show_whatsapp_fab': false,
          'enable_blog': true,
        },
        'category': 'website',
        'is_public': true,
      }),
      PlatformSettingRecord.fromJson({
        'key': 'maintenance',
        'value': {
          'enabled': true,
          'title': 'Offline',
        },
        'category': 'ops',
        'is_public': true,
      }),
      PlatformSettingRecord.fromJson({
        'key': 'portal_features',
        'value': {
          'client': {
            'enabled': true,
            'show_payments': false,
            'welcome_message': 'Client hello',
          },
          'investor': {
            'enabled': false,
            'show_portfolio': true,
          },
        },
        'category': 'portals',
        'is_public': false,
      }),
      PlatformSettingRecord.fromJson({
        'key': 'integrations',
        'value': {
          'cloudinary': {'configured': true},
          'sms': {'configured': false},
        },
        'category': 'integrations',
        'is_public': false,
      }),
    ]);

    final map = bundle.toCompanyCompatibilityMap();
    expect(map['company_name'], 'HD Homes Limited');
    expect(map['support_email'], 'hello@hdhomes.ng');
    expect(map['facebook_url'], 'https://facebook.com/hdhomes');
    expect(bundle.showWhatsappFab, isFalse);
    expect(bundle.enableBlog, isTrue);
    expect(bundle.maintenanceEnabled, isTrue);
    expect(bundle.maintenanceTitle, 'Offline');
    expect(bundle.clientPortalEnabled, isTrue);
    expect(bundle.investorPortalEnabled, isFalse);
    expect(bundle.clientModuleEnabled('show_payments'), isFalse);
    expect(bundle.clientWelcomeMessage, 'Client hello');
    expect(bundle.integrations['cloudinary'], isA<Map>());
  });

  test('platform health status parse and snapshot issues', () {
    expect(
      PlatformHealthStatus.parse('connected'),
      PlatformHealthStatus.connected,
    );
    expect(
      PlatformHealthStatus.parse('not_configured'),
      PlatformHealthStatus.notConfigured,
    );

    final snapshot = PlatformHealthSnapshot.fromJson(
      {
        'checked_at': '2026-09-15T10:00:00Z',
        'database': {'status': 'connected', 'app_settings_keys': 9},
        'authentication': {'status': 'connected'},
        'cloudinary': {'status': 'warning', 'assets_with_public_id': 0},
        'seo': {'status': 'connected', 'path_rows': 12},
        'last_settings_update': {'at': '2026-09-15T09:00:00Z', 'by': null},
      },
      realtimeStatus: PlatformHealthStatus.warning,
      realtimeNotes: 'not subscribed',
      clientSupabaseStatus: PlatformHealthStatus.connected,
      clientSupabaseNotes: 'ok',
    );

    expect(snapshot.checks['database']?.status, PlatformHealthStatus.connected);
    expect(snapshot.checks['realtime']?.status, PlatformHealthStatus.warning);
    expect(snapshot.issues, isNotEmpty);
  });

  test('edit state dirty detection tracks draft changes', () {
    const baseline = PlatformSettingsBundle(
      company: {'name': 'HD Homes'},
      contact: {'email': 'a@hdhomes.ng'},
    );
    final clean = PlatformSettingsEditState(
      baseline: baseline,
      draft: baseline,
    );
    expect(clean.isDirty, isFalse);

    final dirty = clean.copyWith(
      draft: baseline.copyWith(company: {'name': 'HD Homes Limited'}),
    );
    expect(dirty.isDirty, isTrue);
  });

  test('published brand color parse accepts hex', () {
    expect(PublishedBrandColors.parseHex('#B48743'), isNotNull);
    expect(PublishedBrandColors.parseHex(''), isNull);
    expect(PublishedBrandColors.parseHex('not-a-color'), isNull);
  });

  test('public website gates hide investment blog and portal entries', () {
    final gated = PlatformSettingsBundle.fromRecords([
      PlatformSettingRecord.fromJson({
        'key': 'website_features',
        'value': {
          'enable_blog': false,
          'enable_investment_section': false,
          'enable_client_portal_entry': false,
          'enable_investor_portal_entry': true,
          'enable_contact_forms': false,
        },
        'category': 'website',
        'is_public': true,
      }),
    ]);

    expect(gated.allowBlog, isFalse);
    expect(gated.allowInvestment, isFalse);
    expect(gated.allowsPublicPath('/blog'), isFalse);
    expect(gated.allowsPublicPath('/investment'), isFalse);
    expect(gated.allowsPublicPath('/contact'), isFalse);
    expect(gated.allowsFooterLabel('Client Login'), isFalse);
    expect(gated.allowsFooterLabel('Investor Login'), isTrue);
  });

  test('portal feature flags filter nav and welcome message', () {
    final client = PortalFeatureFlags.fromRpc({
      'portal': 'client',
      'flags': {
        'enabled': true,
        'show_payments': false,
        'show_referrals': false,
        'welcome_message': 'Client hello from Control Center',
      },
    });
    expect(client.welcomeMessage, 'Client hello from Control Center');
    expect(client.allowsPath(RoutePaths.clientPayments), isFalse);
    expect(client.allowsPath(RoutePaths.clientReferrals), isFalse);
    expect(client.allowsPath(RoutePaths.clientDocuments), isTrue);
    expect(client.allowsPath(RoutePaths.clientSettings), isTrue);

    final disabled = PortalFeatureFlags.fromRpc({
      'portal': 'investor',
      'flags': {'enabled': false, 'show_portfolio': true},
    });
    final filtered = disabled.filterNav([
      const NavItem(label: 'Dashboard', path: RoutePaths.investor),
      const NavItem(label: 'Portfolio', path: RoutePaths.investorPortfolio),
      const NavItem(label: 'Logout', path: NavItem.actionLogout),
    ]);
    expect(
      filtered.map((e) => e.path),
      [RoutePaths.investor, NavItem.actionLogout],
    );
  });

  test('media delivery requires Cloudinary for website binaries', () {
    expect(
      MediaDelivery.isCloudinaryUrl(
        'https://res.cloudinary.com/demo/image/upload/v1/sample.jpg',
      ),
      isTrue,
    );
    expect(
      MediaDelivery.isCloudinaryUrl(
        'https://example.supabase.co/storage/v1/object/public/marketing/a.jpg',
      ),
      isFalse,
    );
    expect(
      () => MediaDelivery.assertCloudinaryMediaUrl(
        'https://example.supabase.co/storage/v1/object/public/marketing/a.jpg',
        field: 'Hero',
      ),
      throwsStateError,
    );
    expect(
      () => MediaDelivery.assertCloudinaryMediaUrl(
        'https://res.cloudinary.com/demo/video/upload/v1/clip.mp4',
        field: 'Hero video',
      ),
      returnsNormally,
    );
  });
}
