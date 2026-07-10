import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Section 7 — Leadership team.
class AboutLeadershipSection extends StatelessWidget {
  const AboutLeadershipSection({super.key, required this.leaders});

  final List<AboutLeaderProfile> leaders;

  @override
  Widget build(BuildContext context) {
    final columns = context.isMobile ? 1 : context.isTablet ? 2 : 4;

    return SectionWrapper(
      child: Column(
        children: [
          const AnimatedSectionTitle(
            overline: 'LEADERSHIP',
            title: 'Meet our leadership team',
            subtitle:
                'Experienced professionals guiding HD Homes with vision and integrity.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth - (columns - 1) * AppSpacing.base) /
                      columns;
              return Wrap(
                spacing: AppSpacing.base,
                runSpacing: AppSpacing.base,
                children: leaders
                    .map((l) => SizedBox(width: width, child: LeadershipCard(leader: l)))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class LeadershipCard extends StatefulWidget {
  const LeadershipCard({super.key, required this.leader});

  final AboutLeaderProfile leader;

  @override
  State<LeadershipCard> createState() => _LeadershipCardState();
}

class _LeadershipCardState extends State<LeadershipCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              child: widget.leader.photoUrl != null
                  ? null
                  : const Icon(LucideIcons.user, size: 40, color: AppColors.gold),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(widget.leader.name, style: Theme.of(context).textTheme.titleMedium),
            Text(
              widget.leader.position,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.gold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.leader.bio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${widget.leader.yearsExperience}+ years experience',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: widget.leader.qualifications
                  .map((q) => Chip(label: Text(q, style: const TextStyle(fontSize: 11))))
                  .toList(),
            ),
            if (widget.leader.linkedinUrl != null || widget.leader.email != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.leader.linkedinUrl != null)
                    IconButton(
                      icon: const Icon(LucideIcons.linkedin, size: 18),
                      onPressed: () => launchUrl(Uri.parse(widget.leader.linkedinUrl!)),
                    ),
                  if (widget.leader.email != null)
                    IconButton(
                      icon: const Icon(LucideIcons.mail, size: 18),
                      onPressed: () => launchUrl(Uri.parse('mailto:${widget.leader.email}')),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
