import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/live_chat/domain/entities/live_chat_models.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const _bg = Color(0xFF0A0A0A);
const _panelSoft = Color(0xFF1A1A1A);
const _muted = Color(0xFF9A9A9A);

const liveChatEmojis = <String>[
  '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎',
  '🤔', '😅', '😢', '😭', '😡', '👍', '👎', '👏',
  '🙏', '🔥', '✨', '🎉', '🏠', '🏡', '💰', '✅',
  '❤️', '💙', '🤝', '👋', '📞', '📍', '⭐', '🏆',
];

String? liveChatGuessMime(String fileName) {
  final n = fileName.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.doc')) return 'application/msword';
  if (n.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (n.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (n.endsWith('.txt')) return 'text/plain';
  if (n.endsWith('.mp4')) return 'video/mp4';
  if (n.endsWith('.webm')) return 'video/webm';
  return null;
}

/// Shared composer: +, emoji, attachments strip, send.
class LiveChatComposer extends ConsumerStatefulWidget {
  const LiveChatComposer({
    super.key,
    required this.controller,
    this.compact = false,
    this.showSendLabel = false,
  });

  final TextEditingController controller;
  final bool compact;
  final bool showSendLabel;

  @override
  ConsumerState<LiveChatComposer> createState() => _LiveChatComposerState();
}

class _LiveChatComposerState extends ConsumerState<LiveChatComposer> {
  bool _emojiOpen = false;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final files = <({String name, Uint8List bytes, String? mimeType})>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        files.add((
          name: f.name,
          bytes: bytes,
          mimeType: liveChatGuessMime(f.name) ??
              (f.extension == null
                  ? null
                  : liveChatGuessMime('x.${f.extension}')),
        ));
      }
      if (files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read that file. Try another format.'),
          ),
        );
        return;
      }
      await ref
          .read(liveChatVisitorControllerProvider.notifier)
          .pickAndQueueFiles(files: files);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'Upload failed. Please try again.'))),
      );
    }
  }

  Future<void> _send() async {
    final text = widget.controller.text;
    final state = ref.read(liveChatVisitorControllerProvider);
    if (text.trim().isEmpty && state.pendingAttachments.isEmpty) return;
    widget.controller.clear();
    setState(() => _emojiOpen = false);
    await ref.read(liveChatVisitorControllerProvider.notifier).send(text);
  }

  void _insertEmoji(String emoji) {
    final c = widget.controller;
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    ref.read(liveChatVisitorControllerProvider.notifier).onComposerChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveChatVisitorControllerProvider);
    final notifier = ref.read(liveChatVisitorControllerProvider.notifier);
    final busy = state.sending || state.uploading;
    final canSend = !busy &&
        (widget.controller.text.trim().isNotEmpty ||
            state.pendingAttachments.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.uploading)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Uploading…',
                  style: GoogleFonts.manrope(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        if (state.pendingAttachments.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.pendingAttachments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final a = state.pendingAttachments[i];
                return _PendingChip(
                  attachment: a,
                  onRemove: () => notifier.removePendingAttachment(a),
                );
              },
            ),
          ),
        if (state.pendingAttachments.isNotEmpty) const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach any file (images, PDF, docs…)',
              onPressed: busy ? null : _pickFiles,
              style: IconButton.styleFrom(
                backgroundColor: _panelSoft,
                foregroundColor: AppColors.gold,
                disabledForegroundColor: _muted,
              ),
              icon: const Icon(LucideIcons.plus, size: 20),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Insert emoji',
              onPressed: () => setState(() => _emojiOpen = !_emojiOpen),
              style: IconButton.styleFrom(
                backgroundColor: _emojiOpen ? AppColors.gold : _panelSoft,
                foregroundColor: _emojiOpen ? _bg : AppColors.gold,
              ),
              icon: const Icon(LucideIcons.smile, size: 20),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: widget.controller,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 13 : 14,
                ),
                minLines: 1,
                maxLines: widget.compact ? 2 : 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                onChanged: (v) {
                  notifier.onComposerChanged(v);
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                    color: _muted,
                    fontSize: widget.compact ? 13 : 14,
                  ),
                  filled: true,
                  fillColor: _panelSoft,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.showSendLabel)
              FilledButton.icon(
                onPressed: canSend ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: _bg,
                  disabledBackgroundColor: _panelSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.send, size: 16),
                label: const Text('Send'),
              )
            else
              FilledButton(
                onPressed: canSend ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: _bg,
                  disabledBackgroundColor: _panelSoft,
                  minimumSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(LucideIcons.send, size: 16),
              ),
          ],
        ),
        if (_emojiOpen) ...[
          const SizedBox(height: 8),
          Container(
            height: 132,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _panelSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: GridView.builder(
              itemCount: liveChatEmojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, i) {
                final e = liveChatEmojis[i];
                return InkWell(
                  onTap: () => _insertEmoji(e),
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated “typing…” bubble shown in the message list while the peer types.
class LiveChatTypingIndicator extends StatefulWidget {
  const LiveChatTypingIndicator({
    super.key,
    this.label = 'Concierge is typing…',
    this.compact = false,
    this.light = false,
  });

  final String label;
  final bool compact;
  final bool light;

  @override
  State<LiveChatTypingIndicator> createState() =>
      _LiveChatTypingIndicatorState();
}

class _LiveChatTypingIndicatorState extends State<LiveChatTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.light ? AppColors.charcoal : AppColors.gold;
    final fg = widget.light ? AppColors.textSecondaryLight : _muted;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: widget.compact ? 8 : 10),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 12 : 14,
          vertical: widget.compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: widget.light
              ? AppColors.lightBackground
              : const Color(0xFF2A2A2A),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          ),
          border: widget.light
              ? null
              : Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.moreHorizontal, size: 14, color: fg),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Row(
                  children: List.generate(3, (i) {
                    final t = (_ctrl.value + i * 0.2) % 1.0;
                    final opacity = 0.35 + (0.65 * (1 - (t - 0.5).abs() * 2));
                    return Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Opacity(
                        opacity: opacity.clamp(0.35, 1),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: GoogleFonts.manrope(color: fg, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.attachment, required this.onRemove});

  final LiveChatAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: _panelSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (attachment.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: MediaDeliveryImage(
                url: attachment.url,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: const Icon(
                  LucideIcons.image,
                  size: 18,
                  color: AppColors.gold,
                ),
              ),
            )
          else
            const Icon(LucideIcons.file, size: 18, color: AppColors.gold),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              attachment.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 11),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(LucideIcons.x, color: _muted),
          ),
        ],
      ),
    );
  }
}

