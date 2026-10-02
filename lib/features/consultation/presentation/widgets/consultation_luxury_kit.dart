import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

abstract final class ConsultationLux {
  static const Color bg = Color(0xFF0E1015);
  static const Color surface = Color(0xFF171C24);
  static const Color elevated = Color(0xFF1D2430);
  static const Color gold = Color(0xFFD8A63C);
  static const Color goldMid = Color(0xFFE9BE58);
  static const Color goldLight = Color(0xFFF6D47A);
  static const Color muted = Color(0xB8FFFFFF);
  static const Color border = Color(0xFF2A3140);
  static const Color success = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFFF5C5C);
  static const double radius = 24;
  static const double buttonRadius = 20;

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldMid, goldLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ConsultationLux.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(ConsultationLux.radius),
        border: Border.all(
          color: (borderColor ?? ConsultationLux.border).withValues(alpha: 0.9),
        ),
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

class LuxuryCard extends StatelessWidget {
  const LuxuryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      margin: margin,
      borderColor: borderColor,
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
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
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

class PremiumTextField extends StatelessWidget {
  const PremiumTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.white),
      cursorColor: ConsultationLux.gold,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: ConsultationLux.muted),
        hintStyle: TextStyle(color: ConsultationLux.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: ConsultationLux.elevated,
        prefixIcon: icon == null
            ? null
            : Icon(icon, color: ConsultationLux.gold, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ConsultationLux.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ConsultationLux.gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ConsultationLux.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ConsultationLux.danger, width: 1.4),
        ),
      ),
    );
  }
}

class PremiumDropdown<T> extends StatelessWidget {
  const PremiumDropdown({
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
        labelStyle: const TextStyle(color: ConsultationLux.muted),
        filled: true,
        fillColor: ConsultationLux.elevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ConsultationLux.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ConsultationLux.gold, width: 1.4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint == null
              ? null
              : Text(hint!, style: const TextStyle(color: ConsultationLux.muted)),
          dropdownColor: ConsultationLux.elevated,
          style: const TextStyle(color: AppColors.white),
          iconEnabledColor: ConsultationLux.gold,
          items: items,
          onChanged: onChanged,
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
    this.height = 72,
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
            gradient: ConsultationLux.goldGradient,
            borderRadius: BorderRadius.circular(ConsultationLux.buttonRadius),
            boxShadow: [
              BoxShadow(
                color:
                    ConsultationLux.gold.withValues(alpha: _hover ? 0.5 : 0.28),
                blurRadius: _hover ? 30 : 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(ConsultationLux.buttonRadius),
              onTap: enabled ? widget.onPressed : null,
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: ConsultationLux.bg,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: GoogleFonts.inter(
                              color: ConsultationLux.bg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _hover ? 14 : 10,
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: ConsultationLux.bg,
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

class ProgressStepper extends StatelessWidget {
  const ProgressStepper({
    super.key,
    required this.step,
    required this.onStepTap,
  });

  final int step;
  final ValueChanged<int> onStepTap;

  static const labels = [
    'Personal Details',
    'Consultation Type',
    'Schedule',
    'Review & Confirm',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 36,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: i <= step ? ConsultationLux.goldGradient : null,
                  color: i <= step ? null : ConsultationLux.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            InkWell(
              onTap: () => onStepTap(i),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: i == step
                      ? ConsultationLux.gold.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: i <= step
                        ? ConsultationLux.gold
                        : ConsultationLux.border,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: i <= step
                          ? ConsultationLux.gold
                          : ConsultationLux.elevated,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i <= step
                              ? ConsultationLux.bg
                              : ConsultationLux.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: i <= step
                            ? AppColors.white
                            : ConsultationLux.muted,
                        fontWeight:
                            i == step ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
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
  }
}

class StickySidebar extends StatelessWidget {
  const StickySidebar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(alignment: Alignment.topCenter, child: child);
  }
}
