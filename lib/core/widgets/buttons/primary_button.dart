import 'package:flutter/foundation.dart';
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
    this.loadingLabel,
    this.icon,
    this.expand = false,
    this.variant = ButtonVariant.primary,
    this.useGradient = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Optional label shown while [isLoading] (defaults to [label]).
  final String? loadingLabel;
  final IconData? icon;
  final bool expand;
  final ButtonVariant variant;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final canTap = onPressed != null && !isLoading;
    // Keep primary buttons visually “active” while loading so the spinner
    // stays readable (disabled gold was washing out white indicators).
    final visuallyEnabled = canTap || isLoading;
    final busyLabel = loadingLabel ?? label;
    final indicatorColor = switch (variant) {
      ButtonVariant.primary => AppColors.charcoal,
      _ => AppColors.gold,
    };
    final labelColor = switch (variant) {
      ButtonVariant.primary => AppColors.charcoal,
      ButtonVariant.secondary => AppColors.gold,
      ButtonVariant.ghost || ButtonVariant.text => AppColors.gold,
    };

    Widget labelText({required String text, required Color color}) {
      final child = Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      );
      return expand ? Flexible(child: child) : child;
    }

    Widget child = isLoading
        ? Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                ),
              ),
              SizedBox(width: context.spacing.sm),
              labelText(text: busyLabel, color: labelColor),
            ],
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIcons.sm),
                SizedBox(width: context.spacing.sm),
              ],
              labelText(text: label, color: labelColor),
            ],
          );

    final button = switch (variant) {
      ButtonVariant.primary => _PrimaryGradientButton(
          onPressed: canTap ? onPressed : null,
          useGradient: useGradient,
          activeLook: visuallyEnabled,
          expand: expand,
          child: child,
        ),
      ButtonVariant.secondary => OutlinedButton(
          onPressed: canTap ? onPressed : null,
          child: child,
        ),
      ButtonVariant.ghost => TextButton(
          onPressed: canTap ? onPressed : null,
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
          onPressed: canTap ? onPressed : null,
          child: child,
        ),
    };

    final wrapped =
        expand ? SizedBox(width: double.infinity, child: button) : button;

    if (kIsWeb) return wrapped;

    return wrapped
        .animate(target: canTap ? 1 : 0)
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
    required this.activeLook,
    required this.expand,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool useGradient;
  final bool activeLook;
  final bool expand;

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
            gradient: useGradient && activeLook ? AppColors.goldGradient : null,
            color: !activeLook
                ? AppColors.gold.withValues(alpha: 0.4)
                : (useGradient ? null : AppColors.gold),
            boxShadow: activeLook ? AppShadows.goldGlow : null,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 48,
              minWidth: expand ? double.infinity : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.base,
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w700,
                    ),
                child: IconTheme(
                  data: const IconThemeData(color: AppColors.charcoal),
                  child: child,
                ),
              ),
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
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      expand: expand,
      isLoading: isLoading,
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
