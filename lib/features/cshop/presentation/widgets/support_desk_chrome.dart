import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared dark/gold tokens + chrome widgets for Support desks (mockup-aligned).
abstract final class SupportDeskChrome {
  static const bg = Color(0xFF020D1B);
  static const surface = Color(0xFF061629);
  static const panel = Color(0xFF061629);
  static const elevated = Color(0xFF081C31);
  static const card = Color(0xFF061629);
  static const border = Color(0xFF17304B);
  static const muted = Color(0xFF8FA3B9);
  static const text = Color(0xFFF4F7FB);
  static const gold = Color(0xFFFFBF32);
  static const goldDeep = Color(0xFFD99719);
  static const clientBubble = Color(0xFF123054);
  static const staffBubble = Color(0xFF8A641D);
  static const online = Color(0xFF23C997);
  static const inProgress = Color(0xFF6E8CFF);
  static const escalated = Color(0xFFFF4E69);

  static Color statusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'resolved' || s == 'closed' || s == 'ended') return online;
    if (s == 'escalated' || s == 'urgent') return escalated;
    if (s == 'in_progress' || s == 'in progress' || s == 'active') {
      return inProgress;
    }
    if (s == 'waiting' || s == 'queued' || s == 'open' || s == 'new' ||
        s == 'medium' || s == 'normal') {
      return gold;
    }
    return muted;
  }

  static String prettyStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  static String initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static Color avatarColor(String seed) {
    const palette = [
      Color(0xFFD4A34E),
      Color(0xFF3B82F6),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
      Color(0xFFA855F7),
      Color(0xFFEF4444),
      Color(0xFF14B8A6),
      Color(0xFFEC4899),
    ];
    if (seed.isEmpty) return palette.first;
    return palette[seed.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length];
  }

  static String timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    if (sameDay) return '$hh:$mm $ampm';
    return '${local.day}/${local.month} $hh:$mm $ampm';
  }

  static String dateTimeLabel(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = dt.toLocal();
    final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm, ${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

class SupportKpiCard extends StatelessWidget {
  const SupportKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.foot,
    this.icon = LucideIcons.activity,
    this.accent = SupportDeskChrome.gold,
    this.wide = false,
    this.compact = true,
  });

  final String label;
  final String value;
  final String? trend;
  final String? foot;
  final IconData icon;
  final Color accent;
  /// Kept for call-site compatibility; cards never stretch full-width.
  final bool wide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 68,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SupportDeskChrome.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupportDeskChrome.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SupportDeskChrome.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const Spacer(),
                      if (trend != null)
                        Text(
                          trend!,
                          style: TextStyle(
                            color: trend!.startsWith('-')
                                ? SupportDeskChrome.escalated
                                : accent,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    foot ?? 'vs last 7 days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SupportDeskChrome.muted,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportHeadsetTitle extends StatelessWidget {
  const SupportHeadsetTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 48 : 64,
          height: compact ? 48 : 64,
          decoration: BoxDecoration(
            color: SupportDeskChrome.gold.withValues(alpha: 0.17),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            LucideIcons.headphones,
            color: SupportDeskChrome.gold,
            size: compact ? 24 : 32,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 18 : 24,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SupportDeskChrome.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SupportStatusBadge extends StatelessWidget {
  const SupportStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = SupportDeskChrome.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        SupportDeskChrome.prettyStatus(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SupportAvatar extends StatelessWidget {
  const SupportAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.online,
  });

  final String? name;
  final double size;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final seed = name?.trim().isNotEmpty == true ? name!.trim() : '?';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SupportDeskChrome.avatarColor(seed).withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(
              color: SupportDeskChrome.avatarColor(seed).withValues(alpha: 0.55),
            ),
          ),
          child: Text(
            SupportDeskChrome.initials(seed),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.34,
            ),
          ),
        ),
        if (online != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: online!
                    ? SupportDeskChrome.online
                    : SupportDeskChrome.muted,
                shape: BoxShape.circle,
                border: Border.all(color: SupportDeskChrome.panel, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class SupportConversationTile extends StatelessWidget {
  const SupportConversationTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.preview,
    this.time,
    this.status,
    this.unread,
    this.online,
    this.tag,
    this.tagColor,
  });

  final String title;
  final String subtitle;
  final String? preview;
  final String? time;
  final String? status;
  final int? unread;
  final bool? online;
  final bool selected;
  final VoidCallback onTap;
  /// Small pill (e.g. Client / Investor).
  final String? tag;
  final Color? tagColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF10253B) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? SupportDeskChrome.gold.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.22),
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SupportAvatar(name: title, online: online),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    selected ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (time != null && time!.isNotEmpty)
                            Text(
                              time!,
                              style: const TextStyle(
                                color: SupportDeskChrome.muted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (tag != null && tag!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (tagColor ?? AppColors.gold)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (tagColor ?? AppColors.gold)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                tag!,
                                style: TextStyle(
                                  color: tagColor ?? AppColors.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (preview != null && preview!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SupportDeskChrome.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(width: 6),
                  SupportStatusBadge(status: status!),
                ],
                if (unread != null && unread! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SupportDeskChrome.gold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SupportGoldSendButton extends StatelessWidget {
  const SupportGoldSendButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.size = 44,
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? SupportDeskChrome.gold
                : SupportDeskChrome.elevated,
          ),
          child: Icon(
            LucideIcons.send,
            size: 16,
            color: enabled ? AppColors.charcoal : SupportDeskChrome.muted,
          ),
        ),
      ),
    );
  }
}

/// Exact mockup spacing for Support chatting surfaces.
abstract final class SupportChatMetrics {
  static const threadHeaderPadding = EdgeInsets.fromLTRB(10, 8, 10, 8);
  static const messageListPadding = EdgeInsets.fromLTRB(10, 8, 10, 10);
  static const composerPadding = EdgeInsets.fromLTRB(8, 6, 8, 8);
  static const bubblePadding = EdgeInsets.fromLTRB(9, 6, 9, 5);
  static const bubbleRadius = 12.0;
  static const composerRadius = 18.0;
  static const sendSize = 34.0;
  static const bubbleGap = 6.0;
  static const paneGap = 8.0;
}

class SupportPaneGutter extends StatelessWidget {
  const SupportPaneGutter({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: SupportChatMetrics.paneGap,
      child: ColoredBox(
        color: SupportDeskChrome.bg,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: SupportDeskChrome.border,
        ),
      ),
    );
  }
}

