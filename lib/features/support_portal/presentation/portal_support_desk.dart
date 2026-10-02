import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_shell.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Light support workspace matching the client/investor desk mockup.
///
/// The conversation fills the right side from top to bottom. The ticket
/// list, hero, and counts stay in the left column.
class PortalSupportDesk extends StatelessWidget {
  const PortalSupportDesk({
    super.key,
    required this.filter,
    required this.onFilter,
    required this.allCount,
    required this.openCount,
    required this.closedCount,
    required this.onNewTicket,
    required this.tickets,
    required this.selectedId,
    required this.onSelect,
    required this.thread,
    this.form,
  });

  final PortalTicketHistoryFilter filter;
  final ValueChanged<PortalTicketHistoryFilter> onFilter;
  final int allCount;
  final int openCount;
  final int closedCount;
  final VoidCallback onNewTicket;
  final List<PortalSupportDeskTicket> tickets;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final Widget thread;
  final Widget? form;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    return ColoredBox(
      color: PortalSupportDeskColors.canvas,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 430,
                      child: _LeftColumn(
                        filter: filter,
                        onFilter: onFilter,
                        allCount: allCount,
                        openCount: openCount,
                        closedCount: closedCount,
                        onNewTicket: onNewTicket,
                        tickets: tickets,
                        selectedId: selectedId,
                        onSelect: onSelect,
                        form: form,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: thread),
                  ],
                )
              : selectedId == null
              ? _LeftColumn(
                  filter: filter,
                  onFilter: onFilter,
                  allCount: allCount,
                  openCount: openCount,
                  closedCount: closedCount,
                  onNewTicket: onNewTicket,
                  tickets: tickets,
                  selectedId: selectedId,
                  onSelect: onSelect,
                  form: form,
                )
              : thread,
        ),
      ),
    );
  }
}

abstract final class PortalSupportDeskColors {
  static const canvas = Color(0xFFF6F3EE);
  static const card = Colors.white;
  static const ink = Color(0xFF1C1915);
  static const muted = Color(0xFF8A8178);
  static const line = Color(0xFFE8E2D8);
  static const open = Color(0xFF16A34A);
  static const selected = Color(0xFFFFF6E6);
  static const bubble = Color(0xFFF4C542);
  static const supportBubble = Color(0xFFF3F4F6);
}

class PortalSupportDeskTicket {
  const PortalSupportDeskTicket({
    required this.id,
    required this.subject,
    required this.status,
    this.ticketNumber,
    this.createdAt,
    this.activityAt,
    this.preview,
  });

  final String id;
  final String subject;
  final String status;
  final String? ticketNumber;
  final DateTime? createdAt;
  final DateTime? activityAt;
  final String? preview;

  bool get closed => portalTicketStatusIsClosed(status);
}

class PortalSupportDeskMessage {
  const PortalSupportDeskMessage({
    required this.body,
    required this.isMine,
    this.senderName,
    this.createdAt,
    this.attachment,
  });

  final String body;
  final bool isMine;
  final String? senderName;
  final DateTime? createdAt;
  final Widget? attachment;
}

class PortalSupportDeskThread extends StatelessWidget {
  const PortalSupportDeskThread({
    super.key,
    required this.ticket,
    required this.messages,
    required this.loading,
    required this.canReply,
    required this.replyController,
    required this.onSend,
    required this.sending,
    this.onBack,
    this.onReopen,
    this.onClose,
    this.onConfirm,
    this.onAttach,
    this.attachmentLabel,
    this.onClearAttachment,
    this.errorText,
    this.mineInitial = 'Y',
  });

  final PortalSupportDeskTicket? ticket;
  final List<PortalSupportDeskMessage> messages;
  final bool loading;
  final bool canReply;
  final TextEditingController replyController;
  final VoidCallback onSend;
  final bool sending;
  final VoidCallback? onBack;
  final VoidCallback? onReopen;
  final VoidCallback? onClose;
  final VoidCallback? onConfirm;
  final VoidCallback? onAttach;
  final String? attachmentLabel;
  final VoidCallback? onClearAttachment;
  final String? errorText;
  final String mineInitial;

