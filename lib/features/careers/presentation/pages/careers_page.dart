import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/website/seo/seo_binder.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/core/website/seo/seo_metadata.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/careers/presentation/sections/careers_premium_sections.dart';
import 'package:url_launcher/url_launcher.dart';

/// Careers Hub — premium dark-luxury CMS-backed page.
class CareersPage extends ConsumerStatefulWidget {
  const CareersPage({super.key});

  @override
  ConsumerState<CareersPage> createState() => _CareersPageState();
}

class _CareersPageState extends ConsumerState<CareersPage> {
  final _rolesKey = GlobalKey();

  void _scrollToRoles() {
    final target = _rolesKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
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
    final cms = ref.watch(careersHubCmsProvider);

    final title = cms.seoTitle?.trim();
    final description = cms.seoDescription?.trim();
    final page = CareersPremiumSections(
      cms: cms,
      rolesKey: _rolesKey,
      dense: true,
      onApply: (job) => _apply(job, cms.cvEmail),
      onViewRoles: _scrollToRoles,
      onSubmitCv: () => _mailto(
        cms.cvEmail,
        subject: 'CV submission — HD Homes careers',
      ),
    );

    if ((title == null || title.isEmpty) &&
        (description == null || description.isEmpty)) {
      return page;
    }

    return SeoBinder(
      metadata: SeoMetadata(
        title: (title != null && title.isNotEmpty)
            ? title
            : SeoMetadata.careersHub.title,
        description: (description != null && description.isNotEmpty)
            ? description
            : SeoMetadata.careersHub.description,
        canonicalUrl: SeoConfig.canonicalFor(RoutePaths.careers),
        keywords: SeoMetadata.careersHub.keywords,
        structuredData: SeoMetadata.careersHub.structuredData,
        ogImageUrl: cms.heroImageUrl,
      ),
      child: page,
    );
  }
}
