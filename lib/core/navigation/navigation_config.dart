import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/navigation/nav_item.dart';
import 'package:hdhomesproject/core/theme/tokens/app_icons.dart';

/// Navigation definitions for all four platform applications.
abstract final class NavigationConfig {
  static const publicNav = [
    NavItem(label: 'Home', path: RoutePaths.home, icon: AppIcons.home),
    NavItem(label: 'About', path: RoutePaths.about, icon: Icons.info_outline_rounded),
    NavItem(label: 'Properties', path: RoutePaths.properties, icon: AppIcons.property),
    NavItem(label: 'Estates', path: RoutePaths.estates, icon: Icons.apartment_rounded),
    NavItem(label: 'Investment', path: RoutePaths.investment, icon: Icons.trending_up_rounded),
    NavItem(label: 'Services', path: RoutePaths.services, icon: Icons.handyman_outlined),
    NavItem(label: 'Blog', path: RoutePaths.blog, icon: Icons.article_outlined),
    NavItem(label: 'Gallery', path: RoutePaths.gallery, icon: Icons.photo_library_outlined),
    NavItem(label: 'Careers', path: RoutePaths.careers, icon: Icons.work_outline_rounded),
    NavItem(label: 'Contact', path: RoutePaths.contact, icon: Icons.mail_outline_rounded),
  ];

  static const clientNav = [
    NavItem(label: 'Dashboard', path: RoutePaths.client, icon: Icons.dashboard_rounded),
    NavItem(label: 'My Properties', path: RoutePaths.clientProperties, icon: AppIcons.property),
    NavItem(label: 'Saved Properties', path: RoutePaths.clientSaved, icon: AppIcons.favoriteOutline),
    NavItem(label: 'Payments', path: RoutePaths.clientPayments, icon: AppIcons.payment),
    NavItem(label: 'Documents', path: RoutePaths.clientDocuments, icon: AppIcons.receipt),
    NavItem(label: 'Construction Updates', path: RoutePaths.clientConstruction, icon: Icons.construction_rounded),
    NavItem(label: 'Inspection Bookings', path: RoutePaths.clientInspections, icon: Icons.event_rounded),
    NavItem(label: 'Messages', path: RoutePaths.clientMessages, icon: Icons.chat_bubble_outline_rounded),
    NavItem(label: 'Notifications', path: RoutePaths.clientNotifications, icon: AppIcons.notification),
    NavItem(label: 'Support', path: RoutePaths.clientSupport, icon: Icons.support_agent_rounded),
    NavItem(label: 'Referrals', path: RoutePaths.clientReferrals, icon: Icons.people_outline_rounded),
    NavItem(label: 'Settings', path: RoutePaths.clientSettings, icon: AppIcons.settings),
  ];

  static const clientBottomNav = [
    NavItem(label: 'Home', path: RoutePaths.client, icon: Icons.dashboard_rounded),
    NavItem(label: 'Properties', path: RoutePaths.clientProperties, icon: AppIcons.property),
    NavItem(label: 'Payments', path: RoutePaths.clientPayments, icon: AppIcons.payment),
    NavItem(label: 'More', path: RoutePaths.clientSettings, icon: Icons.menu_rounded),
  ];

  static const investorNav = [
    NavItem(label: 'Dashboard', path: RoutePaths.investor, icon: Icons.dashboard_rounded),
    NavItem(label: 'Portfolio', path: RoutePaths.investorPortfolio, icon: Icons.pie_chart_outline_rounded),
    NavItem(label: 'Investment Analytics', path: RoutePaths.investorAnalytics, icon: Icons.analytics_outlined),
    NavItem(label: 'Construction Progress', path: RoutePaths.investorConstruction, icon: Icons.construction_rounded),
    NavItem(label: 'Reports', path: RoutePaths.investorReports, icon: AppIcons.receipt),
    NavItem(label: 'Payments', path: RoutePaths.investorPayments, icon: AppIcons.payment),
    NavItem(label: 'Documents', path: RoutePaths.investorDocuments, icon: Icons.folder_outlined),
    NavItem(label: 'Referrals', path: RoutePaths.investorReferrals, icon: Icons.people_outline_rounded),
    NavItem(label: 'Messages', path: RoutePaths.investorMessages, icon: Icons.chat_bubble_outline_rounded),
    NavItem(label: 'Notifications', path: RoutePaths.investorNotifications, icon: AppIcons.notification),
    NavItem(label: 'Support', path: RoutePaths.investorSupport, icon: Icons.support_agent_rounded),
    NavItem(label: 'Settings', path: RoutePaths.investorSettings, icon: AppIcons.settings),
  ];