  @override
  Widget build(BuildContext context) {
    final ticket = this.ticket;
    if (ticket == null) {
      return const _Panel(
        child: Center(
          child: Text(
            'Select a ticket to view the conversation.',
            style: TextStyle(color: PortalSupportDeskColors.muted),
          ),
        ),
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(LucideIcons.arrowLeft, size: 18),
                    color: PortalSupportDeskColors.ink,
                  ),
                const _TicketMark(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PortalSupportDeskColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _metaLine(ticket),
                        style: const TextStyle(
                          color: PortalSupportDeskColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(closed: ticket.closed, status: ticket.status),
                PopupMenuButton<String>(
                  icon: const Icon(
                    LucideIcons.moreVertical,
                    size: 18,
                    color: PortalSupportDeskColors.muted,
                  ),
                  onSelected: (value) {
                    if (value == 'reopen') onReopen?.call();
                    if (value == 'close') onClose?.call();
                    if (value == 'confirm') onConfirm?.call();
                  },
                  itemBuilder: (context) => [
                    if (ticket.status == 'resolved' && onConfirm != null)
                      const PopupMenuItem(
                        value: 'confirm',
                        child: Text('Confirm resolution'),
                      ),
                    if (ticket.closed && onReopen != null)
                      const PopupMenuItem(
                        value: 'reopen',
                        child: Text('Reopen ticket'),
                      ),
                    if (!ticket.closed && onClose != null)
                      const PopupMenuItem(
                        value: 'close',
                        child: Text('Close ticket'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: PortalSupportDeskColors.line),
          Expanded(
            child: Stack(
              children: [
                const Positioned(
                  right: 36,
                  top: 80,
                  child: Opacity(
                    opacity: 0.06,
                    child: Icon(
                      LucideIcons.hexagon,
                      size: 180,
                      color: PortalSupportDeskColors.ink,
                    ),
                  ),
                ),
                if (loading && messages.isEmpty)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                else if (errorText != null && messages.isEmpty)
                  Center(child: Text(errorText!))
                else
                  _MessageList(messages: messages, mineInitial: mineInitial),
              ],
            ),
          ),
          if (!canReply)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'This ticket is closed. Reopen it to send another reply.',
                      style: TextStyle(
                        color: PortalSupportDeskColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (onReopen != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: onReopen,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PortalSupportDeskColors.ink,
                        side: const BorderSide(
                          color: PortalSupportDeskColors.bubble,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Reopen ticket'),
                    ),
                  ],
                ],
              ),
            )
          else
            _DeskComposer(
              controller: replyController,
              onSend: onSend,
              onAttach: onAttach,
              attachmentLabel: attachmentLabel,
              onClearAttachment: onClearAttachment,
            ),
        ],
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.filter,
    required this.onFilter,
    required this.allCount,
    required this.openCount,
    required this.closedCount,
    required this.onNewTicket,
    required this.tickets,
    required this.selectedId,
    required this.onSelect,
    this.form,
  });

  final PortalTicketHistoryFilter filter;
  final ValueChanged<PortalTicketHistoryFilter> onFilter;
  final int allCount;
  final int openCount;
  final int closedCount;
  final VoidCallback onNewTicket;
  final List<PortalSupportDeskTicket> tickets;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final Widget? form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Hero(),
        const SizedBox(height: 12),
        _Stats(
          allCount: allCount,
          openCount: openCount,
          closedCount: closedCount,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              LucideIcons.ticket,
              size: 16,
              color: PortalSupportDeskColors.ink,
            ),
            const SizedBox(width: 8),
            const Text(
              'Tickets',
              style: TextStyle(
                color: PortalSupportDeskColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onNewTicket,
              icon: const Icon(LucideIcons.plus, size: 15),
              label: const Text('New Ticket'),
              style: FilledButton.styleFrom(
                backgroundColor: PortalSupportDeskColors.bubble,
                foregroundColor: PortalSupportDeskColors.ink,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _FilterPills(
          filter: filter,
          onFilter: onFilter,
          allCount: allCount,
          openCount: openCount,
          closedCount: closedCount,
        ),
        if (form != null) ...[const SizedBox(height: 10), form!],
        const SizedBox(height: 10),
        Expanded(
          child: _TicketList(
            tickets: tickets,
            selectedId: selectedId,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 112,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF14110E), Color(0xFF2C261C)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -10,
              top: -20,
              bottom: -20,
              width: 170,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x002C261C), Color(0xFF8A6A32)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 18),
                    child: Icon(
                      LucideIcons.building2,
                      size: 78,
                      color: Color(0x66F4C542),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 150, 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PortalSupportDeskColors.bubble,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.headphones,
                      color: Color(0xFF1C1915),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "We're here to help. Track open and closed tickets, get quick responses, and resolve issues.",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFD5CFC4),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
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

class _Stats extends StatelessWidget {
  const _Stats({
    required this.allCount,
    required this.openCount,
    required this.closedCount,
  });

  final int allCount;
  final int openCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'All Tickets',
            value: allCount,
            icon: LucideIcons.ticket,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Open',
            value: openCount,
            icon: LucideIcons.clock,
            accent: PortalSupportDeskColors.open,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Closed',
            value: closedCount,
            icon: LucideIcons.checkCircle2,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? PortalSupportDeskColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PortalSupportDeskColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: accent == null ? 0.06 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PortalSupportDeskColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: PortalSupportDeskColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.filter,
    required this.onFilter,
    required this.allCount,
    required this.openCount,
    required this.closedCount,
  });

  final PortalTicketHistoryFilter filter;
  final ValueChanged<PortalTicketHistoryFilter> onFilter;
  final int allCount;
  final int openCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    Widget pill(PortalTicketHistoryFilter value, String label, int count) {
      final selected = filter == value;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: selected
                ? PortalSupportDeskColors.bubble
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onFilter(value),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$label ($count)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? PortalSupportDeskColors.ink
                        : const Color(0xFF5C564E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PortalSupportDeskColors.line),
      ),
      child: Row(
        children: [
          pill(PortalTicketHistoryFilter.all, 'All', allCount),
          pill(PortalTicketHistoryFilter.open, 'Open', openCount),
          pill(PortalTicketHistoryFilter.closed, 'Closed', closedCount),
        ],
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.selectedId,
    required this.onSelect,
  });

  final List<PortalSupportDeskTicket> tickets;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(
        child: Text(
          'No tickets in this view.',
          style: TextStyle(color: PortalSupportDeskColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final t = tickets[index];
        final selected = t.id == selectedId;
        final when = t.activityAt ?? t.createdAt;
        return Material(
          color: selected ? PortalSupportDeskColors.selected : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => onSelect(t.id),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE7C56A)
                      : PortalSupportDeskColors.line,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _TicketMark(small: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PortalSupportDeskColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      _StatusPill(closed: t.closed, status: t.status),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: PortalSupportDeskColors.muted,
                      ),
                    ],
                  ),
                  if (t.preview != null && t.preview!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    if (when != null)
                      Text(
                        DateFormat.jm().format(when.toLocal()),
                        style: const TextStyle(
                          color: PortalSupportDeskColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      t.preview!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4A453E),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _idLine(t),
                    style: const TextStyle(
                      color: PortalSupportDeskColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({required this.messages, required this.mineInitial});

  final List<PortalSupportDeskMessage> messages;
  final String mineInitial;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _jumpEnd();
  }

  @override
  void didUpdateWidget(covariant _MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) _jumpEnd();
  }

  void _jumpEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped(widget.messages);
    return ListView(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      children: [
        if (widget.messages.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(
              child: Text(
                'No replies yet. Send a message below.',
                style: TextStyle(color: PortalSupportDeskColors.muted),
              ),
            ),
          ),
        for (final entry in groups) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                entry.$1,
                style: const TextStyle(
                  color: PortalSupportDeskColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          for (final m in entry.$2)
            _Bubble(message: m, mineInitial: widget.mineInitial),
        ],
      ],
    );
  }
}

class _DeskComposer extends StatefulWidget {
  const _DeskComposer({
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.attachmentLabel,
    this.onClearAttachment,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final String? attachmentLabel;
  final VoidCallback? onClearAttachment;

  @override
  State<_DeskComposer> createState() => _DeskComposerState();
}

class _DeskComposerState extends State<_DeskComposer> {
  bool _emojiOpen = false;

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

  void _insertEmoji(String emoji) {
    final t = widget.controller;
    final text = t.text;
    final sel = t.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    t.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = PortalSupportDeskColors.ink;
    const iconInk = Color(0xFF5C564F);
    final base = Theme.of(context);
    final composerTheme = base.copyWith(
      brightness: Brightness.light,
      iconTheme: const IconThemeData(color: iconInk, size: 18),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: iconInk,
          disabledForegroundColor: iconInk,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFFBF9F6),
        hintStyle: TextStyle(color: Color(0xFF6E675F), fontSize: 14.5),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
    );
    return Theme(
      data: composerTheme,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        child: IconTheme(
          data: const IconThemeData(color: iconInk, size: 18),
          child: DefaultTextStyle(
            style: const TextStyle(color: ink, fontSize: 13.5),
            child: Column(
              children: [
                if (widget.attachmentLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PortalSupportDeskColors.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.paperclip,
                              size: 14,
                              color: ink,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.attachmentLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.onClearAttachment != null)
                              IconButton(
                                onPressed: widget.onClearAttachment,
                                color: iconInk,
                                disabledColor: iconInk,
                                icon: const Icon(LucideIcons.x, size: 14),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_emojiOpen)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 4,
                      children: [
                        for (final e in _emojis)
                          InkWell(
                            onTap: () => _insertEmoji(e),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  },
                  child: Actions(
                    actions: {
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (_) {
                          widget.onSend();
                          return null;
                        },
                      ),
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF9F6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: PortalSupportDeskColors.line),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: widget.onAttach,
                            tooltip: 'Attach file',
                            color: iconInk,
                            disabledColor: iconInk,
                            icon: const Icon(LucideIcons.paperclip, size: 18),
                          ),
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              minLines: 1,
                              maxLines: 4,
                              cursorColor: ink,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF6E675F),
                                  fontSize: 14.5,
                                ),
                                filled: true,
                                fillColor: Color(0xFFFBF9F6),
                                hoverColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _emojiOpen = !_emojiOpen),
                            tooltip: 'Emoji',
                            color: iconInk,
                            disabledColor: iconInk,
                            icon: const Icon(LucideIcons.smile, size: 18),
                          ),
                          IconButton(
                            onPressed: widget.onAttach,
                            tooltip: 'Add image',
                            color: iconInk,
                            disabledColor: iconInk,
                            icon: const Icon(LucideIcons.image, size: 18),
                          ),
                          Material(
                            color: PortalSupportDeskColors.bubble,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onSend,
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  LucideIcons.send,
                                  size: 16,
                                  color: Color(0xFF1C1915),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mineInitial});

  final PortalSupportDeskMessage message;
  final String mineInitial;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final time = message.createdAt == null
        ? ''
        : DateFormat.jm().format(message.createdAt!.toLocal());
    final name = mine ? 'You' : (message.senderName ?? 'HD Homes Support');
    final maxBubble = (MediaQuery.sizeOf(context).width * 0.42).clamp(
      180.0,
      340.0,
    );
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxBubble),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine
                ? PortalSupportDeskColors.bubble
                : PortalSupportDeskColors.supportBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                message.body,
                textWidthBasis: TextWidthBasis.longestLine,
                style: const TextStyle(
                  color: PortalSupportDeskColors.ink,
                  height: 1.4,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (message.attachment != null) message.attachment!,
              if (mine)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.check,
                    size: 12,
                    color: Color(0xFF5C4510),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[const _HdAvatar(), const SizedBox(width: 8)],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  time.isEmpty ? name : '$name   $time',
                  style: const TextStyle(
                    color: PortalSupportDeskColors.muted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 4),
                bubble,
              ],
            ),
            if (mine) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: PortalSupportDeskColors.bubble,
                child: Text(
                  mineInitial,
                  style: const TextStyle(
                    color: PortalSupportDeskColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HdAvatar extends StatelessWidget {
  const _HdAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1915),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'HD',
        style: TextStyle(
          color: PortalSupportDeskColors.bubble,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.closed, required this.status});

  final bool closed;
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = closed ? 'Closed' : status.replaceAll('_', ' ');
    final pretty = label.isEmpty
        ? 'Open'
        : '${label[0].toUpperCase()}${label.substring(1)}';
    final color = closed
        ? const Color(0xFF6B7280)
        : PortalSupportDeskColors.open;
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        pretty,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TicketMark extends StatelessWidget {
  const _TicketMark({this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 28.0 : 36.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1915),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        LucideIcons.ticket,
        size: small ? 14 : 16,
        color: PortalSupportDeskColors.bubble,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PortalSupportDeskColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1C1915),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }
}

String _metaLine(PortalSupportDeskTicket ticket) {
  return [
    if (ticket.ticketNumber != null) ticket.ticketNumber,
    if (ticket.createdAt != null)
      DateFormat('MMM d, y').format(ticket.createdAt!.toLocal()),
  ].whereType<String>().join(' · ');
}

String _idLine(PortalSupportDeskTicket ticket) {
  return [
    if (ticket.ticketNumber != null) 'ID: ${ticket.ticketNumber}',
    if (ticket.createdAt != null)
      DateFormat('MMM d, y').format(ticket.createdAt!.toLocal()),
  ].whereType<String>().join(' · ');
}

List<(String, List<PortalSupportDeskMessage>)> _grouped(
  List<PortalSupportDeskMessage> messages,
) {
  final groups = <String, List<PortalSupportDeskMessage>>{};
  final order = <String>[];
  final now = DateTime.now();
  for (final m in messages) {
    final at = m.createdAt?.toLocal();
    final label = at == null
        ? 'Earlier'
        : (at.year == now.year && at.month == now.month && at.day == now.day)
        ? 'Today'
        : DateFormat.MMMd().format(at);
    groups
        .putIfAbsent(label, () {
          order.add(label);
          return [];
        })
        .add(m);
  }
  return [for (final label in order) (label, groups[label]!)];
}
