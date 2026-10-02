import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

/// Admin → Website → Team: choose which staff (`employees`) show on the
/// public "About / Team" page, and edit their public bio & job title.
///
/// There is no dedicated public "team" table — website-facing attributes
/// (bio, job title, visibility, sort order) live in `employees.metadata`.
class CmsTeamPage extends ConsumerWidget {
  const CmsTeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(cmsTeamProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Team',
            subtitle: 'Choose which staff appear on the public About and Trust pages.',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: teamAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () => ref.invalidate(cmsTeamProvider),
              ),
              data: (team) {
                if (team.isEmpty) {
                  return const AdminEmptyState(
                    title: 'No staff records yet',
                    message: 'Add employees from the HR → Organization admin section first.',
                    icon: LucideIcons.users,
                  );
                }
                return ListView.separated(
                  itemCount: team.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final member = team[i];
                    return AdminCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.slate400.withValues(alpha: 0.2),
                            backgroundImage:
                                member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                            child: member.avatarUrl == null
                                ? Text(member.fullName.isNotEmpty ? member.fullName[0] : '?')
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.fullName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                if (member.jobTitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    member.jobTitle!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.slate500,
                                        ),
                                  ),
                                ],
                                if (member.bio != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    member.bio!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Switch(
                                value: member.showOnWebsite,
                                activeTrackColor: AppColors.gold,
                                onChanged: (v) async {
                                  await ref
                                      .read(cmsServiceProvider)
                                      .updateTeamDisplay(member.id, showOnWebsite: v);
                                  ref.invalidate(cmsTeamProvider);
                                  ref.invalidate(publishedTeamProvider);
                                },
                              ),
                              const Text('On website', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _openEditor(context, ref, member),
                            icon: const Icon(LucideIcons.pencil, size: 18),
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    CmsTeamMember member,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TeamEditDialog(member: member),
    );
    ref.invalidate(cmsTeamProvider);
    ref.invalidate(publishedTeamProvider);
  }
}

class _TeamEditDialog extends ConsumerStatefulWidget {
  const _TeamEditDialog({required this.member});

  final CmsTeamMember member;

  @override
  ConsumerState<_TeamEditDialog> createState() => _TeamEditDialogState();
}

class _TeamEditDialogState extends ConsumerState<_TeamEditDialog> {
  late TextEditingController _jobTitle;
  late TextEditingController _bio;
  String? _avatarUrl;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _jobTitle = TextEditingController(text: widget.member.jobTitle ?? '');
    _bio = TextEditingController(text: widget.member.bio ?? '');
    _avatarUrl = widget.member.avatarUrl;
  }

  @override
  void dispose() {
    _jobTitle.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    setState(() {
      _error = null;
      _uploadingPhoto = true;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read file bytes. Try another file.');
      }

      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : name.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';

      final url = await ref.read(cmsServiceProvider).uploadTeamPhoto(
            employeeId: widget.member.id,
            bytes: bytes,
            contentType: contentType,
          );

      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ref.invalidate(cmsTeamProvider);
      ref.invalidate(publishedTeamProvider);
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(cmsServiceProvider).updateTeamDisplay(
            widget.member.id,
            jobTitle: _jobTitle.text.trim(),
            bio: _bio.text.trim(),
          );
      ref.invalidate(cmsTeamProvider);
      ref.invalidate(publishedTeamProvider);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit ${widget.member.fullName}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.slate400.withValues(alpha: 0.2),
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? Text(widget.member.fullName.isNotEmpty
                            ? widget.member.fullName[0]
                            : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    icon: _uploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.upload, size: 16),
                    label: Text(_avatarUrl == null ? 'Upload photo' : 'Replace photo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jobTitle,
                decoration: const InputDecoration(labelText: 'Public job title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Public bio'),
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
    );
  }
}
