import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:hdhomesproject/features/settings/presentation/providers/platform_settings_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → FAQ: CRUD + reordering for frequently asked questions.
class CmsFaqPage extends ConsumerWidget {
  const CmsFaqPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqsAsync = ref.watch(cmsFaqsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'FAQs',
            subtitle:
                'Published questions appear on the homepage, services, properties, estates, investment, and trust pages. Turn the section off to hide it everywhere.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref, null),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add FAQ'),
            ),
          ),
          const SizedBox(height: 12),
          const _PublicFaqSwitch(),
          const SizedBox(height: 12),
          Expanded(
            child: faqsAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsFaqsProvider),
              ),
              data: (faqs) {
                if (faqs.isEmpty) {
                  return AdminEmptyState(
                    title: 'No FAQs yet',
                    message: 'Add your first frequently asked question.',
                    icon: LucideIcons.helpCircle,
                    action: FilledButton.icon(
                      onPressed: () => _openEditor(context, ref, null),
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add FAQ'),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: faqs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final faq = faqs[i];
                    return AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              IconButton(
                                onPressed: i == 0
                                    ? null
                                    : () => _reorder(ref, faqs, i, -1),
                                icon: const Icon(LucideIcons.arrowUp, size: 16),
                              ),
                              IconButton(
                                onPressed: i == faqs.length - 1
                                    ? null
                                    : () => _reorder(ref, faqs, i, 1),
                                icon: const Icon(LucideIcons.arrowDown, size: 16),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  faq.question,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(faq.answer, style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    AdminStatusPill(
                                      label: faq.status == 'active'
                                          ? 'Published'
                                          : 'Draft',
                                      color: faq.status == 'active'
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                    if (faq.category != null &&
                                        faq.category!.trim().isNotEmpty)
                                      AdminStatusPill(
                                        label: faq.category!,
                                        color: AppColors.info,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: faq.status == 'active'
                                ? 'Unpublish'
                                : 'Publish',
                            onPressed: () async {
                              await ref.read(cmsServiceProvider).setFaqPublished(
                                    faq.id,
                                    faq.status != 'active',
                                  );
                              ref.invalidate(cmsFaqsProvider);
                              ref.invalidate(publishedFaqsProvider);
                            },
                            icon: Icon(
                              faq.status == 'active'
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 18,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openEditor(context, ref, faq),
                            icon: const Icon(LucideIcons.pencil, size: 18),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref.read(cmsServiceProvider).deleteFaq(faq.id);
                              ref.invalidate(cmsFaqsProvider);
                            },
                            icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CmsFaq> faqs,
    int index,
    int delta,
  ) async {
    final target = index + delta;
    if (target < 0 || target >= faqs.length) return;
    final reordered = List<CmsFaq>.from(faqs);
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    await ref.read(cmsServiceProvider).reorderFaqs(reordered);
    ref.invalidate(cmsFaqsProvider);
    ref.invalidate(publishedFaqsProvider);
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, CmsFaq? faq) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _FaqEditDialog(faq: faq),
    );
    ref.invalidate(cmsFaqsProvider);
    ref.invalidate(publishedFaqsProvider);
  }
}

class _PublicFaqSwitch extends ConsumerWidget {
  const _PublicFaqSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(adminPlatformSettingsProvider);
    return settings.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (bundle) => AdminCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show FAQs on the public website'),
          subtitle: const Text(
            'Off hides the FAQ section on every public page. Individual questions can still be drafted or published.',
          ),
          value: bundle.enableFaq,
          onChanged: (value) async {
            final features = Map<String, dynamic>.from(bundle.websiteFeatures);
            features['enable_faq'] = value;
            await ref.read(platformSettingsServiceProvider).saveBundle(
                  bundle.copyWith(websiteFeatures: features),
                );
            ref.read(platformSettingsTickProvider.notifier).state++;
          },
        ),
      ),
    );
  }
}

class _FaqEditDialog extends ConsumerStatefulWidget {
  const _FaqEditDialog({this.faq});

  final CmsFaq? faq;

  @override
  ConsumerState<_FaqEditDialog> createState() => _FaqEditDialogState();
}

class _FaqEditDialogState extends ConsumerState<_FaqEditDialog> {
  late TextEditingController _question;
  late TextEditingController _answer;
  late TextEditingController _category;
  late bool _published;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _question = TextEditingController(text: widget.faq?.question ?? '');
    _answer = TextEditingController(text: widget.faq?.answer ?? '');
    _category = TextEditingController(text: widget.faq?.category ?? '');
    _published = widget.faq == null || widget.faq!.status == 'active';
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_question.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      setState(() => _error = 'Question and answer are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).upsertFaq(
            id: widget.faq?.id,
            question: _question.text.trim(),
            answer: _answer.text.trim(),
            category: _category.text.trim().isEmpty ? null : _category.text.trim(),
            sortOrder: widget.faq?.sortOrder ?? 0,
            status: _published ? 'active' : 'draft',
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogBorder),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.faq == null ? 'Add FAQ' : 'Edit FAQ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _question,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answer,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Answer'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category (optional)'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  subtitle: const Text('Draft questions stay off the public site.'),
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
