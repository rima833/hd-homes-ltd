import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/website_forms/domain/entities/website_form_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

abstract final class WebsiteFormLux {
  static const Color bg = AppColors.deepBlack;
  static const Color surface = AppColors.darkSurface;
  static const Color field = AppColors.darkElevated;
  static const Color card = Color(0xFF14161D);
  static const Color gold = AppColors.gold;
  static const Color muted = AppColors.textSecondaryDark;
  static const Color border = Color(0xFF3A3F4A);
}

class WebsiteFeatureItem {
  const WebsiteFeatureItem({
    required this.title,
    required this.description,
    this.icon = LucideIcons.sparkles,
  });

  final String title;
  final String description;
  final IconData icon;
}

class WebsiteSplitSectionCard extends StatelessWidget {
  const WebsiteSplitSectionCard({
    super.key,
    required this.overline,
    required this.title,
    required this.description,
    required this.features,
    required this.formIcon,
    required this.formChild,
    this.calloutTitle,
    this.calloutDescription,
  });

  final String overline;
  final String title;
  final String description;
  final List<WebsiteFeatureItem> features;
  final IconData formIcon;
  final Widget formChild;
  final String? calloutTitle;
  final String? calloutDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: WebsiteFormLux.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WebsiteFormLux.border.withValues(alpha: 0.35)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 980;
          final leftPanel = _InfoPanel(
            overline: overline,
            title: title,
            description: description,
            features: features,
            calloutTitle: calloutTitle,
            calloutDescription: calloutDescription,
          );
          final rightPanel = _FormPanel(
            icon: formIcon,
            child: formChild,
          );

          if (stacked) {
            return Column(
              children: [
                leftPanel,
                const SizedBox(height: AppSpacing.base),
                rightPanel,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: leftPanel),
              const SizedBox(width: AppSpacing.base),
              Expanded(flex: 6, child: rightPanel),
            ],
          );
        },
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.overline,
    required this.title,
    required this.description,
    required this.features,
    this.calloutTitle,
    this.calloutDescription,
  });

  final String overline;
  final String title;
  final String description;
  final List<WebsiteFeatureItem> features;
  final String? calloutTitle;
  final String? calloutDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebsiteFormLux.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebsiteFormLux.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: WebsiteFormLux.gold,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: WebsiteFormLux.muted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in features) ...[
            _FeatureTile(item: item),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (calloutTitle != null && calloutDescription != null) ...[
            const SizedBox(height: AppSpacing.base),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: WebsiteFormLux.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WebsiteFormLux.border.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    calloutTitle!,
                    style: const TextStyle(
                      color: WebsiteFormLux.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calloutDescription!,
                    style: const TextStyle(color: WebsiteFormLux.muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item});

  final WebsiteFeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: WebsiteFormLux.bg,
            border: Border.all(color: WebsiteFormLux.gold.withValues(alpha: 0.4)),
          ),
          child: Icon(item.icon, size: 16, color: WebsiteFormLux.gold),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                item.description,
                style: const TextStyle(color: WebsiteFormLux.muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WebsiteFormLux.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebsiteFormLux.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: WebsiteFormLux.bg,
              border: Border.all(color: WebsiteFormLux.gold.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: WebsiteFormLux.gold),
          ),
          const SizedBox(height: AppSpacing.base),
          child,
        ],
      ),
    );
  }
}

class WebsiteFormShell extends StatelessWidget {
  const WebsiteFormShell({
    super.key,
    required this.overline,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String overline;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          overline,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: WebsiteFormLux.gold,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: WebsiteFormLux.muted,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        child,
      ],
    );
  }
}

class WebsiteFormField extends StatelessWidget {
  const WebsiteFormField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(color: AppColors.white),
      validator:
          validator ??
          (required
              ? (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                }
              : null),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        filled: true,
        fillColor: WebsiteFormLux.field,
        counterStyle: const TextStyle(color: WebsiteFormLux.muted),
      ),
    );
  }
}

class WebsiteUploadButton extends StatelessWidget {
  const WebsiteUploadButton({
    super.key,
    required this.label,
    required this.onPick,
    this.file,
    this.onRemove,
    this.enabled = true,
    this.uploading = false,
    this.error,
  });

  final String label;
  final VoidCallback onPick;
  final WebsitePickedFile? file;
  final VoidCallback? onRemove;
  final bool enabled;
  final bool uploading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: enabled && !uploading ? onPick : null,
          icon: Icon(
            uploading ? LucideIcons.loader : LucideIcons.upload,
            color: WebsiteFormLux.gold,
            size: 18,
          ),
          label: Text(
            file == null ? label : file!.fileName,
            style: const TextStyle(color: AppColors.white),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WebsiteFormLux.gold),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
        ),
        if (file != null && onRemove != null)
          TextButton(
            onPressed: enabled ? onRemove : null,
            child: const Text('Remove file'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class WebsiteFormSuccess extends StatelessWidget {
  const WebsiteFormSuccess({
    super.key,
    required this.result,
    required this.onReset,
  });

  final WebsiteFormSubmitResult result;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: WebsiteFormLux.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: WebsiteFormLux.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 44),
          const SizedBox(height: 16),
          Text(
            result.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WebsiteFormLux.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Reference: ${result.reference}',
            style: const TextStyle(
              color: WebsiteFormLux.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onReset, child: const Text('Submit another')),
        ],
      ),
    );
  }
}

class WebsiteFormUnavailable extends StatelessWidget {
  const WebsiteFormUnavailable({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebsiteFormLux.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: WebsiteFormLux.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: WebsiteFormLux.muted, height: 1.5),
      ),
    );
  }
}

class WebsiteSecureNote extends StatelessWidget {
  const WebsiteSecureNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.lock, size: 14, color: WebsiteFormLux.muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WebsiteFormLux.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class WebsiteSubmitButton extends StatelessWidget {
  const WebsiteSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      expand: true,
      isLoading: loading,
      icon: LucideIcons.send,
      onPressed: onPressed,
    );
  }
}

Future<WebsitePickedFile?> pickWebsiteDocument({
  required List<String> extensions,
  required int maxBytes,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: true,
  );
  final file = result?.files.single;
  final bytes = file?.bytes;
  if (file == null || bytes == null || bytes.isEmpty) return null;
  final ext = (file.extension ?? '').toLowerCase();
  if (!extensions.contains(ext)) {
    throw StateError('Please upload a ${extensions.join(', ').toUpperCase()} file.');
  }
  if (bytes.length > maxBytes) {
    final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
    throw StateError('File is too large. Maximum size is ${mb}MB.');
  }
  return WebsitePickedFile(
    bytes: bytes,
    fileName: file.name,
    extension: ext,
  );
}

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Required';
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
    return 'Enter a valid email';
  }
  return null;
}

String? validateRequiredName(String? value) {
  final v = value?.trim() ?? '';
  if (v.length < 2) return 'Enter your name';
  if (v.length > 120) return 'Name is too long';
  return null;
}
