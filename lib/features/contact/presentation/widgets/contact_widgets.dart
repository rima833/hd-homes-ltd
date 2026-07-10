import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class ContactIcons {
  static IconData resolve(String name) => switch (name) {
        'phone' => LucideIcons.phone,
        'messageCircle' => LucideIcons.messageCircle,
        'mail' => LucideIcons.mail,
        'building' => LucideIcons.building2,
        'calendar' => LucideIcons.calendar,
        'home' => LucideIcons.home,
        'landmark' => LucideIcons.landmark,
        'handshake' => LucideIcons.users,
        'messagesSquare' => LucideIcons.messagesSquare,
        'video' => LucideIcons.video,
        _ => LucideIcons.circle,
      };
}

/// Premium contact channel card.
class ContactOptionCard extends StatefulWidget {
  const ContactOptionCard({
    super.key,
    required this.option,
    this.onTap,
  });

  final ContactOption option;
  final VoidCallback? onTap;

  @override
  State<ContactOptionCard> createState() => _ContactOptionCardState();
}

class _ContactOptionCardState extends State<ContactOptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.option;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          boxShadow: _hovered ? AppShadows.lg : AppShadows.md,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.cardBorder,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ContactIcons.resolve(o.iconName), color: AppColors.gold, size: 28),
                  const SizedBox(height: AppSpacing.base),
                  Text(o.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(o.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
                  const SizedBox(height: AppSpacing.base),
                  Text(o.department, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${o.availability} · ${o.responseTime}', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(o.ctaLabel, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Office location card for directory section.
class OfficeLocationCard extends StatelessWidget {
  const OfficeLocationCard({
    super.key,
    required this.office,
    this.onBook,
  });

  final OfficeLocation office;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(office.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _row(LucideIcons.mapPin, '${office.address}, ${office.city}'),
            _row(LucideIcons.phone, office.phone),
            _row(LucideIcons.mail, office.email),
            _row(LucideIcons.clock, office.hours),
            _row(LucideIcons.car, office.parkingInfo),
            if (office.landmarks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Nearby: ${office.landmarks.join(', ')}', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.base),
            if (onBook != null)
              TextButton.icon(
                onPressed: onBook,
                icon: const Icon(LucideIcons.calendar, size: 16),
                label: const Text('Book appointment'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Lead qualification fields used across forms (enterprise feature).
class LeadQualificationFields extends StatelessWidget {
  const LeadQualificationFields({
    super.key,
    required this.budget,
    required this.location,
    required this.propertyType,
    required this.timeline,
    required this.financing,
    required this.investmentInterest,
    required this.onBudgetChanged,
    required this.onLocationChanged,
    required this.onPropertyTypeChanged,
    required this.onTimelineChanged,
    required this.onFinancingChanged,
    required this.onInvestmentChanged,
  });

  final String budget;
  final String location;
  final String propertyType;
  final String timeline;
  final String financing;
  final bool investmentInterest;
  final ValueChanged<String> onBudgetChanged;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onPropertyTypeChanged;
  final ValueChanged<String> onTimelineChanged;
  final ValueChanged<String> onFinancingChanged;
  final ValueChanged<bool> onInvestmentChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart lead qualification (optional)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.base,
          children: [
            SizedBox(
              width: 200,
              child: TextFormField(
                initialValue: budget,
                decoration: const InputDecoration(labelText: 'Budget'),
                onChanged: onBudgetChanged,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextFormField(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Preferred location'),
                onChanged: onLocationChanged,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextFormField(
                initialValue: propertyType,
                decoration: const InputDecoration(labelText: 'Property type'),
                onChanged: onPropertyTypeChanged,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextFormField(
                initialValue: timeline,
                decoration: const InputDecoration(labelText: 'Timeline'),
                onChanged: onTimelineChanged,
              ),
            ),
            SizedBox(
              width: 200,
              child: TextFormField(
                initialValue: financing,
                decoration: const InputDecoration(labelText: 'Financing method'),
                onChanged: onFinancingChanged,
              ),
            ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('I am interested in property investment'),
          value: investmentInterest,
          onChanged: (v) => onInvestmentChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}

/// Confirmation panel after form submission with CRM routing summary.
class LeadConfirmationPanel extends StatelessWidget {
  const LeadConfirmationPanel({
    super.key,
    required this.lead,
    this.showVisitorPass = false,
  });

  final SubmittedLead lead;
  final bool showVisitorPass;

  @override
  Widget build(BuildContext context) {
    final r = lead.routing;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 48),
          const SizedBox(height: AppSpacing.base),
          Text('Request received', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(r.summary, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.base,
            alignment: WrapAlignment.center,
            children: [
              _chip('Score', '${r.score}/100'),
              _chip('Department', r.department),
              _chip('Assigned', r.assignedTo),
              _chip('Priority', r.priority.name),
            ],
          ),
          if (showVisitorPass && lead.visitorPassCode != null) ...[
            const SizedBox(height: AppSpacing.xl),
            const Icon(LucideIcons.qrCode, size: 64, color: AppColors.gold),
            const SizedBox(height: AppSpacing.sm),
            Text('Digital Visitor Pass', style: Theme.of(context).textTheme.titleMedium),
            Text('Code: ${lead.visitorPassCode}', style: Theme.of(context).textTheme.headlineSmall),
            const Text(
              'Present this QR code at reception or site entrance. Check-in tracked in Admin Dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }
}
