import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

class WebsiteBreadcrumbs extends StatelessWidget {
  const WebsiteBreadcrumbs({
    super.key,
    required this.items,
  });

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Breadcrumb',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xs,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Theme.of(context).hintColor,
              ),
            if (items[i].path != null && i < items.length - 1)
              TextButton(
                onPressed: () => context.go(items[i].path!),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  items[i].label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              )
            else
              Text(
                items[i].label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
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
