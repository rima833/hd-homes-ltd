import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

const _kHomepageKey = 'homepage';

/// Admin → Website → Hero Manager
///
/// Upload image/video to Supabase Storage, preview the full-bleed hero,
/// save as draft, then publish to the public homepage.
class CmsHeroPage extends ConsumerWidget {
  const CmsHeroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroAsync = ref.watch(cmsHeroProvider(_kHomepageKey));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Hero manager',
            subtitle:
                'Upload a background image or video, preview it, then publish to the public homepage.',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: heroAsync.when(
              loading: () => const AdminLoadingView(),
              error: (err, _) => AdminErrorView(
                message: '$err',
                onRetry: () =>
                    ref.invalidate(cmsHeroProvider(_kHomepageKey)),
              ),
              data: (hero) => _HeroEditor(hero: hero),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroEditor extends ConsumerStatefulWidget {
  const _HeroEditor({required this.hero});

  final CmsHeroSection hero;

  @override
  ConsumerState<_HeroEditor> createState() => _HeroEditorState();
}

class _HeroEditorState extends ConsumerState<_HeroEditor> {
  late TextEditingController _headline;
  late TextEditingController _subheadline;
  late TextEditingController _ctaLabel;
  late TextEditingController _ctaUrl;
  late TextEditingController _secondaryCtaLabel;
  late TextEditingController _secondaryCtaUrl;
  late double _overlayOpacity;

  String? _imageUrl;
  String? _videoUrl;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _uploadingVideo = false;
  String? _error;
  String? _success;
  bool _showPreview = true;

  @override
  void initState() {
    super.initState();
    final hero = widget.hero;
    _headline = TextEditingController(text: hero.headline);
    _subheadline = TextEditingController(text: hero.subheadline ?? '');
    _ctaLabel = TextEditingController(text: hero.ctaLabel ?? '');
    _ctaUrl = TextEditingController(text: hero.ctaUrl ?? '');
    _secondaryCtaLabel =
        TextEditingController(text: hero.secondaryCtaLabel ?? '');
    _secondaryCtaUrl = TextEditingController(text: hero.secondaryCtaUrl ?? '');
    _overlayOpacity = hero.overlayOpacity;
    _imageUrl = hero.backgroundUrl;
    _videoUrl = hero.videoUrl;
  }

  @override
  void dispose() {
    _headline.dispose();
    _subheadline.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    _secondaryCtaLabel.dispose();
    _secondaryCtaUrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool video}) async {
    setState(() {
      _error = null;
      _success = null;
      if (video) {
        _uploadingVideo = true;
      } else {
        _uploadingImage = true;
      }
    });
    try {
      final result = await FilePicker.pickFiles(
        type: video ? FileType.video : FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Could not read file bytes. Try another file.');
      }

      final name = (file.name).toLowerCase();
      final contentType = video
          ? (name.endsWith('.webm')
              ? 'video/webm'
              : name.endsWith('.mov')
                  ? 'video/quicktime'
                  : 'video/mp4')
          : (name.endsWith('.png')
              ? 'image/png'
              : name.endsWith('.webp')
                  ? 'image/webp'
                  : name.endsWith('.gif')
                      ? 'image/gif'
                      : 'image/jpeg');

      final url = await ref.read(cmsServiceProvider).uploadHeroMedia(
            bytes: bytes,
            contentType: contentType,
            pageKey: _kHomepageKey,
            kind: video ? 'video' : 'image',
          );

      if (!mounted) return;
      setState(() {
        if (video) {
          _videoUrl = url;
        } else {
          _imageUrl = url;
        }
        _showPreview = true;
        _success = video
            ? 'Video uploaded. Preview below — save draft or publish.'
            : 'Image uploaded. Preview below — save draft or publish.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _uploadingVideo = false;
        });
      }
    }
  }

  Future<void> _persist({required bool publish}) async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      final content = Map<String, dynamic>.from(widget.hero.content)
        ..['secondary_cta_label'] = _secondaryCtaLabel.text.trim()
        ..['secondary_cta_url'] = _secondaryCtaUrl.text.trim()
        ..['video_url'] = (_videoUrl ?? '').trim()
        ..['overlay_opacity'] = _overlayOpacity;

