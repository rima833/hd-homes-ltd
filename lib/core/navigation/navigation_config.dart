import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/auth/policies/admin_access_policy.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/theme/tokens/app_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Navigation definitions for all four platform applications.
abstract final class NavigationConfig {
  static const publicNav = [
    NavItem(label: 'Home', path: RoutePaths.home, icon: AppIcons.home),
    NavItem(
      label: 'About',
      path: RoutePaths.about,
      icon: Icons.info_outline_rounded,
    ),
    NavItem(
      label: 'Properties',
      path: RoutePaths.properties,
      icon: AppIcons.property,
      children: [
        NavItem(
          label: 'All Properties',
          path: RoutePaths.properties,
          icon: AppIcons.property,
        ),
        NavItem(
          label: 'Payment Calculator',
          path: RoutePaths.paymentCalculator,
          icon: LucideIcons.calculator,
        ),
        NavItem(
          label: 'Construction Updates',
          path: RoutePaths.construction,
          icon: LucideIcons.hardHat,
        ),
      ],
    ),
    NavItem(
      label: 'Investment',
      path: RoutePaths.investment,
      icon: Icons.trending_up_rounded,
      children: [
        NavItem(
          label: 'Opportunities',
          path: RoutePaths.investment,
          icon: Icons.trending_up_rounded,
        ),
        NavItem(
          label: 'ROI Calculator',
          path: RoutePaths.roiCalculator,
          icon: LucideIcons.lineChart,
        ),
      ],
    ),
    NavItem(
      label: 'Discover',
      path: RoutePaths.discover,
      icon: LucideIcons.sparkles,
      children: [
        NavItem(
          label: 'Services',
          path: RoutePaths.services,
          icon: Icons.handyman_outlined,
        ),
        NavItem(
          label: 'Estates',
          path: RoutePaths.estates,
          icon: LucideIcons.map,
        ),
        NavItem(
          label: 'Gallery',
          path: RoutePaths.gallery,
          icon: Icons.photo_library_outlined,
        ),
        NavItem(
          label: 'Blog',
          path: RoutePaths.blog,
          icon: Icons.article_outlined,
        ),
        NavItem(
          label: 'Careers',
          path: RoutePaths.careers,
          icon: Icons.work_outline_rounded,
        ),
        NavItem(
          label: 'Trust Center',
          path: RoutePaths.trust,
          icon: LucideIcons.shieldCheck,
        ),
        NavItem(
          label: 'Contact',
          path: RoutePaths.contact,
          icon: Icons.mail_outline_rounded,
        ),
      ],
    ),
  ];

  /// Compact desktop header order (Discover holds former quick-link pages).
  static const publicHeaderPaths = <String>[
    RoutePaths.home,
    RoutePaths.about,
    RoutePaths.properties,
    RoutePaths.investment,
    RoutePaths.discover,
  ];

  static NavItem? publicNavByPath(String path) {
    for (final item in publicNav) {
      if (item.path == path) return item;
    }
    return null;
  }

