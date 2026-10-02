import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Local luxury tokens for the Book Inspection experience.
abstract final class InspectionLux {
  static const Color bg = Color(0xFF0D0E12);
  static const Color surface = Color(0xFF171A21);
  static const Color elevated = Color(0xFF1A1D23);
  static const Color gold = Color(0xFFD8A63C);
  static const Color goldLight = Color(0xFFF0C76A);
  static const Color muted = Color(0xFF9AA0AB);
  static const Color border = Color(0xFF2A3140);
  static const double radius = 16;

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class LuxuryCard extends StatelessWidget {
  const LuxuryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: InspectionLux.surface,
        borderRadius: BorderRadius.circular(InspectionLux.radius),
        border: Border.all(color: InspectionLux.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AnimatedSection extends StatefulWidget {
  const AnimatedSection({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<AnimatedSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    // Start visible so a delayed ticker never leaves form sections blank
    // (common on Flutter web when the first paint is loading).
    _c.value = 1;
    if (widget.delay > Duration.zero) {
      _c.value = 0;
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class LuxuryDropdown<T> extends StatelessWidget {
  const LuxuryDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: InspectionLux.muted),
        filled: true,
        fillColor: InspectionLux.elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InspectionLux.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InspectionLux.gold, width: 1.4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint == null
              ? null
              : Text(hint!, style: const TextStyle(color: InspectionLux.muted)),
          dropdownColor: InspectionLux.elevated,
          style: const TextStyle(color: AppColors.white),
          iconEnabledColor: InspectionLux.gold,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class LuxuryTextField extends StatelessWidget {
  const LuxuryTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.white),
      cursorColor: InspectionLux.gold,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: InspectionLux.muted),
        hintStyle: TextStyle(color: InspectionLux.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: InspectionLux.elevated,
        suffixIcon: icon == null
            ? null
            : Icon(icon, color: InspectionLux.gold, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InspectionLux.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: InspectionLux.gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),
    );
  }
}

class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = 64,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover && enabled ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: widget.height,
          decoration: BoxDecoration(
            gradient: InspectionLux.goldGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: InspectionLux.gold.withValues(alpha: _hover ? 0.45 : 0.25),
                blurRadius: _hover ? 28 : 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? widget.onPressed : null,
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: InspectionLux.bg,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: GoogleFonts.inter(
                              color: InspectionLux.bg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: InspectionLux.bg,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InspectionStepper extends StatelessWidget {
  const InspectionStepper({
    super.key,
    required this.step,
    required this.onStepTap,
    this.maxStepReached = 0,
  });

  final int step;
  final int maxStepReached;
  final ValueChanged<int> onStepTap;

  static const labels = [
    'Personal Info',
    'Property',
    'Schedule',
    'Preferences',
    'Confirm',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Container(
                    width: compact ? 16 : 36,
                    height: 1,
                    margin: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
                    color: i <= step
                        ? InspectionLux.gold.withValues(alpha: 0.75)
                        : InspectionLux.border,
                  ),
                InkWell(
                  onTap: i <= maxStepReached ? () => onStepTap(i) : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 2 : 4,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == step
                                ? InspectionLux.gold
                                : Colors.transparent,
                            border: Border.all(
                              color: i == step
                                  ? InspectionLux.gold
                                  : InspectionLux.border,
                              width: 1.4,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: i == step
                                  ? InspectionLux.bg
                                  : InspectionLux.muted,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: i == step
                                ? InspectionLux.gold
                                : InspectionLux.muted,
                            fontWeight: i == step
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: compact ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
