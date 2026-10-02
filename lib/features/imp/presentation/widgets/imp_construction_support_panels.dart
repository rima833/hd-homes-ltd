import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/widgets/delivery_image.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Compact construction progress for Investor 360.
class ImpConstruction360Panel extends StatelessWidget {
  const ImpConstruction360Panel({
    super.key,
    required this.snapshot,
    this.loading = false,
    this.error,
    this.onOpenConstructionDesk,
  });

  final ImpConstructionSnapshot? snapshot;
  final bool loading;
  final String? error;
  final VoidCallback? onOpenConstructionDesk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Construction progress',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            if (onOpenConstructionDesk != null)
              TextButton(
                onPressed: onOpenConstructionDesk,
                child: const Text('Open CPMS'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (error != null)
          Text(error!, style: const TextStyle(color: AdminDeskColors.muted))
        else if (snapshot == null || snapshot!.isEmpty)
          const Text(
            'No construction projects are linked to this investor’s holdings yet.',
            style: TextStyle(color: AdminDeskColors.muted),
          )
        else ...[
          if (snapshot!.overallPercent > 0) ...[
            Text(
              'Overall ${snapshot!.overallPercent.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AdminDeskColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (snapshot!.overallPercent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AdminDeskColors.elevated,
                color: AdminDeskColors.gold,
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final project in snapshot!.projects)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(
                    url: project.coverImageUrl,
                    fallbackIcon: LucideIcons.hardHat,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            '${project.progressPct.toStringAsFixed(0)}%',
                            project.status.replaceAll('_', ' '),
                            project.scheduleStatus.replaceAll('_', ' '),
                            if (project.targetEndDate != null)
                              'Target ${DateFormat.yMMMd().format(project.targetEndDate!)}',
                          ].join(' · '),
                          style: const TextStyle(
                            color: AdminDeskColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${project.progressPct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AdminDeskColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (snapshot!.updates.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Latest investor-visible updates',
              style: TextStyle(
                color: AdminDeskColors.muted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            for (final update in snapshot!.updates.take(5))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Thumb(
                          url: update.media.isNotEmpty
                              ? update.media.first.displayUrl
                              : null,
                          fallbackIcon: LucideIcons.megaphone,
                          showVideoBadge: update.media.isNotEmpty &&
                              update.media.first.isVideo,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                update.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (update.projectName != null)
                                    update.projectName!,
                                  if (update.shortDescription != null)
                                    update.shortDescription!,
                                  if (update.publishedAt != null)
                                    DateFormat.yMMMd()
                                        .add_jm()
                                        .format(update.publishedAt!),
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AdminDeskColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (update.media.length > 1) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: update.media.take(6).length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final item = update.media[index];
                            return _Thumb(
                              url: item.displayUrl,
                              size: 56,
                              showVideoBadge: item.isVideo,
                              fallbackIcon: LucideIcons.image,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    this.url,
    required this.fallbackIcon,
    this.size = 44,
    this.showVideoBadge = false,
  });

  final String? url;
  final IconData fallbackIcon;
  final double size;
  final bool showVideoBadge;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (trimmed != null && trimmed.isNotEmpty)
              MediaDeliveryImage(
                url: trimmed,
                width: size,
                height: size,
                thumbnail: true,
                fit: BoxFit.cover,
              )
            else
              ColoredBox(
                color: AdminDeskColors.elevated,
                child: Icon(
                  fallbackIcon,
                  size: size * 0.4,
                  color: AdminDeskColors.gold,
                ),
              ),
            if (showVideoBadge)
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    LucideIcons.playCircle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Desk inbox: investor portal conversations + support tickets with in-IMP reply.
class ImpSupportInboxPanel extends StatefulWidget {
  const ImpSupportInboxPanel({
    super.key,
    required this.inbox,
    required this.loadConversationMessages,
    required this.loadTicketMessages,
    required this.onReplyConversation,
    required this.onReplyTicket,
    this.canReply = false,
    this.loading = false,
    this.error,
    this.onOpenInvestor,
    this.onOpenConversationInDesk,
    this.onOpenTicketInDesk,
  });

  final ImpSupportInbox? inbox;
  final bool canReply;
  final bool loading;
  final String? error;
  final Future<List<ImpSupportThreadMessage>> Function(String conversationId)
      loadConversationMessages;
  final Future<List<ImpSupportThreadMessage>> Function(String ticketId)
      loadTicketMessages;
  final Future<void> Function({
    required String investorId,
    required String conversationId,
    required String body,
    required String subject,
  })
  onReplyConversation;
  final Future<void> Function({
    required String ticketId,
    required String body,
    required bool isInternal,
  })
  onReplyTicket;
  final ValueChanged<String>? onOpenInvestor;
  final ValueChanged<String>? onOpenConversationInDesk;
  final ValueChanged<String>? onOpenTicketInDesk;

  @override
  State<ImpSupportInboxPanel> createState() => _ImpSupportInboxPanelState();
}

enum _ImpSupportTargetKind { conversation, ticket }

class _ImpSupportInboxPanelState extends State<ImpSupportInboxPanel> {
  _ImpSupportTargetKind? _kind;
  String? _selectedId;
  String? _selectedInvestorId;
  String? _selectedSubject;
  List<ImpSupportThreadMessage> _messages = const [];
  var _loadingThread = false;
  var _sending = false;
  var _internalNote = false;
  String? _threadError;
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ImpSupportInboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inbox != widget.inbox && _selectedId != null) {
      _loadThread();
    }
  }

  Future<void> _selectConversation(ImpConversation c) async {
    setState(() {
      _kind = _ImpSupportTargetKind.conversation;
      _selectedId = c.id;
      _selectedInvestorId = c.investorId;
      _selectedSubject = c.subject;
      _internalNote = false;
      _threadError = null;
    });
    widget.onOpenInvestor?.call(c.investorId);
    await _loadThread();
  }

  Future<void> _selectTicket(ImpSupportTicketRow t) async {
    setState(() {
      _kind = _ImpSupportTargetKind.ticket;
      _selectedId = t.id;
      _selectedInvestorId = null;
      _selectedSubject = t.ticketNumber == null
          ? t.subject
          : '${t.ticketNumber} · ${t.subject}';
      _threadError = null;
    });
    await _loadThread();
  }

  Future<void> _loadThread() async {
    final id = _selectedId;
    final kind = _kind;
    if (id == null || kind == null) return;
    setState(() {
      _loadingThread = true;
      _threadError = null;
    });
    try {
      final messages = kind == _ImpSupportTargetKind.conversation
          ? await widget.loadConversationMessages(id)
          : await widget.loadTicketMessages(id);
      if (!mounted || _selectedId != id) return;
      setState(() {
        _messages = messages;
        _loadingThread = false;
      });
    } catch (e) {
      if (!mounted || _selectedId != id) return;
      setState(() {
        _loadingThread = false;
        _threadError = '$e';
        _messages = const [];
      });
    }
  }

  Future<void> _send() async {
    final body = _replyCtrl.text.trim();
    final id = _selectedId;
    final kind = _kind;
    if (body.isEmpty || id == null || kind == null || !widget.canReply) return;
    setState(() => _sending = true);
    try {
      if (kind == _ImpSupportTargetKind.conversation) {
        final investorId = _selectedInvestorId;
        if (investorId == null || investorId.isEmpty) {
          throw StateError('Conversation has no investor');
        }
        await widget.onReplyConversation(
          investorId: investorId,
          conversationId: id,
          body: body,
          subject: _selectedSubject ?? 'Message from HD Homes',
        );
      } else {
        await widget.onReplyTicket(
          ticketId: id,
          body: body,
          isInternal: _internalNote,
        );
      }
      if (!mounted) return;
      _replyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == _ImpSupportTargetKind.ticket && _internalNote
                ? 'Internal note saved'
                : 'Reply sent',
          ),
        ),
      );
      await _loadThread();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.error != null) {
      return Text(
        widget.error!,
        style: const TextStyle(color: AdminDeskColors.muted),
      );
    }
    final data = widget.inbox;
    if (data == null || data.isEmpty) {
      return const Text(
        'No investor conversations or support tickets right now.',
        style: TextStyle(color: AdminDeskColors.muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Portal conversations',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(
                '${RoutePaths.dashboardSupport}?tab=clientMessages&kind=investor',
              ),
              child: const Text('Open Support desk'),
            ),
          ],
        ),
        for (final c in data.conversations.take(12))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            selected: _kind == _ImpSupportTargetKind.conversation &&
                _selectedId == c.id,
            leading: const Icon(
              LucideIcons.messageSquare,
              size: 18,
              color: AdminDeskColors.gold,
            ),
            title: Text(c.subject),
            subtitle: Text(
              [
                if (c.investorName != null) c.investorName!,
                c.status,
                if (c.lastMessagePreview != null) c.lastMessagePreview!,
                if (c.lastMessageAt != null)
                  DateFormat.yMMMd().add_jm().format(c.lastMessageAt!),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Open in Support desk',
              icon: const Icon(LucideIcons.externalLink, size: 16),
              onPressed: () {
                final open = widget.onOpenConversationInDesk;
                if (open != null) {
                  open(c.id);
                } else {
                  context.go(
                    '${RoutePaths.dashboardSupport}'
                    '?tab=clientMessages&kind=investor&conversation=${c.id}',
                  );
                }
              },
            ),
            onTap: _sending ? null : () => _selectConversation(c),
          ),
        if (data.tickets.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Support tickets',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final t in data.tickets.take(12))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              selected:
                  _kind == _ImpSupportTargetKind.ticket && _selectedId == t.id,
              leading: const Icon(
                LucideIcons.ticket,
                size: 18,
                color: AdminDeskColors.muted,
              ),
              title: Text(
                t.ticketNumber == null
                    ? t.subject
                    : '${t.ticketNumber} · ${t.subject}',
              ),
              subtitle: Text(
                [
                  if (t.investorName != null) t.investorName!,
                  t.status,
                  t.priority,
                  if (t.updatedAt != null)
                    DateFormat.yMMMd().format(t.updatedAt!),
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Open in Support desk',
                icon: const Icon(LucideIcons.externalLink, size: 16),
                onPressed: () {
                  final open = widget.onOpenTicketInDesk;
                  if (open != null) {
                    open(t.id);
                  } else {
                    context.go(
                      '${RoutePaths.dashboardSupport}?tab=tickets&ticket=${t.id}',
                    );
                  }
                },
              ),
              onTap: _sending ? null : () => _selectTicket(t),
            ),
        ],
        if (_selectedId != null) ...[
          const SizedBox(height: 16),
          const Divider(color: AdminDeskColors.border),
          const SizedBox(height: 12),
          Text(
            _selectedSubject ?? 'Thread',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_loadingThread)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else if (_threadError != null)
            Text(
              _threadError!,
              style: const TextStyle(color: AdminDeskColors.muted),
            )
          else if (_messages.isEmpty)
            const Text(
              'No messages in this thread yet.',
              style: TextStyle(color: AdminDeskColors.muted),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: m.isInternal
                          ? AdminDeskColors.elevated
                          : m.isStaff
                          ? AdminDeskColors.gold.withValues(alpha: 0.12)
                          : AdminDeskColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminDeskColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if (m.isInternal) 'Internal note',
                            if (m.senderName != null) m.senderName!,
                            if (m.senderName == null)
                              (m.isStaff ? 'Staff' : 'Investor'),
                            if (m.createdAt != null)
                              DateFormat.yMMMd()
                                  .add_jm()
                                  .format(m.createdAt!),
                          ].join(' · '),
                          style: const TextStyle(
                            color: AdminDeskColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(m.body),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (widget.canReply) ...[
            const SizedBox(height: 12),
            if (_kind == _ImpSupportTargetKind.ticket)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _internalNote,
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _internalNote = v ?? false),
                title: const Text('Internal note (not visible to investor)'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            TextField(
              controller: _replyCtrl,
              maxLines: 3,
              enabled: !_sending,
              decoration: InputDecoration(
                labelText: _kind == _ImpSupportTargetKind.ticket && _internalNote
                    ? 'Internal note'
                    : 'Reply',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _sending || _replyCtrl.text.trim().isEmpty
                  ? null
                  : _send,
              icon: const Icon(LucideIcons.send, size: 16),
              label: Text(_sending ? 'Sending…' : 'Send reply'),
            ),
            if (_sending) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ],
      ],
    );
  }
}
