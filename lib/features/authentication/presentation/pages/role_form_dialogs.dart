import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/platform_user_models.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/rbac_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RoleFormResult {
  const RoleFormResult({
    required this.name,
    required this.slug,
    this.description,
    this.cloneFromRoleId,
    this.parentRoleId,
    this.clearParent = false,
  });

  final String name;
  final String slug;
  final String? description;
  final String? cloneFromRoleId;
  final String? parentRoleId;
  final bool clearParent;
}

Future<RoleFormResult?> showRoleFormDialog({
  required BuildContext context,
  required List<RoleDefinition> roles,
  RoleDefinition? role,
  bool isBusy = false,
}) {
  return showDialog<RoleFormResult>(
    context: context,
    builder: (_) => _RoleFormDialog(
      roles: roles,
      role: role,
      isBusy: isBusy,
    ),
  );
}

Future<String?> showAssignRoleUserDialog({
  required BuildContext context,
  required RoleDefinition role,
  required List<PlatformUser> users,
  bool isBusy = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AssignRoleUserDialog(
      role: role,
      users: users,
      isBusy: isBusy,
    ),
  );
}

String slugifyRoleName(String input) => input
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

class _RoleFormDialog extends HookWidget {
  const _RoleFormDialog({
    required this.roles,
    this.role,
    this.isBusy = false,
  });

  final List<RoleDefinition> roles;
  final RoleDefinition? role;
  final bool isBusy;

  bool get isEdit => role != null;

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: role?.name ?? '');
    final slug = useTextEditingController(text: role?.slug ?? '');
    final desc = useTextEditingController(text: role?.description ?? '');
    final cloneFrom = useState<String?>(null);
    final parentRole = useState<String?>(role?.parentRoleId);
    final error = useState<String?>(null);
    final slugTouched = useState(isEdit);

    final parentOptions = roles.where((r) {
      if (r.id == role?.id) return false;
      return r.lifecycle == RoleLifecycle.active;
    }).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: Text(
        isEdit ? 'Edit role' : 'Create custom role',
        style: const TextStyle(color: Colors.white),
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
              decoration: const InputDecoration(labelText: 'Role name *'),
              enabled: !isBusy && !(role?.isSystem ?? false),
              onChanged: (v) {
                if (!slugTouched.value && !isEdit) {
                  slug.text = slugifyRoleName(v);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: slug,
              decoration: InputDecoration(
                labelText: 'Slug *',
                helperText: isEdit ? 'Slug cannot change after create' : null,
              ),
              enabled: !isBusy && !isEdit,
              onChanged: (_) => slugTouched.value = true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
              enabled: !isBusy && !(role?.isSystem ?? false),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: parentRole.value,
              decoration: const InputDecoration(
                labelText: 'Inherit from (optional)',
                helperText: 'Child roles receive parent grants via RLS',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final r in parentOptions)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: isBusy || (role?.isSystem ?? false)
                  ? null
                  : (v) => parentRole.value = v,
            ),
            if (!isEdit) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: cloneFrom.value,
                decoration: const InputDecoration(
                  labelText: 'Clone permissions from',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final r in roles)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: isBusy ? null : (v) => cloneFrom.value = v,
              ),
            ],
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
          label: isEdit ? 'Save' : 'Create role',
          isLoading: isBusy,
          icon: isEdit ? LucideIcons.save : LucideIcons.shield,
          onPressed: isBusy
              ? null
              : () {
                  final n = name.text.trim();
                  final s = slug.text.trim().toLowerCase();
                  if (n.isEmpty || s.isEmpty) {
                    error.value = 'Name and slug are required.';
                    return;
                  }
                  Navigator.of(context).pop(
                    RoleFormResult(
                      name: n,
                      slug: s,
                      description: desc.text.trim().isEmpty
                          ? null
                          : desc.text.trim(),
                      cloneFromRoleId: cloneFrom.value,
                      parentRoleId: parentRole.value,
                      clearParent:
                          isEdit && role?.parentRoleId != null && parentRole.value == null,
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _AssignRoleUserDialog extends HookWidget {
  const _AssignRoleUserDialog({
    required this.role,
    required this.users,
    this.isBusy = false,
  });

  final RoleDefinition role;
  final List<PlatformUser> users;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final query = useTextEditingController();
    final selected = useState<String?>(null);
    final filter = useState('');
    final error = useState<String?>(null);

    final candidates = users.where((u) {
      if (u.hasRoleSlug(role.slug)) return false;
      final q = filter.value.trim().toLowerCase();
      if (q.isEmpty) return true;
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).take(80).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF141820),
      title: Text(
        'Assign ${role.name}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 440,
        height: 360,
        child: Column(
          children: [
            if (error.value != null) ...[
              Text(error.value!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: query,
              decoration: const InputDecoration(
                hintText: 'Search users…',
                prefixIcon: Icon(LucideIcons.search),
              ),
              onChanged: (v) => filter.value = v,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: candidates.isEmpty
                  ? const Center(
                      child: Text(
                        'No eligible users found.',
                        style: TextStyle(color: Color(0xFF8B929E)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final u = candidates[index];
                        return RadioListTile<String>(
                          value: u.id,
                          // ignore: deprecated_member_use
                          groupValue: selected.value,
                          // ignore: deprecated_member_use
                          onChanged: isBusy
                              ? null
                              : (v) => selected.value = v,
                          title: Text(
                            u.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            u.email,
                            style: const TextStyle(color: Color(0xFF8B929E)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Assign role',
          isLoading: isBusy,
          icon: LucideIcons.userPlus,
          onPressed: isBusy
              ? null
              : () {
                  final id = selected.value;
                  if (id == null) {
                    error.value = 'Select a user.';
                    return;
                  }
                  Navigator.of(context).pop(id);
                },
        ),
      ],
    );
  }
}
