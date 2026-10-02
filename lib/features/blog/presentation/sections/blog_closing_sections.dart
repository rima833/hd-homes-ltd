import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/cta_banner.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';

/// Closing CTA for the public blog hub.
class BlogClosingSections extends StatelessWidget {
  const BlogClosingSections({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionWrapper(
      backgroundColor: AppColors.charcoal,
      child: CtaBanner(
        title: 'Need advice on a property decision?',
        subtitle:
            'Talk to HD Homes — inspections, investment, and documentation support.',
        primaryLabel: 'Contact hub',
        primaryPath: RoutePaths.contact,
        secondaryLabel: 'Book consultation',
        secondaryPath: RoutePaths.bookConsultation,
      ),
    );
  }
}