class SupportChatBubble extends StatelessWidget {
  const SupportChatBubble({
    super.key,
    required this.body,
    required this.mine,
    this.senderLabel,
    this.createdAt,
    this.isInternal = false,
    this.isSystem = false,
    this.isRead = false,
    this.showChecks = true,
    this.senderAbove = false,
    this.showSideAvatar = false,
    this.avatarName,
    this.footer,
  });

  final String body;
  final bool mine;
  final String? senderLabel;
  final DateTime? createdAt;
  final bool isInternal;
  final bool isSystem;
  final bool isRead;
  final bool showChecks;
  /// When true, sender sits above the bubble (Live Chat mockup).
  final bool senderAbove;
  final bool showSideAvatar;
  final String? avatarName;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: SupportDeskChrome.muted,
            fontSize: 12.5,
          ),
        ),
      );
    }

    final time = createdAt == null
        ? null
        : SupportDeskChrome.timeLabel(createdAt);
    final maxW = (MediaQuery.sizeOf(context).width * 0.42).clamp(160.0, 360.0);
    final label = senderLabel?.trim();
    final showLabel = label != null && label.isNotEmpty;
    final avatar = showSideAvatar
        ? SupportAvatar(
            name: avatarName ?? label ?? (mine ? 'A' : 'C'),
            size: 24,
          )
        : null;

    // Solid near-black on gold — charcoal reads muddy on #D4A34E.
    final onGold = mine && !isInternal;
    const goldInk = Color(0xFF0B0E14);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: IntrinsicWidth(
        child: Container(
          padding: SupportChatMetrics.bubblePadding,
          decoration: BoxDecoration(
            color: isInternal
                ? Colors.amber.withValues(alpha: 0.16)
                : (mine
                    ? SupportDeskChrome.staffBubble
                    : SupportDeskChrome.clientBubble),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(SupportChatMetrics.bubbleRadius),
              topRight: const Radius.circular(SupportChatMetrics.bubbleRadius),
              bottomLeft:
                  Radius.circular(mine ? SupportChatMetrics.bubbleRadius : 4),
              bottomRight:
                  Radius.circular(mine ? 4 : SupportChatMetrics.bubbleRadius),
            ),
            border: isInternal
                ? Border.all(color: Colors.amber.withValues(alpha: 0.35))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showLabel && !senderAbove) ...[
                Text(
                  isInternal ? '$label · internal' : label!,
                  style: TextStyle(
                    color: onGold
                        ? goldInk.withValues(alpha: 0.72)
                        : SupportDeskChrome.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                body,
                textAlign: mine ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  color: isInternal ? Colors.amber.shade100 : Colors.white,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 4),
                footer!,
              ],
              if (time != null) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: onGold
                            ? goldInk.withValues(alpha: 0.62)
                            : SupportDeskChrome.muted,
                        fontSize: 9.5,
                      ),
                    ),
                    if (mine && showChecks) ...[
                      const SizedBox(width: 3),
                      Icon(
                        isRead ? LucideIcons.checkCheck : LucideIcons.check,
                        size: 11,
                        color: goldInk.withValues(
                          alpha: isRead ? 0.9 : 0.55,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: SupportChatMetrics.bubbleGap),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        // No Flexible around IntrinsicWidth — Flexible forces a wide tight
        // width and makes short bubbles stretch past the text.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (avatar != null && !mine) ...[
              avatar,
              const SizedBox(width: 6),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showLabel && senderAbove)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, bottom: 3),
                    child: Text(
                      label!,
                      style: const TextStyle(
                        color: SupportDeskChrome.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
            if (avatar != null && mine) ...[
              const SizedBox(width: 6),
              avatar,
            ],
          ],
        ),
      ),
    );
  }
}

