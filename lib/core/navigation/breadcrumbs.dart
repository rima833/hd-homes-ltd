import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Breadcrumb trail for internal pages.
class AppBreadcrumbs extends StatelessWidget {
  const AppBreadcrumbs({
    super.key,
    required this.items,
  });

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            _Crumb(
              item: items[i],
              isLast: i == items.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class BreadcrumbItem {
  const BreadcrumbItem({required this.label, this.path});

  final String label;
  final String? path;
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.item, required this.isLast});

  final BreadcrumbItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isLast
              ? AppColors.gold
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
        );

    if (item.path != null && !isLast) {
      return InkWell(
        onTap: () => context.go(item.path!),
        borderRadius: AppRadius.buttonBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(item.label, style: style),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(item.label, style: style),
    );
  }
}
