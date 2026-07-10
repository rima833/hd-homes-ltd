import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/contact/data/models/contact_content.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/contact/data/providers/lead_routing_provider.dart';
import 'package:hdhomesproject/features/contact/presentation/widgets/contact_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Property inspection booking form — highest-converting contact flow.
class InspectionBookingForm extends HookConsumerWidget {
  const InspectionBookingForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(contactHubCmsProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final property = useState(cms.inspectionProperties.first);
    final estate = useState(cms.inspectionEstates.first);
    final meetingType = useState('Physical');
    final language = useState('English');
    final submittedLead = useState<SubmittedLead?>(null);
    final budget = useState('');
    final location = useState('');
    final propertyType = useState('');
    final timeline = useState('');
    final financing = useState('');
    final investment = useState(false);

    if (submittedLead.value != null) {
      return LeadConfirmationPanel(lead: submittedLead.value!, showVisitorPass: true);
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              _field('Full name *', width: 220, required: true),
              _field('Phone *', width: 220, required: true),
              _field('Email *', width: 220, required: true, email: true),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: property.value,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: cms.inspectionProperties
                      .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => property.value = v ?? property.value,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: estate.value,
                  decoration: const InputDecoration(labelText: 'Estate'),
                  items: cms.inspectionEstates.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => estate.value = v ?? estate.value,
                ),
              ),
              _field('Preferred date', width: 220),
              _field('Preferred time', width: 220),
              _field('Preferred agent', width: 220),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Meeting type', style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Physical', label: Text('Physical')),
              ButtonSegment(value: 'Virtual', label: Text('Virtual')),
            ],
            selected: {meetingType.value},
            onSelectionChanged: (s) => meetingType.value = s.first,
          ),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: language.value,
              decoration: const InputDecoration(labelText: 'Preferred language'),
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Yoruba', child: Text('Yoruba')),
                DropdownMenuItem(value: 'Igbo', child: Text('Igbo')),
                DropdownMenuItem(value: 'Hausa', child: Text('Hausa')),
              ],
              onChanged: (v) => language.value = v ?? language.value,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(decoration: const InputDecoration(labelText: 'Special requests'), maxLines: 2),
          const SizedBox(height: AppSpacing.base),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload documents (PDF, images)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          LeadQualificationFields(
            budget: budget.value,
            location: location.value,
            propertyType: propertyType.value,
            timeline: timeline.value,
            financing: financing.value,
            investmentInterest: investment.value,
            onBudgetChanged: (v) => budget.value = v,
            onLocationChanged: (v) => location.value = v,
            onPropertyTypeChanged: (v) => propertyType.value = v,
            onTimelineChanged: (v) => timeline.value = v,
            onFinancingChanged: (v) => financing.value = v,
            onInvestmentChanged: (v) => investment.value = v,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Book Inspection',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submittedLead.value = submitLead(
                  ref,
                  type: 'inspection',
                  qualification: LeadQualificationInput(
                    budget: budget.value,
                    location: location.value,
                    propertyType: propertyType.value,
                    timeline: timeline.value,
                    financingMethod: financing.value,
                    investmentInterest: investment.value,
                  ),
                  generatePass: true,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Consultation booking with live calendar slots.
class ConsultationBookingForm extends HookConsumerWidget {
  const ConsultationBookingForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cms = ref.watch(contactHubCmsProvider);
    final slots = ref.watch(availableCalendarSlotsProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final meetingType = useState(cms.consultationTypes.first);
    final meetingMode = useState('Video');
    final selectedSlot = useState<CalendarSlot?>(slots.isNotEmpty ? slots.first : null);
    final submittedLead = useState<SubmittedLead?>(null);
    final investment = useState(false);

    if (submittedLead.value != null) {
      return LeadConfirmationPanel(lead: submittedLead.value!, showVisitorPass: true);
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              _field('Full name *', width: 220, required: true),
              _field('Phone *', width: 220, required: true),
              _field('Email *', width: 220, required: true, email: true),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: meetingType.value,
                  decoration: const InputDecoration(labelText: 'Meeting type'),
                  items: cms.consultationTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => meetingType.value = v ?? meetingType.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Phone', label: Text('Phone')),
              ButtonSegment(value: 'Video', label: Text('Video')),
              ButtonSegment(value: 'Office', label: Text('Office')),
            ],
            selected: {meetingMode.value},
            onSelectionChanged: (s) => meetingMode.value = s.first,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Available slots (real-time calendar)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: slots.map((slot) {
              final selected = selectedSlot.value == slot;
              return ChoiceChip(
                label: Text('${slot.date} ${slot.time}\n${slot.consultant}'),
                selected: selected,
                onSelected: (_) => selectedSlot.value = slot,
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This is an investment consultation'),
            value: investment.value,
            onChanged: (v) => investment.value = v ?? false,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Book Consultation',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submittedLead.value = submitLead(
                  ref,
                  type: 'consultation',
                  qualification: LeadQualificationInput(
                    investmentInterest: investment.value || meetingType.value == 'Investment',
                    department: meetingType.value == 'Investment'
                        ? DepartmentId.investorRelations
                        : DepartmentId.sales,
                  ),
                  generatePass: meetingMode.value == 'Office',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Callback request form.
class CallbackRequestForm extends HookConsumerWidget {
  const CallbackRequestForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final department = useState('Sales');
    final priority = useState('Normal');
    final submittedLead = useState<SubmittedLead?>(null);

    if (submittedLead.value != null) {
      return LeadConfirmationPanel(lead: submittedLead.value!);
    }

    return Form(
      key: formKey,
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              _field('Name *', width: 220, required: true),
              _field('Phone *', width: 220, required: true),
              _field('Best time to call', width: 220),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: department.value,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: ['Sales', 'Support', 'Investor Relations', 'Legal']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => department.value = v ?? department.value,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: priority.value,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['Low', 'Normal', 'High', 'VIP']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => priority.value = v ?? priority.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(decoration: const InputDecoration(labelText: 'Reason for callback'), maxLines: 2),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Request Callback',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submittedLead.value = submitLead(
                  ref,
                  type: 'callback',
                  qualification: LeadQualificationInput(
                    priority: priority.value == 'VIP'
                        ? LeadPriority.vip
                        : priority.value == 'High'
                            ? LeadPriority.high
                            : LeadPriority.normal,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Support / complaint ticket form.
class SupportTicketForm extends HookConsumerWidget {
  const SupportTicketForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedLead = useState<SubmittedLead?>(null);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    if (submittedLead.value != null) {
      return LeadConfirmationPanel(lead: submittedLead.value!);
    }

    return Form(
      key: formKey,
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.base,
            children: [
              _field('Name *', width: 220, required: true),
              _field('Email *', width: 220, required: true, email: true),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: 'Complaint',
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'Complaint', child: Text('Complaint')),
                    DropdownMenuItem(value: 'Feedback', child: Text('Feedback')),
                    DropdownMenuItem(value: 'Suggestion', child: Text('Suggestion')),
                    DropdownMenuItem(value: 'Technical', child: Text('Technical issue')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(decoration: const InputDecoration(labelText: 'Details *'), maxLines: 4),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Submit Ticket',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submittedLead.value = submitLead(
                  ref,
                  type: 'support',
                  qualification: const LeadQualificationInput(department: DepartmentId.customerSupport),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Careers contact form.
class CareersContactForm extends HookConsumerWidget {
  const CareersContactForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedLead = useState<SubmittedLead?>(null);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    if (submittedLead.value != null) {
      return LeadConfirmationPanel(lead: submittedLead.value!);
    }

    return Form(
      key: formKey,
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              _field('Full name *', width: 220, required: true),
              _field('Email *', width: 220, required: true, email: true),
              _field('Phone', width: 220),
              _field('Position applying for', width: 220),
              _field('Preferred location', width: 220),
              _field('LinkedIn URL', width: 220),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(decoration: const InputDecoration(labelText: 'Cover letter'), maxLines: 3),
          const SizedBox(height: AppSpacing.base),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Upload CV')),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Submit Application',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submittedLead.value = submitLead(
                  ref,
                  type: 'careers',
                  qualification: const LeadQualificationInput(department: DepartmentId.careers),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Partnership request form.
class PartnershipRequestForm extends HookConsumerWidget {
  const PartnershipRequestForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedLead = useState<SubmittedLead?>(null);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    if (submittedLead.value != null) {
      return LeadConfirmationPanel(lead: submittedLead.value!);
    }

    return Form(
      key: formKey,
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              _field('Company name *', width: 220, required: true),
              _field('Contact person *', width: 220, required: true),
              _field('Email *', width: 220, required: true, email: true),
              _field('Phone *', width: 220, required: true),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: 'Joint Venture',
                  decoration: const InputDecoration(labelText: 'Partnership type'),
                  items: const [
                    DropdownMenuItem(value: 'Joint Venture', child: Text('Joint Venture')),
                    DropdownMenuItem(value: 'Vendor', child: Text('Vendor Registration')),
                    DropdownMenuItem(value: 'Construction', child: Text('Construction')),
                    DropdownMenuItem(value: 'Investment', child: Text('Investment')),
                    DropdownMenuItem(value: 'Corporate', child: Text('Corporate')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(decoration: const InputDecoration(labelText: 'Proposal summary'), maxLines: 3),
          const SizedBox(height: AppSpacing.base),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Upload documents')),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Submit Partnership Request',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submittedLead.value = submitLead(
                  ref,
                  type: 'partnership',
                  qualification: const LeadQualificationInput(),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

Widget _field(String label, {required double width, bool required = false, bool email = false}) {
  return SizedBox(
    width: width,
    child: TextFormField(
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (email && !v.contains('@')) return 'Valid email required';
              return null;
            }
          : null,
    ),
  );
}
