import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_admin_models.dart';

abstract final class InspectionAdminUi {
  static const bg = Color(0xFF0A0B0D);
  static const surface = Color(0xFF12141A);
  static const surfaceElevated = Color(0xFF1A1D26);
  static const border = Color(0x22FFFFFF);
  static const muted = Color(0x99FFFFFF);
  static const gold = AppColors.primaryGold;

  static InputDecoration fieldDecoration(
    String label, {
    Widget? prefix,
    Widget? suffix,
    String? hint,
    bool compact = false,
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
      isDense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 10 : 14,
      ),
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

class InspectionLiveBadge extends StatelessWidget {
  const InspectionLiveBadge({super.key, this.tick = 0});

  /// Kept so existing desks can keep passing the animation tick.
  final int tick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: ValueKey<int>(tick), width: 0, height: 0);
  }
}

/// KPI strip shared by inspection / consultation / callback desks.
/// Every card is kept — scroll horizontally to see them all.
class AdminOpsStatItem {
  const AdminOpsStatItem({
    required this.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String key;
  final String label;
  final int value;
  final IconData icon;
  final Color accent;
}

class AdminOpsStatStrip extends StatefulWidget {
  const AdminOpsStatStrip({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<AdminOpsStatItem> items;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  static const double height = 78;

  @override
  State<AdminOpsStatStrip> createState() => _AdminOpsStatStripState();
}

class _AdminOpsStatStripState extends State<AdminOpsStatStrip> {
  final _scroll = ScrollController();
  static const double _cardWidth = 148;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AdminOpsStatStrip.height,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              overscroll: true,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: false,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                primary: false,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 6, right: 4),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return SizedBox(
                    width: _cardWidth,
                    child: _AdminOpsStatCard(
                      item: item,
                      selected: widget.selectedKey == item.key,
                      onTap: () => widget.onSelect(item.key),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (items.length > 4)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Scroll sideways to see every status card',
              style: TextStyle(
                color: InspectionAdminUi.muted,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminOpsStatCard extends StatelessWidget {
  const _AdminOpsStatCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AdminOpsStatItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? item.accent.withValues(alpha: 0.12)
                : InspectionAdminUi.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? item.accent.withValues(alpha: 0.45)
                  : InspectionAdminUi.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(item.icon, size: 15, color: item.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${item.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sales-style horizontal page tabs for ops desks (no TabBarView nesting).
class AdminOpsPageTabs extends StatelessWidget {
  const AdminOpsPageTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: InspectionAdminUi.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              InkWell(
                onTap: () => onChanged(i),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == index
                            ? InspectionAdminUi.gold
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color:
                          i == index ? InspectionAdminUi.gold : Colors.white54,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class InspectionFilterChip extends StatelessWidget {
  const InspectionFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? InspectionAdminUi.gold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : InspectionAdminUi.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.55) : InspectionAdminUi.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : InspectionAdminUi.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? color : InspectionAdminUi.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InspectionStatusBadge extends StatelessWidget {
  const InspectionStatusBadge({super.key, required this.status});

  final String status;

  Color get _color => switch (status) {
        'confirmed' => AppColors.success,
        'completed' => const Color(0xFF3B82F6),
        'cancelled' => AppColors.error,
        'no_show' => const Color(0xFFF59E0B),
        _ => InspectionAdminUi.gold,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.28)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class InspectionAdminCard extends StatelessWidget {
  const InspectionAdminCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InspectionAdminUi.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InspectionAdminUi.border),
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
                        color: InspectionAdminUi.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: InspectionAdminUi.muted,
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

class InspectionNumberField extends StatelessWidget {
  const InspectionNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InspectionAdminUi.fieldDecoration(label),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

extension InspectionSettingsCopy on InspectionSettingsRow {
  InspectionSettingsRow copyWith({
    int? slotDurationMinutes,
    int? bufferMinutes,
    int? minNoticeHours,
    int? maxBookingDays,
    int? maxDailyInspections,
    int? maxAgentDailyInspections,
    bool? allowAgentSelection,
    String? timezone,
  }) {
    return InspectionSettingsRow(
      id: id,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      minNoticeHours: minNoticeHours ?? this.minNoticeHours,
      maxBookingDays: maxBookingDays ?? this.maxBookingDays,
      maxDailyInspections: maxDailyInspections ?? this.maxDailyInspections,
      maxAgentDailyInspections:
          maxAgentDailyInspections ?? this.maxAgentDailyInspections,
      allowAgentSelection: allowAgentSelection ?? this.allowAgentSelection,
      timezone: timezone ?? this.timezone,
    );
  }
}
