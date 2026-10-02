import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/domain/services/property_wizard_persistence.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

const kWizardBg = Color(0xFF0B0D11);
const kWizardCard = Color(0xFF151B2B);
const kWizardField = Color(0xFF1C2333);
const kWizardBorder = Color(0xFF2A3347);

/// Step metadata for the 9-step create-property mockup.
class WizardStepInfo {
  const WizardStepInfo({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;
}

const kWizardSteps = <WizardStepInfo>[
  WizardStepInfo(
    label: 'Basic Information',
    subtitle: 'Title, type & overview',
    icon: LucideIcons.fileText,
  ),
  WizardStepInfo(
    label: 'Location',
    subtitle: 'Address & map',
    icon: LucideIcons.mapPin,
  ),
  WizardStepInfo(
    label: 'Specifications',
    subtitle: 'Beds, baths & sizes',
    icon: LucideIcons.ruler,
  ),
  WizardStepInfo(
    label: 'Amenities',
    subtitle: 'Features & lifestyle',
    icon: LucideIcons.sparkles,
  ),
  WizardStepInfo(
    label: 'Pricing',
    subtitle: 'Price & payment plans',
    icon: LucideIcons.wallet,
  ),
  WizardStepInfo(
    label: 'Media',
    subtitle: 'Gallery & tours',
    icon: LucideIcons.image,
  ),
  WizardStepInfo(
    label: 'Documents',
    subtitle: 'Vault & floor plans',
    icon: LucideIcons.folderOpen,
  ),
  WizardStepInfo(
    label: 'SEO',
    subtitle: 'Public page content',
    icon: LucideIcons.search,
  ),
  WizardStepInfo(
    label: 'Publish',
    subtitle: 'Status & go live',
    icon: LucideIcons.rocket,
  ),
];

String wizardAutoSlug(String title) => slugifyPropertyTitle(title);

InputDecoration wizardFieldDecoration({
  required String label,
  String? helper,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 18, color: AppColors.gold),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: kWizardField,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    labelStyle: GoogleFonts.manrope(
      color: AppColors.textSecondaryDark,
      fontSize: 13,
    ),
    hintStyle: GoogleFonts.manrope(
      color: AppColors.textSecondaryDark.withValues(alpha: 0.55),
      fontSize: 14,
    ),
    helperStyle: GoogleFonts.manrope(fontSize: 11, color: AppColors.neutral500),
    floatingLabelStyle: GoogleFonts.manrope(color: AppColors.gold),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kWizardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Empty numeric fields show the floating label as placeholder (never "0").
String wizardNumText(num? value) {
  if (value == null || value == 0) return '';
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

TextStyle get wizardInputStyle => GoogleFonts.manrope(
      color: AppColors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

/// Two-column responsive field row used on every step.
class WizardFieldRow extends StatelessWidget {
  const WizardFieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.length == 1) return children.first;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class PropertyWizardHorizontalSteps extends StatelessWidget {
  const PropertyWizardHorizontalSteps({
    super.key,
    required this.current,
    required this.onTap,
  });

  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < kWizardSteps.length; i++) ...[
            if (i > 0)
              Container(
                width: 36,
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: i <= current
                    ? AppColors.gold
                    : AppColors.white.withValues(alpha: 0.12),
              ),
            InkWell(
              onTap: () => onTap(i),
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 96,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == current
                            ? AppColors.gold
                            : i < current
                                ? AppColors.gold.withValues(alpha: 0.18)
                                : kWizardField,
                        border: Border.all(
                          color: i <= current
                              ? AppColors.gold
                              : kWizardBorder,
                        ),
                      ),
                      child: i < current
                          ? const Icon(
                              LucideIcons.check,
                              size: 15,
                              color: AppColors.gold,
                            )
                          : Text(
                              '${i + 1}',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: i == current
                                    ? AppColors.deepBlack
                                    : AppColors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kWizardSteps[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight:
                            i == current ? FontWeight.w700 : FontWeight.w500,
                        color: i == current
                            ? AppColors.gold
                            : AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PropertyWizardVerticalNav extends StatelessWidget {
  const PropertyWizardVerticalNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWizardBorder),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        itemCount: kWizardSteps.length,
        itemBuilder: (context, i) {
          final step = kWizardSteps[i];
          final active = i == current;
          final done = i < current;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: active
                        ? AppColors.gold.withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color: active
                          ? AppColors.gold.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        step.icon,
                        size: 16,
                        color: active || done
                            ? AppColors.gold
                            : AppColors.textSecondaryDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.label,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight:
                                    active ? FontWeight.w700 : FontWeight.w600,
                                color: active
                                    ? AppColors.white
                                    : AppColors.textSecondaryDark,
                              ),
                            ),
                            Text(
                              step.subtitle,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                color: AppColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (done)
                        const Icon(
                          LucideIcons.checkCircle2,
                          size: 15,
                          color: AppColors.success,
                        )
                      else if (active)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kWizardBorder),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PropertyWizardLivePreview extends StatelessWidget {
  const PropertyWizardLivePreview({super.key, required this.draft});

  final PmsWizardDraft draft;

  double get completionRatio {
    var filled = 0;
    const total = 10;
    if (draft.title.trim().isNotEmpty) filled++;
    if (draft.slug.trim().isNotEmpty) filled++;
    if (draft.description.trim().isNotEmpty) filled++;
    if (draft.city.trim().isNotEmpty || draft.estateName.trim().isNotEmpty) {
      filled++;
    }
    if (draft.bedrooms > 0) filled++;
    if (draft.amenities.isNotEmpty) filled++;
    if ((draft.listingPrice ?? 0) > 0) filled++;
    if (draft.mediaFiles.isNotEmpty || draft.existingGalleryUrls.isNotEmpty) {
      filled++;
    }
    final docs = draft.detailExtras?.documents ?? const [];
    if (docs.any((d) => d.url.trim().isNotEmpty) ||
        draft.pendingDocumentFiles.any((e) => e != null)) {
      filled++;
    }
    if (draft.step >= 7) filled++;
    return (filled / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (completionRatio * 100).round();
    final title =
        draft.title.trim().isEmpty ? 'Untitled property' : draft.title.trim();
    final type = draft.propertyType.isEmpty
        ? 'Apartment'
        : '${draft.propertyType[0].toUpperCase()}${draft.propertyType.substring(1)}';
    final locationParts = [
      if (draft.estateName.trim().isNotEmpty) draft.estateName.trim(),
      if (draft.city.trim().isNotEmpty) draft.city.trim(),
    ];
    final location =
        locationParts.isEmpty ? 'Location pending' : locationParts.join(', ');
    final price = draft.priceLabel.trim().isNotEmpty
        ? draft.priceLabel.trim()
        : ((draft.listingPrice ?? 0) <= 0
            ? 'Price on request'
            : NumberFormat.currency(
                locale: 'en_NG',
                symbol: '₦',
                decimalDigits: 0,
              ).format(draft.listingPrice));

    // Prefer freshly uploaded cover bytes, then existing gallery URL.
    List<int>? imageBytes;
    if (draft.mediaFiles.isNotEmpty) {
      PmsWizardMediaFile chosen = draft.mediaFiles.first;
      for (final file in draft.mediaFiles) {
        if (file.isCover) {
          chosen = file;
          break;
        }
      }
      imageBytes = chosen.bytes;
    }
    final imageUrl = (imageBytes == null || imageBytes.isEmpty) &&
            draft.existingGalleryUrls.isNotEmpty
        ? draft.existingGalleryUrls.first
        : null;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            'LIVE PREVIEW',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          _PreviewCard(
            title: title,
            location: location,
            price: price,
            imageUrl: imageUrl,
            imageBytes: imageBytes,
            bedrooms: draft.bedrooms,
            bathrooms: draft.bathrooms,
            area: draft.builtUpAreaSqm,
            type: type,
            featured: draft.featureOnHomepage,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kWizardField,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kWizardBorder),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 5,
                        backgroundColor:
                            AppColors.white.withValues(alpha: 0.08),
                        color: AppColors.gold,
                      ),
                      Text(
                        '$pct%',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete your property profile',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fill every step to increase visibility.',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.lightbulb,
                  size: 15,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add high quality images and a detailed description to get more inquiries.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textSecondaryDark,
                    ),
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.location,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.type,
    required this.featured,
    this.imageUrl,
    this.imageBytes,
    this.area,
  });

  final String title;
  final String location;
  final String price;
  final String? imageUrl;
  final List<int>? imageBytes;
  final double bedrooms;
  final double bathrooms;
  final double? area;
  final String type;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWizardField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWizardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageBytes != null && imageBytes!.isNotEmpty)
                  Image.memory(
                    Uint8List.fromList(imageBytes!),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                else if (imageUrl != null && imageUrl!.startsWith('http'))
                  MediaDeliveryImage(
                    url: imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: _placeholder(),
                  )
                else
                  _placeholder(),
                if (featured)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Featured',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlack,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 11,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _chip(
                      LucideIcons.bed,
                      bedrooms > 0 ? '${bedrooms.round()} Beds' : 'Beds —',
                    ),
                    _chip(
                      LucideIcons.bath,
                      bathrooms > 0 ? '${bathrooms.round()} Baths' : 'Baths —',
                    ),
                    _chip(
                      LucideIcons.maximize,
                      (area ?? 0) > 0 ? '${area!.round()} SQM' : 'SQM —',
                    ),
                    _chip(LucideIcons.home, type),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF222A3A),
      child: const Icon(
        LucideIcons.building2,
        color: AppColors.gold,
        size: 34,
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.gold),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}
