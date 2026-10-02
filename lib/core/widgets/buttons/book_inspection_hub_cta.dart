import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/l10n/app_strings.dart';

/// Nav CTA — cycles Book Inspection ↔ Contact Hub; tap goes straight to the route.
class BookInspectionHubCta extends StatefulWidget {
  const BookInspectionHubCta({
    super.key,
    this.expand = false,
    this.onPressed,
  });

  final bool expand;
  final VoidCallback? onPressed;

  @override
  State<BookInspectionHubCta> createState() => _BookInspectionHubCtaState();
}

class _BookInspectionHubCtaState extends State<BookInspectionHubCta> {
  static const _width = 152.0;
  static const _hubGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF16324F), Color(0xFF0F766E)],
  );

  var _showHub = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _showHub = !_showHub);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _open() {
    final path = _showHub
        ? '${RoutePaths.contact}?from=book-inspection'
        : RoutePaths.bookInspection;
    widget.onPressed?.call();
    // Defer go_router until after the tap frame — sync go() can freeze Flutter web.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          width: widget.expand ? double.infinity : _width,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: _showHub ? _hubGradient : AppColors.goldGradient,
            border: Border.all(
              color: AppColors.gold.withValues(alpha: _showHub ? 0.85 : 0.35),
              width: 1.2,
            ),
          ),
          child: Text(
            _showHub
                ? AppStrings.navContactHub
                : AppStrings.navBookInspection,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _showHub ? AppColors.goldLight : AppColors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
          ),
        ),
      ),
    );
  }
}
