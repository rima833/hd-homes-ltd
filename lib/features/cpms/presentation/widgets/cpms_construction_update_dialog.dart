import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/construction/presentation/providers/construction_platform_providers.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:hdhomesproject/features/cpms/presentation/widgets/cpms_command_center_shell.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Create + publish a unified construction progress update (all portals).
Future<void> showCpmsConstructionUpdateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required CpmsProject project,
}) async {
  final controller = ref.read(cpmsControllerProvider.notifier);
  final snap = ref.read(cpmsSnapshotProvider).valueOrNull;
  if (snap != null && !snap.fromRemote) {
    controller.setMessage(
      'Connect Supabase to publish construction updates.',
    );
    return;
  }

  final titleCtrl = TextEditingController(text: 'Site progress update');
  final shortCtrl = TextEditingController(
    text: '${project.name} — ${project.progressPct.toStringAsFixed(0)}% complete',
  );
  final descCtrl = TextEditingController();
  final progressCtrl =
      TextEditingController(text: project.progressPct.toStringAsFixed(0));
  var publishPublic = true;
  var publishClients = true;
  var publishInvestors = true;
  final pendingFiles = <_PendingMedia>[];
  var uploading = false;
  var publishing = false;
  var uploadIndex = 0;
  var uploadTotal = 0;

  if (!context.mounted) {
    titleCtrl.dispose();
    shortCtrl.dispose();
    descCtrl.dispose();
    progressCtrl.dispose();
    return;
  }

  Future<void> pickImages(VoidCallback refresh) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      pendingFiles.add(
        _PendingMedia(
          bytes: bytes,
          contentType: _imageContentType(file),
          fileName: file.name,
        ),
      );
    }
    refresh();
  }

  Future<void> pickVideos(VoidCallback refresh) async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      pendingFiles.add(
        _PendingMedia(
          bytes: bytes,
          contentType: _videoContentType(file),
          fileName: file.name,
        ),
      );
    }
    refresh();
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        List<String> visibility() => [
              if (publishPublic) 'public',
              if (publishClients) 'clients',
              if (publishInvestors) 'investors',
              if (!publishPublic && !publishClients && !publishInvestors)
                'internal',
            ];

        return AlertDialog(
          backgroundColor: CpmsDeskColors.elevated,
          title: const Text('New construction update'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      color: CpmsDeskColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CpmsDeskColors.border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publish flow (realtime)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '1. Write title + progress %\n'
                          '2. Add site photos / videos\n'
                          '3. Choose Public / Client / Investor visibility\n'
                          '4. Publish — website, client, and investor update live',
                          style: TextStyle(
                            color: CpmsDeskColors.muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: shortCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Short description (public summary)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Full description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: progressCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Progress %',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Visibility',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  CheckboxListTile(
                    value: publishPublic,
                    onChanged: (v) =>
                        setLocal(() => publishPublic = v ?? false),
                    title: const Text('Public website'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: publishClients,
                    onChanged: (v) =>
                        setLocal(() => publishClients = v ?? false),
                    title: const Text('Client portal'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: publishInvestors,
                    onChanged: (v) =>
                        setLocal(() => publishInvestors = v ?? false),
                    title: const Text('Investor portal'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Photos & videos',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: uploading
                            ? null
                            : () => pickImages(() => setLocal(() {})),
                        icon: const Icon(LucideIcons.image, size: 16),
                        label: const Text('Photos'),
                      ),
                      TextButton.icon(
                        onPressed: uploading
                            ? null
                            : () => pickVideos(() => setLocal(() {})),
                        icon: const Icon(LucideIcons.video, size: 16),
                        label: const Text('Videos'),
                      ),
                    ],
                  ),
                  if (pendingFiles.isEmpty)
                    const Text(
                      'Add site photos or progress videos before publishing.',
                      style: TextStyle(color: CpmsDeskColors.muted, fontSize: 12),
                    ),
                  if (pendingFiles.isNotEmpty)
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pendingFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: CpmsDeskColors.gold),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    pendingFiles[i].isVideo
                                        ? LucideIcons.video
                                        : LucideIcons.image,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pendingFiles[i].fileName ?? 'File ${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () {
                                  pendingFiles.removeAt(i);
                                  setLocal(() {});
                                },
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (uploading || publishing) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      color: CpmsDeskColors.gold,
                      backgroundColor: Colors.white12,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      publishing
                          ? 'Publishing update…'
                          : 'Uploading media ${uploadIndex + 1} of $uploadTotal…',
                      style: const TextStyle(
                        color: CpmsDeskColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: publishing ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: publishing
                  ? null
                  : () async {
                      setLocal(() => publishing = true);
                      try {
                        if (pendingFiles.isEmpty) {
                          setLocal(() => publishing = false);
                          controller.setMessage(
                            'Add at least one site photo or video before publishing.',
                          );
                          return;
                        }
                        final service =
                            ref.read(constructionPlatformServiceProvider);
                        final pct =
                            double.tryParse(progressCtrl.text.trim()) ??
                                project.progressPct;
                        final update = await service.createUpdate(
                          projectId: project.id,
                          title: titleCtrl.text.trim(),
                          shortDescription: shortCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          progressPct: pct,
                          updateDate: DateTime.now(),
                          visibility: visibility(),
                        );

                        setLocal(() {
                          publishing = false;
                          uploading = true;
                          uploadTotal = pendingFiles.length;
                          uploadIndex = 0;
                        });
                        String? firstImageUrl;
                        for (var i = 0; i < pendingFiles.length; i++) {
                          final f = pendingFiles[i];
                          setLocal(() => uploadIndex = i);
                          final url = await service.uploadMedia(
                            bytes: f.bytes,
                            contentType: f.contentType,
                            projectId: project.id,
                            updateId: update.id,
                            displayOrder: i,
                            fileName: f.fileName,
                          );
                          if (firstImageUrl == null &&
                              f.contentType.startsWith('image/')) {
                            firstImageUrl = url;
                          }
                        }
                        setLocal(() {
                          uploading = false;
                          publishing = true;
                        });
                        await service.publishUpdate(update.id);

                        if (publishPublic) {
                          await service.setProjectPublished(
                            projectId: project.id,
                            isPublishedPublic: true,
                            coverImageUrl: firstImageUrl,
                          );
                        }

                        ref.invalidate(publicConstructionProjectsProvider);
                        ref.invalidate(publicConstructionProjectBySlugProvider);
                        ref.invalidate(adminConstructionUpdatesProvider);
                        ref.invalidate(cpmsSnapshotProvider);

                        controller.setMessage(
                          'Published live — website, client, and investor feeds updated.',
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setLocal(() {
                          publishing = false;
                          uploading = false;
                        });
                        controller.setMessage('Publish failed: $e');
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: CpmsDeskColors.gold,
                foregroundColor: const Color(0xFF1A1205),
              ),
              child: const Text('Publish update'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed == true && context.mounted) {
    controller.setMessage(
      'Published construction update for ${project.name} — '
      '${DateFormat.jm().format(DateTime.now())}',
    );
    await controller.refresh();
  }

  titleCtrl.dispose();
  shortCtrl.dispose();
  descCtrl.dispose();
  progressCtrl.dispose();
}

class _PendingMedia {
  _PendingMedia({
    required this.bytes,
    required this.contentType,
    this.fileName,
  });

  final List<int> bytes;
  final String contentType;
  final String? fileName;

  bool get isVideo => contentType.startsWith('video/');
}

String _imageContentType(PlatformFile file) {
  final ext = (file.extension ?? '').toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}

String _videoContentType(PlatformFile file) {
  final ext = (file.extension ?? '').toLowerCase();
  return switch (ext) {
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    _ => 'video/mp4',
  };
}
