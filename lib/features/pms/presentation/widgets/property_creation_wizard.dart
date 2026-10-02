import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/media/widgets/property_gallery_manager.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/property_inspection_config_panel.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/presentation/widgets/property_wizard_live_preview.dart';
import 'package:hdhomesproject/features/pms/presentation/widgets/wizard_asset_editors.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared 9-step property creation wizard — mockup UI (CMS + PMS).
class PropertyCreationWizard extends StatelessWidget {
  const PropertyCreationWizard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onSubmit,
    this.onCancel,
    this.onSaveDraft,
    this.isSubmitting = false,
    this.submitLabel = 'Publish property',
    this.showPreview = true,
  });

  final PmsWizardDraft draft;
  final ValueChanged<PmsWizardDraft> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onCancel;
  final VoidCallback? onSaveDraft;
  final bool isSubmitting;
  final String submitLabel;
  final bool showPreview;

  PropertyDetailExtras get extras =>
      draft.detailExtras ?? PropertyDetailExtras.emptyForWizard();

  void _setExtras(PropertyDetailExtras next) =>
      onChanged(draft.copyWith(detailExtras: next));

  String get _subtitleName {
    final name = draft.title.trim();
    return name.isEmpty ? 'Luxury Residential Development' : name;
  }

  String get _continueLabel {
    final step = draft.step.clamp(0, kWizardSteps.length - 1);
    if (step >= kWizardSteps.length - 1) return submitLabel;
    return 'Continue to ${kWizardSteps[step + 1].label}';
  }

  @override
  Widget build(BuildContext context) {
    final step = draft.step.clamp(0, kWizardSteps.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 1080;

    return ColoredBox(
      color: kWizardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                Text(
                  draft.isEditing ? 'Edit Property' : 'Create New Property',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitleName,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          PropertyWizardHorizontalSteps(
            current: step,
            onTap: isSubmitting
                ? (_) {}
              : (i) => onChanged(draft.copyWith(step: i)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                      PropertyWizardVerticalNav(
                        current: step,
                        onTap: isSubmitting
                            ? (_) {}
                            : (i) => onChanged(draft.copyWith(step: i)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: _formPane(context, step)),
                      if (showPreview) ...[
                        const SizedBox(width: 14),
                        PropertyWizardLivePreview(draft: draft),
                      ],
                    ],
                  )
                : ListView(
                    children: [
                      SizedBox(
                        height: 360,
                        child: PropertyWizardVerticalNav(
                          current: step,
                          onTap: isSubmitting
                              ? (_) {}
                              : (i) => onChanged(draft.copyWith(step: i)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 520,
                        child: _formPane(context, step),
                      ),
                      if (showPreview) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 480,
                          child: PropertyWizardLivePreview(draft: draft),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _formPane(BuildContext context, int step) {
    final info = kWizardSteps[step];
    return Container(
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.gold.withValues(alpha: 0.14),
                  ),
                  child: Icon(info.icon, size: 18, color: AppColors.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.label,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        info.subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Auto-saved',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Theme(
                data: Theme.of(context).copyWith(
                  brightness: Brightness.dark,
                  canvasColor: kWizardField,
                  unselectedWidgetColor: AppColors.textSecondaryDark,
                ),
                child: DefaultTextStyle(
                  style: wizardInputStyle,
                  child: _stepContent(context, step),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kWizardBorder)),
            ),
            child: _actionBar(context, step),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context, int step) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isSubmitting ? null : (onCancel ?? () {}),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: const BorderSide(color: kWizardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : (onSaveDraft ?? onSubmit),
          icon: const Icon(LucideIcons.save, size: 16),
          label: const Text('Save Draft'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.gold),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
                    FilledButton.icon(
          onPressed: isSubmitting
              ? null
              : () {
                  if (step < kWizardSteps.length - 1) {
                    onChanged(draft.copyWith(step: step + 1));
                  } else {
                    onSubmit();
                  }
                },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
              : Icon(
                  step < kWizardSteps.length - 1
                      ? LucideIcons.arrowRight
                      : LucideIcons.check,
                  size: 16,
                ),
          label: Text(
            isSubmitting ? 'Saving…' : _continueLabel,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.deepBlack,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepContent(BuildContext context, int i) {
    switch (i) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WizardFieldRow(
          children: [
            TextFormField(
              initialValue: draft.title,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Property Title',
                    icon: LucideIcons.home,
                  ),
                  onChanged: (v) {
                    final previousAuto = wizardAutoSlug(draft.title);
                    final shouldSyncSlug = draft.slug.trim().isEmpty ||
                        draft.slug == previousAuto;
                    onChanged(
                      draft.copyWith(
                        title: v,
                        slug: shouldSyncSlug ? wizardAutoSlug(v) : draft.slug,
                      ),
                    );
                  },
                ),
                TextFormField(
                  key: ValueKey('slug-${draft.slug}'),
                  initialValue: draft.slug,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'URL Slug',
                    helper:
                        'https://hdhomes.com/p/properties/${draft.slug.isEmpty ? 'your-slug' : draft.slug}',
                    icon: LucideIcons.link,
                    suffixIcon: IconButton(
                      tooltip: 'Copy slug',
                      onPressed: draft.slug.isEmpty
                          ? null
                          : () => Clipboard.setData(
                                ClipboardData(text: draft.slug),
                              ),
                      icon: const Icon(
                        LucideIcons.copy,
                        size: 16,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  onChanged: (v) => onChanged(draft.copyWith(slug: v)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            TextFormField(
              initialValue: draft.propertyCode,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Property Code',
                    icon: LucideIcons.qrCode,
                  ),
                  onChanged: (v) =>
                      onChanged(draft.copyWith(propertyCode: v)),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('type-${draft.propertyType}'),
              initialValue: draft.propertyType,
                  dropdownColor: kWizardField,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Property Type',
                    icon: LucideIcons.building2,
                  ),
              items: const [
                'apartment',
                'duplex',
                'penthouse',
                'maisonette',
                'studio',
                'land',
              ]
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            '${t[0].toUpperCase()}${t.substring(1)}',
                          ),
                        ),
                      )
                  .toList(),
              onChanged: (v) {
                    if (v != null) {
                      onChanged(draft.copyWith(propertyType: v));
                    }
              },
            ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: draft.description,
              maxLines: 6,
              maxLength: 1000,
              style: wizardInputStyle,
              decoration: wizardFieldDecoration(
                label: 'Overview / Description',
                helper: 'Public property overview summary',
                icon: LucideIcons.alignLeft,
              ),
              onChanged: (v) => onChanged(draft.copyWith(description: v)),
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            WizardFieldRow(
          children: [
            TextFormField(
              initialValue: draft.estateName,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Estate',
                    icon: LucideIcons.building,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(estateName: v)),
            ),
            TextFormField(
              initialValue: draft.city,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'City',
                    icon: LucideIcons.mapPin,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(city: v)),
            ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            TextFormField(
              initialValue: draft.state,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'State',
                    icon: LucideIcons.map,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(state: v)),
            ),
            TextFormField(
              initialValue: draft.addressLine,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Address',
                    icon: LucideIcons.home,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(addressLine: v)),
                ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            WizardFieldRow(
          children: [
            _numField(
              label: 'Bedrooms',
                  icon: LucideIcons.bed,
              value: draft.bedrooms,
              onChanged: (v) => onChanged(draft.copyWith(bedrooms: v)),
            ),
            _numField(
              label: 'Bathrooms',
                  icon: LucideIcons.bath,
              value: draft.bathrooms,
              onChanged: (v) => onChanged(draft.copyWith(bathrooms: v)),
            ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            _numField(
              label: 'Toilets',
              value: draft.toilets,
              onChanged: (v) => onChanged(draft.copyWith(toilets: v)),
            ),
            _numField(
              label: 'Kitchens',
              value: draft.kitchens,
              onChanged: (v) => onChanged(draft.copyWith(kitchens: v)),
            ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            _numField(
              label: 'Parking spaces',
              value: draft.parkingSpaces.toDouble(),
              onChanged: (v) =>
                  onChanged(draft.copyWith(parkingSpaces: v.round())),
            ),
            _numField(
              label: 'Floors',
              value: draft.floors.toDouble(),
                  onChanged: (v) =>
                      onChanged(draft.copyWith(floors: v.round())),
            ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            _numField(
              label: 'Floor area (sqm)',
              value: draft.builtUpAreaSqm ?? 0,
                  onChanged: (v) =>
                      onChanged(draft.copyWith(builtUpAreaSqm: v)),
            ),
            _numField(
              label: 'Land area (sqm)',
              value: draft.landSizeSqm ?? 0,
              onChanged: (v) => onChanged(draft.copyWith(landSizeSqm: v)),
            ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            TextFormField(
              initialValue: draft.yearBuilt,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Year built',
                    icon: LucideIcons.calendar,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(yearBuilt: v)),
            ),
            TextFormField(
              initialValue: draft.powerSupply,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Power',
                    icon: LucideIcons.zap,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(powerSupply: v)),
            ),
              ],
            ),
            const SizedBox(height: 14),
            WizardFieldRow(
              children: [
            TextFormField(
              initialValue: draft.waterSupply,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Water',
                    icon: LucideIcons.droplets,
                  ),
              onChanged: (v) => onChanged(draft.copyWith(waterSupply: v)),
            ),
            TextFormField(
              initialValue: draft.internetConnectivity,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Internet',
                    icon: LucideIcons.wifi,
                  ),
              onChanged: (v) =>
                  onChanged(draft.copyWith(internetConnectivity: v)),
            ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: draft.architecturalConcept,
              maxLines: 2,
              style: wizardInputStyle,
              decoration: wizardFieldDecoration(
                label: 'Architectural concept',
                icon: LucideIcons.penTool,
              ),
              onChanged: (v) =>
                  onChanged(draft.copyWith(architecturalConcept: v)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: draft.investmentPotential,
              maxLines: 2,
              style: wizardInputStyle,
              decoration: wizardFieldDecoration(
                label: 'Investment potential',
                icon: LucideIcons.trendingUp,
              ),
              onChanged: (v) =>
                  onChanged(draft.copyWith(investmentPotential: v)),
            ),
          ],
        );
      case 3:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PmsWizardDraft.amenityCatalog.map((a) {
            final selected = draft.amenities.contains(a);
            return FilterChip(
              label: Text(a),
              selected: selected,
              selectedColor: AppColors.gold.withValues(alpha: 0.25),
              checkmarkColor: AppColors.gold,
              labelStyle: GoogleFonts.manrope(
                color: selected ? AppColors.white : AppColors.textSecondaryDark,
              ),
              side: BorderSide(
                color: selected ? AppColors.gold : kWizardBorder,
              ),
              backgroundColor: kWizardField,
              onSelected: (on) {
                final next = [...draft.amenities];
                if (on) {
                  next.add(a);
                } else {
                  next.remove(a);
                }
                onChanged(draft.copyWith(amenities: next));
              },
            );
          }).toList(),
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WizardSectionCard(
              title: 'Listing price',
              subtitle: 'Public price shown on marketplace & detail pages',
              icon: LucideIcons.banknote,
              child: Column(
                children: [
                  WizardFieldRow(
          children: [
            _numField(
              label: 'Listing price (NGN)',
                        icon: LucideIcons.banknote,
              value: draft.listingPrice ?? 0,
                        onChanged: (v) =>
                            onChanged(draft.copyWith(listingPrice: v)),
                      ),
                      TextFormField(
                        initialValue: draft.priceLabel,
                        style: wizardInputStyle,
                        decoration: wizardFieldDecoration(
                          label: 'Price label (optional)',
                          hint: 'e.g. ₦85M',
                          helper: 'Overrides numeric display when set',
                          icon: LucideIcons.tag,
                        ),
                        onChanged: (v) =>
                            onChanged(draft.copyWith(priceLabel: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  WizardFieldRow(
                    children: [
            _numField(
              label: 'Promo price',
              value: draft.promoPrice ?? 0,
                        onChanged: (v) =>
                            onChanged(draft.copyWith(promoPrice: v)),
            ),
            _numField(
              label: 'Investor price',
              value: draft.investorPrice ?? 0,
                        onChanged: (v) =>
                            onChanged(draft.copyWith(investorPrice: v)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            WizardSectionCard(
              title: 'Payment plans',
              subtitle: 'Installments shown on the public pricing section',
              icon: LucideIcons.wallet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WizardFieldRow(
                    children: [
                      _numField(
                        label: 'Reservation fee %',
                        value: extras.reservationFeePercent,
                        onChanged: (v) => _setExtras(
                          extras.copyWith(reservationFeePercent: v),
                        ),
                      ),
                      TextFormField(
                        initialValue: extras.taxesAndFees,
                        style: wizardInputStyle,
                        decoration: wizardFieldDecoration(
                          label: 'Taxes & fees note',
                          hint: 'Documentation & statutory fees…',
                          icon: LucideIcons.receipt,
                        ),
                        onChanged: (v) =>
                            _setExtras(extras.copyWith(taxesAndFees: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Mortgage eligible',
                      style: GoogleFonts.manrope(color: AppColors.white),
                    ),
                    subtitle: Text(
                      'Marks this listing as eligible for a mortgage.',
                      style: GoogleFonts.manrope(
                        color: AppColors.slate400,
                        fontSize: 12,
                      ),
                    ),
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.gold.withValues(alpha: 0.45),
                    value: extras.mortgageEligible,
                    onChanged: (v) =>
                        _setExtras(extras.copyWith(mortgageEligible: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Show mortgage calculator',
                      style: GoogleFonts.manrope(color: AppColors.white),
                    ),
                    subtitle: Text(
                      'Public property page uses the values below. Turn this off to hide the calculator.',
                      style: GoogleFonts.manrope(
                        color: AppColors.slate400,
                        fontSize: 12,
                      ),
                    ),
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.gold.withValues(alpha: 0.45),
                    value: extras.showMortgageCalculator,
                    onChanged: (v) => _setExtras(
                      extras.copyWith(showMortgageCalculator: v),
                    ),
                  ),
                  if (extras.showMortgageCalculator) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Calculator defaults and slider limits',
                      style: GoogleFonts.manrope(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    WizardFieldRow(
                      children: [
                        _numField(
                          label: 'Default deposit %',
                          value: extras.mortgageDepositPercent,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageDepositPercent: v),
                          ),
                        ),
                        _numField(
                          label: 'Min deposit %',
                          value: extras.mortgageDepositMinPercent,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageDepositMinPercent: v),
                          ),
                        ),
                        _numField(
                          label: 'Max deposit %',
                          value: extras.mortgageDepositMaxPercent,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageDepositMaxPercent: v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WizardFieldRow(
                      children: [
                        _numField(
                          label: 'Default interest %',
                          value: extras.mortgageInterestRate,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageInterestRate: v),
                          ),
                        ),
                        _numField(
                          label: 'Min interest %',
                          value: extras.mortgageInterestMin,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageInterestMin: v),
                          ),
                        ),
                        _numField(
                          label: 'Max interest %',
                          value: extras.mortgageInterestMax,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageInterestMax: v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WizardFieldRow(
                      children: [
                        _numField(
                          label: 'Default term (years)',
                          value: extras.mortgageTermYears,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageTermYears: v),
                          ),
                        ),
                        _numField(
                          label: 'Min term (years)',
                          value: extras.mortgageTermMinYears,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageTermMinYears: v),
                          ),
                        ),
                        _numField(
                          label: 'Max term (years)',
                          value: extras.mortgageTermMaxYears,
                          onChanged: (v) => _setExtras(
                            extras.copyWith(mortgageTermMaxYears: v),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  for (var i = 0; i < extras.paymentPlans.length; i++)
                    _PaymentPlanEditor(
                      index: i,
                      plan: extras.paymentPlans[i],
                      onChanged: (plan) {
                        final next = [...extras.paymentPlans];
                        next[i] = plan;
                        _setExtras(extras.copyWith(paymentPlans: next));
                      },
                      onRemove: () {
                        final next = [...extras.paymentPlans]..removeAt(i);
                        _setExtras(extras.copyWith(paymentPlans: next));
                      },
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        _setExtras(
                          extras.copyWith(
                            paymentPlans: [
                              ...extras.paymentPlans,
                              const ExtrasPaymentPlan(
                                name: '',
                                downPaymentPercent: 0,
                                months: 0,
                                interestRate: 0,
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add payment plan'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (draft.existingId != null) ...[
              WizardSectionCard(
                title: 'Property gallery',
                subtitle: 'Uploads go to Cloudinary immediately — website updates in realtime',
                icon: LucideIcons.cloud,
                child: PropertyGalleryManager(propertyId: draft.existingId!),
              ),
              const SizedBox(height: 14),
            ],
            WizardSectionCard(
              title: draft.existingId != null ? 'Pending uploads' : 'Gallery images',
              subtitle: draft.existingId != null
                  ? 'Optional images added on next save (use live gallery above for immediate publish)'
                  : 'Upload photos — cover appears in live preview instantly',
              icon: LucideIcons.image,
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  if (draft.existingGalleryUrls.isNotEmpty) ...[
                    Text(
                      'Saved gallery',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final url in draft.existingGalleryUrls)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 88,
                              height: 88,
                              child: url.startsWith('http')
                                  ? MediaDeliveryImage(
                                      url: url,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: kWizardCard,
                                      child: const Icon(
                                        LucideIcons.image,
                                        color: AppColors.gold,
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : () => _pickMedia(),
              icon: const Icon(LucideIcons.upload, size: 16),
                    label: Text(
                      draft.existingGalleryUrls.isEmpty &&
                              draft.mediaFiles.isEmpty
                          ? 'Upload gallery images'
                          : 'Add more images',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                  if (draft.mediaFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
              Text(
                      'New uploads (shown in live preview)',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < draft.mediaFiles.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  Uint8List.fromList(draft.mediaFiles[i].bytes),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                              if (draft.mediaFiles[i].isCover)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Cover',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.deepBlack,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(28, 28),
                                  ),
                                  onPressed: isSubmitting
                          ? null
                          : () {
                                          final next = [...draft.mediaFiles]
                                            ..removeAt(i);
                                          if (next.isNotEmpty &&
                                              !next.any((f) => f.isCover)) {
                                            next[0] = PmsWizardMediaFile(
                                              name: next[0].name,
                                              bytes: next[0].bytes,
                                              contentType: next[0].contentType,
                                              isCover: true,
                                            );
                                          }
                                          onChanged(
                                            draft.copyWith(mediaFiles: next),
                                          );
                                        },
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 14,
                                    color: AppColors.white,
                                  ),
                                ),
                    ),
                ],
              ),
                      ],
                    ),
                  ] else if (draft.existingGalleryUrls.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No images yet — upload to update the live preview.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.mediaNote,
              maxLines: 2,
                    style: wizardInputStyle,
                    decoration: wizardFieldDecoration(
                      label: 'Media notes (optional)',
                      icon: LucideIcons.stickyNote,
              ),
              onChanged: (v) => onChanged(draft.copyWith(mediaNote: v)),
                  ),
                ],
              ),
            ),
            WizardSectionCard(
              title: 'Virtual tours',
              subtitle: 'Upload video or paste a tour URL',
              icon: LucideIcons.video,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: extras.tour360Url,
                    style: wizardInputStyle,
                    decoration: wizardFieldDecoration(
                      label: '360° walkthrough URL',
                      icon: LucideIcons.rotate3d,
                    ),
                    onChanged: (v) =>
                        _setExtras(extras.copyWith(tour360Url: v)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Video tour',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  WizardUploadOrUrlField(
                    url: extras.videoTourUrl,
                    pendingFile: draft.pendingVideoTour,
                    pickLabel: 'Upload video',
                    urlLabel: 'Or paste video URL',
                    onUrlChanged: (v) =>
                        _setExtras(extras.copyWith(videoTourUrl: v)),
                    onClearPending: () => onChanged(
                      draft.copyWith(clearPendingVideoTour: true),
                    ),
                    onPickFile: () async {
                      final file = await pickWizardAsset(
                        type: FileType.custom,
                        extensions: const ['mp4', 'webm', 'mov'],
                      );
                      if (file == null) return;
                      onChanged(draft.copyWith(pendingVideoTour: file));
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drone tour',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  WizardUploadOrUrlField(
                    url: extras.droneTourUrl,
                    pendingFile: draft.pendingDroneTour,
                    pickLabel: 'Upload drone clip',
                    urlLabel: 'Or paste drone URL',
                    onUrlChanged: (v) =>
                        _setExtras(extras.copyWith(droneTourUrl: v)),
                    onClearPending: () => onChanged(
                      draft.copyWith(clearPendingDroneTour: true),
                    ),
                    onPickFile: () async {
                      final file = await pickWizardAsset(
                        type: FileType.custom,
                        extensions: const ['mp4', 'webm', 'mov'],
                      );
                      if (file == null) return;
                      onChanged(draft.copyWith(pendingDroneTour: file));
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      case 6:
        final pendingDocs = ensurePendingLength(
          draft.pendingDocumentFiles,
          extras.documents.length,
        );
        final pendingPlans = ensurePendingLength(
          draft.pendingFloorPlanFiles,
          extras.floorPlans.length,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WizardSectionCard(
              title: 'Internal notes',
              subtitle: 'Admin-only document references',
              icon: LucideIcons.bookOpen,
              child: TextFormField(
          initialValue: draft.documentsNote,
                maxLines: 2,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Title, survey, C of O refs',
                  icon: LucideIcons.bookOpen,
          ),
          onChanged: (v) => onChanged(draft.copyWith(documentsNote: v)),
              ),
            ),
            Text(
              'Document vault',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < extras.documents.length; i++)
              WizardDocumentCard(
                doc: extras.documents[i],
                pending: pendingDocs[i],
                onChanged: (doc) {
                  final next = [...extras.documents];
                  next[i] = doc;
                  _setExtras(extras.copyWith(documents: next));
                },
                onPendingChanged: (file) {
                  final next = ensurePendingLength(
                    draft.pendingDocumentFiles,
                    extras.documents.length,
                  );
                  next[i] = file;
                  onChanged(draft.copyWith(pendingDocumentFiles: next));
                },
                onRemove: extras.documents.length <= 1
                    ? null
                    : () {
                        final nextDocs = [...extras.documents]..removeAt(i);
                        final nextPending = ensurePendingLength(
                          draft.pendingDocumentFiles,
                          extras.documents.length,
                        )..removeAt(i);
                        onChanged(
                          draft.copyWith(
                            detailExtras:
                                extras.copyWith(documents: nextDocs),
                            pendingDocumentFiles: nextPending,
                          ),
                        );
                      },
              ),
            TextButton.icon(
              onPressed: () {
                final nextDocs = [
                  ...extras.documents,
                  const ExtrasDocument(
                    title: 'New document',
                    type: 'PDF',
                    url: '',
                  ),
                ];
                final nextPending = ensurePendingLength(
                  draft.pendingDocumentFiles,
                  extras.documents.length,
                )..add(null);
                onChanged(
                  draft.copyWith(
                    detailExtras: extras.copyWith(documents: nextDocs),
                    pendingDocumentFiles: nextPending,
                  ),
                );
              },
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add document'),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            ),
            const SizedBox(height: 12),
            Text(
              'Floor plans',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < extras.floorPlans.length; i++)
              WizardFloorPlanCard(
                plan: extras.floorPlans[i],
                pending: pendingPlans[i],
                onChanged: (plan) {
                  final next = [...extras.floorPlans];
                  next[i] = plan;
                  _setExtras(extras.copyWith(floorPlans: next));
                },
                onPendingChanged: (file) {
                  final next = ensurePendingLength(
                    draft.pendingFloorPlanFiles,
                    extras.floorPlans.length,
                  );
                  next[i] = file;
                  onChanged(draft.copyWith(pendingFloorPlanFiles: next));
                },
                onRemove: extras.floorPlans.length <= 1
                    ? null
                    : () {
                        final nextPlans = [...extras.floorPlans]..removeAt(i);
                        final nextPending = ensurePendingLength(
                          draft.pendingFloorPlanFiles,
                          extras.floorPlans.length,
                        )..removeAt(i);
                        onChanged(
                          draft.copyWith(
                            detailExtras:
                                extras.copyWith(floorPlans: nextPlans),
                            pendingFloorPlanFiles: nextPending,
                          ),
                        );
                      },
              ),
            TextButton.icon(
              onPressed: () {
                final nextPlans = [
                  ...extras.floorPlans,
                  const ExtrasFloorPlan(
                    label: 'New floor',
                    dimensions: '',
                    downloadUrl: '',
                  ),
                ];
                final nextPending = ensurePendingLength(
                  draft.pendingFloorPlanFiles,
                  extras.floorPlans.length,
                )..add(null);
                onChanged(
                  draft.copyWith(
                    detailExtras: extras.copyWith(floorPlans: nextPlans),
                    pendingFloorPlanFiles: nextPending,
                  ),
                );
              },
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add floor plan'),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            ),
          ],
        );
      case 7:
        return _PublicPageStep(
          extras: extras,
          onChanged: _setExtras,
          existingPropertyId: draft.existingId,
          propertyTitle: draft.title.trim().isEmpty ? null : draft.title,
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WizardFieldRow(
          children: [
            DropdownButtonFormField<PublishWorkflowStatus>(
              key: ValueKey('publish-${draft.publishStatus}'),
              initialValue: draft.publishStatus,
                  dropdownColor: kWizardField,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Publish status',
                    icon: LucideIcons.globe,
                  ),
              items: PublishWorkflowStatus.values
                  .map(
                        (s) =>
                            DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) {
                    if (v != null) {
                      onChanged(draft.copyWith(publishStatus: v));
                    }
              },
            ),
            DropdownButtonFormField<InventoryStatus>(
              key: ValueKey('inventory-${draft.inventoryStatus}'),
              initialValue: draft.inventoryStatus,
                  dropdownColor: kWizardField,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Inventory status',
                    icon: LucideIcons.package,
                  ),
              items: InventoryStatus.values
                  .map(
                        (s) =>
                            DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) {
                    if (v != null) {
                      onChanged(draft.copyWith(inventoryStatus: v));
                    }
              },
            ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<MarketingStatus>(
              key: ValueKey('marketing-${draft.marketingStatus}'),
              initialValue: draft.marketingStatus,
              dropdownColor: kWizardField,
              style: wizardInputStyle,
              decoration: wizardFieldDecoration(
                label: 'Marketing status',
                icon: LucideIcons.megaphone,
              ),
              items: MarketingStatus.values
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  onChanged(draft.copyWith(marketingStatus: v));
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Feature on homepage',
                style: GoogleFonts.manrope(color: AppColors.white),
              ),
              activeThumbColor: AppColors.gold,
              value: draft.featureOnHomepage,
              onChanged: (v) =>
                  onChanged(draft.copyWith(featureOnHomepage: v)),
            ),
            Text(
              'Publish saves pricing, vault, tours, nearby, availability, FAQs and reviews to the public listing.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        );
    }
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final next = [...draft.mediaFiles];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : name.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      next.add(
        PmsWizardMediaFile(
          name: file.name,
          bytes: bytes,
          contentType: contentType,
          isCover: next.isEmpty,
        ),
      );
    }
    onChanged(draft.copyWith(mediaFiles: next));
  }

  Widget _numField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    IconData? icon,
  }) {
    return TextFormField(
      initialValue: wizardNumText(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: wizardInputStyle,
      decoration: wizardFieldDecoration(label: label, hint: label, icon: icon),
      onChanged: (v) {
        final trimmed = v.trim();
        if (trimmed.isEmpty) {
          onChanged(0);
          return;
        }
        onChanged(double.tryParse(trimmed) ?? 0);
      },
    );
  }
}

class _PublicPageStep extends StatelessWidget {
  const _PublicPageStep({
    required this.extras,
    required this.onChanged,
    this.existingPropertyId,
    this.propertyTitle,
  });

  final PropertyDetailExtras extras;
  final ValueChanged<PropertyDetailExtras> onChanged;
  final String? existingPropertyId;
  final String? propertyTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WizardSectionCard(
          title: 'Master plan',
          subtitle: 'Estate overview on the public detail page',
          icon: LucideIcons.map,
          child: Column(
            children: [
              TextFormField(
                initialValue: extras.masterPlanDescription,
                maxLines: 3,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Description',
                  hint: 'Master-planned estate with roads, green belts…',
                ),
                onChanged: (v) =>
                    onChanged(extras.copyWith(masterPlanDescription: v)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.masterPlanLegend.join(', '),
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Legend chips',
                  hint: 'Available plots, Reserved plots, Clubhouse…',
                  helper: 'Comma-separated',
                ),
                onChanged: (v) => onChanged(
                  extras.copyWith(
                    masterPlanLegend: v
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        WizardSectionCard(
          title: 'Availability',
          subtitle: 'Unit counts shown on the public listing',
          icon: LucideIcons.pieChart,
          child: Column(
            children: [
              WizardFieldRow(
                children: [
                  _intField(
                    label: 'Total units',
                    value: extras.totalUnits,
                    onChanged: (v) =>
                        onChanged(extras.copyWith(totalUnits: v)),
                  ),
                  _intField(
                    label: 'Available',
                    value: extras.availableUnits,
                    onChanged: (v) =>
                        onChanged(extras.copyWith(availableUnits: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              WizardFieldRow(
                children: [
                  _intField(
                    label: 'Reserved',
                    value: extras.reservedUnits,
                    onChanged: (v) =>
                        onChanged(extras.copyWith(reservedUnits: v)),
                  ),
                  _intField(
                    label: 'Sold',
                    value: extras.soldUnits,
                    onChanged: (v) =>
                        onChanged(extras.copyWith(soldUnits: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        WizardSectionCard(
          title: 'Neighborhood intelligence',
          subtitle: 'Scores and insights for buyers',
          icon: LucideIcons.radar,
          child: Column(
            children: [
              WizardFieldRow(
                children: [
                  _intField(
                    label: 'Safety score',
                    value: extras.safetyScore,
                    onChanged: (v) =>
                        onChanged(extras.copyWith(safetyScore: v)),
                  ),
                  _intField(
                    label: 'Walkability',
                    value: extras.walkabilityScore,
                    onChanged: (v) =>
                        onChanged(extras.copyWith(walkabilityScore: v)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _intField(
                label: 'Lifestyle',
                value: extras.lifestyleScore,
                onChanged: (v) =>
                    onChanged(extras.copyWith(lifestyleScore: v)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.appreciationEstimate,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Appreciation estimate',
                  hint: 'e.g. 8–12% annually',
                ),
                onChanged: (v) =>
                    onChanged(extras.copyWith(appreciationEstimate: v)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.trafficConditions,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Traffic',
                  hint: 'Moderate — peak hours…',
                ),
                onChanged: (v) =>
                    onChanged(extras.copyWith(trafficConditions: v)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.plannedInfrastructure,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Infrastructure',
                  hint: 'Road expansion, BRT corridor…',
                ),
                onChanged: (v) =>
                    onChanged(extras.copyWith(plannedInfrastructure: v)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.targetBuyers,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Target buyers',
                  hint: 'Families and professionals…',
                ),
                onChanged: (v) =>
                    onChanged(extras.copyWith(targetBuyers: v)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.communityFeatures.join('\n'),
                maxLines: 3,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Community features',
                  hint: 'One feature per line',
                  helper: 'One per line',
                ),
                onChanged: (v) => onChanged(
                  extras.copyWith(
                    communityFeatures: v
                        .split('\n')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: extras.developerHighlights.join('\n'),
                maxLines: 3,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Developer highlights',
                  hint: 'One highlight per line',
                  helper: 'One per line',
                ),
                onChanged: (v) => onChanged(
                  extras.copyWith(
                    developerHighlights: v
                        .split('\n')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        WizardSectionCard(
          title: 'Nearby places',
          icon: LucideIcons.mapPin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < extras.nearbyPlaces.length; i++)
                _NearbyEditor(
                  place: extras.nearbyPlaces[i],
                  onChanged: (place) {
                    final next = [...extras.nearbyPlaces];
                    next[i] = place;
                    onChanged(extras.copyWith(nearbyPlaces: next));
                  },
                  onRemove: () {
                    final next = [...extras.nearbyPlaces]..removeAt(i);
                    onChanged(extras.copyWith(nearbyPlaces: next));
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    onChanged(
                      extras.copyWith(
                        nearbyPlaces: [
                          ...extras.nearbyPlaces,
                          const ExtrasNearbyPlace(
                            name: '',
                            category: '',
                            distance: '',
                            travelTime: '',
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add nearby place'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
        WizardSectionCard(
          title: 'Inspection booking',
          icon: LucideIcons.calendar,
          child: existingPropertyId != null
              ? PropertyInspectionConfigPanel(
                  propertyId: existingPropertyId!,
                  propertyTitle: propertyTitle,
                )
              : const Text(
                  'After publishing, configure inspection availability for this property '
                  'in the property editor or Inspections → Availability admin.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
        ),
        WizardSectionCard(
          title: 'FAQs',
          icon: LucideIcons.helpCircle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < extras.faqs.length; i++)
                _FaqEditor(
                  faq: extras.faqs[i],
                  onChanged: (faq) {
                    final next = [...extras.faqs];
                    next[i] = faq;
                    onChanged(extras.copyWith(faqs: next));
                  },
                  onRemove: () {
                    final next = [...extras.faqs]..removeAt(i);
                    onChanged(extras.copyWith(faqs: next));
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    onChanged(
                      extras.copyWith(
                        faqs: [
                          ...extras.faqs,
                          const ExtrasFaq(question: '', answer: ''),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add FAQ'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
        WizardSectionCard(
          title: 'Reviews',
          icon: LucideIcons.star,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < extras.reviews.length; i++)
                _ReviewEditor(
                  review: extras.reviews[i],
                  onChanged: (review) {
                    final next = [...extras.reviews];
                    next[i] = review;
                    onChanged(extras.copyWith(reviews: next));
                  },
                  onRemove: () {
                    final next = [...extras.reviews]..removeAt(i);
                    onChanged(extras.copyWith(reviews: next));
                  },
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    onChanged(
                      extras.copyWith(
                        reviews: [
                          ...extras.reviews,
                          const ExtrasReview(
                            name: '',
                            role: '',
                            rating: 0,
                            comment: '',
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add review'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _intField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: wizardNumText(value),
      keyboardType: TextInputType.number,
      style: wizardInputStyle,
      decoration: wizardFieldDecoration(label: label, hint: label),
      onChanged: (v) {
        final trimmed = v.trim();
        if (trimmed.isEmpty) {
          onChanged(0);
          return;
        }
        onChanged(int.tryParse(trimmed) ?? 0);
      },
    );
  }
}

class _PaymentPlanEditor extends StatelessWidget {
  const _PaymentPlanEditor({
    required this.index,
    required this.plan,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final ExtrasPaymentPlan plan;
  final ValueChanged<ExtrasPaymentPlan> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: plan.name,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Plan ${index + 1}',
                    hint: 'e.g. 12-Month Plan',
                  ),
                  onChanged: (v) => onChanged(
                    ExtrasPaymentPlan(
                      name: v,
                      downPaymentPercent: plan.downPaymentPercent,
                      months: plan.months,
                      interestRate: plan.interestRate,
                    ),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove plan',
                  onPressed: onRemove,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: wizardNumText(plan.downPaymentPercent),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Down payment',
              hint: '30 for 30%, or 3000000 for ₦3,000,000',
            ),
            onChanged: (v) => onChanged(
              ExtrasPaymentPlan(
                name: plan.name,
                downPaymentPercent: double.tryParse(v.trim()) ?? 0,
                months: plan.months,
                interestRate: plan.interestRate,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: wizardNumText(plan.months),
            keyboardType: TextInputType.number,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Months',
              hint: 'e.g. 12',
            ),
            onChanged: (v) => onChanged(
              ExtrasPaymentPlan(
                name: plan.name,
                downPaymentPercent: plan.downPaymentPercent,
                months: int.tryParse(v.trim()) ?? 0,
                interestRate: plan.interestRate,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: wizardNumText(plan.interestRate),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Interest %',
              hint: 'e.g. 0 or 10',
            ),
            onChanged: (v) => onChanged(
              ExtrasPaymentPlan(
                name: plan.name,
                downPaymentPercent: plan.downPaymentPercent,
                months: plan.months,
                interestRate: double.tryParse(v.trim()) ?? 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyEditor extends StatelessWidget {
  const _NearbyEditor({
    required this.place,
    required this.onChanged,
    required this.onRemove,
  });

  final ExtrasNearbyPlace place;
  final ValueChanged<ExtrasNearbyPlace> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: place.name,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Name',
                    hint: 'e.g. Local School',
                  ),
                  onChanged: (v) => onChanged(
                    ExtrasNearbyPlace(
                      name: v,
                      category: place.category,
                      distance: place.distance,
                      travelTime: place.travelTime,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WizardFieldRow(
            children: [
              TextFormField(
                initialValue: place.category,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Category',
                  hint: 'School, Shopping…',
                ),
                onChanged: (v) => onChanged(
                  ExtrasNearbyPlace(
                    name: place.name,
                    category: v,
                    distance: place.distance,
                    travelTime: place.travelTime,
                  ),
                ),
              ),
              TextFormField(
                initialValue: place.distance,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Distance',
                  hint: '1.2 km',
                ),
                onChanged: (v) => onChanged(
                  ExtrasNearbyPlace(
                    name: place.name,
                    category: place.category,
                    distance: v,
                    travelTime: place.travelTime,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: place.travelTime,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Travel time',
              hint: '4 min',
            ),
            onChanged: (v) => onChanged(
              ExtrasNearbyPlace(
                name: place.name,
                category: place.category,
                distance: place.distance,
                travelTime: v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotEditor extends StatelessWidget {
  const _SlotEditor({
    required this.slot,
    required this.onChanged,
    required this.onRemove,
  });

  final ExtrasInspectionSlot slot;
  final ValueChanged<ExtrasInspectionSlot> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: slot.date,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Date',
                    hint: 'Sat 12 Jul',
                  ),
                  onChanged: (v) => onChanged(
                    ExtrasInspectionSlot(
                      date: v,
                      time: slot.time,
                      available: slot.available,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: slot.time,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Time',
              hint: '10:00 AM',
            ),
            onChanged: (v) => onChanged(
              ExtrasInspectionSlot(
                date: slot.date,
                time: v,
                available: slot.available,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Available',
              style: GoogleFonts.manrope(color: AppColors.white),
            ),
            activeThumbColor: AppColors.gold,
            value: slot.available,
            onChanged: (v) => onChanged(
              ExtrasInspectionSlot(
                date: slot.date,
                time: slot.time,
                available: v,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqEditor extends StatelessWidget {
  const _FaqEditor({
    required this.faq,
    required this.onChanged,
    required this.onRemove,
  });

  final ExtrasFaq faq;
  final ValueChanged<ExtrasFaq> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: faq.question,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Question',
                    hint: 'Is the title verified?',
                  ),
                  onChanged: (v) =>
                      onChanged(ExtrasFaq(question: v, answer: faq.answer)),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: faq.answer,
            maxLines: 2,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Answer',
              hint: 'Yes. All HD Homes estates include…',
            ),
            onChanged: (v) =>
                onChanged(ExtrasFaq(question: faq.question, answer: v)),
          ),
        ],
      ),
    );
  }
}

class _ReviewEditor extends StatelessWidget {
  const _ReviewEditor({
    required this.review,
    required this.onChanged,
    required this.onRemove,
  });

  final ExtrasReview review;
  final ValueChanged<ExtrasReview> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWizardCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: review.name,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(
                    label: 'Name',
                    hint: 'Chioma A.',
                  ),
                  onChanged: (v) => onChanged(
                    ExtrasReview(
                      name: v,
                      role: review.role,
                      rating: review.rating,
                      comment: review.comment,
                      verified: review.verified,
                      type: review.type,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WizardFieldRow(
            children: [
              TextFormField(
                initialValue: review.role,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Role',
                  hint: 'Verified Buyer',
                ),
                onChanged: (v) => onChanged(
                  ExtrasReview(
                    name: review.name,
                    role: v,
                    rating: review.rating,
                    comment: review.comment,
                    verified: review.verified,
                    type: review.type,
                  ),
                ),
              ),
              TextFormField(
                initialValue: wizardNumText(review.rating),
                keyboardType: TextInputType.number,
                style: wizardInputStyle,
                decoration: wizardFieldDecoration(
                  label: 'Rating (1–5)',
                  hint: '5',
                ),
                onChanged: (v) => onChanged(
                  ExtrasReview(
                    name: review.name,
                    role: review.role,
                    rating: int.tryParse(v.trim()) ?? 0,
                    comment: review.comment,
                    verified: review.verified,
                    type: review.type,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: review.comment,
            maxLines: 2,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(
              label: 'Comment',
              hint: 'Exceptional build quality…',
            ),
            onChanged: (v) => onChanged(
              ExtrasReview(
                name: review.name,
                role: review.role,
                rating: review.rating,
                comment: v,
                verified: review.verified,
                type: review.type,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
