import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/export/export_engine.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/domain/entities/property_listings_insights.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Premium Property Listings admin surface matching the HD Homes mockup.
class PropertyListingsDashboard extends ConsumerStatefulWidget {
  const PropertyListingsDashboard({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.propertiesAsync,
    required this.onRetry,
    required this.onNewProperty,
    required this.onEdit,
    required this.onView,
    required this.onTogglePublished,
    required this.onToggleFeatured,
    required this.onDelete,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final AsyncValue<List<CmsPropertyFeatured>> propertiesAsync;
  final VoidCallback onRetry;
  final VoidCallback onNewProperty;
  final ValueChanged<CmsPropertyFeatured> onEdit;
  final ValueChanged<CmsPropertyFeatured> onView;
  final Future<void> Function(CmsPropertyFeatured property, bool value)
      onTogglePublished;
  final Future<void> Function(CmsPropertyFeatured property, bool value)
      onToggleFeatured;
  final Future<void> Function(CmsPropertyFeatured property) onDelete;

  @override
  ConsumerState<PropertyListingsDashboard> createState() =>
      _PropertyListingsDashboardState();
}

class _PropertyListingsDashboardState
    extends ConsumerState<PropertyListingsDashboard> {
  String? _statusFilter;
  String? _typeFilter;
  String? _locationFilter;
  int _page = 0;
  static const _pageSize = 5;

  static const _bg = Color(0xFF0B0E14);
  static const _card = Color(0xFF12161F);
  static const _cardBorder = Color(0xFF2A3140);
  static const _muted = Color(0xFF8B93A7);
  static const _field = Color(0xFF161B26);

  @override
  Widget build(BuildContext context) {
    ref.watch(propertyListingsRealtimeProvider);
    ref.watch(publishedPropertiesRealtimeProvider);
    final insightsAsync = ref.watch(propertyListingsInsightsProvider);
    final insights =
        insightsAsync.valueOrNull ?? const PropertyListingsInsights();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final body = widget.propertiesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          ),
          error: (err, _) => _ErrorPane(message: '$err', onRetry: widget.onRetry),
          data: (properties) {
            final filtered = _applyFilters(properties);
            final total = filtered.length;
            final pageCount = math.max(1, (total / _pageSize).ceil());
            final page = _page.clamp(0, pageCount - 1);
            final start = page * _pageSize;
            final end = math.min(start + _pageSize, total);
            final pageItems = total == 0
                ? <CmsPropertyFeatured>[]
                : filtered.sublist(start, end);
            final metrics = _Metrics.from(properties);

            final table = _PropertiesTableCard(
              total: total,
              properties: pageItems,
              insights: insights,
              start: total == 0 ? 0 : start + 1,
              end: end,
              page: page,
              pageCount: pageCount,
              onPage: (p) => setState(() => _page = p),
              onEdit: widget.onEdit,
              onView: widget.onView,
              onScheduleInspection: (p) =>
                  context.go(RoutePaths.dashboardInspections),
              onTogglePublished: widget.onTogglePublished,
              onToggleFeatured: widget.onToggleFeatured,
              onDelete: widget.onDelete,
              onNewProperty: widget.onNewProperty,
              onExport: () => _exportProperties(filtered, insights),
            );
            final rail = _RightRail(
              onNewProperty: widget.onNewProperty,
              onSiteInspection: () =>
                  context.go(RoutePaths.dashboardInspections),
              onExportReport: () => _exportProperties(filtered, insights),
              onViewInquiries: () => context.go(RoutePaths.dashboardCrm),
              onReferAgent: () => context.go(RoutePaths.dashboardUsers),
              onViewCalendar: () => context.go(RoutePaths.dashboardInspections),
              inspections: insights.inspections,
              performance: insights.performance,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ListingsHero(onNewProperty: widget.onNewProperty),
                const SizedBox(height: 14),
                _MetricsRow(metrics: metrics),
                const SizedBox(height: 14),
                _FilterBar(
                  searchController: widget.searchController,
                  onSearchChanged: widget.onSearchChanged,
                  statusFilter: _statusFilter,
                  typeFilter: _typeFilter,
                  locationFilter: _locationFilter,
                  statusOptions: _uniqueStatuses(properties),
                  typeOptions: _uniqueTypes(properties),
                  locationOptions: _uniqueLocations(properties),
                  onStatus: (v) => setState(() {
                    _statusFilter = v;
                    _page = 0;
                  }),
                  onType: (v) => setState(() {
                    _typeFilter = v;
                    _page = 0;
                  }),
                  onLocation: (v) => setState(() {
                    _locationFilter = v;
                    _page = 0;
                  }),
                ),
                const SizedBox(height: 14),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: table),
                      const SizedBox(width: 14),
                      SizedBox(width: 280, child: rail),
                    ],
                  )
                else ...[
                  table,
                  const SizedBox(height: 14),
                  rail,
                ],
              ],
            );
          },
        );

        final maxH = constraints.maxHeight;
        final scrollable = !maxH.isFinite || maxH <= 0
            ? body
            : SingleChildScrollView(
                primary: false,
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: maxH),
                  child: body,
                ),
              );

        return ColoredBox(
          color: _bg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: scrollable,
          ),
        );
      },
    );
  }

  Future<void> _exportProperties(
    List<CmsPropertyFeatured> properties,
    PropertyListingsInsights insights,
  ) async {
    final buf = StringBuffer(
      'Title,Code,Type,Location,Price,Status,Views,Inquiries,Published,Featured\n',
    );
    for (final p in properties) {
      final stats = insights.statsFor(p.id);
      String esc(String? v) {
        final s = (v ?? '').replaceAll('"', '""');
        return '"$s"';
      }

      buf.writeln(
        [
          esc(p.title),
          esc(p.propertyCode),
          esc(p.propertyType),
          esc(p.location),
          esc(p.displayPrice),
          esc(p.displayStatus),
          stats.views,
          stats.inquiries,
          p.isPublished,
          p.isFeatured,
        ].join(','),
      );
    }
    await ExportEngine.shareCsv(
      filename: 'hdhomes-property-listings',
      csv: buf.toString(),
    );
  }

  List<CmsPropertyFeatured> _applyFilters(List<CmsPropertyFeatured> all) {
    return all.where((p) {
      if (_statusFilter != null &&
          p.displayStatus.toLowerCase() != _statusFilter!.toLowerCase()) {
        return false;
      }
      if (_typeFilter != null &&
          (p.propertyType ?? '').toLowerCase() != _typeFilter!.toLowerCase()) {
        return false;
      }
      if (_locationFilter != null) {
        final loc = p.location.isNotEmpty
            ? p.location
            : (p.city ?? p.state ?? '');
        if (loc.toLowerCase() != _locationFilter!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  List<String> _uniqueStatuses(List<CmsPropertyFeatured> all) {
    final set = <String>{};
    for (final p in all) {
      set.add(p.displayStatus);
    }
    return set.toList()..sort();
  }

  List<String> _uniqueTypes(List<CmsPropertyFeatured> all) {
    final set = <String>{};
    for (final p in all) {
      final t = p.propertyType?.trim();
      if (t != null && t.isNotEmpty) set.add(t);
    }
    return set.toList()..sort();
  }

  List<String> _uniqueLocations(List<CmsPropertyFeatured> all) {
    final set = <String>{};
    for (final p in all) {
      final loc = p.location.isNotEmpty
          ? p.location
          : [p.city, p.state].whereType<String>().where((s) => s.isNotEmpty).join(', ');
      if (loc.isNotEmpty) set.add(loc);
    }
    return set.toList()..sort();
  }
}

class _Metrics {
  const _Metrics({
    required this.total,
    required this.available,
    required this.sold,
    required this.underConstruction,
    required this.reserved,
    required this.addedThisMonth,
  });

  factory _Metrics.from(List<CmsPropertyFeatured> properties) {
    var available = 0;
    var sold = 0;
    var under = 0;
    var reserved = 0;
    var addedThisMonth = 0;
    final now = DateTime.now();
    for (final p in properties) {
      final created = p.createdAt?.toLocal();
      if (created != null &&
          created.year == now.year &&
          created.month == now.month) {
        addedThisMonth++;
      }
      final s = p.displayStatus.toLowerCase();
      if (s.contains('sold')) {
        sold++;
      } else if (s.contains('construction') || s.contains('building')) {
        under++;
      } else if (s.contains('reserved') || s.contains('booked')) {
        reserved++;
      } else if (p.isPublished || s.contains('available') || s.contains('live')) {
        available++;
      } else if (s.contains('draft')) {
        // drafts count toward total only
      } else {
        available++;
      }
    }
    return _Metrics(
      total: properties.length,
      available: available,
      sold: sold,
      underConstruction: under,
      reserved: reserved,
      addedThisMonth: addedThisMonth,
    );
  }

  final int total;
  final int available;
  final int sold;
  final int underConstruction;
  final int reserved;
  final int addedThisMonth;

  String pct(int n) {
    if (total == 0) return '0% of total';
    return '${((n / total) * 100).round()}% of total';
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _ListingsHero extends StatelessWidget {
  const _ListingsHero({required this.onNewProperty});

  final VoidCallback onNewProperty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeroBackdropPainter()),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Text(
                      'Property Listings',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage all properties, track performance, schedule\n'
                      'inspections and publish across all platforms.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.4,
                        color: _PropertyListingsDashboardState._muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _NewPropertyButton(onPressed: onNewProperty),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewPropertyButton extends StatelessWidget {
  const _NewPropertyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE0B35A), Color(0xFFC98A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.plus, size: 18, color: Color(0xFF1A1205)),
                const SizedBox(width: 8),
                Text(
                  'New Property',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF1A1205),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(LucideIcons.chevronDown,
                    size: 16, color: Color(0xFF1A1205)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = AppColors.gold.withValues(alpha: 0.14);
    final paint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Large HD monogram
    final tp = TextPainter(
      text: TextSpan(
        text: 'HD',
        style: TextStyle(
          fontSize: size.height * 1.35,
          fontWeight: FontWeight.w800,
          color: AppColors.gold.withValues(alpha: 0.07),
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.52, -size.height * 0.25));

    // Wireframe house silhouette (right side)
    final ox = size.width * 0.62;
    final oy = size.height * 0.18;
    final path = Path()
      ..moveTo(ox + 20, oy + 70)
      ..lineTo(ox + 20, oy + 30)
      ..lineTo(ox + 70, oy + 8)
      ..lineTo(ox + 120, oy + 30)
      ..lineTo(ox + 120, oy + 70)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(Offset(ox + 45, oy + 70), Offset(ox + 45, oy + 42), paint);
    canvas.drawLine(Offset(ox + 70, oy + 70), Offset(ox + 70, oy + 42), paint);
    canvas.drawLine(Offset(ox + 95, oy + 70), Offset(ox + 95, oy + 42), paint);
    canvas.drawRect(Rect.fromLTWH(ox + 52, oy + 48, 16, 22), paint);
    // Perspective lines
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(ox + 130 + i * 18.0, oy + 20 + i * 8),
        Offset(ox + 200 + i * 22.0, oy + 55 + i * 6),
        paint..color = AppColors.gold.withValues(alpha: 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Metrics ─────────────────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});

  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricSpec(
        label: 'Total Properties',
        value: '${metrics.total}',
        subtitle: metrics.total == 0
            ? 'No listings yet'
            : metrics.addedThisMonth == 0
                ? 'None added this month'
                : '+${metrics.addedThisMonth} this month',
        subtitleColor: metrics.addedThisMonth > 0
            ? AppColors.success
            : _PropertyListingsDashboardState._muted,
        icon: LucideIcons.building2,
        iconColor: AppColors.gold,
      ),
      _MetricSpec(
        label: 'Available',
        value: '${metrics.available}',
        subtitle: metrics.pct(metrics.available),
        subtitleColor: AppColors.success,
        icon: LucideIcons.checkCircle2,
        iconColor: AppColors.success,
      ),
      _MetricSpec(
        label: 'Sold',
        value: '${metrics.sold}',
        subtitle: metrics.pct(metrics.sold),
        subtitleColor: const Color(0xFFF59E0B),
        icon: LucideIcons.badgeCheck,
        iconColor: const Color(0xFFF59E0B),
      ),
      _MetricSpec(
        label: 'Under Construction',
        value: '${metrics.underConstruction}',
        subtitle: metrics.pct(metrics.underConstruction),
        subtitleColor: AppColors.info,
        icon: LucideIcons.hardHat,
        iconColor: AppColors.info,
      ),
      _MetricSpec(
        label: 'Reserved',
        value: '${metrics.reserved}',
        subtitle: metrics.pct(metrics.reserved),
        subtitleColor: const Color(0xFFA855F7),
        icon: LucideIcons.bookmark,
        iconColor: const Color(0xFFA855F7),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final wrap = c.maxWidth < 900;
        if (wrap) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards
                .map(
                  (m) => SizedBox(
                    width: (c.maxWidth - 10) / 2,
                    child: _MetricCard(spec: m),
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _MetricCard(spec: cards[i])),
            ],
          ],
        );
      },
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final IconData icon;
  final Color iconColor;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.spec});

  final _MetricSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _PropertyListingsDashboardState._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _PropertyListingsDashboardState._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: spec.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(spec.icon, size: 16, color: spec.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            spec.label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _PropertyListingsDashboardState._muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.value,
            style: GoogleFonts.manrope(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtitle,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: spec.subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filters ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.statusFilter,
    required this.typeFilter,
    required this.locationFilter,
    required this.statusOptions,
    required this.typeOptions,
    required this.locationOptions,
    required this.onStatus,
    required this.onType,
    required this.onLocation,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? statusFilter;
  final String? typeFilter;
  final String? locationFilter;
  final List<String> statusOptions;
  final List<String> typeOptions;
  final List<String> locationOptions;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onType;
  final ValueChanged<String?> onLocation;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          height: 44,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: GoogleFonts.manrope(color: AppColors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search properties by title, code, location...',
              hintStyle: GoogleFonts.manrope(
                color: _PropertyListingsDashboardState._muted,
                fontSize: 13,
              ),
              prefixIcon: const Icon(LucideIcons.search,
                  size: 16, color: _PropertyListingsDashboardState._muted),
              filled: true,
              fillColor: _PropertyListingsDashboardState._field,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: _PropertyListingsDashboardState._cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: _PropertyListingsDashboardState._cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
        _FilterDropdown(
          label: statusFilter ?? 'All Status',
          value: statusFilter,
          options: statusOptions,
          onChanged: onStatus,
        ),
        _FilterDropdown(
          label: typeFilter ?? 'All Types',
          value: typeFilter,
          options: typeOptions,
          onChanged: onType,
        ),
        _FilterDropdown(
          label: locationFilter ?? 'All Locations',
          value: locationFilter,
          options: locationOptions,
          onChanged: onLocation,
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(LucideIcons.slidersHorizontal, size: 15),
          label: Text(
            'Filters',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: const BorderSide(
                color: _PropertyListingsDashboardState._cardBorder),
            backgroundColor: _PropertyListingsDashboardState._field,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      color: _PropertyListingsDashboardState._card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _PropertyListingsDashboardState._cardBorder),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: null,
          child: Text('All', style: GoogleFonts.manrope(color: AppColors.white)),
        ),
        ...options.map(
          (o) => PopupMenuItem(
            value: o,
            child: Text(o, style: GoogleFonts.manrope(color: AppColors.white)),
          ),
        ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _PropertyListingsDashboardState._field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _PropertyListingsDashboardState._cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: value == null
                    ? _PropertyListingsDashboardState._muted
                    : AppColors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronDown,
                size: 14, color: _PropertyListingsDashboardState._muted),
          ],
        ),
      ),
    );
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────

class _PropertiesTableCard extends StatelessWidget {
  const _PropertiesTableCard({
    required this.total,
    required this.properties,
    required this.insights,
    required this.start,
    required this.end,
    required this.page,
    required this.pageCount,
    required this.onPage,
    required this.onEdit,
    required this.onView,
    required this.onScheduleInspection,
    required this.onTogglePublished,
    required this.onToggleFeatured,
    required this.onDelete,
    required this.onNewProperty,
    required this.onExport,
  });

  final int total;
  final List<CmsPropertyFeatured> properties;
  final PropertyListingsInsights insights;
  final int start;
  final int end;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;
  final ValueChanged<CmsPropertyFeatured> onEdit;
  final ValueChanged<CmsPropertyFeatured> onView;
  final ValueChanged<CmsPropertyFeatured> onScheduleInspection;
  final Future<void> Function(CmsPropertyFeatured, bool) onTogglePublished;
  final Future<void> Function(CmsPropertyFeatured, bool) onToggleFeatured;
  final Future<void> Function(CmsPropertyFeatured) onDelete;
  final VoidCallback onNewProperty;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _PropertyListingsDashboardState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PropertyListingsDashboardState._cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
            child: Row(
              children: [
                Text(
                  'All Properties ($total)',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.white,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onExport,
                  icon: const Icon(LucideIcons.upload, size: 14),
                  label: Text(
                    'Export',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _PropertyListingsDashboardState._muted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _PropertyListingsDashboardState._cardBorder),
          if (properties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.home,
                      size: 36,
                      color: _PropertyListingsDashboardState._muted),
                  const SizedBox(height: 12),
                  Text(
                    'No properties found',
                    style: GoogleFonts.manrope(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: onNewProperty,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('New property'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF1A1205),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final tableWidth = math.max(c.maxWidth, 980.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TableHeader(),
                        const Divider(
                          height: 1,
                          color: _PropertyListingsDashboardState._cardBorder,
                        ),
                        for (var i = 0; i < properties.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color:
                                  _PropertyListingsDashboardState._cardBorder,
                            ),
                          _PropertyRow(
                            property: properties[i],
                            stats: insights.statsFor(properties[i].id),
                            onEdit: () => onEdit(properties[i]),
                            onView: () => onView(properties[i]),
                            onScheduleInspection: () =>
                                onScheduleInspection(properties[i]),
                            onTogglePublished: (v) =>
                                onTogglePublished(properties[i], v),
                            onToggleFeatured: (v) =>
                                onToggleFeatured(properties[i], v),
                            onDelete: () => onDelete(properties[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 1, color: _PropertyListingsDashboardState._cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    total == 0
                        ? 'Showing 0 properties'
                        : 'Showing $start to $end of $total properties',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: _PropertyListingsDashboardState._muted,
                    ),
                  ),
                ),
                _Pagination(
                  page: page,
                  pageCount: pageCount,
                  onPage: onPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.manrope(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: _PropertyListingsDashboardState._muted,
      letterSpacing: 0.3,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('PROPERTY', style: style)),
          Expanded(flex: 2, child: Text('TYPE', style: style)),
          Expanded(flex: 2, child: Text('LOCATION', style: style)),
          Expanded(flex: 2, child: Text('PRICE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          SizedBox(width: 52, child: Text('VIEWS', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 64, child: Text('INQUIRIES', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 148, child: Text('')),
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.property,
    required this.stats,
    required this.onEdit,
    required this.onView,
    required this.onScheduleInspection,
    required this.onTogglePublished,
    required this.onToggleFeatured,
    required this.onDelete,
  });

  final CmsPropertyFeatured property;
  final PropertyEngagementStats stats;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final VoidCallback onScheduleInspection;
  final ValueChanged<bool> onTogglePublished;
  final ValueChanged<bool> onToggleFeatured;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final code = property.propertyCode?.trim().isNotEmpty == true
        ? property.propertyCode!
        : 'HDH-${property.id.substring(0, math.min(6, property.id.length)).toUpperCase()}';
    final views = stats.views;
    final inquiries = stats.inquiries;
    final type = property.propertyType?.trim().isNotEmpty == true
        ? property.propertyType!
        : 'Property';
    final loc = property.location.isNotEmpty
        ? property.location
        : (property.city ?? '—');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: property.coverImageUrl != null
                        ? MediaDeliveryImage(
                          url: property.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: _thumbPlaceholder(),
                        )
                        : _thumbPlaceholder(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: _PropertyListingsDashboardState._muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_typeIcon(type),
                    size: 14, color: _PropertyListingsDashboardState._muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 13, color: _PropertyListingsDashboardState._muted),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    loc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fullPrice(property),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusPill(status: property.displayStatus),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$views',
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(fontSize: 12, color: AppColors.white),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '$inquiries',
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(fontSize: 12, color: AppColors.white),
            ),
          ),
          SizedBox(
            width: 148,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionIcon(icon: LucideIcons.eye, tooltip: 'View', onTap: onView),
                _ActionIcon(icon: LucideIcons.pencil, tooltip: 'Edit', onTap: onEdit),
                _ActionIcon(
                  icon: LucideIcons.calendar,
                  tooltip: 'Schedule inspection',
                  onTap: onScheduleInspection,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  color: _PropertyListingsDashboardState._card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(
                        color: _PropertyListingsDashboardState._cardBorder),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pub',
                      child: Text(
                        property.isPublished ? 'Unpublish' : 'Publish',
                        style: GoogleFonts.manrope(color: AppColors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'feat',
                      child: Text(
                        property.isFeatured
                            ? 'Remove from homepage'
                            : 'Feature on homepage',
                        style: GoogleFonts.manrope(color: AppColors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'del',
                      child: Text(
                        'Delete',
                        style: GoogleFonts.manrope(color: const Color(0xFFF87171)),
                      ),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'pub') onTogglePublished(!property.isPublished);
                    if (v == 'feat') onToggleFeatured(!property.isFeatured);
                    if (v == 'del') onDelete();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(LucideIcons.moreHorizontal,
                        size: 15,
                        color: _PropertyListingsDashboardState._muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _thumbPlaceholder() => Container(
        color: const Color(0xFF1E2430),
        alignment: Alignment.center,
        child: const Icon(LucideIcons.home,
            size: 18, color: _PropertyListingsDashboardState._muted),
      );

  static IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('apartment') || t.contains('flat')) return LucideIcons.building;
    if (t.contains('duplex')) return LucideIcons.home;
    if (t.contains('terrace') || t.contains('town')) return LucideIcons.warehouse;
    if (t.contains('land')) return LucideIcons.map;
    return LucideIcons.building2;
  }

  static String _fullPrice(CmsPropertyFeatured p) {
    if (p.priceLabel != null && p.priceLabel!.trim().isNotEmpty) {
      return p.priceLabel!.trim();
    }
    final price = p.listingPrice;
    if (price == null) return p.displayPrice;
    final whole = price.round();
    final s = whole.toString();
    final buf = StringBuffer('₦');
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    if (s.contains('sold')) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      fg = const Color(0xFFFBBF24);
    } else if (s.contains('construction') || s.contains('building')) {
      bg = AppColors.info.withValues(alpha: 0.15);
      fg = const Color(0xFF60A5FA);
    } else if (s.contains('reserved') || s.contains('booked')) {
      bg = const Color(0xFFA855F7).withValues(alpha: 0.15);
      fg = const Color(0xFFC084FC);
    } else if (s.contains('draft')) {
      bg = AppColors.slate500.withValues(alpha: 0.2);
      fg = AppColors.slate400;
    } else {
      bg = AppColors.success.withValues(alpha: 0.15);
      fg = const Color(0xFF4ADE80);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      icon: Icon(icon, size: 15, color: _PropertyListingsDashboardState._muted),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = <int>[];
    for (var i = 0; i < pageCount && i < 5; i++) {
      pages.add(i);
    }
    if (pageCount > 5) {
      // show last as ellipsis target
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in pages)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: InkWell(
              onTap: () => onPage(p),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p == page ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: p == page
                      ? null
                      : Border.all(
                          color: _PropertyListingsDashboardState._cardBorder),
                ),
                child: Text(
                  '${p + 1}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p == page
                        ? const Color(0xFF1A1205)
                        : _PropertyListingsDashboardState._muted,
                  ),
                ),
              ),
            ),
          ),
        if (pageCount > 5) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('…',
                style: GoogleFonts.manrope(
                    color: _PropertyListingsDashboardState._muted)),
          ),
          InkWell(
            onTap: () => onPage(pageCount - 1),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _PropertyListingsDashboardState._cardBorder),
              ),
              child: Text(
                '$pageCount',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _PropertyListingsDashboardState._muted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Right rail ──────────────────────────────────────────────────────────────

class _RightRail extends StatelessWidget {
  const _RightRail({
    required this.onNewProperty,
    required this.onSiteInspection,
    required this.onExportReport,
    required this.onViewInquiries,
    required this.onReferAgent,
    required this.onViewCalendar,
    required this.inspections,
    required this.performance,
  });

  final VoidCallback onNewProperty;
  final VoidCallback onSiteInspection;
  final VoidCallback onExportReport;
  final VoidCallback onViewInquiries;
  final VoidCallback onReferAgent;
  final VoidCallback onViewCalendar;
  final List<ListingsInspectionItem> inspections;
  final PropertyPerformanceBreakdown performance;

  static const _avatarPalette = [
    Color(0xFFD4A34E),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFA855F7),
    Color(0xFF60A5FA),
  ];

  @override
  Widget build(BuildContext context) {
    final todayInspections = inspections.where((i) {
      final now = DateTime.now();
      return i.scheduledAt.year == now.year &&
          i.scheduledAt.month == now.month &&
          i.scheduledAt.day == now.day;
    }).toList();
    final shown =
        todayInspections.isNotEmpty ? todayInspections : inspections.take(5).toList();

    final highPct = (performance.highShare * 100).round();
    final avgPct = (performance.averageShare * 100).round();
    final lowPct = (performance.lowShare * 100).round();
    final scorePct = performance.averageScore.round();
    final hasPerf = performance.total > 0;

    return Column(
      children: [
        _RailCard(
          title: 'Quick Actions',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = [
                _QuickAction(
                  icon: LucideIcons.plus,
                  label: 'Add\nProperty',
                  onTap: onNewProperty,
                  accent: true,
                ),
                _QuickAction(
                  icon: LucideIcons.calendarCheck,
                  label: 'Site\nInspection',
                  onTap: onSiteInspection,
                ),
                _QuickAction(
                  icon: LucideIcons.fileSpreadsheet,
                  label: 'Export\nReport',
                  onTap: onExportReport,
                ),
                _QuickAction(
                  icon: LucideIcons.messageSquare,
                  label: 'View\nInquiries',
                  onTap: onViewInquiries,
                ),
                _QuickAction(
                  icon: LucideIcons.userPlus,
                  label: 'Refer\nAgent',
                  onTap: onReferAgent,
                ),
              ];
              // Full-width stack (sidebar open) must not stretch tiles with
              // the page. The narrow right rail keeps the 3-column grid.
              if (constraints.maxWidth > 360) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in actions)
                      SizedBox(width: 88, height: 84, child: action),
                  ],
                );
              }
              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 0.9,
                children: actions,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _RailCard(
          title: 'Site Inspections',
          trailing: InkWell(
            onTap: onViewCalendar,
            child: Text(
              'View Calendar',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                todayInspections.isNotEmpty
                    ? 'Today, ${_formatToday()}'
                    : shown.isEmpty
                        ? 'No upcoming inspections'
                        : 'Upcoming · ${_formatToday()}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: _PropertyListingsDashboardState._muted,
                ),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Text(
                  'Bookings from clients appear here in real time.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: _PropertyListingsDashboardState._muted,
                  ),
                )
              else
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _InspectionTile(
                    title: shown[i].title,
                    subtitle: shown[i].subtitle,
                    colors: [
                      _avatarPalette[i % _avatarPalette.length],
                      _avatarPalette[(i + 2) % _avatarPalette.length],
                    ],
                    visitorLabel: shown[i].visitorName,
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RailCard(
          title: 'Property Performance',
          child: Column(
            children: [
              SizedBox(
                height: 150,
                child: CustomPaint(
                  painter: _DonutPainter(
                    high: hasPerf ? performance.highShare : 0,
                    average: hasPerf ? performance.averageShare : 0,
                    low: hasPerf ? performance.lowShare : 0,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasPerf ? '$scorePct%' : '—',
                          style: GoogleFonts.manrope(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                        Text(
                          'Performance\nScore',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            height: 1.2,
                            color: _PropertyListingsDashboardState._muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasPerf
                    ? '${performance.total} scored listing${performance.total == 1 ? '' : 's'}'
                    : 'No scored listings yet',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: _PropertyListingsDashboardState._muted,
                ),
              ),
              const SizedBox(height: 8),
              _LegendRow(
                color: const Color(0xFF22C55E),
                label: 'High Performers',
                value: hasPerf ? '$highPct%' : '0%',
              ),
              const SizedBox(height: 6),
              _LegendRow(
                color: const Color(0xFFF59E0B),
                label: 'Average',
                value: hasPerf ? '$avgPct%' : '0%',
              ),
              const SizedBox(height: 6),
              _LegendRow(
                color: const Color(0xFFEF4444),
                label: 'Low Performers',
                value: hasPerf ? '$lowPct%' : '0%',
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatToday() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PropertyListingsDashboardState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PropertyListingsDashboardState._cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.white,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: accent
                  ? const LinearGradient(
                      colors: [Color(0xFFE0B35A), Color(0xFFC98A2E)],
                    )
                  : null,
              color: accent ? null : const Color(0xFF1A2030),
              border: accent
                  ? null
                  : Border.all(
                      color: _PropertyListingsDashboardState._cardBorder),
            ),
            child: Icon(
              icon,
              size: 18,
              color: accent ? const Color(0xFF1A1205) : AppColors.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: _PropertyListingsDashboardState._muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({
    required this.title,
    required this.subtitle,
    required this.colors,
    this.visitorLabel,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final String? visitorLabel;

  @override
  Widget build(BuildContext context) {
    final initials = (visitorLabel ?? title)
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: _PropertyListingsDashboardState._muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 44,
          height: 24,
          child: Stack(
            children: [
              for (var i = 0; i < colors.length; i++)
                Positioned(
                  left: i * 14.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[i],
                      border: Border.all(
                        color: _PropertyListingsDashboardState._card,
                        width: 2,
                      ),
                    ),
                    child: i == 0 && initials.isNotEmpty
                        ? Text(
                            initials.length > 2
                                ? initials.substring(0, 2)
                                : initials,
                            style: GoogleFonts.manrope(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepBlack,
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: _PropertyListingsDashboardState._muted,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.high,
    required this.average,
    required this.low,
  });

  final double high;
  final double average;
  final double low;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const stroke = 14.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final segments = [
      (high, const Color(0xFF22C55E)),
      (average, const Color(0xFFF59E0B)),
      (low, const Color(0xFFEF4444)),
    ];
    final total = high + average + low;
    if (total <= 0) {
      canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = const Color(0xFF2A3140)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      return;
    }
    var start = -math.pi / 2;
    for (final (frac, color) in segments) {
      final sweep = frac * 2 * math.pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.high != high ||
      oldDelegate.average != average ||
      oldDelegate.low != low;
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: GoogleFonts.manrope(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