  static const adminNav = [
    NavItem(label: 'Dashboard', path: RoutePaths.dashboard, icon: Icons.dashboard_rounded),
    NavItem(
      label: 'Ops Center',
      path: RoutePaths.dashboardEoc,
      icon: Icons.radar_rounded,
    ),
    NavItem(
      label: 'Website',
      path: RoutePaths.dashboard,
      icon: Icons.language_rounded,
      children: [
        NavItem(label: 'Pages', path: RoutePaths.dashboardWebsite),
        NavItem(label: 'Banners', path: RoutePaths.dashboardBanners),
        NavItem(label: 'SEO', path: RoutePaths.dashboardSeo),
      ],
    ),
    NavItem(label: 'Properties', path: RoutePaths.dashboardProperties, icon: AppIcons.property),
    NavItem(label: 'Estates', path: RoutePaths.dashboardEstates, icon: Icons.apartment_rounded),
    NavItem(label: 'Clients', path: RoutePaths.dashboardClients, icon: Icons.people_rounded),
    NavItem(label: 'Investors', path: RoutePaths.dashboardInvestors, icon: Icons.account_balance_rounded),
    NavItem(label: 'CRM', path: RoutePaths.dashboardCrm, icon: Icons.contact_phone_rounded),
    NavItem(
      label: 'Support',
      path: RoutePaths.dashboardSupport,
      icon: Icons.support_agent_rounded,
    ),
    NavItem(
      label: 'Documents',
      path: RoutePaths.dashboardDocuments,
      icon: Icons.folder_shared_rounded,
    ),
    NavItem(
      label: 'Procurement',
      path: RoutePaths.dashboardProcurement,
      icon: Icons.local_shipping_rounded,
    ),
    NavItem(
      label: 'Assets',
      path: RoutePaths.dashboardAssets,
      icon: Icons.inventory_2_rounded,
    ),
    NavItem(
      label: 'GRC',
      path: RoutePaths.dashboardGrc,
      icon: Icons.account_balance,
    ),
    NavItem(label: 'Sales', path: RoutePaths.dashboardSales, icon: Icons.point_of_sale_rounded),
    NavItem(label: 'Construction', path: RoutePaths.dashboardConstruction, icon: Icons.construction_rounded),
    NavItem(label: 'Finance', path: RoutePaths.dashboardFinance, icon: AppIcons.payment),
    NavItem(label: 'Marketing', path: RoutePaths.dashboardMarketing, icon: Icons.campaign_rounded),
    NavItem(label: 'Blog', path: RoutePaths.dashboardBlog, icon: Icons.article_rounded),
    NavItem(label: 'Media Library', path: RoutePaths.dashboardMedia, icon: Icons.perm_media_rounded),
    NavItem(label: 'Reports', path: RoutePaths.dashboardReports, icon: Icons.assessment_rounded),
    NavItem(label: 'Analytics', path: RoutePaths.dashboardAnalytics, icon: Icons.analytics_rounded),
    NavItem(
      label: 'AI Hub',
      path: RoutePaths.aiGovernance,
      icon: Icons.smart_toy_outlined,
    ),
    NavItem(
      label: 'Integrations',
      path: RoutePaths.dashboardIntegrations,
      icon: Icons.hub_outlined,
    ),
    NavItem(label: 'Notifications', path: RoutePaths.dashboardNotifications, icon: AppIcons.notification),
    NavItem(label: 'Users', path: RoutePaths.dashboardUsers, icon: Icons.group_rounded),
    NavItem(
      label: 'Organization',
      path: RoutePaths.dashboardOrganization,
      icon: Icons.account_tree_rounded,
    ),
    NavItem(
      label: 'HR',
      path: RoutePaths.dashboardHr,
      icon: Icons.badge_outlined,
    ),
    NavItem(label: 'Roles & Permissions', path: RoutePaths.dashboardRoles, icon: Icons.admin_panel_settings_rounded),
    NavItem(label: 'Settings', path: RoutePaths.dashboardSettings, icon: AppIcons.settings),
    NavItem(label: 'Activity Logs', path: RoutePaths.dashboardActivityLogs, icon: Icons.history_rounded),
    NavItem(label: 'Profile', path: RoutePaths.dashboardProfile, icon: AppIcons.user),
  ];
}
