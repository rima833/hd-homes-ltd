import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/registration_models.dart';
import 'package:hdhomesproject/features/cms/domain/data/hub_page_cms.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Maps registration checkboxes to CMS legal page slugs (Admin → Website → Pages).
enum RegistrationLegalDoc {
  terms(
    slug: 'terms',
    label: 'Terms & Conditions',
    versionKey: LegalDocumentVersions.terms,
  ),
  privacy(
    slug: 'privacy',
    label: 'Privacy Policy',
    versionKey: LegalDocumentVersions.privacy,
  ),
  cookies(
    slug: 'cookies',
    label: 'Cookie Policy',
    versionKey: LegalDocumentVersions.cookies,
  );

  const RegistrationLegalDoc({
    required this.slug,
    required this.label,
    required this.versionKey,
  });

  final String slug;
  final String label;
  final String versionKey;
}

class RegistrationLegalDocView {
  const RegistrationLegalDocView({
    required this.slug,
    required this.title,
    required this.body,
    this.subtitle,
    this.updatedLabel,
    this.versionKey,
  });

  final String slug;
  final String title;
  final String body;
  final String? subtitle;
  final String? updatedLabel;
  final String? versionKey;
}

RegistrationLegalDocView _fallback(RegistrationLegalDoc doc) {
  Map<String, dynamic>? seed;
  for (final row in kLegalPageSeeds) {
    if (row['slug'] == doc.slug) {
      seed = row;
      break;
    }
  }
  final content = seed?['content'];
  final map = content is Map
      ? Map<String, dynamic>.from(content)
      : const <String, dynamic>{};
  return RegistrationLegalDocView(
    slug: doc.slug,
    title: seed?['title']?.toString() ?? doc.label,
    subtitle: map['heroSubheadline']?.toString(),
    body: (map['body']?.toString() ??
            'Please review this policy on the HD Homes website.')
        .trim(),
    versionKey: doc.versionKey,
  );
}

RegistrationLegalDocView _fromPage(
  RegistrationLegalDoc doc,
  CmsPageRecord? page,
) {
  if (page == null) return _fallback(doc);
  final content = page.content;
  final body = (content['body'] ?? content['html'] ?? content['text'] ?? '')
      .toString()
      .trim();
  final subtitle = (content['heroSubheadline'] ?? content['subtitle'] ?? '')
      .toString()
      .trim();
  return RegistrationLegalDocView(
    slug: doc.slug,
    title: page.title.trim().isEmpty ? doc.label : page.title.trim(),
    subtitle: subtitle.isEmpty ? null : subtitle,
    body: body.isEmpty ? _fallback(doc).body : body,
    versionKey: doc.versionKey,
    updatedLabel: page.updatedAt == null
        ? null
        : 'Updated ${page.updatedAt!.day}/${page.updatedAt!.month}/${page.updatedAt!.year}',
  );
}

/// Opens a readable sheet with policy content from Admin CMS pages.
Future<void> showRegistrationLegalDocument(
  BuildContext context,
  RegistrationLegalDocView view,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF12141A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.82;
      return SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.fileText, color: AppColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          view.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (view.updatedLabel != null)
                          Text(
                            view.updatedLabel!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (view.subtitle != null) ...[
                      Text(
                        view.subtitle!,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SelectableText(
                      view.body,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.55,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(RoutePaths.cmsPagePath(view.slug));
                      },
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                      label: const Text('Open full page'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.deepBlack,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Agreement checkbox with inline “Read” action fed by Admin CMS pages.
class RegistrationLegalCheckbox extends ConsumerWidget {
  const RegistrationLegalCheckbox({
    super.key,
    required this.doc,
    required this.value,
    required this.onChanged,
  });

  final RegistrationLegalDoc doc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(publishedPageBySlugProvider(doc.slug));
    final view = pageAsync.when(
      data: (page) => _fromPage(doc, page),
      loading: () => _fallback(doc),
      error: (_, _) => _fallback(doc),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: value
            ? AppColors.gold.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.gold.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.gold,
        checkColor: AppColors.deepBlack,
        title: Text(
          'I agree to the ${view.title}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          doc.versionKey,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        secondary: TextButton(
          onPressed: () => showRegistrationLegalDocument(context, view),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.gold,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Read'),
        ),
      ),
    );
  }
}

/// Extra published policies (e.g. refund) available to browse during signup.
class RegistrationExtraPolicies extends ConsumerWidget {
  const RegistrationExtraPolicies({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(publishedLegalPagesProvider).valueOrNull ?? const [];
    final required = RegistrationLegalDoc.values.map((e) => e.slug).toSet();
    final extras = pages
        .where((p) => p.slug.isNotEmpty && !required.contains(p.slug))
        .toList();
    if (extras.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'More policies',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final page in extras)
              ActionChip(
                avatar: const Icon(
                  LucideIcons.fileText,
                  size: 14,
                  color: AppColors.gold,
                ),
                label: Text(
                  page.title,
                  style: const TextStyle(color: Colors.white70),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                onPressed: () {
                  final body =
                      (page.content['body'] ??
                              page.content['html'] ??
                              page.content['text'] ??
                              '')
                          .toString()
                          .trim();
                  final subtitle =
                      (page.content['heroSubheadline'] ??
                              page.content['subtitle'] ??
                              '')
                          .toString()
                          .trim();
                  showRegistrationLegalDocument(
                    context,
                    RegistrationLegalDocView(
                      slug: page.slug,
                      title: page.title,
                      subtitle: subtitle.isEmpty ? null : subtitle,
                      body: body.isEmpty
                          ? 'Open the full page for the complete policy.'
                          : body,
                      updatedLabel: page.updatedAt == null
                          ? null
                          : 'Updated ${page.updatedAt!.day}/${page.updatedAt!.month}/${page.updatedAt!.year}',
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
