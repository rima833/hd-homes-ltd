import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

const kInvestmentHubBg = Color(0xFF0B0D11);
const kInvestmentCardBg = Color(0xFF171A21);
const kInvestmentGold = Color(0xFFDDAA3F);
const kInvestmentGoldSoft = Color(0xFFF2C66D);
const kInvestmentMuted = Color(0xFFB7BDC8);

IconData investmentCategoryIcon(String name) {
  switch (name) {
    case 'layoutGrid':
      return LucideIcons.layoutGrid;
    case 'lineChart':
      return LucideIcons.lineChart;
    case 'package':
      return LucideIcons.package;
    case 'building':
      return LucideIcons.building;
    case 'map':
      return LucideIcons.mapPin;
    case 'splitSquareVertical':
      return LucideIcons.pieChart;
    case 'building2':
    default:
      return LucideIcons.building2;
  }
}

Color investmentStatusColor(String status) {
  switch (status) {
    case 'limited':
    case 'closing_soon':
      return const Color(0xFFC084FC);
    case 'coming_soon':
      return kInvestmentGoldSoft;
    case 'closed':
    case 'sold_out':
      return const Color(0xFF94A3B8);
    default:
      return const Color(0xFF4ADE80);
  }
}

class InvestmentStatusBadge extends StatelessWidget {
  const InvestmentStatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = investmentStatusColor(status);
    final pulse = status == 'open';
    final dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: pulse ? 8 : 0,
          ),
        ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label ?? status.replaceAll('_', ' '),
          style: const TextStyle(
            color: kInvestmentGold,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class InvestmentCategoryBadge extends StatelessWidget {
  const InvestmentCategoryBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kInvestmentGold.withValues(alpha: 0.45)),
        color: Colors.black.withValues(alpha: 0.28),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kInvestmentGoldSoft,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class InvestmentMetric extends StatelessWidget {
  const InvestmentMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: kInvestmentGold),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: kInvestmentMuted,
                    fontSize: 10,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InvestmentProgressBar extends StatelessWidget {
  const InvestmentProgressBar({
    super.key,
    required this.progress,
    this.label,
  });

  final double progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label ?? '$pct% funded',
              style: const TextStyle(
                color: kInvestmentMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: const TextStyle(
                color: kInvestmentGold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: kInvestmentGold.withValues(alpha: 0.12),
            color: kInvestmentGold,
          ),
        ),
      ],
    );
  }
}

class InvestmentEmptyState extends StatelessWidget {
  const InvestmentEmptyState({
    super.key,
    this.title = 'No investment opportunities are currently available.',
    this.message =
        'Published opportunities from the HD Homes Admin Panel appear here in real time.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: kInvestmentCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInvestmentGold.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.lineChart, color: kInvestmentGold, size: 28),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kInvestmentMuted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class InvestmentCardSkeleton extends StatelessWidget {
  const InvestmentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = 120, double h = 12}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: kInvestmentCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kInvestmentGold.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(w: 90, h: 22),
          const SizedBox(height: 18),
          bar(w: 220, h: 22),
          const SizedBox(height: 10),
          bar(w: 140, h: 12),
          const SizedBox(height: 16),
          bar(w: 280, h: 12),
          const Spacer(),
          Row(
            children: [
              bar(w: 70, h: 28),
              const SizedBox(width: 16),
              bar(w: 70, h: 28),
              const SizedBox(width: 16),
              bar(w: 70, h: 28),
            ],
          ),
        ],
      ),
    );
  }
}

class InvestmentTrustStrip extends StatelessWidget {
  const InvestmentTrustStrip({super.key, required this.mobile});

  final bool mobile;

  static const items = [
    (
      LucideIcons.shieldCheck,
      'Secure Investments',
      'Regulated partners and secure escrow protection.',
    ),
    (
      LucideIcons.award,
      'Proven Performance',
      '15+ years of delivering strong returns.',
    ),
    (
      LucideIcons.headphones,
      'Expert Guidance',
      'Dedicated team supporting your investment journey.',
    ),
    (
      LucideIcons.fileBarChart,
      'Transparent Reporting',
      'Regular updates, full visibility, and audited reports.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final item in items)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$1, size: 18, color: kInvestmentGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          color: kInvestmentMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 8 : 6,
        vertical: mobile ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: kInvestmentCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInvestmentGold.withValues(alpha: 0.16)),
      ),
      child: mobile
          ? Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(color: kInvestmentGold.withValues(alpha: 0.12)),
                  tiles[i],
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 54,
                      color: kInvestmentGold.withValues(alpha: 0.16),
                    ),
                  tiles[i],
                ],
              ],
            ),
    );
  }
}

class InvestmentFilterBar extends StatelessWidget {
  const InvestmentFilterBar({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.onSelected,
  });

  final List<CmsWebsiteInvestmentCategory> categories;
  final String? selectedSlug;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _FilterChip(
        label: 'All',
        icon: LucideIcons.layoutGrid,
        selected: selectedSlug == null,
        onTap: () => onSelected(null),
      ),
      for (final c in categories)
        _FilterChip(
          label: c.name,
          icon: investmentCategoryIcon(c.icon),
          selected: selectedSlug == c.slug,
          onTap: () => onSelected(c.slug),
        ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? kInvestmentGold.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? kInvestmentGold
                  : Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(LucideIcons.check, size: 13, color: kInvestmentGold),
                const SizedBox(width: 6),
              ] else ...[
                Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? kInvestmentGold : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvestmentSectionHeader extends StatelessWidget {
  const InvestmentSectionHeader({
    super.key,
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.mobile,
  });

  final String overline;
  final String title;
  final String subtitle;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final lower = title.toLowerCase();
    final accentWord = 'investment';
    final idx = lower.indexOf(accentWord);
    final before = idx >= 0 ? title.substring(0, idx) : title;
    final accent = idx >= 0
        ? title.substring(idx, idx + accentWord.length)
        : '';
    final after = idx >= 0 ? title.substring(idx + accentWord.length) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 1,
              color: kInvestmentGold.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 10),
            Text(
              overline.toUpperCase(),
              style: const TextStyle(
                color: kInvestmentGold,
                letterSpacing: 2.4,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: before),
              if (accent.isNotEmpty)
                TextSpan(
                  text: accent,
                  style: GoogleFonts.playfairDisplay(
                    fontStyle: FontStyle.italic,
                    color: kInvestmentGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              TextSpan(text: after),
            ],
          ),
          style: GoogleFonts.playfairDisplay(
            fontSize: mobile ? 32 : 44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kInvestmentMuted,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}
