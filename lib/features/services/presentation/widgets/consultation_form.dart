import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';

/// Smart consultation form — creates CRM lead placeholder on submit.
class ConsultationForm extends HookWidget {
  const ConsultationForm({
    super.key,
    this.preselectedService,
    this.onSubmitted,
  });

  final String? preselectedService;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final meetingType = useState('Video');
    final submitted = useState(false);

    if (submitted.value) {
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
            const Text(
              'Your consultation request has been logged. A branded proposal will be '
              'generated and our team will contact you within 24 hours.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Digital Proposal Generator — proposal stored in Client Dashboard (placeholder).',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
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
              SizedBox(
                width: 220,
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Full name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(decoration: const InputDecoration(labelText: 'Company')),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Phone *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Email *'),
                  validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  initialValue: preselectedService,
                  decoration: const InputDecoration(labelText: 'Service needed'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(decoration: const InputDecoration(labelText: 'Budget')),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(decoration: const InputDecoration(labelText: 'Timeline')),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(decoration: const InputDecoration(labelText: 'Location')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Preferred meeting type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Phone', label: Text('Phone')),
              ButtonSegment(value: 'Video', label: Text('Video')),
              ButtonSegment(value: 'Physical', label: Text('On-site')),
            ],
            selected: {meetingType.value},
            onSelectionChanged: (s) => meetingType.value = s.first,
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Preferred date'),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Preferred time'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I consent to HD Homes processing my data for this inquiry.'),
            value: true,
            onChanged: (_) {},
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Submit Consultation Request',
            expand: true,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                submitted.value = true;
                onSubmitted?.call();
              }
            },
          ),
        ],
      ),
    );
  }
}
