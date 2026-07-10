import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppAnimations.standard,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.gold.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: AppRadius.buttonBorder,
        ),
        child: IconButton(
          onPressed: widget.onPressed,
          icon: Icon(
            widget.icon,
            color: widget.color ?? Theme.of(context).colorScheme.onSurface,
            size: AppIcons.md,
          ),
          tooltip: widget.tooltip,
        ),
      ),
    );
    return button;
  }
}
