import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared spacing for portal Support page shells.
abstract final class PortalSupportSpacing {
  static const double afterSubtitle = 6;
  static const double afterHeader = 28;
  static const double afterSectionHeader = 12;
  static const double betweenSections = 32;
}

/// Soft panel used to frame Support sections without heavy “card” clutter.
class PortalSupportSurface extends StatelessWidget {
  const PortalSupportSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentEdge = false,
    this.height,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool accentEdge;
  final double? height;

  @override
  Widget build(BuildContext context) {
    Widget panel = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF171C26),
            AppColors.darkSurface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (accentEdge)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    gradient: AppColors.goldGradientVertical,
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
    if (height != null) {
      panel = SizedBox(height: height, child: panel);
    }
    return panel;
  }
}

/// Open / closed / all filter for ticket history.
enum PortalTicketHistoryFilter { all, open, closed }

bool portalTicketStatusIsClosed(String status) {
  final s = status.toLowerCase();
  return s == 'closed' || s == 'resolved';
}

class PortalSupportHistoryFilterBar extends StatelessWidget {
  const PortalSupportHistoryFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.allCount,
    required this.openCount,
    required this.closedCount,
  });

  final PortalTicketHistoryFilter filter;
  final ValueChanged<PortalTicketHistoryFilter> onChanged;
  final int allCount;
  final int openCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required PortalTicketHistoryFilter value,
      required String label,
      required int count,
    }) {
      final selected = filter == value;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.45)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.gold : AppColors.slate400,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? AppColors.white : AppColors.slate400,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          chip(
            value: PortalTicketHistoryFilter.all,
            label: 'All',
            count: allCount,
          ),
          chip(
            value: PortalTicketHistoryFilter.open,
            label: 'Open',
            count: openCount,
          ),
          chip(
            value: PortalTicketHistoryFilter.closed,
            label: 'Closed',
            count: closedCount,
          ),
        ],
      ),
    );
  }
}

class _PortalSupportSendIntent extends Intent {
  const _PortalSupportSendIntent();
}

/// Polished reply / message composer for Support (and portal Messages).
class PortalSupportReplyComposer extends StatefulWidget {
  const PortalSupportReplyComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onChanged,
    this.onAttach,
    this.attachmentLabel,
    this.onClearAttachment,
    this.sending = false,
    this.enabled = true,
    this.hintText = 'Write a reply…',
    this.showEmoji = true,
    this.helperText = 'Enter to send · Shift+Enter for a new line',
    this.light = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttach;
  final String? attachmentLabel;
  final VoidCallback? onClearAttachment;
  final bool sending;
  final bool enabled;
  final String hintText;
  final bool showEmoji;
  final String? helperText;
  final bool light;

  @override
  State<PortalSupportReplyComposer> createState() =>
      _PortalSupportReplyComposerState();
}

