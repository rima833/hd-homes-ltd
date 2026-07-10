import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/careers/data/models/careers_hub_content.dart';
import 'package:hdhomesproject/features/careers/data/providers/careers_cms_provider.dart';
import 'package:hdhomesproject/features/careers/presentation/sections/careers_closing_sections.dart';
import 'package:hdhomesproject/features/careers/presentation/sections/careers_hero_section.dart';
import 'package:hdhomesproject/features/careers/presentation/sections/careers_hub_sections.dart';

/// Careers Hub — Volume 2 Part 12.
class CareersPage extends ConsumerStatefulWidget {
  const CareersPage({super.key});

  @override
  ConsumerState<CareersPage> createState() => _CareersPageState();
}

class _CareersPageState extends ConsumerState<CareersPage> {
  final _rolesKey = GlobalKey();
  final _applyKey = GlobalKey();
  final _faqKey = GlobalKey();
  CareerJob? _selectedJob;

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

  void _applyFor(CareerJob job) {
    setState(() => _selectedJob = job);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_applyKey));
  }

  @override
  Widget build(BuildContext context) {
    final cms = ref.watch(careersHubCmsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CareersHeroSection(
            headline: cms.heroHeadline,
            subheadline: cms.heroSubheadline,
            openPositions: cms.openPositionsCount,
            onViewRoles: () => _scrollTo(_rolesKey),
            onGeneralApply: () {
              setState(() => _selectedJob = null);
              _scrollTo(_applyKey);
            },
          ),
        ),
        SliverToBoxAdapter(
          child: CareersHubSections(
            rolesKey: _rolesKey,
            onApply: _applyFor,
          ),
        ),
        SliverToBoxAdapter(
          child: CareersClosingSections(
            applyKey: _applyKey,
            faqKey: _faqKey,
            preselectedJob: _selectedJob,
          ),
        ),
      ],
    );
  }
}
