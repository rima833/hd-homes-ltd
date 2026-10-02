import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_cms_provider.dart';
import 'package:hdhomesproject/features/trust/presentation/sections/trust_closing_sections.dart';
import 'package:hdhomesproject/features/trust/presentation/sections/trust_hero_section.dart';
import 'package:hdhomesproject/features/trust/presentation/sections/trust_hub_sections.dart';

/// Trust, Legal & Corporate Information Center — live CMS end-to-end.
class TrustCenterPage extends ConsumerStatefulWidget {
  const TrustCenterPage({super.key});

  @override
  ConsumerState<TrustCenterPage> createState() => _TrustCenterPageState();
}

class _TrustCenterPageState extends ConsumerState<TrustCenterPage> {
  final _certificationsKey = GlobalKey();
  final _legalKey = GlobalKey();
  final _faqKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _openProfileDownload() async {
    final cms = ref.read(trustHubCmsProvider);
    final raw = cms.profilePdfUrl ?? cms.profileBrochureUrl ?? cms.profileViewUrl;
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Company profile download is not published yet. Update it in Admin → Website → Digital Profile.',
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(trustHubCmsProvider);

    return Column(
      children: [
        TrustHeroSection(
          headline: cms.heroHeadline,
          subheadline: cms.heroSubheadline,
          backgroundImageUrl: cms.backgroundImageUrl,
          backgroundVideoUrl: cms.backgroundVideoUrl,
          onDownloadProfile: _openProfileDownload,
          onViewCertifications: () => _scrollTo(_certificationsKey),
          onInvestorInfo: () => _scrollTo(_legalKey),
        ),
        TrustHubSections(
          certificationsKey: _certificationsKey,
          legalKey: _legalKey,
        ),
        TrustClosingSections(faqKey: _faqKey),
      ],
    );
  }
}
