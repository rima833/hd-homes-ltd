import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Legal & compliance inquiry form — stored as a website support ticket.
class TrustLegalInquiryForm extends HookConsumerWidget {
  const TrustLegalInquiryForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final emailController = useTextEditingController();
    final phoneController = useTextEditingController();
    final referenceController = useTextEditingController();
    final messageController = useTextEditingController();
    final inquiryType = useState('Legal assistance');
    final submitted = useState(false);
    final submitting = useState(false);

    if (submitted.value) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.badgeCheck, color: AppColors.gold),
              SizedBox(height: AppSpacing.sm),
              Text('Your enquiry has been received.'),
              SizedBox(height: AppSpacing.xs),
              Text(
                'The legal team can read it with the other website support tickets. '
                'They will reply to the email you entered.',
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
              decoration: const InputDecoration(
                labelText: 'Inquiry type',
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.base),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
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
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Submit inquiry',
              icon: LucideIcons.send,
              isLoading: submitting.value,
              onPressed: submitting.value
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final phone = phoneController.text.trim();
                      if (name.isEmpty ||
                          email.isEmpty ||
                          !email.contains('@') ||
                          phone.length < 7) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid name, email, and phone.',
                            ),
                          ),
                        );
                        return;
                      }
                      final reference = referenceController.text.trim();
                      final message = messageController.text.trim();
                      submitting.value = true;
                      try {
                        final service = ref.read(websiteFormsServiceProvider);
                        final types = await service.fetchSupportTypes();
                        final type = _supportTypeForLegal(types);
                        if (type == null) {
                          throw StateError(
                            'We could not save this enquiry yet. Please use the Contact page.',
                          );
                        }
                        await service.submitSupportTicket(
                          fullName: name,
                          email: email,
                          typeId: type.id,
                          details: [
                            'Inquiry type: ${inquiryType.value}',
                            'Phone: $phone',
                            if (reference.isNotEmpty) 'Reference: $reference',
                            if (message.isNotEmpty) message,
                          ].join('\n'),
                        );
                        submitted.value = true;
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error is StateError
                                  ? error.message
                                  : 'We could not save this enquiry. Please try again.',
                            ),
                          ),
                        );
                      } finally {
                        submitting.value = false;
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

WebsiteFormOption? _supportTypeForLegal(List<WebsiteFormOption> types) {
  for (final preferred in ['legal', 'other', 'complaint']) {
    for (final type in types) {
      if (type.slug == preferred || type.slug.contains(preferred)) {
        return type;
      }
    }
  }
  if (types.isEmpty) return null;
  return types.first;
}
