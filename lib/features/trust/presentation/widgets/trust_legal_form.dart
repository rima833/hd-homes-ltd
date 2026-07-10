import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Legal & compliance inquiry form — CRM integration placeholder.
class TrustLegalInquiryForm extends HookWidget {
  const TrustLegalInquiryForm({super.key});

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final referenceController = useTextEditingController();
    final messageController = useTextEditingController();
    final inquiryType = useState('Legal assistance');
    final submitted = useState(false);

    if (submitted.value) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Icon(LucideIcons.checkCircle, color: AppColors.success, size: 48),
              const SizedBox(height: AppSpacing.base),
              Text('Inquiry submitted', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Your request has been routed to the Legal & Compliance team. '
                'Reference will be emailed within 24 hours.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: inquiryType.value,
              decoration: const InputDecoration(labelText: 'Inquiry type', border: OutlineInputBorder()),
              isExpanded: true,
              items: const [
                'Legal assistance',
                'Compliance question',
                'Document verification',
                'Report a concern',
                'Whistleblower report',
                'Corporate information request',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => inquiryType.value = v ?? inquiryType.value,
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Document reference (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Submit inquiry',
              icon: LucideIcons.send,
              onPressed: () => submitted.value = true,
            ),
          ],
        ),
      ),
    );
  }
}
