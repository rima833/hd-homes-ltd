import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hdhomesproject/core/theme/app_theme_extension.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

enum ButtonVariant { primary, secondary, ghost, text }

/// Premium gold primary button with gradient, loading, and hover feedback.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = false,
    this.variant = ButtonVariant.primary,
    this.useGradient = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;
  final ButtonVariant variant;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == ButtonVariant.primary
                  ? AppColors.white
                  : AppColors.gold,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIcons.sm),
                SizedBox(width: context.spacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final button = switch (variant) {
      ButtonVariant.primary => _PrimaryGradientButton(
          onPressed: enabled ? onPressed : null,
          useGradient: useGradient,
          child: child,
        ),
      ButtonVariant.secondary => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      ButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.gold,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.base,
            ),
          ),
          child: child,
        ),
      ButtonVariant.text => TextButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
    };

    final wrapped = expand ? SizedBox(width: double.infinity, child: button) : button;

    return wrapped
        .animate(target: enabled ? 1 : 0)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.98, 0.98),
          duration: AppDurations.fast,
          curve: AppAnimations.standard,
        );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.onPressed,
    required this.child,
    required this.useGradient,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.buttonBorder,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.buttonBorder,
            gradient: useGradient && onPressed != null
                ? AppColors.goldGradient
                : null,
            color: onPressed == null
                ? AppColors.gold.withValues(alpha: 0.4)
                : (useGradient ? null : AppColors.gold),
            boxShadow: onPressed != null ? AppShadows.goldGlow : null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.base,
            ),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: AppColors.white,
                  ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Alias for outline/secondary style button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      expand: expand,
      variant: ButtonVariant.secondary,
      useGradient: false,
    );
  }
}

/// Transparent ghost button with gold text.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      expand: expand,
      variant: ButtonVariant.ghost,
      useGradient: false,
    );
  }
}
