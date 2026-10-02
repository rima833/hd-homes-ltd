import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

export 'delivery_image.dart';

/// Shared upload UX — progress, errors, retry. Does not call Cloudinary directly.
class MediaUploadPanel extends StatefulWidget {
  const MediaUploadPanel({
    super.key,
    required this.onUpload,
    this.allowedExtensions,
    this.allowVideo = true,
    this.label = 'Upload media',
    this.hint,
  });

  final Future<void> Function(
    List<int> bytes,
    String contentType,
    String fileName,
    void Function(double progress) onProgress,
  ) onUpload;

  final List<String>? allowedExtensions;
  final bool allowVideo;
  final String label;
  final String? hint;

  @override
  State<MediaUploadPanel> createState() => _MediaUploadPanelState();
}

class _MediaUploadPanelState extends State<MediaUploadPanel> {
  double _progress = 0;
  bool _uploading = false;
  String? _error;
  String? _previewUrl;
  String? _fileName;
  bool _success = false;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _success = false;
      _progress = 0;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: widget.allowVideo ? FileType.media : FileType.image,
        withData: true,
        allowMultiple: false,
        allowedExtensions: widget.allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read file bytes.');
      }

      final name = file.name.toLowerCase();
      final contentType = _mimeFromName(name);
      setState(() {
        _uploading = true;
        _fileName = file.name;
        _previewUrl = contentType.startsWith('image/')
            ? null // bytes preview handled below
            : null;
      });

      await widget.onUpload(bytes, contentType, file.name, (p) {
        if (mounted) setState(() => _progress = p);
      });

      if (!mounted) return;
      setState(() {
        _uploading = false;
        _success = true;
        _progress = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = userFacingError(e);
      });
    }
  }

  String _mimeFromName(String name) {
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.mp4')) return 'video/mp4';
    if (name.endsWith('.webm')) return 'video/webm';
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _uploading ? null : _pick,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _success
                    ? AppColors.success
                    : AppColors.gold.withValues(alpha: 0.35),
                width: 1.5,
              ),
              color: AppColors.darkSurface.withValues(alpha: 0.5),
            ),
            child: Column(
              children: [
                Icon(
                  _success ? LucideIcons.checkCircle2 : LucideIcons.uploadCloud,
                  color: _success ? AppColors.success : AppColors.gold,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  _uploading
                      ? 'Uploading… ${(_progress * 100).round()}%'
                      : _success
                          ? 'Upload complete'
                          : widget.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (widget.hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.hint!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_fileName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fileName!,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_uploading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            color: AppColors.gold,
            backgroundColor: AppColors.slate700,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          TextButton.icon(
            onPressed: _pick,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }
}

