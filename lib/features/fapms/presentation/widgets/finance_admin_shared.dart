import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

/// Shared dark ops tokens — aligned with CRM Sales desk.
abstract final class FinanceAdminUi {
  static const bg = Color(0xFF0B0E14);
  static const surface = Color(0xFF141820);
  static const surfaceElevated = Color(0xFF1A1F28);
  static const border = Color(0x18FFFFFF);
  static const muted = Color(0xFF8B929E);
  static const gold = AppColors.primaryGold;
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  static InputDecoration fieldDecoration(
    String label, {
    Widget? prefix,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: muted),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.7)),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gold.withValues(alpha: 0.7)),
      ),
    );
  }
}

class FinanceLiveBadge extends StatelessWidget {
  const FinanceLiveBadge({super.key, this.tick = 0, this.live = true});

  final int tick;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? FinanceAdminUi.success : FinanceAdminUi.gold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: live
                  ? (tick.isEven ? color : const Color(0xFF86EFAC))
                  : FinanceAdminUi.gold,
              shape: BoxShape.circle,
              boxShadow: live
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            live ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              color: live ? const Color(0xFF86EFAC) : FinanceAdminUi.gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class FinanceAdminCard extends StatelessWidget {
  const FinanceAdminCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FinanceAdminUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FinanceAdminUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FinanceAdminUi.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: FinanceAdminUi.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class FinanceEmptyState extends StatelessWidget {
  const FinanceEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FinanceAdminUi.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceStatusPill extends StatelessWidget {
  const FinanceStatusPill({
    super.key,
    required this.label,
    this.color = FinanceAdminUi.gold,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
