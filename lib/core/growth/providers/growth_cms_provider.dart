import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';

final growthHubCmsProvider = Provider<GrowthHubCms>((ref) => _cms);

final _cms = GrowthHubCms(
  personalizationEnabled: true,
  leadScoringRules: const [
    'Budget tier weighting (+8 to +25)',
    'Investment interest (+20)',
    'Immediate timeline (+12)',
    'Property views (+3 each)',
    'Page depth (+1 per page)',
    'Downloads (+10)',
    'Chat engagement (+5)',
  ],
  seoDefaults: const {
    'titleSuffix': '| HD Homes',
    'defaultDescription':
        'Premium Nigerian property developer — luxury homes, estates, and investment opportunities.',
    'ogImage': 'https://hdhomes.ng/og-default.jpg',
    'robots': 'index, follow',
  },
  automationRules: const [
    AutomationRule(
      id: 'rule-1',
      name: 'Hot lead → Sales Manager',
      trigger: 'IF lead score ≥ 80',
      actions: ['Assign Senior Sales', 'Send WhatsApp', 'Create CRM task', 'Notify admin'],
      enabled: true,
    ),
    AutomationRule(
      id: 'rule-2',
      name: 'Construction milestone → Investors',
      trigger: 'IF milestone completed',
      actions: ['Email investors', 'Update dashboard', 'Publish progress report'],
      enabled: true,
    ),
    AutomationRule(
      id: 'rule-3',
      name: 'Abandoned inquiry recovery',
      trigger: 'IF form started but not submitted (24h)',
      actions: ['Send follow-up email', 'Assign callback task'],
      enabled: true,
    ),
  ],
  abTests: const [
    AbTestExperiment(
      id: 'ab-hero-cta',
      name: 'Homepage hero CTA',
      variants: ['Book Inspection', 'Explore Properties'],
      metric: 'Click-through rate',
      winner: 'Book Inspection',
    ),
    AbTestExperiment(
      id: 'ab-property-card',
      name: 'Property card layout',
      variants: ['Compact', 'Expanded'],
      metric: 'Detail page visits',
    ),
  ],
  integrations: const [
    ThirdPartyIntegration(
      id: 'ga4',
      name: 'Google Analytics 4',
      category: 'Analytics',
      status: IntegrationStatus.configured,
      description: 'Event streaming via Growth Engine abstraction layer.',
    ),
    ThirdPartyIntegration(
      id: 'gsc',
      name: 'Google Search Console',
      category: 'SEO',
      status: IntegrationStatus.configured,
      description: 'Search performance dashboards (Volume 1.5).',
    ),
    ThirdPartyIntegration(
      id: 'gtm',
      name: 'Google Tag Manager',
      category: 'Analytics',
      status: IntegrationStatus.disconnected,
      description: 'Tag management container — configure in Admin.',
    ),
    ThirdPartyIntegration(
      id: 'meta-pixel',
      name: 'Meta Pixel',
      category: 'Marketing',
      status: IntegrationStatus.disconnected,
      description: 'Conversion tracking for Meta campaigns.',
    ),
    ThirdPartyIntegration(
      id: 'resend',
      name: 'Resend / SendGrid',
      category: 'Email',
      status: IntegrationStatus.configured,
      description: 'Transactional and marketing email delivery.',
    ),
    ThirdPartyIntegration(
      id: 'termii',
      name: 'Termii',
      category: 'SMS',
      status: IntegrationStatus.disconnected,
      description: 'SMS and OTP for Nigerian market.',
    ),
  ],
  campaigns: const [
    'Welcome email series',
    'Property alert notifications',
    'Construction update broadcasts',
    'Investment newsletter — Q2 2026',
    'Re-engagement — dormant leads',
  ],
);
