import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/pages/role_form_dialogs.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PermissionFormResult {
  const PermissionFormResult({
    required this.name,
    required this.slug,
    required this.module,
    this.description,
  });

  final String name;
  final String slug;
  final String module;
  final String? description;
}

Future<PermissionFormResult?> showPermissionFormDialog({
  required BuildContext context,
  bool isBusy = false,
}) {
  return showDialog<PermissionFormResult>(
    context: context,
    builder: (_) => _PermissionFormDialog(isBusy: isBusy),
  );
}

class _PermissionFormDialog extends HookWidget {
  const _PermissionFormDialog({this.isBusy = false});

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController();
    final slug = useTextEditingController();
    final module = useTextEditingController(text: 'custom');
    final desc = useTextEditingController();
    final error = useState<String?>(null);
    final slugTouched = useState(false);

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: const Text(
        'Create custom permission',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            if (error.value != null) ...[
              Text(error.value!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name *'),
              enabled: !isBusy,
              onChanged: (v) {
                if (!slugTouched.value) {
                  slug.text = slugifyRoleName(v);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: slug,
              decoration: const InputDecoration(
                labelText: 'Slug *',
                helperText: 'Stored in DB / used by RLS (snake_case)',
              ),
              enabled: !isBusy,
              onChanged: (_) => slugTouched.value = true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: module,
              decoration: const InputDecoration(labelText: 'Module *'),
              enabled: !isBusy,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              enabled: !isBusy,
            ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Create permission',
          isLoading: isBusy,
          icon: LucideIcons.key,
          onPressed: isBusy
              ? null
              : () {
                  final n = name.text.trim();
                  final s = slug.text.trim().toLowerCase();
                  final m = module.text.trim();
                  if (n.isEmpty || s.isEmpty || m.isEmpty) {
                    error.value = 'Name, slug, and module are required.';
                    return;
                  }
                  Navigator.of(context).pop(
                    PermissionFormResult(
                      name: n,
                      slug: s,
                      module: m,
                      description:
                          desc.text.trim().isEmpty ? null : desc.text.trim(),
                    ),
                  );
                },
        ),
      ],
    );
  }
}
