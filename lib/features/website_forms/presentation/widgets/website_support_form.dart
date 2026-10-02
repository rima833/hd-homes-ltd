import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_form_kit.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SupportTicketForm extends ConsumerStatefulWidget {
  const SupportTicketForm({super.key});

  @override
  ConsumerState<SupportTicketForm> createState() => _SupportTicketFormState();
}

class _SupportTicketFormState extends ConsumerState<SupportTicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _details = TextEditingController();
  String? _typeId;
  var _submitting = false;
  String? _error;
  WebsiteFormSubmitResult? _result;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(websiteFormsServiceProvider).submitSupportTicket(
            fullName: _name.text,
            email: _email.text,
            typeId: _typeId!,
            details: _details.text,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFacingError(
          e,
          fallback: 'We couldn\'t complete your submission. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(websiteSupportSettingsProvider);
    final typesAsync = ref.watch(websiteSupportTypesProvider);

    if (_result != null) {
      return WebsiteFormSuccess(
        result: _result!,
        onReset: () {
          _name.clear();
          _email.clear();
          _details.clear();
          setState(() {
            _result = null;
            _typeId = null;
          });
        },
      );
    }

    return settingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      error: (_, _) => const WebsiteFormUnavailable(
        message: 'Support is temporarily unavailable. Please try again shortly.',
      ),
      data: (settings) {
        if (settings != null && !settings.isEnabled) {
          return WebsiteFormUnavailable(message: settings.disabledMessage);
        }
        final types = typesAsync.valueOrNull ?? const <WebsiteFormOption>[];
        return WebsiteSplitSectionCard(
          overline: 'SUPPORT',
          title: 'Support Center',
          description:
              'We are here to help with complaints, feedback, suggestions, and technical issues.',
          features: const [
            WebsiteFeatureItem(
              title: 'Quick Response',
              description: 'Our team responds within 24-48 hours.',
              icon: LucideIcons.messageCircle,
            ),
            WebsiteFeatureItem(
              title: 'Confidential & Secure',
              description: 'Your information is handled confidentially and safely.',
              icon: LucideIcons.shieldCheck,
            ),
            WebsiteFeatureItem(
              title: 'Dedicated Support',
              description: 'Experienced professionals are ready to assist.',
              icon: LucideIcons.headphones,
            ),
          ],
          formIcon: LucideIcons.headphones,
          formChild: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 720;
                    final fields = [
                      WebsiteFormField(
                        label: 'Name',
                        required: true,
                        controller: _name,
                        enabled: !_submitting,
                        validator: validateRequiredName,
                      ),
                      WebsiteFormField(
                        label: 'Email',
                        required: true,
                        controller: _email,
                        enabled: !_submitting,
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail,
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_typeId),
                        isExpanded: true,
                        initialValue: types.any((t) => t.id == _typeId) ? _typeId : null,
                        items: types
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.name, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _typeId = v),
                        validator: (v) => v == null ? 'Required' : null,
                        decoration: const InputDecoration(
                          labelText: 'Type *',
                          filled: true,
                          fillColor: WebsiteFormLux.field,
                        ),
                      ),
                    ];
                    if (stacked) {
                      return Column(
                        children: [
                          for (final f in fields) ...[
                            f,
                            const SizedBox(height: AppSpacing.base),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.base),
                          Expanded(child: fields[i]),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                WebsiteFormField(
                  label: 'Details',
                  required: true,
                  controller: _details,
                  enabled: !_submitting,
                  maxLines: 6,
                  maxLength: 1000,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.length < 10) return 'Please provide at least 10 characters';
                    if (t.length > 1000) return 'Maximum 1000 characters';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                WebsiteSubmitButton(
                  label: 'Submit Ticket',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.base),
                const WebsiteSecureNote(
                  text: 'Your information is secure and will only be used to assist you.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