class _PortalSupportReplyComposerState
    extends State<PortalSupportReplyComposer> {
  bool _emojiOpen = false;
  bool _focused = false;

  static const _emojis = <String>[
    '😀',
    '😊',
    '👍',
    '🙏',
    '🏠',
    '✅',
    '🔥',
    '💬',
  ];

  bool get _canSend => widget.enabled && !widget.sending;

  void _insertEmoji(String emoji) {
    final t = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    final next = t.replaceRange(start, end, emoji);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.attachmentLabel != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.paperclip,
                  size: 14,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.attachmentLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slate400,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (widget.onClearAttachment != null)
                  IconButton(
                    onPressed: widget.onClearAttachment,
                    icon: const Icon(LucideIcons.x, size: 14),
                    color: AppColors.slate400,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
        Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter):
                _PortalSupportSendIntent(),
          },
          child: Actions(
            actions: {
              _PortalSupportSendIntent: CallbackAction<_PortalSupportSendIntent>(
                onInvoke: (_) {
                  if (_canSend) widget.onSend();
                  return null;
                },
              ),
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: widget.light ? const Color(0xFFF7F4EE) : const Color(0xFF0F1218),
                borderRadius: BorderRadius.circular(widget.light ? 28 : 16),
                border: Border.all(
                  color: _focused
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : widget.light
                          ? const Color(0xFFE7E1D6)
                          : Colors.white.withValues(alpha: 0.1),
                  width: _focused ? 1.4 : 1,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.onAttach != null)
                    IconButton(
                      onPressed: _canSend ? widget.onAttach : null,
                      tooltip: 'Attach file',
                      icon: const Icon(LucideIcons.paperclip, size: 18),
                      color: AppColors.gold,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.showEmoji && !widget.light)
                    IconButton(
                      onPressed: !widget.enabled || widget.sending
                          ? null
                          : () => setState(() => _emojiOpen = !_emojiOpen),
                      tooltip: 'Emoji',
                      icon: Icon(
                        LucideIcons.smile,
                        size: 18,
                        color: _emojiOpen ? AppColors.gold : AppColors.slate400,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  Expanded(
                    child: Focus(
                      onFocusChange: (v) => setState(() => _focused = v),
                      child: TextField(
                        controller: widget.controller,
                        enabled: widget.enabled && !widget.sending,
                        onChanged: widget.onChanged,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(
                          color: widget.light
                              ? const Color(0xFF1C1915)
                              : AppColors.white,
                          height: 1.35,
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: widget.light
                                ? const Color(0xFF8A8176)
                                : AppColors.slate400.withValues(alpha: 0.9),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                  if (widget.light && widget.showEmoji)
                    IconButton(
                      onPressed: !widget.enabled || widget.sending
                          ? null
                          : () => setState(() => _emojiOpen = !_emojiOpen),
                      tooltip: 'Emoji',
                      icon: Icon(
                        LucideIcons.smile,
                        size: 18,
                        color: _emojiOpen
                            ? AppColors.gold
                            : const Color(0xFF6E675F),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (widget.light && widget.onAttach != null)
                    IconButton(
                      onPressed: _canSend ? widget.onAttach : null,
                      tooltip: 'Add image',
                      icon: const Icon(LucideIcons.image, size: 18),
                      color: const Color(0xFF6E675F),
                      visualDensity: VisualDensity.compact,
                    ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canSend ? widget.onSend : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: _canSend ? AppColors.goldGradient : null,
                            color: _canSend
                                ? null
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              widget.light ? 20 : 12,
                            ),
                          ),
                          child: Center(
                            child: widget.sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0B0E14),
                                    ),
                                  )
                                : Icon(
                                    LucideIcons.send,
                                    size: 16,
                                    color: widget.enabled
                                        ? const Color(0xFF0B0E14)
                                        : AppColors.slate400,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_emojiOpen) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _emojis)
                InkWell(
                  onTap: () => _insertEmoji(e),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
        ],
        if (widget.helperText != null && widget.helperText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.slate400.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact page header for client / investor Support.
class PortalSupportPageHeader extends StatelessWidget {
  const PortalSupportPageHeader({
    super.key,
    required this.subtitle,
    required this.onOpenMessages,
    this.trailing,
  });

  final String subtitle;
  final VoidCallback onOpenMessages;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: PortalSupportSurface(
        accentEdge: true,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.lifeBuoy,
                color: Color(0xFF0B0E14),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            const SizedBox(width: 4),
            TextButton(
              onPressed: onOpenMessages,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Messages'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with gold accent mark.
class PortalSupportSectionTitle extends StatelessWidget {
  const PortalSupportSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 16, color: AppColors.gold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

/// Tickets section header with optional trailing action (e.g. New ticket).
class PortalSupportTicketsHeader extends StatelessWidget {
  const PortalSupportTicketsHeader({
    super.key,
    this.action,
    this.subtitle = 'Tracked cases with status and follow-up',
  });

  final Widget? action;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PortalSupportSectionTitle(
      title: 'Tickets',
      icon: LucideIcons.ticket,
      subtitle: subtitle,
      action: action,
    );
  }
}

/// Shared ticket list row for client / investor Support.
class PortalTicketListTile extends StatelessWidget {
  const PortalTicketListTile({
    super.key,
    required this.subject,
    required this.status,
    required this.statusColor,
    this.meta,
    this.selected = false,
    this.onTap,
  });

  final String subject;
  final String status;
  final Color statusColor;
  final String? meta;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.08)
                  : const Color(0xFF151922),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      LucideIcons.ticket,
                      color: AppColors.gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (meta != null && meta!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.slate400),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      status.replaceAll('_', ' '),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact shortcut tile for Support / Messages cross-links.
class PortalSupportShortcutTile extends StatelessWidget {
  const PortalSupportShortcutTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = AppColors.gold,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF151922),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ticket thread panel — shared chrome for client / investor Support replies.
class PortalSupportThreadPanel extends StatelessWidget {
  const PortalSupportThreadPanel({
    super.key,
    this.title = 'Conversation',
    this.onOpenMessages,
    this.actions = const [],
    required this.body,
    this.footer,
    this.expandBody = false,
  });

  final String title;
  final VoidCallback? onOpenMessages;
  final List<Widget> actions;
  final Widget body;
  final Widget? footer;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    return PortalSupportSurface(
      accentEdge: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.messagesSquare,
                  size: 16,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onOpenMessages != null)
                TextButton(
                  onPressed: onOpenMessages,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Open Messages'),
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
          const SizedBox(height: 14),
          if (expandBody)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: body,
              ),
            )
          else
            body,
          if (footer != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}
