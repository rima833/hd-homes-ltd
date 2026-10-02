import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/layout/public/published_chrome.dart';
import 'package:hdhomesproject/core/navigation/deferred_navigation.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/settings/domain/entities/platform_settings.dart';
import 'package:hdhomesproject/features/settings/domain/entities/public_website_gates.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';

class PublicFooter extends ConsumerWidget {
  const PublicFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(footerRealtimeProvider);
    final configured = ref.watch(supabaseConfiguredProvider);
    final columns = ref.watch(publishedFooterSectionsProvider).valueOrNull;
    final settings = ref.watch(publishedPlatformSettingsProvider).valueOrNull;

    return Container(
      width: double.infinity,
      color: AppColors.charcoal,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          Text(
            AppStrings.companyName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.tagline,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.gray),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (columns != null)
            _CmsColumns(columns: columns, settings: settings)
          else if (!configured)
            const _BuiltInLinks(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '© ${DateTime.now().year} HD Homes Ltd. All rights reserved.',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}

class _CmsColumns extends StatelessWidget {
  const _CmsColumns({required this.columns, required this.settings});

  final List<CmsSectionRecord> columns;
  final PlatformSettingsBundle? settings;

  @override
  Widget build(BuildContext context) {
    final visible = <Widget>[];
    for (final column in columns) {
      final links = cmsLinksFromContent(column.content).where((link) {
        if (settings == null) return true;
        return settings!.allowsPublicPath(link.url) &&
            settings!.allowsFooterLabel(link.label);
      }).toList();
      if (links.isEmpty && (column.title ?? '').trim().isEmpty) continue;
      visible.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (column.displayTitle.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  column.displayTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 0,
              children: [
                for (final link in links)
                  TextButton(
                    onPressed: () => openCmsLink(context, link.url),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(link.label),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.lg,
      alignment: WrapAlignment.center,
      children: visible,
    );
  }
}

class _BuiltInLinks extends StatelessWidget {
  const _BuiltInLinks();

  @override
  Widget build(BuildContext context) {
    const links = <(String, String)>[
      ('About', RoutePaths.about),
      ('Properties', RoutePaths.properties),
      ('Payment Calculator', RoutePaths.paymentCalculator),
      ('Investment', RoutePaths.investment),
      ('ROI Calculator', RoutePaths.roiCalculator),
      ('Contact', RoutePaths.contact),
      ('Privacy', '/pages/privacy'),
      ('Terms', '/pages/terms'),
      ('Cookies', '/pages/cookies'),
      ('Refunds', '/pages/refund-policy'),
    ];
    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.sm,
      alignment: WrapAlignment.center,
      children: [
        for (final link in links)
          TextButton(
            onPressed: () => goDeferred(context, link.$2),
            child: Text(
              link.$1,
              style: const TextStyle(color: AppColors.white),
            ),
          ),
      ],
    );
  }
}
