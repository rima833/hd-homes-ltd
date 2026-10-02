import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/contact/data/providers/office_directory_provider.dart';
import 'package:hdhomesproject/features/contact/domain/entities/office_directory_models.dart';
import 'package:hdhomesproject/features/contact/domain/services/office_status_service.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/office_gallery_viewer.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const _panel = Color(0xFF15171D);
const _card = Color(0xFF1C1F28);
const _gold = Color(0xFFD4AF37);
const _goldSoft = Color(0xFFE8C56A);
const _muted = Color(0xFF9CA3AF);
const _border = Color(0x332A3140);

/// Premium split-layout office directory for the Contact hub.
class ContactOfficeDirectorySection extends HookConsumerWidget {
  const ContactOfficeDirectorySection({
    super.key,
    this.onBookAppointment,
  });

  final VoidCallback? onBookAppointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(officeDirectoryRealtimeProvider);
    final async = ref.watch(officeDirectoryProvider);
    final search = useState('');
    final typeFilter = useState<String?>(null);
    final cityFilter = useState<String?>(null);
    final selectedId = useState<String?>(null);
    final searchCtrl = useTextEditingController(text: search.value);

    useEffect(() {
      void listener() => search.value = searchCtrl.text;
      searchCtrl.addListener(listener);
      return () => searchCtrl.removeListener(listener);
    }, [searchCtrl]);

