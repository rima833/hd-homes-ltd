import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/company_statistics_section.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/about/data/models/about_cms_content.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/contact/data/providers/office_directory_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sections 15–16 — Statistics and offices.
class AboutOperationsSection extends ConsumerWidget {
  const AboutOperationsSection({
    super.key,
    required this.stats,
  });

  final List<AboutStatItem> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Full directory realtime (locations + hours + media) so About cards
    // refresh the moment Admin saves.
    ref.watch(officeDirectoryRealtimeProvider);
    ref.watch(officeLocationsRealtimeProvider);
    final cmsOffices =
        ref.watch(publishedOfficeLocationsProvider).valueOrNull ?? const [];
    final resolvedOffices = cmsOffices.isNotEmpty
        ? [
            for (final o in cmsOffices)
              AboutOfficeLocation(
                id: o.id,
                name: o.name,
                type: o.officeType,
                address: o.address,
                phone: o.phone,
                email: o.email,
                hours: o.hours,
                mapUrl: o.mapUrl,
                appointmentPath: o.appointmentPath.isEmpty
                    ? RoutePaths.bookConsultation
                    : o.appointmentPath,
                mapLabel: o.mapLabel,
                appointmentLabel: o.appointmentLabel,
              ),
          ]
        : const <AboutOfficeLocation>[];

    return Column(
      children: [
        CompanyStatisticsSection(
          stats: [
            for (final s in stats)
              CompanyStatItem(
                value: s.value,
                label: s.label,
                suffix: s.suffix ?? '',
                description: s.description,
                iconName: s.iconName,
                logoUrl: s.logoUrl,
                placement: s.placement,
              ),
          ],
        ),
        if (resolvedOffices.isNotEmpty)
          SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const AnimatedSectionTitle(
                overline: 'VISIT US',
                title: 'Office locations',
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                  spacing: AppSpacing.base,
                  runSpacing: AppSpacing.base,
                  children: resolvedOffices
                      .map(
                        (o) => SizedBox(
                          width: context.isMobile ? double.infinity : 340,
                          child: _OfficeCard(office: o),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office});

  final AboutOfficeLocation office;

  @override
  Widget build(BuildContext context) {
    final mapUri = Uri.tryParse(office.mapUrl);
    final appointmentPath = office.appointmentPath.trim().isEmpty
        ? RoutePaths.bookConsultation
        : office.appointmentPath.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.neutral200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(label: Text(office.type)),
          const SizedBox(height: AppSpacing.sm),
          Text(office.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _OfficeRow(icon: LucideIcons.mapPin, text: office.address),
          _OfficeRow(icon: LucideIcons.phone, text: office.phone),
          _OfficeRow(icon: LucideIcons.mail, text: office.email),
          _OfficeRow(icon: LucideIcons.clock, text: office.hours),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Flexible(
                child: TextButton(
                  onPressed: mapUri == null
                      ? null
                      : () => launchUrl(
                            mapUri,
                            mode: LaunchMode.externalApplication,
                          ),
                  child: Text(
                    office.mapLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                flex: 2,
                child: PrimaryButton(
                  label: office.appointmentLabel,
                  expand: true,
                  onPressed: () {
                    if (appointmentPath.startsWith('http')) {
                      launchUrl(
                        Uri.parse(appointmentPath),
                        mode: LaunchMode.externalApplication,
                      );
                      return;
                    }
                    final id = office.id?.trim();
                    final path = (id != null && id.isNotEmpty)
                        ? '$appointmentPath?office=$id'
                        : appointmentPath;
                    context.go(path);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficeRow extends StatelessWidget {
  const _OfficeRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
