import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Left-rail destinations for the Platform Control Center.
enum PlatformControlSection {
  overview,
  business,
  brandSocial,
  contact,
  publicWebsite,
  seo,
  clientPortal,
  investorPortal,
  homepageNav,
  contentCms,
  properties,
  finance,
  opsModules,
  staffRoles,
  mediaCloudinary,
  securityPrivacy,
  integrations,
  email,
  audit,
}

class PlatformControlNavItem {
  const PlatformControlNavItem({
    required this.section,
    required this.label,
    required this.icon,
    this.group = '',
    this.editable = false,
  });

  final PlatformControlSection section;
  final String label;
  final IconData icon;
  final String group;

  /// When true, Save/Discard apply to this section's draft fields.
  final bool editable;
}

abstract final class PlatformControlNav {
  static const items = <PlatformControlNavItem>[
    PlatformControlNavItem(
      section: PlatformControlSection.overview,
      label: 'Overview',
      icon: LucideIcons.layoutDashboard,
      group: 'Control',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.business,
      label: 'Business',
      icon: LucideIcons.building2,
      group: 'Identity',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.brandSocial,
      label: 'Brand & Social',
      icon: LucideIcons.palette,
      group: 'Identity',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.contact,
      label: 'Contact',
      icon: LucideIcons.phone,
      group: 'Identity',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.publicWebsite,
      label: 'Public Website',
      icon: LucideIcons.globe,
      group: 'Website',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.seo,
      label: 'SEO Defaults',
      icon: LucideIcons.search,
      group: 'Website',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.homepageNav,
      label: 'Homepage & Menus',
      icon: LucideIcons.panelTop,
      group: 'Website',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.contentCms,
      label: 'Content & CMS',
      icon: LucideIcons.files,
      group: 'Website',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.clientPortal,
      label: 'Client Portal',
      icon: LucideIcons.user,
      group: 'Portals',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.investorPortal,
      label: 'Investor Portal',
      icon: LucideIcons.lineChart,
      group: 'Portals',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.properties,
      label: 'Properties',
      icon: LucideIcons.home,
      group: 'Operations',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.finance,
      label: 'Finance & Payments',
      icon: LucideIcons.wallet,
      group: 'Operations',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.opsModules,
      label: 'CRM · Construction · Support',
      icon: LucideIcons.layers,
      group: 'Operations',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.staffRoles,
      label: 'Staff & Roles',
      icon: LucideIcons.shield,
      group: 'People',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.mediaCloudinary,
      label: 'Media / Cloudinary',
      icon: LucideIcons.image,
      group: 'Platform',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.securityPrivacy,
      label: 'Security & Privacy',
      icon: LucideIcons.lock,
      group: 'Platform',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.integrations,
      label: 'Integrations',
      icon: LucideIcons.plug,
      group: 'Platform',
      editable: true,
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.email,
      label: 'Email',
      icon: LucideIcons.mail,
      group: 'Platform',
    ),
    PlatformControlNavItem(
      section: PlatformControlSection.audit,
      label: 'Audit Logs',
      icon: LucideIcons.scrollText,
      group: 'Platform',
    ),
  ];

  static PlatformControlNavItem itemFor(PlatformControlSection section) =>
      items.firstWhere((e) => e.section == section);
}
