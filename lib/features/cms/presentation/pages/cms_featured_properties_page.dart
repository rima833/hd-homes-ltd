import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/property_listings_dashboard.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/property_wizard_persistence.dart';
import 'package:hdhomesproject/features/pms/presentation/widgets/property_creation_wizard.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Properties → Listings
///
/// Create listings, upload covers, then Feature + Publish for homepage & /properties.
class CmsFeaturedPropertiesPage extends ConsumerStatefulWidget {
  const CmsFeaturedPropertiesPage({super.key});

  @override
  ConsumerState<CmsFeaturedPropertiesPage> createState() =>
      _CmsFeaturedPropertiesPageState();
}

class _CmsFeaturedPropertiesPageState
    extends ConsumerState<CmsFeaturedPropertiesPage> {
  final _searchController = TextEditingController();
  String? _search;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _search = value.trim().isEmpty ? null : value.trim());
    });
  }

  void _invalidate() {
    ref.invalidate(cmsFeaturedPropertiesProvider(_search));
    ref.invalidate(publishedFeaturedPropertiesProvider);
    ref.invalidate(publishedPropertiesCatalogProvider);
  }

  Future<void> _openEditor(CmsPropertyFeatured? property) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _PropertyWizardDialog(property: property),
    );
    _invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(cmsFeaturedPropertiesProvider(_search));

    return PropertyListingsDashboard(
      searchController: _searchController,
      onSearchChanged: _onSearchChanged,
      propertiesAsync: propertiesAsync,
      onRetry: () => ref.invalidate(cmsFeaturedPropertiesProvider(_search)),
      onNewProperty: () => _openEditor(null),
      onEdit: (property) => _openEditor(property),
      onView: (property) {
        final slug = property.slug.trim();
        if (slug.isEmpty) return;
        context.go('/properties/$slug');
      },
      onTogglePublished: (property, value) async {
        await ref.read(cmsServiceProvider).setPropertyPublished(property.id, value);
        _invalidate();
      },
      onToggleFeatured: (property, value) async {
        await ref.read(cmsServiceProvider).setPropertyFeatured(property.id, value);
        _invalidate();
      },
      onDelete: (property) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete property'),
            content: Text(
              'Remove “${property.title}” from listings and the public site?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        await ref.read(cmsServiceProvider).deleteProperty(property.id);
        _invalidate();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted “${property.title}”')),
        );
      },
    );
  }
}

class _PropertyWizardDialog extends ConsumerStatefulWidget {
  const _PropertyWizardDialog({this.property});

  final CmsPropertyFeatured? property;

  @override
  ConsumerState<_PropertyWizardDialog> createState() =>
      _PropertyWizardDialogState();
}

class _PropertyWizardDialogState extends ConsumerState<_PropertyWizardDialog> {
  late PmsWizardDraft _draft;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final property = widget.property;
    _draft = property == null
        ? PmsWizardDraft(
            detailExtras: PropertyDetailExtras.emptyForWizard(),
          )
        : wizardDraftFromCms(property);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_draft.title.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final saved = await persistWizardDraft(
        cms: ref.read(cmsServiceProvider),
        draft: _draft,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final verb = widget.property == null ? 'Created' : 'Updated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.isPublished
                ? '$verb “${saved.title}” — live at /properties/${saved.slug}'
                : '$verb “${saved.title}” as draft',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingError(e);
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.property != null;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: size.width,
        height: size.height - 32,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D11),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      editing
                          ? 'Dashboard  >  Properties  >  Edit Property'
                          : 'Dashboard  >  Properties  >  New Property',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => context.go('/'),
                    icon: const Icon(LucideIcons.externalLink, size: 15),
                    label: const Text('Visit Website'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, color: AppColors.white),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PropertyCreationWizard(
                  draft: _draft,
                  onChanged: (d) => setState(() => _draft = d),
                  onSubmit: _submit,
                  onCancel: () => Navigator.of(context).pop(),
                  onSaveDraft: () {
                    _draft = _draft.copyWith(
                      publishStatus: PublishWorkflowStatus.draft,
                    );
                    setState(() {});
                    _submit();
                  },
                  isSubmitting: _submitting,
                  submitLabel: editing ? 'Save & Publish' : 'Publish property',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