  static const clientNav = [
    NavItem.section('MAIN'),
    NavItem(
      label: 'Dashboard',
      path: RoutePaths.client,
      icon: LucideIcons.layoutDashboard,
    ),
    NavItem(
      label: 'My Properties',
      path: RoutePaths.clientProperties,
      icon: LucideIcons.building2,
    ),
    NavItem(
      label: 'Applications',
      path: RoutePaths.clientApplications,
      icon: LucideIcons.fileCheck,
    ),
    NavItem(
      label: 'Buying Tools',
      path: RoutePaths.clientTools,
      icon: LucideIcons.calculator,
    ),
    NavItem(
      label: 'Payments',
      path: RoutePaths.clientPayments,
      icon: LucideIcons.creditCard,
    ),
    NavItem(
      label: 'Documents',
      path: RoutePaths.clientDocuments,
      icon: LucideIcons.fileText,
    ),
    NavItem(
      label: 'Inspections',
      path: RoutePaths.clientInspections,
      icon: LucideIcons.clipboardCheck,
    ),
    NavItem(
      label: 'Messages',
      path: RoutePaths.clientMessages,
      icon: LucideIcons.messageSquare,
    ),
    NavItem(
      label: 'Support',
      path: RoutePaths.clientSupport,
      icon: LucideIcons.lifeBuoy,
    ),
    NavItem(
      label: 'Referrals',
      path: RoutePaths.clientReferrals,
      icon: LucideIcons.gift,
    ),
    NavItem.section('ACCOUNT'),
    NavItem(
      label: 'Profile Settings',
      path: RoutePaths.clientSettings,
      icon: LucideIcons.settings,
    ),
    NavItem(
      label: 'Notifications',
      path: RoutePaths.clientNotifications,
      icon: LucideIcons.bell,
    ),
    NavItem(
      label: 'Saved Properties',
      path: RoutePaths.clientSaved,
      icon: LucideIcons.heart,
    ),
    NavItem(
      label: 'Consultations',
      path: RoutePaths.clientConsultations,
      icon: LucideIcons.calendar,
    ),
    NavItem(
      label: 'Construction',
      path: RoutePaths.clientConstruction,
      icon: LucideIcons.hardHat,
    ),
    NavItem(
      label: 'Logout',
      path: NavItem.actionLogout,
      icon: LucideIcons.logOut,
      isDestructive: true,
    ),
  ];

  static const clientBottomNav = [
    NavItem(
      label: 'Home',
      path: RoutePaths.client,
      icon: Icons.dashboard_rounded,
    ),
    NavItem(
      label: 'Properties',
      path: RoutePaths.clientProperties,
      icon: AppIcons.property,
    ),
    NavItem(
      label: 'Payments',
      path: RoutePaths.clientPayments,
      icon: AppIcons.payment,
    ),
    NavItem(
      label: 'More',
      path: RoutePaths.clientMore,
      icon: Icons.menu_rounded,
    ),
  ];

  static const investorNav = [
    NavItem.section('MAIN'),
    NavItem(
      label: 'Dashboard',
      path: RoutePaths.investor,
      icon: LucideIcons.layoutDashboard,
    ),
    NavItem(
      label: 'Portfolio',
      path: RoutePaths.investorPortfolio,
      icon: LucideIcons.pieChart,
    ),
    NavItem(
      label: 'Investment Analytics',
      path: RoutePaths.investorAnalytics,
      icon: LucideIcons.lineChart,
    ),
    NavItem(
      label: 'Investment Tools',
      path: RoutePaths.investorTools,
      icon: LucideIcons.calculator,
    ),
    NavItem(
      label: 'Construction Progress',
      path: RoutePaths.investorConstruction,
      icon: LucideIcons.hardHat,
    ),
    NavItem(
      label: 'Reports',
      path: RoutePaths.investorReports,
      icon: LucideIcons.fileBarChart,
    ),
    NavItem(
      label: 'Payments',
      path: RoutePaths.investorPayments,
      icon: LucideIcons.creditCard,
    ),
    NavItem(
      label: 'Documents',
      path: RoutePaths.investorDocuments,
      icon: LucideIcons.fileText,
    ),
    NavItem(
      label: 'Referrals',
      path: RoutePaths.investorReferrals,
      icon: LucideIcons.gift,
    ),
    NavItem(
      label: 'Messages',
      path: RoutePaths.investorMessages,
      icon: LucideIcons.messageSquare,
    ),
    NavItem(
      label: 'Support',
      path: RoutePaths.investorSupport,
      icon: LucideIcons.lifeBuoy,
    ),
    NavItem.section('ACCOUNT'),
    NavItem(
      label: 'Profile Settings',
      path: RoutePaths.investorSettings,
      icon: LucideIcons.settings,
    ),
    NavItem(
      label: 'Notifications',
      path: RoutePaths.investorNotifications,
      icon: LucideIcons.bell,
    ),
    NavItem(
      label: 'Logout',
      path: NavItem.actionLogout,
      icon: LucideIcons.logOut,
      isDestructive: true,
    ),
  ];

