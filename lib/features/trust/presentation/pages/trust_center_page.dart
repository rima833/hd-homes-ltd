import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/trust/data/providers/trust_cms_provider.dart';
import 'package:hdhomesproject/features/trust/presentation/sections/trust_closing_sections.dart';
import 'package:hdhomesproject/features/trust/presentation/sections/trust_hero_section.dart';
import 'package:hdhomesproject/features/trust/presentation/sections/trust_hub_sections.dart';

/// Trust, Legal & Corporate Information Center — Volume 2 Part 14.
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

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(trustHubCmsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TrustHeroSection(
            headline: cms.heroHeadline,
            subheadline: cms.heroSubheadline,
            onDownloadProfile: () {},
            onViewCertifications: () => _scrollTo(_certificationsKey),
            onInvestorInfo: () => _scrollTo(_legalKey),
          ),
        ),
        SliverToBoxAdapter(
          child: TrustHubSections(
            certificationsKey: _certificationsKey,
            legalKey: _legalKey,
            faqKey: _faqKey,
          ),
        ),
        SliverToBoxAdapter(child: TrustClosingSections(faqKey: _faqKey)),
      ],
    );
  }
}
