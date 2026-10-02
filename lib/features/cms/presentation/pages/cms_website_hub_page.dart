import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin → Website root: one place to open every public-site control.
class CmsWebsiteHubPage extends ConsumerWidget {
  const CmsWebsiteHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const AdminSectionHeader(
            title: 'Website control center',
            subtitle:
                'Public-site content lives here. Use the sidebar for homepage, '
                'pages, blog, media, chrome, and SEO — open section editors below.',
          ),
          const SizedBox(height: 4),
          _buildKpiStrip(context, ref),
          const SizedBox(height: 24),
          _Group(
            title: 'Homepage',
            description: 'Flagship landing page layout and hero media',
            items: [
              _Link(
                label: 'Homepage sections',
                hint: 'Order, visibility, and section copy',
                path: RoutePaths.dashboardWebsiteHomepage,
                icon: LucideIcons.layoutTemplate,
                countProvider: cmsHomepageSectionsProvider,
              ),
              const _Link(
                label: 'Hero Manager',
                hint: 'Background image/video and CTAs',
                path: RoutePaths.dashboardWebsiteHero,
                icon: LucideIcons.image,
              ),
              _Link(
                label: 'Estates catalog',
                hint: 'Create → upload cover → Featured + Published',
                path: RoutePaths.dashboardEstates,
                icon: LucideIcons.map,
                countProvider: cmsEstatesProvider,
              ),
              const _Link(
                label: 'Property listings',
                hint: 'Create → upload cover → Featured + Published',
                path: RoutePaths.dashboardProperties,
                icon: LucideIcons.home,
              ),
            ],
          ),
          _Group(
            title: 'Public hub pages',
            description:
                'Hero headlines for Properties, Estates, Services, Contact, and more',
            items: [
              _Link(
                label: 'Pages & hub heroes',
                hint: 'Edit published page copy and legal pages',
                path: RoutePaths.dashboardWebsitePages,
                icon: LucideIcons.fileText,
                countProvider: cmsPagesProvider,
              ),
            ],
          ),
          _Group(
            title: 'Content',
            description: 'Stories, social proof, and team',
            items: [
              _Link(
                label: 'Blog',
                hint: 'Articles for /blog and homepage teaser',
                path: RoutePaths.dashboardWebsiteBlog,
                icon: LucideIcons.newspaper,
                countProvider: cmsBlogsProvider,
              ),
              _Link(
                label: 'Testimonials',
                hint: 'Customer quotes',
                path: RoutePaths.dashboardWebsiteTestimonials,
                icon: LucideIcons.quote,
                countProvider: cmsTestimonialsProvider,
              ),
              _Link(
                label: 'Awards',
                hint: 'Awards & certifications on Home, About, and Trust',
                path: RoutePaths.dashboardWebsiteAwards,
                icon: LucideIcons.award,
                countProvider: cmsAwardsProvider,
              ),
              _Link(
                label: 'Partners',
                hint: 'Partners & affiliations on Home, About, and Trust',
                path: RoutePaths.dashboardWebsitePartners,
                icon: LucideIcons.heartHandshake,
                countProvider: cmsPartnersProvider,
              ),
              _Link(
                label: 'Statistics',
                hint: 'Company KPIs on Home, About, and Trust',
                path: RoutePaths.dashboardWebsiteStatistics,
                icon: LucideIcons.barChart3,
                countProvider: cmsCompanyStatsProvider,
              ),
              _Link(
                label: 'Client Journey',
                hint: 'About page serpentine journey steps',
                path: RoutePaths.dashboardWebsiteClientJourney,
                icon: LucideIcons.gitBranch,
                countProvider: cmsClientJourneyStepsProvider,
              ),
              _Link(
                label: 'Journey Benefits',
                hint: 'Feature strip under client journey',
                path: RoutePaths.dashboardWebsiteJourneyBenefits,
                icon: LucideIcons.sparkles,
                countProvider: cmsJourneyBenefitsProvider,
              ),
              _Link(
                label: 'Offices',
                hint: 'About office location cards',
                path: RoutePaths.dashboardWebsiteOffices,
                icon: LucideIcons.mapPin,
                countProvider: cmsOfficeLocationsProvider,
              ),
              _Link(
                label: 'Investments',
                hint: 'Opportunities + Market Insights tabs',
                path: RoutePaths.dashboardWebsiteInvestments,
                icon: LucideIcons.trendingUp,
                countProvider: cmsWebsiteInvestmentOpportunitiesProvider,
              ),
              _Link(
                label: 'Construction',
                hint: 'Public progress cards for Properties → Construction Updates',
                path: RoutePaths.dashboardWebsiteConstruction,
                icon: LucideIcons.hardHat,
                countProvider: cmsWebsiteConstructionUpdatesProvider,
              ),
              const _Link(
                label: 'Digital Profile',
                hint: 'Profile card, downloads, and KPIs on About and Trust',
                path: RoutePaths.dashboardWebsiteDigitalProfile,
                icon: LucideIcons.building2,
              ),
              const _Link(
                label: 'Careers',
                hint: 'Jobs CMS, applications, and public form settings',
                path: RoutePaths.dashboardWebsiteCareers,
                icon: LucideIcons.briefcase,
              ),
              const _Link(
                label: 'Services',
                hint: 'Categories, catalog, and case studies',
                path: RoutePaths.dashboardWebsiteServices,
                icon: LucideIcons.wrench,
              ),
              _Link(
                label: 'Browse Categories',
                hint: 'Featured + grid category cards with live listing counts',
                path: RoutePaths.dashboardWebsiteBrowseCategories,
                icon: LucideIcons.layoutGrid,
                countProvider: cmsBrowseCategoriesProvider,
              ),
              const _Link(
                label: 'Payment Calculator',
                hint: 'Plans, rates, and applications',
                path: RoutePaths.dashboardWebsitePaymentCalculator,
                icon: LucideIcons.calculator,
              ),
              const _Link(
                label: 'ROI Calculator',
                hint: 'Investment returns bounds and formula',
                path: RoutePaths.dashboardWebsiteRoiCalculator,
                icon: LucideIcons.lineChart,
              ),
              _Link(
                label: 'Team',
                hint: 'Leadership on About and Trust',
                path: RoutePaths.dashboardWebsiteTeam,
                icon: LucideIcons.users,
                countProvider: cmsTeamProvider,
              ),
              _Link(
                label: 'FAQ',
                hint: 'FAQs on Home, Trust, and other public pages',
                path: RoutePaths.dashboardWebsiteFaq,
                icon: LucideIcons.helpCircle,
                countProvider: cmsFaqsProvider,
              ),
              const _Link(
                label: 'Media Library',
                hint: 'Images and uploads',
                path: RoutePaths.dashboardWebsiteMedia,
                icon: LucideIcons.folderOpen,
              ),
            ],
          ),
          _Group(
            title: 'Site chrome',
            description: 'Global bars, navigation, and footer',
            items: [
              _Link(
                label: 'Banners',
                hint: 'Top announcement bar',
                path: RoutePaths.dashboardWebsiteBanners,
                icon: LucideIcons.megaphone,
                countProvider: cmsBannersProvider,
              ),
              _Link(
                label: 'Menus',
                hint: 'Header and drawer links',
                path: RoutePaths.dashboardWebsiteMenus,
                icon: LucideIcons.menu,
                countProvider: cmsMenuSectionsProvider,
              ),
              _Link(
                label: 'Footer',
                hint: 'Footer columns and links',
                path: RoutePaths.dashboardWebsiteFooter,
                icon: LucideIcons.panelBottom,
                countProvider: cmsFooterSectionsProvider,
              ),
              const _Link(
                label: 'Company Profile',
                hint: 'Name, phone, email, address',
                path: RoutePaths.dashboardWebsiteCompany,
                icon: LucideIcons.building2,
              ),
            ],
          ),
          _Group(
            title: 'Discovery',
            description: 'Search engines and social previews',
            items: [
              _Link(
                label: 'SEO',
                hint: 'Meta titles and descriptions by path',
                path: RoutePaths.dashboardWebsiteSeo,
                icon: LucideIcons.search,
                countProvider: cmsSeoProvider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(BuildContext context, WidgetRef ref) {
    int cnt(AsyncValue<List<dynamic>> v) => v.valueOrNull?.length ?? 0;

    final blogs = cnt(ref.watch(cmsBlogsProvider));
    final testimonials = cnt(ref.watch(cmsTestimonialsProvider));
    final pages = cnt(ref.watch(cmsPagesProvider));
    final faqs = cnt(ref.watch(cmsFaqsProvider));
    final seo = cnt(ref.watch(cmsSeoProvider));
    final team = cnt(ref.watch(cmsTeamProvider));

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiChip(label: 'Blog articles', value: '$blogs', icon: LucideIcons.newspaper),
        _KpiChip(label: 'Testimonials', value: '$testimonials', icon: LucideIcons.quote),
        _KpiChip(label: 'Pages', value: '$pages', icon: LucideIcons.fileText),
        _KpiChip(label: 'FAQs', value: '$faqs', icon: LucideIcons.helpCircle),
        _KpiChip(label: 'SEO rules', value: '$seo', icon: LucideIcons.search),
        _KpiChip(label: 'Team', value: '$team', icon: LucideIcons.users),
      ],
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.08),
            AppColors.gold.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate500,
                ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<_Link> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final tileWidth = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: tileWidth,
                      child: _HubTile(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Link {
  const _Link({
    required this.label,
    required this.hint,
    required this.path,
    required this.icon,
    this.countProvider,
  });

  final String label;
  final String hint;
  final String path;
  final IconData icon;
  final ProviderBase<AsyncValue<List<dynamic>>>? countProvider;
}

class _HubTile extends ConsumerWidget {
  const _HubTile({required this.item});

  final _Link item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = item.countProvider != null
        ? ref.watch(item.countProvider!)
        : null;

    return AdminCard(
      onTap: () => context.go(item.path),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  item.hint,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.slate500),
                ),
              ],
            ),
          ),
          if (count != null)
            count.when(
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (items) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: AppColors.slate400,
          ),
        ],
      ),
    );
  }
}
