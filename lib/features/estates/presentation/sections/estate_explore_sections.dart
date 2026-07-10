import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/components/animated_section_title.dart';
import 'package:hdhomesproject/core/website/components/page_container.dart';
import 'package:hdhomesproject/core/website/components/section_wrapper.dart';
import 'package:hdhomesproject/features/estates/data/models/estate_detail_content.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sections 9–13 — Location, construction, payment, investment, gallery.
class EstateExploreSections extends HookWidget {
  const EstateExploreSections({super.key, required this.detail});

  final EstateDetailContent detail;

  @override
  Widget build(BuildContext context) {
    final timeIndex = useState(detail.constructionTimeline.length - 1);
    final deposit = useState(detail.summary.startingPriceValue * 0.2);
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Column(
      children: [
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _Location(location: detail.location)),
        ),
        SectionWrapper(
          child: PageContainer(child: _Construction(construction: detail.construction)),
        ),
        SectionWrapper(
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'CONSTRUCTION TIME MACHINE',
                  title: 'Progress over time',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                Slider(
                  value: timeIndex.value.toDouble(),
                  min: 0,
                  max: (detail.constructionTimeline.length - 1).toDouble(),
                  divisions: detail.constructionTimeline.length - 1,
                  label: detail.constructionTimeline[timeIndex.value].month,
                  onChanged: (v) => timeIndex.value = v.round(),
                ),
                Text(
                  detail.constructionTimeline[timeIndex.value].caption,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text('Milestone: ${detail.constructionTimeline[timeIndex.value].milestone}'),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: detail.constructionTimeline[timeIndex.value].progress,
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          child: PageContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AnimatedSectionTitle(
                  overline: 'PAYMENT PLANS',
                  title: 'Flexible payment options',
                  alignment: TextAlign.start,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final plan in detail.paymentPlans)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.base),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                        Text('Deposit: ${currency.format(plan.deposit)}'),
                        if (plan.installment > 0)
                          Text('Installment: ${currency.format(plan.installment)} · ${plan.durationMonths} months'),
                        Text(plan.eligibility, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('Quick calculator', style: Theme.of(context).textTheme.titleSmall),
                Slider(
                  value: deposit.value,
                  min: detail.summary.startingPriceValue * 0.1,
                  max: detail.summary.startingPriceValue * 0.5,
                  onChanged: (v) => deposit.value = v,
                ),
                Text('Deposit: ${currency.format(deposit.value)}'),
                Text(
                  'Est. monthly (24 mo): ${currency.format((detail.summary.startingPriceValue - deposit.value) / 24)}',
                ),
              ],
            ),
          ),
        ),
        SectionWrapper(
          backgroundColor: AppColors.charcoal,
          child: PageContainer(child: _Investment(investment: detail.investment)),
        ),
        SectionWrapper(
          child: PageContainer(child: _Gallery(gallery: detail.gallery, estateName: detail.summary.name)),
        ),
      ],
    );
  }
}

class _Location extends StatelessWidget {
  const _Location({required this.location});

  final EstateLocationDetail location;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AnimatedSectionTitle(overline: 'LOCATION', title: 'Location & connectivity'),
        const SizedBox(height: AppSpacing.xl),
        Container(
          height: context.isMobile ? 280 : 360,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            gradient: LinearGradient(colors: [AppColors.charcoal, AppColors.gold.withValues(alpha: 0.15)]),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.mapPin, color: AppColors.gold, size: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(location.address, style: const TextStyle(color: AppColors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final t in location.travelTimes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.navigation, color: AppColors.gold, size: 18),
            title: Text(t.destination),
            trailing: Text('${t.distance} · ${t.time}'),
          ),
      ],
    );
  }
}

class _Construction extends StatelessWidget {
  const _Construction({required this.construction});

  final EstateConstructionDetail construction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'CONSTRUCTION',
          title: 'Development progress',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        LinearProgressIndicator(value: construction.overallProgress, color: AppColors.gold, minHeight: 8),
        Text('${(construction.overallProgress * 100).round()}% overall · ${construction.completionForecast}'),
        const SizedBox(height: AppSpacing.base),
        Text(construction.weeklyUpdate),
        Text(construction.monthlyUpdate),
        const SizedBox(height: AppSpacing.lg),
        for (final phase in construction.phaseCompletion)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(phase.phase)),
                Expanded(child: LinearProgressIndicator(value: phase.progress, color: AppColors.gold)),
                const SizedBox(width: AppSpacing.sm),
                Text('${(phase.progress * 100).round()}%'),
              ],
            ),
          ),
      ],
    );
  }
}

class _Investment extends StatelessWidget {
  const _Investment({required this.investment});

  final EstateInvestmentDetail investment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AnimatedSectionTitle(
          overline: 'INVESTMENT',
          title: 'Investment potential',
          alignment: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.base,
          children: [
            _inv('Projected ROI', investment.projectedRoi),
            _inv('Rental Yield', investment.rentalYield),
            _inv('Appreciation', investment.appreciationForecast),
            _inv('Demand Index', '${investment.demandIndex}/100'),
            _inv('Occupancy', investment.occupancyForecast),
            _inv('Infrastructure', investment.infrastructureGrowth),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Text(investment.governmentProjects),
      ],
    );
  }

  Widget _inv(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold)),
        ],
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.gallery, required this.estateName});

  final EstateGallery gallery;
  final String estateName;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AnimatedSectionTitle(overline: 'GALLERY', title: 'Estate gallery'),
        const SizedBox(height: AppSpacing.xl),
        CarouselSlider.builder(
          itemCount: widget.gallery.images.length,
          options: CarouselOptions(
            height: context.isMobile ? 240 : 360,
            viewportFraction: 1,
            onPageChanged: (i, _) => setState(() => _index = i),
          ),
          itemBuilder: (_, index, __) => Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              gradient: LinearGradient(
                colors: [
                  AppColors.charcoal,
                  AppColors.gold.withValues(alpha: 0.1 + index * 0.02),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    index.isEven ? LucideIcons.image : LucideIcons.video,
                    color: AppColors.gold,
                    size: 40,
                  ),
                  Text('${widget.estateName} — ${index + 1}/${widget.gallery.images.length}'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${_index + 1} / ${widget.gallery.images.length}'),
      ],
    );
  }
}
