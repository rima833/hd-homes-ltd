import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:hdhomesproject/features/website_forms/presentation/providers/website_forms_providers.dart';
import 'package:hdhomesproject/features/website_forms/presentation/widgets/website_form_kit.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CareersContactForm extends ConsumerStatefulWidget {
  const CareersContactForm({super.key});

  @override
  ConsumerState<CareersContactForm> createState() => _CareersContactFormState();
}

class _CareersContactFormState extends ConsumerState<CareersContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _linkedin = TextEditingController();
  final _cover = TextEditingController();
  String? _jobId;
  WebsitePickedFile? _cv;
  String? _uploadError;
  var _submitting = false;
  String? _error;
  WebsiteFormSubmitResult? _result;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _linkedin.dispose();
    _cover.dispose();
    super.dispose();
  }

  Future<void> _pickCv(CareerApplicationSettings settings) async {
    setState(() => _uploadError = null);
    try {
      final file = await pickWebsiteDocument(
        extensions: settings.allowedCvExtensions,
        maxBytes: settings.maxCvBytes,
      );
      if (!mounted) return;
      setState(() => _cv = file);
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
      final result = await ref.read(websiteFormsServiceProvider).submitCareerApplication(
            fullName: _name.text,
            email: _email.text,
            phone: _phone.text,
            jobId: _jobId,
            preferredLocation: _location.text,
            linkedinUrl: _linkedin.text,
            coverLetter: _cover.text,
            cv: _cv,
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
          fallback: 'We couldn\'t complete your application. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(careerApplicationSettingsProvider);
    final jobsAsync = ref.watch(openCareerJobsProvider);

    if (_result != null) {
      return WebsiteFormSuccess(
        result: _result!,
        onReset: () {
          _name.clear();
          _email.clear();
          _phone.clear();
          _location.clear();
          _linkedin.clear();
          _cover.clear();
          setState(() {
            _result = null;
            _jobId = null;
            _cv = null;
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
        message: 'Career applications are temporarily unavailable.',
      ),
      data: (settings) {
        if (!settings.applicationsEnabled) {
          return WebsiteFormUnavailable(message: settings.disabledMessage);
        }
        final jobs = jobsAsync.valueOrNull ?? const <CmsCareerJob>[];
        return WebsiteSplitSectionCard(
          overline: 'CAREERS',
          title: 'Careers Contact',
          description:
              'Join our team and be part of a company that is building the future. Submit your details and we will reach out if there is a suitable opportunity.',
          features: const [
            WebsiteFeatureItem(
              title: 'Open Roles',
              description: 'Apply for active opportunities or submit a general application.',
              icon: LucideIcons.briefcase,
            ),
            WebsiteFeatureItem(
              title: 'Fast Screening',
              description: 'Our recruitment team reviews qualified applications quickly.',
              icon: LucideIcons.timer,
            ),
          ],
          calloutTitle: 'Why work with us?',
          calloutDescription:
              'We offer growth, innovation, and a culture that values excellence.',
          formIcon: LucideIcons.briefcase,
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
                        label: 'Full name',
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
                      WebsiteFormField(
                        label: 'Phone',
                        controller: _phone,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_jobId),
                        isExpanded: true,
                        initialValue: jobs.any((j) => j.id == _jobId) ? _jobId : (_jobId == null ? '' : null),
                        items: [
                          if (settings.allowGeneralApplication)
                            const DropdownMenuItem(
                              value: '',
                              child: Text('General application'),
                            ),
                          ...jobs.map(
                            (j) => DropdownMenuItem(
                              value: j.id,
                              child: Text(
                                j.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _jobId = (v == null || v.isEmpty) ? null : v),
                        validator: settings.allowGeneralApplication
                            ? null
                            : (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        decoration: const InputDecoration(
                          labelText: 'Position applying for',
                          filled: true,
                          fillColor: WebsiteFormLux.field,
                        ),
                      ),
                      WebsiteFormField(
                        label: 'Preferred location',
                        controller: _location,
                        enabled: !_submitting,
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
                  label: 'LinkedIn URL',
                  controller: _linkedin,
                  enabled: !_submitting,
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    if (!t.startsWith('http')) return 'Enter a valid URL';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.base),
                WebsiteFormField(
                  label: 'Cover letter',
                  controller: _cover,
                  enabled: !_submitting,
                  maxLines: 6,
                  maxLength: 1000,
                ),
                const SizedBox(height: AppSpacing.base),
                WebsiteUploadButton(
                  label: 'Upload CV',
                  file: _cv,
                  enabled: !_submitting,
                  error: _uploadError,
                  onPick: () => _pickCv(settings),
                  onRemove: () => setState(() => _cv = null),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                WebsiteSubmitButton(
                  label: 'Submit Application',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.base),
                const WebsiteSecureNote(
                  text: 'Your application is secure and will only be used for recruitment purposes.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