    return async.when(
      loading: () => const _DirectorySkeleton(),
      error: (e, _) => _DirectoryError(message: '$e'),
      data: (offices) {
        if (offices.isEmpty) return const _DirectoryEmpty();

        final types = offices.map((o) => o.typeLabel).toSet().toList()..sort();
        final cities = offices.map((o) => o.displayCity).toSet().toList()..sort();
        final q = search.value.trim().toLowerCase();

        var filtered = offices;
        if (typeFilter.value != null) {
          filtered = filtered.where((o) => o.typeLabel == typeFilter.value).toList();
        }
        if (cityFilter.value != null) {
          filtered = filtered.where((o) => o.displayCity == cityFilter.value).toList();
        }
        if (q.isNotEmpty) {
          filtered = filtered.where((o) {
            final loc = o.location;
            return loc.name.toLowerCase().contains(q) ||
                loc.address.toLowerCase().contains(q) ||
                loc.city.toLowerCase().contains(q) ||
                loc.state.toLowerCase().contains(q) ||
                loc.officeType.toLowerCase().contains(q);
          }).toList();
        }

        if (filtered.isEmpty) {
          return const _DirectoryEmpty(
            message: 'No offices found. Try another location or search term.',
          );
        }

        final matchIndex = selectedId.value == null
            ? -1
            : filtered.indexWhere((o) => o.location.id == selectedId.value);
        final selected = matchIndex >= 0
            ? filtered[matchIndex]
            : filtered.firstWhere(
                (o) => o.location.isFeatured,
                orElse: () => filtered.first,
              );

        if (selectedId.value != selected.location.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (selectedId.value != selected.location.id) {
              selectedId.value = selected.location.id;
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DirectoryHeader(
              officeCount: offices.length,
              teamCount: offices.length * 35,
              regionCount: cities.length,
            ),
            const SizedBox(height: 24),
            _SearchBar(
              controller: searchCtrl,
              types: types,
              cities: cities,
              typeFilter: typeFilter.value,
              cityFilter: cityFilter.value,
              onTypeChanged: (v) => typeFilter.value = v,
              onCityChanged: (v) => cityFilter.value = v,
            ),
            const SizedBox(height: 24),
            if (context.isMobile)
              _MobileLayout(
                offices: filtered,
                selected: selected,
                onSelect: (id) => selectedId.value = id,
                onBook: (entry) => _book(context, ref, entry, onBookAppointment),
              )
            else
              _DesktopLayout(
                offices: filtered,
                selected: selected,
                onSelect: (id) => selectedId.value = id,
                onBook: (entry) => _book(context, ref, entry, onBookAppointment),
              ),
            const SizedBox(height: 28),
            _FooterActions(
              onSupport: onBookAppointment,
              onMap: () => _openMap(selected),
              onBook: () => _book(context, ref, selected, onBookAppointment),
            ),
          ],
        );
      },
    );
  }

  void _book(
    BuildContext context,
    WidgetRef ref,
    OfficeDirectoryEntry entry,
    VoidCallback? scrollFallback,
  ) {
    ref.read(selectedOfficeForBookingProvider.notifier).state = entry;
    final path = entry.location.appointmentPath.trim();
    if (path.startsWith('/')) {
      context.go('${RoutePaths.bookConsultation}?office=${entry.location.id}');
    } else if (scrollFallback != null) {
      scrollFallback();
    } else {
      context.go(RoutePaths.bookConsultation);
    }
  }

  Future<void> _openMap(OfficeDirectoryEntry entry) async {
    final loc = entry.location;
    Uri uri;
    if (loc.latitude != null && loc.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${loc.latitude},${loc.longitude}',
      );
    } else {
      uri = Uri.parse(loc.mapUrl);
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.officeCount,
    required this.teamCount,
    required this.regionCount,
  });

  final int officeCount;
  final int teamCount;
  final int regionCount;

  @override
  Widget build(BuildContext context) {
    final mobile = context.isMobile;
    return Column(
      children: [
        Text(
          'OFFICES',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: _goldSoft,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Office Directory',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: mobile ? 32 : 44,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          height: 2,
          width: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_gold.withValues(alpha: 0.2), _gold, _gold.withValues(alpha: 0.2)],
            ),
          ),
        ),
        Text(
          'Head office, regional offices, sales centers, and construction sites.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _StatChip(icon: LucideIcons.building2, value: '${officeCount.clamp(1, 99)}+', label: 'Locations'),
            _StatChip(icon: LucideIcons.users, value: '$teamCount+', label: 'Team Members'),
            _StatChip(icon: LucideIcons.mapPin, value: 'Across $regionCount Regions', label: ''),
            _StatChip(icon: LucideIcons.headphones, value: 'Mon–Sat', label: 'Customer Support'),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _goldSoft),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
              if (label.isNotEmpty)
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.types,
    required this.cities,
    required this.typeFilter,
    required this.cityFilter,
    required this.onTypeChanged,
    required this.onCityChanged,
  });

  final TextEditingController controller;
  final List<String> types;
  final List<String> cities;
  final String? typeFilter;
  final String? cityFilter;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onCityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search offices…',
            hintStyle: TextStyle(color: _muted.withValues(alpha: 0.7)),
            prefixIcon: const Icon(LucideIcons.search, color: _goldSoft, size: 20),
            filled: true,
            fillColor: _panel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: typeFilter == null && cityFilter == null,
                onTap: () {
                  onTypeChanged(null);
                  onCityChanged(null);
                },
              ),
              for (final t in types) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: t,
                  selected: typeFilter == t,
                  onTap: () => onTypeChanged(typeFilter == t ? null : t),
                ),
              ],
              for (final c in cities) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: c,
                  selected: cityFilter == c,
                  onTap: () => onCityChanged(cityFilter == c ? null : c),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _gold.withValues(alpha: 0.15) : _panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _gold.withValues(alpha: 0.5) : _border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _goldSoft : _muted,
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.offices,
    required this.selected,
    required this.onSelect,
    required this.onBook,
  });

  final List<OfficeDirectoryEntry> offices;
  final OfficeDirectoryEntry selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<OfficeDirectoryEntry> onBook;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(420.0, 720.0)
            : 620.0;
        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: _OfficeList(
                  offices: offices,
                  selectedId: selected.location.id,
                  onSelect: onSelect,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: _OfficeDetailPanel(
                  entry: selected,
                  onBook: () => onBook(selected),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.offices,
    required this.selected,
    required this.onSelect,
    required this.onBook,
  });

  final List<OfficeDirectoryEntry> offices;
  final OfficeDirectoryEntry selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<OfficeDirectoryEntry> onBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: _OfficeList(
            offices: offices,
            selectedId: selected.location.id,
            onSelect: onSelect,
          ),
        ),
        const SizedBox(height: 16),
        _OfficeDetailPanel(
          entry: selected,
          onBook: () => onBook(selected),
        ),
      ],
    );
  }
}

