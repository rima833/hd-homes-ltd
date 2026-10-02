import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/inspection/domain/entities/inspection_admin_models.dart';
import 'package:hdhomesproject/features/inspection/presentation/providers/inspection_admin_providers.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Admin panel for per-property inspection configuration.
class PropertyInspectionConfigPanel extends ConsumerStatefulWidget {
  const PropertyInspectionConfigPanel({
    super.key,
    required this.propertyId,
    this.propertyTitle,
  });

  final String propertyId;
  final String? propertyTitle;

  @override
  ConsumerState<PropertyInspectionConfigPanel> createState() =>
      _PropertyInspectionConfigPanelState();
}

class _PropertyInspectionConfigPanelState
    extends ConsumerState<PropertyInspectionConfigPanel> {
  bool _inspectionEnabled = true;
  bool _physicalEnabled = true;
  bool _virtualEnabled = true;
  int? _durationMinutes;
  int? _minNoticeHours;
  final _instructions = TextEditingController();
  var _loadedForId = '';
  var _saving = false;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  void _applyConfig(PropertyInspectionConfigRow config) {
    _inspectionEnabled = config.inspectionEnabled;
    _physicalEnabled = config.physicalEnabled;
    _virtualEnabled = config.virtualEnabled;
    _durationMinutes = config.durationMinutes;
    _minNoticeHours = config.minNoticeHours;
    _instructions.text = config.specialInstructions ?? '';
    _loadedForId = config.propertyId;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(inspectionAdminServiceProvider).savePropertyConfig(
            PropertyInspectionConfigRow(
              propertyId: widget.propertyId,
              inspectionEnabled: _inspectionEnabled,
              physicalEnabled: _physicalEnabled,
              virtualEnabled: _virtualEnabled,
              durationMinutes: _durationMinutes,
              minNoticeHours: _minNoticeHours,
              specialInstructions: _instructions.text.trim().isEmpty
                  ? null
                  : _instructions.text.trim(),
            ),
          );
      ref.invalidate(adminPropertyInspectionConfigProvider(widget.propertyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection settings saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync =
        ref.watch(adminPropertyInspectionConfigProvider(widget.propertyId));

    return configAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Failed to load: $e',
        style: const TextStyle(color: Colors.redAccent),
      ),
      data: (config) {
        if (_loadedForId != widget.propertyId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _applyConfig(
                config ??
                    PropertyInspectionConfigRow(propertyId: widget.propertyId),
              );
            });
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.propertyTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.propertyTitle!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Inspection enabled',
                style: TextStyle(color: Colors.white),
              ),
              value: _inspectionEnabled,
              activeThumbColor: InspectionAdminUi.gold,
              onChanged: (v) => setState(() => _inspectionEnabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Physical tour',
                style: TextStyle(color: Colors.white),
              ),
              value: _physicalEnabled,
              activeThumbColor: InspectionAdminUi.gold,
              onChanged: (v) => setState(() => _physicalEnabled = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Virtual tour',
                style: TextStyle(color: Colors.white),
              ),
              value: _virtualEnabled,
              activeThumbColor: InspectionAdminUi.gold,
              onChanged: (v) => setState(() => _virtualEnabled = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('duration-$_loadedForId-$_durationMinutes'),
              initialValue: _durationMinutes?.toString() ?? '',
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InspectionAdminUi.fieldDecoration(
                'Duration override (minutes)',
              ),
              onChanged: (v) =>
                  setState(() => _durationMinutes = int.tryParse(v)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('notice-$_loadedForId-$_minNoticeHours'),
              initialValue: _minNoticeHours?.toString() ?? '',
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InspectionAdminUi.fieldDecoration(
                'Min notice override (hours)',
              ),
              onChanged: (v) =>
                  setState(() => _minNoticeHours = int.tryParse(v)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructions,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InspectionAdminUi.fieldDecoration(
                'Special instructions',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: InspectionAdminUi.gold,
                  foregroundColor: Colors.black,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: Text(_saving ? 'Saving…' : 'Save property settings'),
              ),
            ),
          ],
        );
      },
    );
  }
}