      await ref.read(cmsServiceProvider).upsertHero(
            widget.hero.copyWith(
              headline: _headline.text.trim(),
              subheadline: _subheadline.text.trim(),
              ctaLabel: _ctaLabel.text.trim(),
              ctaUrl: _ctaUrl.text.trim(),
              backgroundUrl: (_imageUrl ?? '').trim().isEmpty
                  ? null
                  : _imageUrl!.trim(),
              content: content,
              status: publish ? 'active' : 'draft',
            ),
          );
      ref.invalidate(cmsHeroProvider(_kHomepageKey));
      ref.invalidate(publishedHomepageHeroProvider);
      if (mounted) {
        setState(() {
          _success = publish
              ? 'Published to the public homepage.'
              : 'Draft saved. Preview looks good — publish when ready.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final form = AdminCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Homepage hero',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  AdminStatusPill(
                label: widget.hero.isPublished ? 'Published' : 'Draft',
                color: widget.hero.isPublished
                    ? AppColors.success
                    : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _headline,
                decoration: const InputDecoration(labelText: 'Headline'),
            onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subheadline,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Subtitle'),
            onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
          Text('Primary CTA', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctaLabel,
                      decoration: const InputDecoration(labelText: 'Label'),
                  onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctaUrl,
                  decoration: const InputDecoration(labelText: 'Path / URL'),
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 16),
          Text('Secondary CTA', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _secondaryCtaLabel,
                      decoration: const InputDecoration(labelText: 'Label'),
                  onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _secondaryCtaUrl,
                  decoration: const InputDecoration(labelText: 'Path / URL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
          Text('Background media', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Upload from your device — files go to HD Homes storage and appear on the public site after publish.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.slate400,
                ),
              ),
              const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _uploadingImage ? null : () => _pickAndUpload(video: false),
                icon: _uploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.upload, size: 16),
                label: Text(_imageUrl == null ? 'Upload image' : 'Replace image'),
              ),
              OutlinedButton.icon(
                onPressed: _uploadingVideo ? null : () => _pickAndUpload(video: true),
                icon: _uploadingVideo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.video, size: 16),
                label: Text(_videoUrl == null ? 'Upload video' : 'Replace video'),
              ),
              if (_imageUrl != null)
                TextButton.icon(
                  onPressed: () => setState(() => _imageUrl = null),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text('Remove image'),
                ),
              if (_videoUrl != null)
                TextButton.icon(
                  onPressed: () => setState(() => _videoUrl = null),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text('Remove video'),
                ),
            ],
          ),
          if (_imageUrl != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              _imageUrl!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
          if (_videoUrl != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              _videoUrl!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
            ),
          ],
              const SizedBox(height: 20),
              Text(
            'Overlay darkness — ${(_overlayOpacity * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Slider(
                value: _overlayOpacity,
                onChanged: (v) => setState(() => _overlayOpacity = v),
                activeColor: AppColors.gold,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
            value: _showPreview,
                activeTrackColor: AppColors.gold,
            title: const Text('Show live preview'),
            subtitle: const Text('Preview updates as you edit — before publishing'),
            onChanged: (v) => setState(() => _showPreview = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              if (_success != null) ...[
                const SizedBox(height: 8),
                Text(_success!, style: const TextStyle(color: AppColors.success)),
              ],
              const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _persist(publish: false),
                icon: const Icon(LucideIcons.fileEdit, size: 16),
                label: const Text('Save draft'),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _persist(publish: true),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                    : const Icon(LucideIcons.globe, size: 16),
                label: const Text('Publish to public site'),
              ),
            ],
          ),
        ],
      ),
    );

    final preview = !_showPreview
        ? const SizedBox.shrink()
        : AdminCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.eye, size: 16, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(
                        'Preview (not live until you publish)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: wide ? 16 / 9 : 4 / 5,
                  child: _HeroPreviewPane(
                    headline: _headline.text.trim().isEmpty
                        ? 'Your headline'
                        : _headline.text.trim(),
                    subheadline: _subheadline.text.trim().isEmpty
                        ? 'Your supporting line'
                        : _subheadline.text.trim(),
                    ctaLabel: _ctaLabel.text.trim().isEmpty
                        ? 'Primary CTA'
                        : _ctaLabel.text.trim(),
                    secondaryCtaLabel: _secondaryCtaLabel.text.trim(),
                    imageUrl: _imageUrl,
                    videoUrl: _videoUrl,
                    overlayOpacity: _overlayOpacity,
                  ),
                ),
              ],
            ),
          );

    if (!wide) {
      return ListView(
        children: [
          form,
          const SizedBox(height: 16),
          preview,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: SingleChildScrollView(child: form)),
        const SizedBox(width: 16),
        Expanded(flex: 6, child: SingleChildScrollView(child: preview)),
      ],
    );
  }
}

class _HeroPreviewPane extends StatefulWidget {
  const _HeroPreviewPane({
    required this.headline,
    required this.subheadline,
    required this.ctaLabel,
    required this.secondaryCtaLabel,
    required this.overlayOpacity,
    this.imageUrl,
    this.videoUrl,
  });

  final String headline;
  final String subheadline;
  final String ctaLabel;
  final String secondaryCtaLabel;
  final double overlayOpacity;
  final String? imageUrl;
  final String? videoUrl;

  @override
  State<_HeroPreviewPane> createState() => _HeroPreviewPaneState();
}

class _HeroPreviewPaneState extends State<_HeroPreviewPane> {
  VideoPlayerController? _controller;
  String? _loadedVideoUrl;

  @override
  void initState() {
    super.initState();
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant _HeroPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _syncVideo();
    }
  }

  Future<void> _syncVideo() async {
    final url = widget.videoUrl?.trim();
    if (url == null || url.isEmpty) {
      await _controller?.dispose();
      _controller = null;
      _loadedVideoUrl = null;
      if (mounted) setState(() {});
      return;
    }
    if (url == _loadedVideoUrl && _controller != null) return;

    await _controller?.dispose();
    _controller = null;
    _loadedVideoUrl = url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _controller = null);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _controller != null && _controller!.value.isInitialized;
    final hasImage = (widget.imageUrl ?? '').isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.deepBlack),
          if (hasVideo)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
          else if (hasImage)
            MediaDeliveryImage(
              url: widget.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: const ColoredBox(
                color: AppColors.charcoal,
                child: Center(
                  child: Icon(LucideIcons.imageOff, color: AppColors.slate400),
                ),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1510),
                    AppColors.charcoal,
                    AppColors.deepBlack,
                  ],
                ),
              ),
            ),
          Container(
            color: AppColors.deepBlack.withValues(alpha: widget.overlayOpacity),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.headline,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.subheadline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: Text(widget.ctaLabel),
                    ),
                    if (widget.secondaryCtaLabel.isNotEmpty)
                      OutlinedButton(
                        onPressed: () {},
                        child: Text(widget.secondaryCtaLabel),
                      ),
                  ],
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}
