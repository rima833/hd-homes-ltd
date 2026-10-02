import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared dark portal chrome for `/account/*` pages (profile, security, MFA, KYC).
class AccountPortalScaffold extends StatelessWidget {
  const AccountPortalScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12151C),
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      body: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0B0E14),
          cardColor: const Color(0xFF14171E),
          dividerColor: Colors.white.withValues(alpha: 0.08),
          listTileTheme: const ListTileThemeData(
            iconColor: AppColors.gold,
            textColor: AppColors.white,
            subtitleTextStyle: TextStyle(color: AppColors.slate400),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            selectedColor: AppColors.gold.withValues(alpha: 0.18),
            labelStyle: const TextStyle(color: AppColors.white),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.gold;
              }
              return AppColors.slate500;
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            labelStyle: const TextStyle(color: AppColors.slate400),
            hintStyle: TextStyle(
              color: AppColors.slate500.withValues(alpha: 0.9),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        child: body,
      ),
    );
  }
}

/// Soft gradient panel for account portal sections.
class AccountPortalCard extends StatelessWidget {
  const AccountPortalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.accentEdge = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final bool accentEdge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF171C26),
            AppColors.darkSurface.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            if (accentEdge)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    gradient: AppColors.goldGradientVertical,
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Gold icon + title + optional subtitle for section headers.
class AccountPortalSectionHeader extends StatelessWidget {
  const AccountPortalSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Hero meter used for security readiness / KYC progress.
class AccountPortalMeterCard extends StatelessWidget {
  const AccountPortalMeterCard({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.progress,
    this.icon = LucideIcons.shield,
    this.tip,
    this.chips = const [],
  });

  final String title;
  final String valueLabel;
  final double progress;
  final IconData icon;
  final String? tip;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return AccountPortalCard(
      accentEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: const Color(0xFF0B0E14), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valueLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              color: AppColors.gold,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          if (tip != null && tip!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.sparkles, size: 16, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip!,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact pill for status / level labels.
class AccountPortalPill extends StatelessWidget {
  const AccountPortalPill({
    super.key,
    required this.label,
    this.tone = AccountPortalPillTone.neutral,
  });

  final String label;
  final AccountPortalPillTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AccountPortalPillTone.success => AppColors.success,
      AccountPortalPillTone.warning => AppColors.warning,
      AccountPortalPillTone.gold => AppColors.gold,
      AccountPortalPillTone.neutral => AppColors.slate400,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum AccountPortalPillTone { neutral, success, warning, gold }

/// Action row for security / KYC checklists.
class AccountPortalActionRow extends StatelessWidget {
  const AccountPortalActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.actionLabel,
    this.onAction,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.gold;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
      child: Row(
        children: [
          Container(
            width: dense ? 36 : 42,
            height: dense ? 36 : 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: dense ? 16 : 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate400,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// Max-width centered content for wide screens.
class AccountPortalContent extends StatelessWidget {
  const AccountPortalContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
    this.maxWidth = 920,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