  static const investorBottomNav = [
    NavItem(
      label: 'Dashboard',
      path: RoutePaths.investor,
      icon: LucideIcons.layoutDashboard,
    ),
    NavItem(
      label: 'Portfolio',
      path: RoutePaths.investorPortfolio,
      icon: LucideIcons.pieChart,
    ),
    NavItem(
      label: 'Payments',
      path: RoutePaths.investorPayments,
      icon: LucideIcons.creditCard,
    ),
    NavItem(
      label: 'More',
      path: RoutePaths.investorMore,
      icon: LucideIcons.menu,
    ),
  ];

  /// Permanent admin control-center sidebar (Volume 4 master refactor).
  static final adminNav = [
    NavItem(
      label: 'Dashboard',
      path: RoutePaths.dashboard,
      icon: Icons.dashboard_rounded,
    ),
    NavItem(
      label: 'Website',
      path: RoutePaths.dashboardWebsite,
      icon: Icons.language_rounded,
      anyOfPermissions: AdminAccessPolicy.website,
      // Lean public-site CMS only. Section editors (testimonials, team, etc.)
      // stay on Website → Overview so the sidebar stays short.
      children: [
        NavItem(label: 'Overview', path: RoutePaths.dashboardWebsite),
        NavItem(label: 'Homepage', path: RoutePaths.dashboardWebsiteHomepage),
        NavItem(label: 'Pages & hubs', path: RoutePaths.dashboardWebsitePages),
        NavItem(label: 'Blog', path: RoutePaths.dashboardWebsiteBlog),
        NavItem(label: 'Media Library', path: RoutePaths.dashboardWebsiteMedia),
        NavItem(label: 'Banners', path: RoutePaths.dashboardWebsiteBanners),
        NavItem(label: 'Menus', path: RoutePaths.dashboardWebsiteMenus),
        NavItem(label: 'Footer', path: RoutePaths.dashboardWebsiteFooter),
        NavItem(
          label: 'Company Profile',
          path: RoutePaths.dashboardWebsiteCompany,
          anyOfPermissions: AdminAccessPolicy.settings,
        ),
        NavItem(label: 'SEO', path: RoutePaths.dashboardWebsiteSeo),
      ],
    ),
    NavItem(
      label: 'Properties',
      path: RoutePaths.dashboardEstates,
      icon: AppIcons.property,
      anyOfPermissions: AdminAccessPolicy.properties,
      children: [
        NavItem(label: 'Estates', path: RoutePaths.dashboardEstates),
        NavItem(label: 'Listings', path: RoutePaths.dashboardProperties),
        NavItem(label: 'Inspections', path: RoutePaths.dashboardInspections),
        NavItem(
          label: 'Consultations',
          path: RoutePaths.dashboardConsultations,
        ),
        NavItem(label: 'Callbacks', path: RoutePaths.dashboardCallbacks),
      ],
    ),
    NavItem(
      label: 'Clients',
      path: RoutePaths.dashboardClients,
      icon: Icons.people_rounded,
      anyOfPermissions: AdminAccessPolicy.sales,
    ),
    NavItem(
      label: 'Sales',
      path: RoutePaths.dashboardCrm,
      icon: Icons.contact_phone_rounded,
      anyOfPermissions: AdminAccessPolicy.sales,
    ),
    NavItem(
      label: 'Investors',
      path: RoutePaths.dashboardInvestors,
      icon: Icons.account_balance_rounded,
      anyOfPermissions: AdminAccessPolicy.investorsDesk,
    ),
    NavItem(
      label: 'Client Applications',
      path: RoutePaths.dashboardClientApplications,
      icon: Icons.assignment_turned_in_outlined,
      anyOfPermissions: AdminAccessPolicy.clientApplications,
    ),
    NavItem(
      label: 'Construction',
      path: RoutePaths.dashboardConstruction,
      icon: Icons.construction_rounded,
      anyOfPermissions: AdminAccessPolicy.construction,
    ),
    NavItem(
      label: 'Finance',
      path: RoutePaths.dashboardFinance,
      icon: AppIcons.payment,
      anyOfPermissions: AdminAccessPolicy.finance,
    ),
    NavItem(
      label: 'Documents',
      path: RoutePaths.dashboardDocuments,
      icon: Icons.folder_shared_rounded,
      anyOfPermissions: AdminAccessPolicy.documents,
    ),
    NavItem(
      label: 'Marketing',
      path: RoutePaths.dashboardMarketing,
      icon: Icons.campaign_rounded,
      anyOfPermissions: AdminAccessPolicy.marketingHub,
    ),
    NavItem(
      label: 'Reports',
      path: RoutePaths.dashboardReports,
      icon: Icons.assessment_rounded,
      anyOfPermissions: AdminAccessPolicy.reports,
    ),
    NavItem(
      label: 'Analytics',
      path: RoutePaths.dashboardAnalytics,
      icon: Icons.analytics_rounded,
      anyOfPermissions: AdminAccessPolicy.analytics,
      children: [
        NavItem(label: 'Overview', path: RoutePaths.dashboardAnalytics),
        NavItem(label: 'Search insights', path: RoutePaths.searchInsights),
        NavItem(
          label: 'Personalization',
          path: RoutePaths.personalizationAnalytics,
        ),
      ],
    ),
    NavItem(
      label: 'Support',
      path: RoutePaths.dashboardSupport,
      icon: Icons.support_agent_rounded,
      anyOfPermissions: AdminAccessPolicy.support,
      children: [
        NavItem(
          label: 'Command Center',
          path: RoutePaths.dashboardSupport,
          icon: Icons.support_agent_rounded,
        ),
        NavItem(
          label: 'Live Chat',
          path: RoutePaths.dashboardLiveChat,
          icon: Icons.chat_rounded,
        ),
      ],
    ),
    NavItem(
      label: 'Users',
      path: RoutePaths.dashboardUsers,
      icon: Icons.group_rounded,
      anyOfPermissions: AdminAccessPolicy.users,
      children: [
        NavItem(label: 'Staff', path: RoutePaths.dashboardUsers),
        NavItem(
          label: 'Roles',
          path: RoutePaths.dashboardRoles,
          anyOfPermissions: AdminAccessPolicy.roles,
        ),
        NavItem(
          label: 'Platform Users',
          path: RoutePaths.dashboardPlatformUsers,
          anyOfPermissions: AdminAccessPolicy.users,
        ),
        NavItem(
          label: 'Compliance',
          path: RoutePaths.kycCompliance,
          anyOfPermissions: AdminAccessPolicy.users,
        ),
        NavItem(
          label: 'Communications',
          path: RoutePaths.adminCommunications,
          anyOfPermissions: AdminAccessPolicy.communications,
        ),
      ],
    ),
    NavItem(
      label: 'Settings',
      path: RoutePaths.dashboardSettings,
      icon: AppIcons.settings,
      anyOfPermissions: AdminAccessPolicy.settings,
    ),
    NavItem(
      label: 'Activity Logs',
      path: RoutePaths.dashboardActivityLogs,
      icon: Icons.history_rounded,
      anyOfPermissions: AdminAccessPolicy.activityLogs,
    ),
    if (kAiFeaturesEnabled)
      NavItem(
        label: 'AI Hub',
        path: RoutePaths.aiGovernance,
        icon: Icons.smart_toy_outlined,
        anyOfPermissions: AdminAccessPolicy.aiHub,
      ),
  ];
}
