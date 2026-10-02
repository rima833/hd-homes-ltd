import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/careers/presentation/sections/careers_premium_sections.dart';
import 'package:url_launcher/url_launcher.dart';

/// About Careers — premium dark mockup only (CMS-backed via Careers admin).
class AboutCareersSection extends ConsumerStatefulWidget {
  const AboutCareersSection({
    super.key,
    required this.fallback,
  });

  /// Kept for API compatibility with [AboutPage]; live copy comes from CMS.
  final AboutCareersPreview fallback;

  @override
  ConsumerState<AboutCareersSection> createState() =>
      _AboutCareersSectionState();
}

class _AboutCareersSectionState extends ConsumerState<AboutCareersSection> {
  final _rolesKey = GlobalKey();

  void _scrollToRoles() {
    final target = _rolesKey.currentContext;
    if (target == null) {
      context.go(RoutePaths.careers);
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _mailto(String email, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject,
      },
    );
    await launchUrl(uri);
  }

  Future<void> _apply(CareerJob job, String cvEmail) async {
    final url = job.applyUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    await _mailto(cvEmail, subject: 'Application: ${job.title}');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(careersRealtimeProvider);
    final hub = ref.watch(careersHubCmsProvider);
    final ctaPath = widget.fallback.ctaPath.isNotEmpty
        ? widget.fallback.ctaPath
        : RoutePaths.careers;

    return ColoredBox(
      color: CareersPremiumSections.bg,
      child: CareersPremiumSections(
        cms: hub,
        rolesKey: _rolesKey,
        dense: true,
        onApply: (job) => _apply(job, hub.cvEmail),
        onViewRoles: _scrollToRoles,
        onViewAll: () => context.go(ctaPath),
        onSubmitCv: () => _mailto(
          hub.cvEmail,
          subject: 'CV submission — HD Homes careers',
        ),
      ),
    );
  }
}
