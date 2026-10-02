import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_form_kit.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PartnershipRequestForm extends ConsumerStatefulWidget {
  const PartnershipRequestForm({super.key});

  @override
  ConsumerState<PartnershipRequestForm> createState() =>
      _PartnershipRequestFormState();
}

class _PartnershipRequestFormState extends ConsumerState<PartnershipRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _person = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _proposal = TextEditingController();
  String? _typeId;
  final _docs = <WebsitePickedFile>[];
  String? _uploadError;
  var _submitting = false;
  String? _error;
  WebsiteFormSubmitResult? _result;

  @override
  void dispose() {
    _company.dispose();
    _person.dispose();
    _email.dispose();
    _phone.dispose();
    _proposal.dispose();
    super.dispose();
  }

  Future<void> _pickDocs(PartnershipSettings settings) async {
    setState(() => _uploadError = null);
    try {
      final file = await pickWebsiteDocument(
        extensions: settings.allowedDocExtensions,
        maxBytes: settings.maxDocBytes,
      );
      if (!mounted || file == null) return;
      setState(() => _docs.add(file));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError = e is StateError ? e.message : 'Could not attach that file.';
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(websiteFormsServiceProvider).submitPartnershipRequest(
            companyName: _company.text,
            contactPerson: _person.text,
            email: _email.text,
            phone: _phone.text,
            typeId: _typeId!,
            proposal: _proposal.text,
            documents: List.of(_docs),
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
          fallback: 'We couldn\'t complete your request. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(partnershipSettingsProvider);
    final typesAsync = ref.watch(partnershipTypesProvider);

    if (_result != null) {
      return WebsiteFormSuccess(
        result: _result!,
        onReset: () {
          _company.clear();
          _person.clear();
          _email.clear();
          _phone.clear();
          _proposal.clear();
          setState(() {
            _result = null;
            _typeId = null;
            _docs.clear();
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
        message: 'Partnership requests are temporarily unavailable.',
      ),
      data: (settings) {
        if (settings != null && !settings.isEnabled) {
          return WebsiteFormUnavailable(message: settings.disabledMessage);
        }
        final types = typesAsync.valueOrNull ?? const <WebsiteFormOption>[];
        final cfg = settings ?? const PartnershipSettings(id: 'local');
        return WebsiteSplitSectionCard(
          overline: 'PARTNERSHIPS',
          title: 'Partnership Requests',
          description:
              'Interested in collaborating with us? Tell us about your proposal and our business development team will be in touch.',
          features: const [
            WebsiteFeatureItem(
              title: 'Business Collaboration',
              description: 'Joint ventures, vendor onboarding, and strategic alliances.',
              icon: LucideIcons.users,
            ),
            WebsiteFeatureItem(
              title: 'Clear Evaluation',
              description: 'Each request is reviewed for strategic fit and impact.',
              icon: LucideIcons.scale,
            ),
          ],
          calloutTitle: 'Let’s Build Together',
          calloutDescription:
              'We are open to strategic partnerships that create long-term value.',
          formIcon: LucideIcons.users,
          formChild: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 900;
                    final fields = <Widget>[
                      WebsiteFormField(
                        label: 'Company name',
                        required: true,
                        controller: _company,
                        enabled: !_submitting,
                        validator: validateRequiredName,
                      ),
                      WebsiteFormField(
                        label: 'Contact person',
                        required: true,
                        controller: _person,
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
                      WebsiteFormField(
                        label: 'Phone',
                        required: true,
                        controller: _phone,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10) return 'Enter a valid phone number';
                          return null;
                        },
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
                          labelText: 'Partnership type',
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
                    return Wrap(
                      spacing: AppSpacing.base,
                      runSpacing: AppSpacing.base,
                      children: fields
                          .map(
                            (f) => SizedBox(
                              width: (c.maxWidth - AppSpacing.base * 4) / 5,
                              child: f,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                WebsiteFormField(
                  label: 'Proposal summary',
                  controller: _proposal,
                  enabled: !_submitting,
                  maxLines: 6,
                  maxLength: 1500,
                ),
                const SizedBox(height: AppSpacing.base),
                WebsiteUploadButton(
                  label: _docs.isEmpty
                      ? 'Upload documents'
                      : '${_docs.length} file${_docs.length == 1 ? '' : 's'} attached',
                  file: _docs.isEmpty ? null : _docs.last,
                  enabled: !_submitting,
                  error: _uploadError,
                  onPick: () => _pickDocs(cfg),
                  onRemove: _docs.isEmpty
                      ? null
                      : () => setState(_docs.clear),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                WebsiteSubmitButton(
                  label: 'Submit Partnership Request',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.base),
                const WebsiteSecureNote(
                  text: 'Your information is secure and will only be used for partnership evaluation.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
