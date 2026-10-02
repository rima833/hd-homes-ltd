import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/home/data/models/home_cms_content.dart';
import 'package:hdhomesproject/features/home/data/providers/home_content_provider.dart';

/// Default `cms_sections` rows for every controllable homepage block,
/// prefilled from [fallbackHomeCmsContent] so Admin → Website → Homepage
/// can edit real public copy immediately after seed/sync.
List<Map<String, dynamic>> buildDefaultHomepageSectionSeeds({
  HomeCmsContent? from,
}) {
  final c = from ?? fallbackHomeCmsContent;
  return [
    _sec('homepage_hero', 'hero', 'Hero', 0, {
      'note': 'Edit media & CTAs in Website → Hero Manager',
    }),
    _sec('homepage_search', 'widget', 'Property Search', 5, {
      'note': 'Toggle visibility for the homepage search block',
    }),
    _sec('homepage_about', 'about', 'About', 11, {
      'title': c.about.title,
      'titleAccent': c.about.titleAccent,
      'story': c.about.story,
      'mission': c.about.mission,
      'vision': c.about.vision,
      'values': c.about.values,
      'ctaLabel': c.about.ctaLabel,
      'ctaPath': c.about.ctaPath,
      'backgroundImageUrl': c.about.backgroundImageUrl,
      'highlights': [
        for (final h in c.about.highlights)
          {
            'title': h.title,
            'description': h.description,
            'iconName': h.iconName,
          },
      ],
    }),
    _sec('homepage_executive_welcome', 'quote', 'Leadership quote', 14, {
      'name': '',
      'title': '',
      'message': '',
    }),
    _sec('homepage_why_choose', 'why_choose', 'Why Choose', 13, {
      'items': [
        for (final i in c.whyChoose)
          {
            'title': i.title,
            'description': i.description,
            'iconName': i.iconName,
          },
      ],
    }),
    _sec('homepage_featured_estates', 'featured_estates', 'Featured Estates', 20,
        {
          'limit': 6,
          'note': 'Enable after publishing estates in Website → Featured Estates',
        },
        visible: false),
    _sec('homepage_featured_properties', 'featured_properties',
        'Featured Properties', 21, {
      'limit': 6,
      'note': 'Manage items in Website → Featured Properties',
    }),
    _sec('homepage_testimonials', 'testimonials', 'Testimonials', 40, {
      'limit': 6,
      'note': 'Manage quotes in Website → Testimonials',
    }),
    _sec('homepage_partners', 'managed_elsewhere', 'Partners', 41, {
      'note': 'Manage partners in Website → Partners & affiliations',
    }),
    _sec('homepage_trust', 'widget', 'Trust Center Teaser', 42, {
      'note': 'Toggle visibility for the trust center teaser',
    }),
    _sec('homepage_awards', 'managed_elsewhere', 'Awards', 43, {
      'note': 'Manage awards in Website → Awards & certifications',
    }),
    _sec('homepage_content_hub', 'content_hub', 'Content Hub', 50, {
      'note': 'Published blog posts and FAQs render in this band',
    }),
    _sec('homepage_blog', 'blog', 'Blog', 51, {
      'limit': 6,
      'note': 'Manage posts in Website → Blog',
    }),
    _sec('homepage_faq', 'faq', 'FAQ', 52, {
      'limit': 6,
      'note': 'Manage questions in Website → FAQ',
    }),
    _sec('homepage_cta', 'cta', 'CTA', 70, {
      'headline': c.cta.headline,
      'subheadline': c.cta.subheadline,
      'cta_label': c.cta.primaryLabel,
      'cta_url': c.cta.primaryPath,
      'secondary_label': c.cta.secondaryLabel,
      'secondary_path': c.cta.secondaryPath,
    }),
    _sec('homepage_stats', 'managed_elsewhere', 'Company Stats', 71, {
      'note': 'Manage KPIs in Website → Statistics',
    }),
    _sec('homepage_closing', 'closing', 'Closing', 72, {
      'note': 'Closing band anchor — keep at the bottom',
    }),
  ];
}