class SupportChatComposer extends StatelessWidget {
  const SupportChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onChanged,
    this.focusNode,
    this.sending = false,
    this.enabled = true,
    this.hintText = 'Type your message...',
    this.onAttach,
    this.onToggleEmoji,
    this.emojiOpen = false,
    this.emojiTray,
    this.leading,
    this.helperText = 'Press Enter to send • Shift + Enter for new line',
    this.emojiInside = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool sending;
  final bool enabled;
  final String hintText;
  final VoidCallback? onAttach;
  final VoidCallback? onToggleEmoji;
  final bool emojiOpen;
  final Widget? emojiTray;
  final Widget? leading;
  final String? helperText;
  /// Portal/Live: emoji inside the pill. Tickets mockup: both icons outside left.
  final bool emojiInside;

  @override
  Widget build(BuildContext context) {
    final emojiBtn = IconButton(
      tooltip: 'Emoji',
      onPressed: !enabled || sending ? null : onToggleEmoji,
      icon: Icon(
        LucideIcons.smile,
        size: 20,
        color: emojiOpen ? AppColors.gold : SupportDeskChrome.muted,
      ),
    );

    return Container(
      padding: SupportChatMetrics.composerPadding,
      decoration: const BoxDecoration(
        color: SupportDeskChrome.panel,
        border: Border(
          top: BorderSide(color: SupportDeskChrome.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach file',
                onPressed: !enabled || sending ? null : onAttach,
                icon: const Icon(
                  LucideIcons.paperclip,
                  size: 20,
                  color: SupportDeskChrome.muted,
                ),
              ),
              if (!emojiInside) emojiBtn,
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1218),
                    borderRadius: BorderRadius.circular(
                      SupportChatMetrics.composerRadius,
                    ),
                    border: Border.all(color: SupportDeskChrome.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          enabled: enabled && !sending,
                          minLines: 1,
                          maxLines: 4,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (enabled && !sending) onSend();
                          },
                          onChanged: onChanged,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(
                              color: SupportDeskChrome.muted,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.fromLTRB(
                              16,
                              14,
                              emojiInside ? 8 : 16,
                              14,
                            ),
                          ),
                        ),
                      ),
                      if (emojiInside) emojiBtn,
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (sending)
                const SizedBox(
                  width: SupportChatMetrics.sendSize,
                  height: SupportChatMetrics.sendSize,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                )
              else
                SupportGoldSendButton(
                  onPressed: enabled ? onSend : null,
                  enabled: enabled,
                  size: SupportChatMetrics.sendSize,
                ),
            ],
          ),
          if (emojiTray != null && emojiOpen) ...[
            const SizedBox(height: 8),
            emojiTray!,
          ],
          if (helperText != null && helperText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              helperText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SupportDeskChrome.muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SupportThreadHeader extends StatelessWidget {
  const SupportThreadHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.online,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: SupportChatMetrics.threadHeaderPadding,
      decoration: const BoxDecoration(
        color: SupportDeskChrome.panel,
        border: Border(
          bottom: BorderSide(color: SupportDeskChrome.border),
        ),
      ),
      child: Row(
        children: [
          SupportAvatar(name: title, online: online, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SupportDeskChrome.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SupportQuickActionButton extends StatelessWidget {
  const SupportQuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = primary ? SupportDeskChrome.gold : SupportDeskChrome.muted;
    return Material(
      color: primary
          ? SupportDeskChrome.gold.withValues(alpha: 0.12)
          : const Color(0xFF0A1E33),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: primary
                  ? SupportDeskChrome.gold.withValues(alpha: 0.7)
                  : SupportDeskChrome.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    color: primary ? Colors.white : SupportDeskChrome.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportDetailField extends StatelessWidget {
  const SupportDetailField({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: SupportDeskChrome.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class SupportRelatedLinkTile extends StatelessWidget {
  const SupportRelatedLinkTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: SupportDeskChrome.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: SupportDeskChrome.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: SupportDeskChrome.text,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 12,
              color: SupportDeskChrome.muted,
            ),
          ],
        ),
      ),
    );
  }
}
