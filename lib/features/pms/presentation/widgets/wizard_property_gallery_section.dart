import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/property_gallery_manager.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/property_wizard_persistence.dart';
import 'package:hdhomesproject/features/pms/presentation/widgets/property_wizard_live_preview.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Step 5 gallery — auto-creates a draft CMS property so Cloudinary uploads
/// work before the wizard is submitted.
class WizardPropertyGallerySection extends ConsumerStatefulWidget {
  const WizardPropertyGallerySection({
    super.key,
    required this.draft,
    required this.onChanged,
    this.enabled = true,
  });

  final PmsWizardDraft draft;
  final ValueChanged<PmsWizardDraft> onChanged;
  final bool enabled;

  @override
  ConsumerState<WizardPropertyGallerySection> createState() =>
      _WizardPropertyGallerySectionState();
}

class _WizardPropertyGallerySectionState
    extends ConsumerState<WizardPropertyGallerySection> {
  bool _ensuring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDraftProperty());
  }

  @override
  void didUpdateWidget(covariant WizardPropertyGallerySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.existingId == null &&
        oldWidget.draft.existingId == null &&
        !_ensuring) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDraftProperty());
    }
  }

  Future<void> _ensureDraftProperty() async {
    if (!widget.enabled || widget.draft.existingId != null || _ensuring) return;

    setState(() {
      _ensuring = true;
      _error = null;
    });

    try {
      final cms = ref.read(cmsServiceProvider);
      final next = await ensureWizardDraftProperty(cms: cms, draft: widget.draft);
      if (!mounted) return;
      widget.onChanged(next);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _ensuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final propertyId = widget.draft.existingId;

    if (_ensuring) {
      return _StatusCard(
        icon: LucideIcons.loader,
        title: 'Preparing live gallery…',
        subtitle: 'Creating a draft property record so uploads sync immediately.',
        trailing: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
        ),
      );
    }

    if (_error != null) {
      return _StatusCard(
        icon: LucideIcons.alertCircle,
        title: 'Could not enable live gallery',
        subtitle: _error!,
        trailing: TextButton(
          onPressed: widget.enabled ? _ensureDraftProperty : null,
          child: const Text('Retry'),
        ),
      );
    }

    if (propertyId == null) {
      return _StatusCard(
        icon: LucideIcons.cloudOff,
        title: 'Gallery unavailable',
        subtitle: 'Connect Supabase to upload via Cloudinary during property creation.',
      );
    }

    return PropertyGalleryManager(propertyId: propertyId);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWizardBorder),
        color: kWizardField,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