Map<String, dynamic> _sec(
  String key,
  String type,
  String title,
  int order,
  Map<String, dynamic> content, {
  bool visible = true,
}) =>
    {
      'section_key': key,
      'section_type': type,
      'title': title,
      'sort_order': order,
      'is_visible': visible,
      'content': content,
    };

/// Homepage blocks that render on the public site. Placeholder rows
/// (map, fake live activity, dead calculators, mock tours) are not included.
const kLiveHomepageSectionKeys = <String>{
  'homepage_hero',
  'homepage_search',
  'homepage_executive_welcome',
  'homepage_about',
  'homepage_why_choose',
  'homepage_featured_estates',
  'homepage_featured_properties',
  'homepage_testimonials',
  'homepage_partners',
  'homepage_trust',
  'homepage_awards',
  'homepage_content_hub',
  'homepage_blog',
  'homepage_faq',
  'homepage_cta',
  'homepage_stats',
  'homepage_closing',
};

/// Human-readable editor mode for a homepage section key.
String homepageEditorKind(String sectionKey) {
  return switch (sectionKey) {
    'homepage_stats' => 'managed_elsewhere',
    'homepage_about' => 'about',
    'homepage_lifestyle' || 'homepage_lifestyles' => 'lifestyle',
    'homepage_why_choose' => 'why',
    'homepage_investments' => 'investments',
    // Legacy homepage construction rows → Website → Construction CMS.
    'homepage_construction' => 'managed_elsewhere',
    'homepage_partners' => 'managed_elsewhere',
    'homepage_awards' => 'managed_elsewhere',
    'homepage_market_insights' => 'insights',
    'homepage_events' => 'events',
    'homepage_downloads' => 'downloads',
    'homepage_live_activity' => 'live',
    'homepage_executive_welcome' => 'executive',
    'homepage_cta' => 'cta',
    'homepage_closing' || 'homepage_content_hub' => 'visibility_only',
    'homepage_hero' => 'hero_link',
    'homepage_search' ||
    'homepage_map' ||
    'homepage_payment_calc' ||
    'homepage_roi_calc' ||
    'homepage_virtual_tours' ||
    'homepage_trust' =>
      'visibility_only',
    'homepage_featured_estates' ||
    'homepage_featured_properties' ||
    'homepage_testimonials' ||
    'homepage_faq' ||
    'homepage_blog' =>
      'managed_elsewhere',
    _ => 'json',
  };
}

/// Empty item templates for list editors.
Map<String, dynamic> emptyHomepageItem(String kind) {
  return switch (kind) {
    'stats' => {
        'value': 0,
        'label': 'New stat',
        'suffix': '+',
        'caption': '',
        'iconName': 'star',
      },
    'why' => {
        'title': 'New reason',
        'description': '',
        'iconName': 'shield',
      },
    'lifestyle' => {
        'label': 'New lifestyle',
        'description': '',
        'route': RoutePaths.properties,
      },
    'investments' => {
        'title': 'New investment',
        'roi': '10–15%',
        'type': 'Estate Development',
        'duration': '24 months',
        'risk': 'Moderate',
        'growth': 'High',
        'route': RoutePaths.investment,
      },
    'partners' => {'name': 'Partner', 'category': 'Partner'},
    'awards' => {'title': 'Award', 'year': '2026', 'issuer': ''},
    'insights' => {
        'title': 'Insight',
        'trend': 'Upward',
        'change': '+5%',
        'summary': '',
      },
    'events' => {
        'title': 'Event',
        'date': '',
        'location': '',
        'type': 'Open House',
      },
    'downloads' => {'title': 'Document', 'fileType': 'PDF', 'url': '#'},
    'live' => {
        'message': 'Update',
        'timeAgo': '1 hr ago',
        'type': 'listing',
      },
    _ => <String, dynamic>{},
  };
}
