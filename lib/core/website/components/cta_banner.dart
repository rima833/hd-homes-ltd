import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';

/// Full-width call-to-action band for conversion moments.
class CtaBanner extends StatelessWidget {
  const CtaBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.primaryLabel,
    this.primaryPath,
    this.secondaryLabel,
    this.secondaryPath,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final String? primaryLabel;
  final String? primaryPath;
  final String? secondaryLabel;
  final String? secondaryPath;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.pagePadding,
        vertical: AppSpacing.section,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.charcoal,
        borderRadius: AppRadius.cardBorder,
      ),
      child: context.isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _children(context),
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _text(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                ..._actions(context),
              ],
            ),
    );
  }

  List<Widget> _children(BuildContext context) => [
        ..._text(context),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: _actions(context),
        ),
      ];

  List<Widget> _text(BuildContext context) => [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.white,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        ],
      ];

  List<Widget> _actions(BuildContext context) => [
        if (primaryLabel != null && primaryPath != null)
          PrimaryButton(
            label: primaryLabel!,
            onPressed: () => context.go(primaryPath!),
          ),
        if (secondaryLabel != null && secondaryPath != null)
          PrimaryButton(
            label: secondaryLabel!,
            variant: ButtonVariant.secondary,
            onPressed: () => context.go(secondaryPath!),
          ),
      ];
}
