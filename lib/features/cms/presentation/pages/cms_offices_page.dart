import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/contact/data/providers/office_directory_provider.dart';
import 'package:hdhomesproject/features/contact/domain/entities/office_directory_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _kOfficeTypes = <String>[
  'Head Office',
  'Regional Office',
  'Sales Office',
  'Construction Site',
  'Customer Care',
  'Other',
];

const _kDayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Admin → Website → Office Directory management.
class CmsOfficesPage extends ConsumerWidget {
  const CmsOfficesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(officeDirectoryRealtimeProvider);
    final async = ref.watch(cmsOfficeLocationsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Office Directory',
            subtitle:
                'Create, edit, publish, and delete locations shown on About (VISIT US) and Contact in real time.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add office'),
            ),
          ),
          async.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) => _StatsRow(offices: items),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsOfficeLocationsProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AdminEmptyState(
                    title: 'No offices yet',
                    message: 'Add your first office location card.',
                    icon: LucideIcons.mapPin,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add office'),
                    ),
                  );
                }
                return ReorderableListView.builder(
                  itemCount: items.length,
                  buildDefaultDragHandles: false,
                  onReorder: (o, n) => _reorder(ref, items, o, n),
                  itemBuilder: (context, i) {
                    final office = items[i];
                    final active = office.status == 'active';
                    return ReorderableDragStartListener(
                      key: ValueKey(office.id),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AdminCard(
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.gripVertical,
                                size: 18,
                                color: AppColors.slate500,
                              ),
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: office.coverImage != null &&
                                          office.coverImage!.isNotEmpty
                                      ? MediaDeliveryImage(
                                          url: office.coverImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : ColoredBox(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.12),
                                          child: const Icon(
                                            LucideIcons.building2,
                                            color: AppColors.gold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      office.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      [
                                        office.officeType,
                                        office.city.isNotEmpty
                                            ? office.city
                                            : office.address,
                                        office.phone,
                                      ]
                                          .where((s) => s.trim().isNotEmpty)
                                          .join(' · '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: active,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .setOfficeLocationStatus(
                                        id: office.id,
                                        status: v ? 'active' : 'draft',
                                      );
                                  _invalidate(ref);
                                },
                              ),
                              IconButton(
                                tooltip: 'Duplicate',
                                onPressed: () async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .duplicateOfficeLocation(office.id);
                                  _invalidate(ref);
                                },
                                icon: const Icon(LucideIcons.copy, size: 18),
                              ),
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () =>
                                    _openEditor(context, ref, office),
                                icon: const Icon(LucideIcons.pencil, size: 18),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _confirmDelete(context, ref, office),
                                icon: const Icon(
                                  LucideIcons.trash2,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(cmsOfficeLocationsProvider);
    ref.invalidate(publishedOfficeLocationsProvider);
    ref.invalidate(officeDirectoryProvider);
    ref.invalidate(adminOfficeDirectoryProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CmsOfficeLocation office,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete office?'),
        content: Text(
          '“${office.name}” will be removed from the public site immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cmsServiceProvider).deleteOfficeLocation(office.id);
    _invalidate(ref);
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsOfficeLocation> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final reordered = [...items];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(cmsServiceProvider);
    for (var i = 0; i < reordered.length; i++) {
      final nextOrder = (i + 1) * 10;
      if (reordered[i].sortOrder != nextOrder) {
        await service.setOfficeLocationSortOrder(reordered[i].id, nextOrder);
      }
    }
    _invalidate(ref);
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsOfficeLocation? office,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OfficeEditDialog(office: office),
    );
    _invalidate(ref);
  }
}

class _OfficeEditDialog extends ConsumerStatefulWidget {
  const _OfficeEditDialog({this.office});

  final CmsOfficeLocation? office;

  @override
  ConsumerState<_OfficeEditDialog> createState() => _OfficeEditDialogState();
}

class _OfficeEditDialogState extends ConsumerState<_OfficeEditDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _shortDesc;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _email;
  late final TextEditingController _hours;
  late final TextEditingController _parking;
  late final TextEditingController _landmarks;
  late final TextEditingController _mapUrl;
  late final TextEditingController _appointmentPath;
  late final TextEditingController _mapLabel;
  late final TextEditingController _appointmentLabel;

  late String _type;
  late bool _active;
  late bool _featured;
  late bool _showOnMap;
  late bool _allowAppointments;
  String? _coverImage;
  bool _saving = false;
  bool _loadingExtras = false;

  final _hourRows = <_HourDraft>[];
  final _gallery = <OfficeMediaEntry>[];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final o = widget.office;
    _name = TextEditingController(text: o?.name ?? '');
    _slug = TextEditingController(text: o?.slug ?? '');
    _type = _normalizeType(o?.officeType);
    _shortDesc = TextEditingController(text: o?.shortDescription ?? '');
    _address = TextEditingController(text: o?.address ?? '');
    _city = TextEditingController(text: o?.city ?? '');
    _state = TextEditingController(text: o?.state ?? '');
    _lat = TextEditingController(text: o?.latitude?.toString() ?? '');
    _lng = TextEditingController(text: o?.longitude?.toString() ?? '');
    _phone = TextEditingController(text: o?.phone ?? '');
    _whatsapp = TextEditingController(text: o?.whatsapp ?? '');
    _email = TextEditingController(text: o?.email ?? '');
    _hours = TextEditingController(text: o?.hours ?? '');
    _parking = TextEditingController(text: o?.parkingInfo ?? '');
    _landmarks = TextEditingController(text: o?.nearbyLandmarks.join(', '));
    _mapUrl =
        TextEditingController(text: o?.mapUrl ?? 'https://maps.google.com');
    _appointmentPath = TextEditingController(
      text: o?.appointmentPath ?? '/book-consultation',
    );
    _mapLabel = TextEditingController(text: o?.mapLabel ?? 'View Map');
    _appointmentLabel = TextEditingController(
      text: o?.appointmentLabel ?? 'Book Appointment',
    );
    _active = (o?.status ?? 'active') == 'active';
    _featured = o?.isFeatured ?? false;
    _showOnMap = o?.showOnMap ?? true;
    _allowAppointments = o?.allowAppointments ?? true;
    _coverImage = o?.coverImage;
    _seedDefaultHours();
    if (o != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExtras(o.id));
    }
  }

  String _normalizeType(String? raw) {
    final t = (raw ?? '').trim();
    if (_kOfficeTypes.contains(t)) return t;
    return 'Head Office';
  }

  void _seedDefaultHours() {
    _hourRows
      ..clear()
      ..addAll([
        for (var d = 0; d < 7; d++)
          _HourDraft(
            dayOfWeek: d,
            isOpen: d < 5,
            openTime: d < 5 ? '08:00' : '09:00',
            closeTime: d < 5 ? '17:00' : '14:00',
          ),
      ]);
  }

  Future<void> _loadExtras(String officeId) async {
    setState(() => _loadingExtras = true);
    try {
      final service = ref.read(cmsServiceProvider);
      final hours = await service.listOfficeHours(officeId);
      final media = await service.listOfficeMedia(officeId);
      if (!mounted) return;
      if (hours.isNotEmpty) {
        for (final h in hours) {
          final i = _hourRows.indexWhere((r) => r.dayOfWeek == h.dayOfWeek);
          if (i >= 0) {
            _hourRows[i] = _HourDraft(
              id: h.id,
              dayOfWeek: h.dayOfWeek,
              isOpen: h.isOpen,
              openTime: h.openTime,
              closeTime: h.closeTime,
            );
          }
        }
      }
      setState(() {
        _gallery
          ..clear()
          ..addAll(media);
      });
    } finally {
      if (mounted) setState(() => _loadingExtras = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _slug.dispose();
    _shortDesc.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _lat.dispose();
    _lng.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _hours.dispose();
    _parking.dispose();
    _landmarks.dispose();
    _mapUrl.dispose();
    _appointmentPath.dispose();
    _mapLabel.dispose();
    _appointmentLabel.dispose();
    super.dispose();
  }

  String _hoursSummaryFromRows() {
    final open = _hourRows.where((h) => h.isOpen).toList();
    if (open.isEmpty) return 'Closed';
    final first = open.first;
    final same = open.every(
      (h) => h.openTime == first.openTime && h.closeTime == first.closeTime,
    );
    if (same && open.length == 5 && open.every((h) => h.dayOfWeek < 5)) {
      return 'Mon–Fri ${first.openTime}–${first.closeTime}';
    }
    if (same && open.length == 6 && open.every((h) => h.dayOfWeek < 6)) {
      return 'Mon–Sat ${first.openTime}–${first.closeTime}';
    }
    return open
        .map(
          (h) =>
              '${_kDayNames[h.dayOfWeek].substring(0, 3)} ${h.openTime}–${h.closeTime}',
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.82;
    return AlertDialog(
      title: Text(widget.office == null ? 'Add office' : 'Edit office'),
      content: SizedBox(
        width: 680,
        height: maxH.clamp(420, 720),
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Hours'),
                Tab(text: 'Gallery'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildDetailsTab(),
                  _buildHoursTab(),
                  _buildGalleryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Office name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _slug,
            decoration: const InputDecoration(
              labelText: 'Slug',
              hintText: 'head-office-lekki',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Office type'),
            items: [
              for (final t in _kOfficeTypes)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shortDesc,
            decoration: const InputDecoration(labelText: 'Short description'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _state,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lng,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsapp,
            decoration: const InputDecoration(labelText: 'WhatsApp'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hours,
            decoration: const InputDecoration(
              labelText: 'Hours summary (card text)',
              hintText: 'Auto-filled from Hours tab if left blank',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _parking,
            decoration: const InputDecoration(labelText: 'Parking info'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landmarks,
            decoration: const InputDecoration(
              labelText: 'Nearby landmarks (comma-separated)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mapUrl,
            decoration: const InputDecoration(labelText: 'Map URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mapLabel,
            decoration: const InputDecoration(labelText: 'Map button label'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appointmentPath,
            decoration: const InputDecoration(
              labelText: 'Appointment path',
              hintText: '/book-consultation',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appointmentLabel,
            decoration:
                const InputDecoration(labelText: 'Appointment button label'),
          ),
          if (_coverImage != null && _coverImage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MediaDeliveryImage(
                url: _coverImage!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploadCover,
            icon: const Icon(LucideIcons.imagePlus, size: 16),
            label: const Text('Upload cover image'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Published (active)'),
            value: _active,
            activeTrackColor: AppColors.gold,
            onChanged: (v) => setState(() => _active = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Featured office'),
            value: _featured,
            activeTrackColor: AppColors.gold,
            onChanged: (v) => setState(() => _featured = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow appointments'),
            value: _allowAppointments,
            activeTrackColor: AppColors.gold,
            onChanged: (v) => setState(() => _allowAppointments = v),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursTab() {
    if (_loadingExtras) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
        Text(
          'Weekly schedule powers Contact “OPEN NOW” status. Saving also refreshes the card hours summary when that field is empty.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate500,
              ),
        ),
        const SizedBox(height: 12),
        for (final row in _hourRows) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      _kDayNames[row.dayOfWeek],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: row.isOpen,
                    activeTrackColor: AppColors.gold,
                    onChanged: (v) => setState(() => row.isOpen = v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: row.openTime,
                      decoration: const InputDecoration(
                        labelText: 'Open',
                        isDense: true,
                      ),
                      onChanged: row.isOpen
                          ? (v) {
                              if (v != null) setState(() => row.openTime = v);
                            }
                          : null,
                      items: [
                        for (final t in _timeOptions)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: row.closeTime,
                      decoration: const InputDecoration(
                        labelText: 'Close',
                        isDense: true,
                      ),
                      onChanged: row.isOpen
                          ? (v) {
                              if (v != null) setState(() => row.closeTime = v);
                            }
                          : null,
                      items: [
                        for (final t in _timeOptions)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGalleryTab() {
    if (_loadingExtras) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _uploadGalleryImage,
          icon: const Icon(LucideIcons.imagePlus, size: 16),
          label: const Text('Add gallery image'),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _gallery.isEmpty
              ? const Center(child: Text('No gallery images yet.'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _gallery.length,
                  itemBuilder: (context, i) {
                    final m = _gallery[i];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: MediaDeliveryImage(
                            url: m.storagePath,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (m.isCover)
                          const Positioned(
                            left: 6,
                            top: 6,
                            child: Chip(
                              label: Text('Cover'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(32, 32),
                            ),
                            onPressed: () => _deleteGalleryItem(m),
                            icon: const Icon(LucideIcons.trash2, size: 14),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _uploadCover() async {
    final url = await _pickAndUpload();
    if (url == null) return;
    setState(() => _coverImage = url);
  }

  Future<void> _uploadGalleryImage() async {
    final officeId = widget.office?.id;
    if (officeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the office first, then add gallery images.'),
        ),
      );
      return;
    }
    final url = await _pickAndUpload(officeId: officeId);
    if (url == null) return;
    final entry = await ref.read(cmsServiceProvider).addOfficeMedia(
          officeId: officeId,
          storagePath: url,
          sortOrder: (_gallery.length + 1) * 10,
          isCover: _gallery.isEmpty && (_coverImage == null || _coverImage!.isEmpty),
        );
    if (_coverImage == null || _coverImage!.isEmpty) {
      setState(() => _coverImage = url);
    }
    setState(() => _gallery.add(entry));
  }

  Future<void> _deleteGalleryItem(OfficeMediaEntry m) async {
    await ref.read(cmsServiceProvider).deleteOfficeMedia(m.id);
    setState(() => _gallery.removeWhere((e) => e.id == m.id));
  }

  Future<String?> _pickAndUpload({String? officeId}) async {
    final result =
        await FilePicker.pickFiles(withData: true, type: FileType.image);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    final id = officeId ??
        widget.office?.id ??
        'new-${DateTime.now().millisecondsSinceEpoch}';
    return ref.read(cmsServiceProvider).uploadOfficeImage(
          officeId: id,
          bytes: bytes,
          filename: file.name,
        );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Office name is required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = widget.office;
      final landmarks = _landmarks.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      var hoursSummary = _hours.text.trim();
      if (hoursSummary.isEmpty) {
        hoursSummary = _hoursSummaryFromRows();
        _hours.text = hoursSummary;
      }
      final saved = await ref.read(cmsServiceProvider).upsertOfficeLocation(
            id: existing?.id,
            name: name,
            slug: _slug.text.trim().isEmpty ? null : _slug.text.trim(),
            officeType: _type,
            shortDescription: _shortDesc.text.trim(),
            address: _address.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            latitude: double.tryParse(_lat.text.trim()),
            longitude: double.tryParse(_lng.text.trim()),
            phone: _phone.text.trim(),
            whatsapp: _whatsapp.text.trim(),
            email: _email.text.trim(),
            hours: hoursSummary,
            parkingInfo: _parking.text.trim(),
            nearbyLandmarks: landmarks,
            mapUrl: _mapUrl.text.trim().isEmpty
                ? 'https://maps.google.com'
                : _mapUrl.text.trim(),
            appointmentPath: _appointmentPath.text.trim().isEmpty
                ? '/book-consultation'
                : _appointmentPath.text.trim(),
            mapLabel: _mapLabel.text.trim().isEmpty
                ? 'View Map'
                : _mapLabel.text.trim(),
            appointmentLabel: _appointmentLabel.text.trim().isEmpty
                ? 'Book Appointment'
                : _appointmentLabel.text.trim(),
            coverImage: _coverImage,
            isFeatured: _featured,
            showOnMap: _showOnMap,
            allowAppointments: _allowAppointments,
            sortOrder: existing?.sortOrder ?? 999,
            status: _active ? 'active' : 'draft',
          );

      await ref.read(cmsServiceProvider).upsertOfficeHours(
            officeId: saved.id,
            hours: [
              for (final h in _hourRows)
                OfficeHourEntry(
                  id: h.id ?? '',
                  officeId: saved.id,
                  dayOfWeek: h.dayOfWeek,
                  isOpen: h.isOpen,
                  openTime: h.openTime,
                  closeTime: h.closeTime,
                ),
            ],
          );

      if (_coverImage != null &&
          _coverImage!.isNotEmpty &&
          !_gallery.any((g) => g.storagePath == _coverImage)) {
        await ref.read(cmsServiceProvider).addOfficeMedia(
              officeId: saved.id,
              storagePath: _coverImage!,
              isCover: true,
            );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _HourDraft {
  _HourDraft({
    this.id,
    required this.dayOfWeek,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  final String? id;
  final int dayOfWeek;
  bool isOpen;
  String openTime;
  String closeTime;
}

List<String> get _timeOptions {
  final out = <String>[];
  for (var h = 6; h <= 21; h++) {
    for (final m in [0, 30]) {
      out.add(
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
      );
    }
  }
  return out;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.offices});

  final List<CmsOfficeLocation> offices;

  @override
  Widget build(BuildContext context) {
    final active = offices.where((o) => o.status == 'active').length;
    final sales =
        offices.where((o) => o.officeType.toLowerCase().contains('sales')).length;
    final regional = offices
        .where((o) => o.officeType.toLowerCase().contains('regional'))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 12,
        children: [
          _Stat(label: 'Total offices', value: '${offices.length}'),
          _Stat(label: 'Published', value: '$active'),
          _Stat(label: 'Sales centres', value: '$sales'),
          _Stat(label: 'Regional', value: '$regional'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.neutral200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