class _OfficeList extends StatelessWidget {
  const _OfficeList({
    required this.offices,
    required this.selectedId,
    required this.onSelect,
  });

  final List<OfficeDirectoryEntry> offices;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: offices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final entry = offices[i];
          final loc = entry.location;
          final selected = loc.id == selectedId;
          final status = OfficeStatusService.compute(hours: entry.hours);
          return _OfficeListItem(
            entry: entry,
            selected: selected,
            status: status,
            onTap: () => onSelect(loc.id),
          );
        },
      ),
    );
  }
}

class _OfficeListItem extends StatelessWidget {
  const _OfficeListItem({
    required this.entry,
    required this.selected,
    required this.status,
    required this.onTap,
  });

  final OfficeDirectoryEntry entry;
  final bool selected;
  final OfficeStatusSnapshot status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = entry.location;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? _gold.withValues(alpha: 0.08) : _card,
            border: Border.all(
              color: selected ? _gold.withValues(alpha: 0.55) : _border,
            ),
            boxShadow: selected
                ? [BoxShadow(color: _gold.withValues(alpha: 0.12), blurRadius: 16)]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _goldSoft : _muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.officeType.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: selected ? _goldSoft : _muted,
                      ),
                    ),
                  ),
                  if (loc.isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FEATURED',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _goldSoft),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.displayCity,
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 8),
              Text(
                loc.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFD1D5DB)),
              ),
              const SizedBox(height: 10),
              Text(
                '${status.label == 'OPEN NOW' ? 'Open today' : status.detail} · ${OfficeStatusService.hoursSummary(entry.hours)}',
                style: GoogleFonts.inter(fontSize: 11, color: _muted),
              ),
              const SizedBox(height: 8),
              Text(
                'View office →',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _goldSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeDetailPanel extends HookWidget {
  const _OfficeDetailPanel({
    required this.entry,
    required this.onBook,
  });

  final OfficeDirectoryEntry entry;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final loc = entry.location;
    final gallery = entry.galleryUrls;
    final page = useState(0);
    final status = OfficeStatusService.compute(hours: entry.hours);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroImage(
              urls: gallery,
              page: page.value,
              onPage: (p) => page.value = p,
              onFullscreen: gallery.isEmpty
                  ? null
                  : () => OfficeGalleryViewer.show(context, gallery, page.value),
              typeLabel: loc.officeType,
              status: status,
            ),
            const SizedBox(height: 20),
            Text(
              loc.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.displayCity}${loc.state.isNotEmpty ? ', ${loc.state}' : ''}',
              style: GoogleFonts.inter(fontSize: 14, color: _goldSoft),
            ),
            const SizedBox(height: 12),
            Text(
              loc.address,
              style: GoogleFonts.inter(fontSize: 14, color: _muted, height: 1.5),
            ),
            if (loc.shortDescription.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(loc.shortDescription, style: GoogleFonts.inter(color: const Color(0xFFD1D5DB))),
            ],
            const SizedBox(height: 20),
            _InfoGrid(entry: entry),
            if (entry.landmarks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Nearby:', style: GoogleFonts.inter(fontSize: 12, color: _goldSoft)),
              Text(entry.landmarks.join(', '), style: GoogleFonts.inter(color: _muted)),
            ],
            const SizedBox(height: 20),
            _ActionButtons(entry: entry, onBook: onBook),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.urls,
    required this.page,
    required this.onPage,
    required this.typeLabel,
    required this.status,
    this.onFullscreen,
  });

  final List<String> urls;
  final int page;
  final ValueChanged<int> onPage;
  final String typeLabel;
  final OfficeStatusSnapshot status;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final url = urls.isNotEmpty ? urls[page.clamp(0, urls.length - 1)] : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onFullscreen,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: url != null
                  ? MediaDeliveryImage(
                    url: url,
                    fit: BoxFit.cover,
                    errorWidget: _placeholder(),
                  )
                  : _placeholder(),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeLabel.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _goldSoft),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: _StatusBadge(status: status),
          ),
          if (urls.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: page > 0 ? () => onPage(page - 1) : null,
                  icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: page < urls.length - 1 ? () => onPage(page + 1) : null,
                  icon: const Icon(LucideIcons.chevronRight, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${page + 1} / ${urls.length}',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: _panel,
      alignment: Alignment.center,
      child: const Icon(LucideIcons.building2, size: 64, color: _muted),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OfficeStatusSnapshot status;

  Color get _color => switch (status.status) {
        OfficeLiveStatus.open => const Color(0xFF22C55E),
        OfficeLiveStatus.closingSoon => const Color(0xFFF59E0B),
        OfficeLiveStatus.opensLater => _goldSoft,
        OfficeLiveStatus.closed => const Color(0xFFEF4444),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _color)),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.entry});

  final OfficeDirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final loc = entry.location;
    final hoursText = entry.hours.isNotEmpty
        ? _formatWeeklyHours(entry.hours)
        : loc.hours;

    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 520;
        final tiles = [
          _InfoCell(label: 'PHONE', value: loc.phone, icon: LucideIcons.phone),
          _InfoCell(label: 'EMAIL', value: loc.email, icon: LucideIcons.mail),
          _InfoCell(label: 'OPENING HOURS', value: hoursText, icon: LucideIcons.clock),
          _InfoCell(
            label: 'PARKING',
            value: loc.parkingInfo.isNotEmpty ? loc.parkingInfo : 'Contact office',
            icon: LucideIcons.car,
          ),
        ];
        if (mobile) {
          return Column(
            children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(height: 10), tiles[i]]],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles.map((t) {
            final half = ((c.maxWidth - 12) / 2).clamp(120.0, 600.0);
            return SizedBox(width: half, child: t);
          }).toList(),
        );
      },
    );
  }

  String _formatWeeklyHours(List<OfficeHourEntry> hours) {
    final open = hours.where((h) => h.isOpen).toList();
    if (open.isEmpty) return 'Closed';
    final first = open.first;
    if (open.length >= 5 &&
        open.every((h) => h.openTime == first.openTime && h.closeTime == first.closeTime)) {
      return 'Mon – Fri\n${first.openTime} – ${first.closeTime}';
    }
    return OfficeStatusService.hoursSummary(hours);
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _goldSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _muted)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.entry, required this.onBook});

  final OfficeDirectoryEntry entry;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final loc = entry.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final lat = loc.latitude;
                  final lng = loc.longitude;
                  final uri = lat != null && lng != null
                      ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
                      : Uri.parse(loc.mapUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(LucideIcons.navigation, size: 16),
                label: const Text('Get Directions'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: loc.phone.isEmpty
                    ? null
                    : () async {
                        final uri = Uri(scheme: 'tel', path: loc.phone.replaceAll(' ', ''));
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                icon: const Icon(LucideIcons.phone, size: 16),
                label: const Text('Call Office'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (loc.allowAppointments)
          FilledButton.icon(
            onPressed: onBook,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF1A1408),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(LucideIcons.calendar),
            label: Text(loc.appointmentLabel),
          ),
      ],
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.onSupport,
    required this.onMap,
    required this.onBook,
  });

  final VoidCallback? onSupport;
  final VoidCallback onMap;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.headphones, 'Need help finding us?', 'Contact Support →', onSupport),
      (LucideIcons.compass, 'Get Directions', 'Open in Maps →', onMap),
      (LucideIcons.calendar, 'Schedule a Visit', 'Book Now →', onBook),
      (LucideIcons.building2, 'Partner With Us', 'Get in Touch →', onSupport),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: items
            .map(
              (item) => InkWell(
                onTap: item.$4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gold.withValues(alpha: 0.15),
                      ),
                      child: Icon(item.$1, size: 16, color: _goldSoft),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: GoogleFonts.inter(fontSize: 11, color: _muted)),
                        Text(
                          item.$3,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _goldSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DirectorySkeleton extends StatelessWidget {
  const _DirectorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 28, width: 200, color: _panel),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}

class _DirectoryEmpty extends StatelessWidget {
  const _DirectoryEmpty({this.message = 'No offices available yet.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(LucideIcons.building2, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _muted)),
        ],
      ),
    );
  }
}

class _DirectoryError extends StatelessWidget {
  const _DirectoryError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text('Could not load offices: $message', style: const TextStyle(color: AppColors.error)),
    );
  }
}
