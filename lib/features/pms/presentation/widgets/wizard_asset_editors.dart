import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/pms/presentation/widgets/property_wizard_live_preview.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared visual shell for wizard field groups (matches steps 1–9 card style).
class WizardSectionCard extends StatelessWidget {
  const WizardSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWizardField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWizardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.gold),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class WizardUploadOrUrlField extends StatelessWidget {
  const WizardUploadOrUrlField({
    super.key,
    required this.url,
    required this.onUrlChanged,
    required this.onPickFile,
    this.pendingFile,
    this.onClearPending,
    this.urlLabel = 'Or paste URL',
    this.pickLabel = 'Upload file',
    this.helper,
  });

  final String url;
  final ValueChanged<String> onUrlChanged;
  final VoidCallback onPickFile;
  final PmsWizardPendingFile? pendingFile;
  final VoidCallback? onClearPending;
  final String urlLabel;
  final String pickLabel;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingFile != null;
    final hasUrl = url.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(LucideIcons.upload, size: 16),
              label: Text(pickLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
              ),
            ),
            if (hasPending)
              Chip(
                avatar: const Icon(LucideIcons.fileCheck, size: 14),
                label: Text('Ready: ${pendingFile!.name}'),
                onDeleted: onClearPending,
                deleteIcon: const Icon(LucideIcons.x, size: 14),
                backgroundColor: kWizardCard,
                labelStyle: GoogleFonts.manrope(color: AppColors.white),
              )
            else if (hasUrl)
              Chip(
                avatar: const Icon(LucideIcons.link, size: 14),
                label: Text(
                  url.length > 36 ? '${url.substring(0, 36)}…' : url,
                ),
                backgroundColor: kWizardCard,
                labelStyle: GoogleFonts.manrope(color: AppColors.white),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: url,
          style: wizardInputStyle,
          decoration: wizardFieldDecoration(
            label: urlLabel,
            helper: helper ??
                'Upload a file or paste an external URL — both work.',
            icon: LucideIcons.link,
          ),
          onChanged: onUrlChanged,
        ),
      ],
    );
  }
}

Future<PmsWizardPendingFile?> pickWizardAsset({
  required FileType type,
  List<String>? extensions,
}) async {
  final result = await FilePicker.pickFiles(
    type: type,
    allowedExtensions: type == FileType.custom ? extensions : null,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;
  final name = file.name;
  final lower = name.toLowerCase();
  final contentType = lower.endsWith('.pdf')
      ? 'application/pdf'
      : lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : lower.endsWith('.webm')
                  ? 'video/webm'
                  : lower.endsWith('.mov')
                      ? 'video/quicktime'
                      : lower.endsWith('.mp4')
                          ? 'video/mp4'
                          : lower.endsWith('.gif')
                              ? 'image/gif'
                              : 'image/jpeg';
  return PmsWizardPendingFile(
    name: name,
    bytes: bytes,
    contentType: contentType,
  );
}

List<PmsWizardPendingFile?> ensurePendingLength(
  List<PmsWizardPendingFile?> current,
  int length,
) {
  final next = List<PmsWizardPendingFile?>.from(current);
  while (next.length < length) {
    next.add(null);
  }
  if (next.length > length) {
    return next.sublist(0, length);
  }
  return next;
}

class WizardDocumentCard extends StatelessWidget {
  const WizardDocumentCard({
    super.key,
    required this.doc,
    required this.pending,
    required this.onChanged,
    required this.onPendingChanged,
    this.onRemove,
  });

  final ExtrasDocument doc;
  final PmsWizardPendingFile? pending;
  final ValueChanged<ExtrasDocument> onChanged;
  final ValueChanged<PmsWizardPendingFile?> onPendingChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return WizardSectionCard(
      title: doc.title.trim().isEmpty ? 'Document' : doc.title,
      subtitle: 'Vault download — upload PDF or paste URL',
      icon: LucideIcons.fileText,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: doc.title,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(label: 'Title'),
                  onChanged: (v) => onChanged(
                    ExtrasDocument(title: v, type: doc.type, url: doc.url),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: doc.type,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(label: 'Type'),
            onChanged: (v) => onChanged(
              ExtrasDocument(title: doc.title, type: v, url: doc.url),
            ),
          ),
          const SizedBox(height: 10),
          WizardUploadOrUrlField(
            url: doc.url,
            pendingFile: pending,
            pickLabel: 'Upload PDF / file',
            onUrlChanged: (v) => onChanged(
              ExtrasDocument(title: doc.title, type: doc.type, url: v),
            ),
            onClearPending: () => onPendingChanged(null),
            onPickFile: () async {
              final file = await pickWizardAsset(
                type: FileType.custom,
                extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
              );
              if (file == null) return;
              onPendingChanged(file);
              if (doc.type.trim().isEmpty || doc.type == 'PDF') {
                onChanged(
                  ExtrasDocument(
                    title: doc.title,
                    type: file.contentType.contains('pdf') ? 'PDF' : 'File',
                    url: doc.url,
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

class WizardFloorPlanCard extends StatelessWidget {
  const WizardFloorPlanCard({
    super.key,
    required this.plan,
    required this.pending,
    required this.onChanged,
    required this.onPendingChanged,
    this.onRemove,
  });

  final ExtrasFloorPlan plan;
  final PmsWizardPendingFile? pending;
  final ValueChanged<ExtrasFloorPlan> onChanged;
  final ValueChanged<PmsWizardPendingFile?> onPendingChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return WizardSectionCard(
      title: plan.label.trim().isEmpty ? 'Floor plan' : plan.label,
      subtitle: 'Upload image/PDF or paste download URL',
      icon: LucideIcons.layout,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: plan.label,
                  style: wizardInputStyle,
                  decoration: wizardFieldDecoration(label: 'Label'),
                  onChanged: (v) => onChanged(
                    ExtrasFloorPlan(
                      label: v,
                      dimensions: plan.dimensions,
                      downloadUrl: plan.downloadUrl,
                    ),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: plan.dimensions,
            style: wizardInputStyle,
            decoration: wizardFieldDecoration(label: 'Dimensions'),
            onChanged: (v) => onChanged(
              ExtrasFloorPlan(
                label: plan.label,
                dimensions: v,
                downloadUrl: plan.downloadUrl,
              ),
            ),
          ),
          const SizedBox(height: 10),
          WizardUploadOrUrlField(
            url: plan.downloadUrl,
            pendingFile: pending,
            pickLabel: 'Upload floor plan',
            onUrlChanged: (v) => onChanged(
              ExtrasFloorPlan(
                label: plan.label,
                dimensions: plan.dimensions,
                downloadUrl: v,
              ),
            ),
            onClearPending: () => onPendingChanged(null),
            onPickFile: () async {
              final file = await pickWizardAsset(
                type: FileType.custom,
                extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
              );
              if (file == null) return;
              onPendingChanged(file);
            },
          ),
        ],
      ),
    );
  }
}
