import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/settings/presentation/pages/platform_control_center_page.dart';
import 'package:hdhomesproject/features/settings/presentation/widgets/platform_control_nav.dart';

/// Legacy entry — forwards to the Platform Control Center.
/// Prefer [PlatformControlCenterPage] directly.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key, this.initialSection});

  final PlatformControlSection? initialSection;

  @override
  Widget build(BuildContext context) {
    return PlatformControlCenterPage(initialSection: initialSection);
  }
}