/// Message bubble with optional attachment previews / links.
class LiveChatMessageBubble extends StatelessWidget {
  const LiveChatMessageBubble({
    super.key,
    required this.message,
    this.compact = false,
  });

  final LiveChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mine = message.isVisitor;
    final created = message.createdAt ?? DateTime.now();
    final time = TimeOfDay.fromDateTime(created).format(context);
    final maxW = compact
        ? 260.0
        : MediaQuery.sizeOf(context).width * 0.55;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: IntrinsicWidth(
        child: Container(
          margin: EdgeInsets.only(bottom: compact ? 6 : 8),
          constraints: BoxConstraints(maxWidth: maxW),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFF2A2A2A) : AppColors.gold,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(compact ? 12 : 14),
              topRight: Radius.circular(compact ? 12 : 14),
              bottomLeft: Radius.circular(mine ? (compact ? 12 : 14) : 4),
              bottomRight: Radius.circular(mine ? 4 : (compact ? 12 : 14)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine && (message.senderName?.trim().isNotEmpty == true)) ...[
                Text(
                  message.senderName!.trim(),
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF0B0E14),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (message.attachments.isNotEmpty) ...[
                ...message.attachments.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: LiveChatAttachmentTile(attachment: a, onGold: !mine),
                  ),
                ),
              ],
              if (message.body.trim().isNotEmpty &&
                  !(message.body == 'Shared a file' &&
                      message.attachments.isNotEmpty))
                Text(
                  message.body,
                  style: GoogleFonts.manrope(
                    color: mine ? Colors.white : const Color(0xFF0B0E14),
                    fontSize: compact ? 12.5 : 13,
                    height: 1.28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                time,
                style: GoogleFonts.manrope(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.55)
                      : const Color(0xFF0B0E14).withValues(alpha: 0.65),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveChatAttachmentTile extends StatelessWidget {
  const LiveChatAttachmentTile({
    super.key,
    required this.attachment,
    required this.onGold,
  });

  final LiveChatAttachment attachment;
  final bool onGold;

  @override
  Widget build(BuildContext context) {
    final fg = onGold ? _bg : Colors.white;
    if (attachment.isImage && attachment.url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => launchUrl(Uri.parse(attachment.url)),
          child: MediaDeliveryImage(
            url: attachment.url,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: _fileRow(fg),
          ),
        ),
      );
    }
    return _fileRow(fg);
  }

  Widget _fileRow(Color fg) {
    return InkWell(
      onTap: attachment.url.isEmpty
          ? null
          : () => launchUrl(
                Uri.parse(attachment.url),
                mode: LaunchMode.externalApplication,
              ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.paperclip, size: 14, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.name,
              style: GoogleFonts.manrope(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
