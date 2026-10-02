import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_portal_chrome.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/support_desk_chrome.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _deskPanel = Color(0xFF061629);
const _deskBorder = Color(0xFF17304B);
const _deskMuted = Color(0xFF8FA3B9);

/// Staff ticket desk — list + detail + reply (dark, overflow-safe, realtime).
class StaffTicketWorkspace extends ConsumerStatefulWidget {
  const StaffTicketWorkspace({
    super.key,
    required this.tickets,
    required this.selectedTicketId,
    required this.onSelect,
    this.onCreateTicket,
    this.listHeader,
  });

  final List<CshopTicket> tickets;
  final String? selectedTicketId;
  final ValueChanged<String?> onSelect;
  final VoidCallback? onCreateTicket;
  /// Optional search/filters rendered above the ticket list (mockup left pane).
  final Widget? listHeader;

  @override
  ConsumerState<StaffTicketWorkspace> createState() =>
      _StaffTicketWorkspaceState();
}

class _StaffTicketWorkspaceState extends ConsumerState<StaffTicketWorkspace> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  bool _sending = false;
  bool _internalNote = false;
  bool _emojiOpen = false;
  bool _attaching = false;

  @override
  void initState() {
    super.initState();
    _ensureSelection();
  }

  @override
  void didUpdateWidget(covariant StaffTicketWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureSelection();
  }

  void _ensureSelection() {
    if (widget.selectedTicketId != null) return;
    if (widget.tickets.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.selectedTicketId == null && widget.tickets.isNotEmpty) {
        widget.onSelect(widget.tickets.first.id);
      }
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  CshopTicket? get _selected {
    final id = widget.selectedTicketId;
    if (id == null) return null;
    for (final t in widget.tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _addNote() {
    setState(() => _internalNote = true);
    _composerFocus.requestFocus();
  }

  Future<void> _send() async {
    final ticket = _selected;
    final text = _composer.text.trim();
    if (ticket == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final service = ref.read(cshopServiceProvider);
      final profileName =
          ref.read(identitySessionProvider).profile?.displayName.trim();
      await service.replyToTicket(
        ticketId: ticket.id,
        message: text,
        isInternal: _internalNote,
        senderName: profileName != null && profileName.isNotEmpty
            ? profileName
            : null,
      );
      _composer.clear();
      setState(() => _emojiOpen = false);
      ref.invalidate(adminTicketMessagesProvider(ticket.id));
      if (!_internalNote && {'new', 'open'}.contains(ticket.status)) {
        await service.updateTicket(
          ticketId: ticket.id,
          status: TicketStatus.inProgress.slug,
        );
        ref.invalidate(cshopSnapshotProvider);
      }
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage(_internalNote ? 'Internal note saved' : 'Reply sent');
    } catch (e) {
      ref.read(cshopControllerProvider.notifier).setMessage('Reply failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachFile() async {
    final media = ref.read(mediaServiceProvider);
    if (media == null) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Media upload is unavailable');
      return;
    }
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        ref
            .read(cshopControllerProvider.notifier)
            .setMessage('Could not read the file');
        return;
      }
      setState(() => _attaching = true);
      final ticket = _selected;
      final asset = await media.upload(
        UploadMediaRequest(
          bytes: Uint8List.fromList(bytes),
          contentType: _mimeFor(file.extension),
          originalFilename: file.name,
          entityType: MediaEntityType.crm,
          entityId: ticket?.id,
          folder: ticket == null
              ? 'hdhomes/support/tickets'
              : 'hdhomes/support/tickets/${ticket.id}',
          role: 'evidence',
          title: 'Ticket attachment',
        ),
      );
      final url = asset.secureUrl ?? asset.fileUrl ?? '';
      if (url.isEmpty) {
        ref
            .read(cshopControllerProvider.notifier)
            .setMessage('Upload succeeded but no delivery URL');
        return;
      }
      final prefix = _composer.text.trim();
      final link = '[${file.name}]($url)';
      _composer.text = prefix.isEmpty ? link : '$prefix\n$link';
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Attachment added — send to include the link');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  String _mimeFor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _setStatus(TicketStatus status) async {
    final ticket = _selected;
    if (ticket == null) return;
    try {
      await ref
          .read(cshopServiceProvider)
          .updateTicket(ticketId: ticket.id, status: status.slug);
      ref.invalidate(cshopSnapshotProvider);
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Status → ${status.label}');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Update failed: $e');
    }
  }

  Future<void> _setPriority(TicketPriority priority) async {
    final ticket = _selected;
    if (ticket == null) return;
    try {
      await ref
          .read(cshopServiceProvider)
          .updateTicket(ticketId: ticket.id, priority: priority.name);
      ref.invalidate(cshopSnapshotProvider);
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Priority → ${priority.label}');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Update failed: $e');
    }
  }

  Future<void> _setCategory(SupportCategory category) async {
    final ticket = _selected;
    if (ticket == null || ticket.categoryId == category.id) return;
    try {
      await ref
          .read(cshopServiceProvider)
          .updateTicket(ticketId: ticket.id, categoryId: category.id);
      ref.invalidate(cshopSnapshotProvider);
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Category → ${category.name}');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Category update failed');
    }
  }

  Future<void> _assignToMe() async {
    final ticket = _selected;
    if (ticket == null) return;
    try {
      await ref.read(cshopServiceProvider).assignTicketToMe(ticket.id);
      ref.invalidate(cshopSnapshotProvider);
      ref.read(cshopControllerProvider.notifier).setMessage('Assigned to you');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Assign failed: $e');
    }
  }

  Future<void> _unassign() async {
    final ticket = _selected;
    if (ticket == null) return;
    try {
      await ref
          .read(cshopServiceProvider)
          .updateTicket(ticketId: ticket.id, unassign: true);
      ref.invalidate(cshopSnapshotProvider);
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Ticket unassigned');
    } catch (e) {
      ref
          .read(cshopControllerProvider.notifier)
          .setMessage('Unassign failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final sidebarCollapsed = ref.watch(adminSidebarCollapsedProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final list = _TicketPane(
          tickets: widget.tickets,
          selectedId: widget.selectedTicketId,
          onSelect: widget.onSelect,
          header: widget.listHeader,
        );
        final detail = selected == null
            ? const _EmptyDetail()
            : _TicketDetailPane(
                ticket: selected,
                composer: _composer,
                composerFocus: _composerFocus,
                sending: _sending || _attaching,
                internalNote: _internalNote,
                emojiOpen: _emojiOpen,
                onToggleInternal: (v) => setState(() => _internalNote = v),
                onToggleEmoji: () => setState(() => _emojiOpen = !_emojiOpen),
                onAttach: _attachFile,
                onSend: _send,
                onStatus: _setStatus,
              );

        if (!wide) {
          return Column(
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.32).clamp(160.0, 240.0),
                child: ColoredBox(color: _deskPanel, child: list),
              ),
              const Divider(height: 1, color: _deskBorder),
              Expanded(child: detail),
            ],
          );
        }

        final ticket = selected;
        final showDetails = sidebarCollapsed && ticket != null;
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: showDetails ? 325 : 300,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _deskPanel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _deskBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: list,
                  ),
                ),
              ),
              const SupportPaneGutter(),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _deskPanel,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _deskBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: detail,
                  ),
                ),
              ),
              if (sidebarCollapsed && ticket != null) ...[
                const SupportPaneGutter(),
                SizedBox(
                  width: 274,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _deskPanel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _deskBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _TicketContextRail(
                        ticket: ticket,
                        onCreateTicket: widget.onCreateTicket,
                        onAddNote: _addNote,
                        onAssign: _assignToMe,
                        onUnassign: _unassign,
                        onMarkResolved: () => _setStatus(TicketStatus.resolved),
                        onStatus: _setStatus,
                        onPriority: _setPriority,
                        onCategory: _setCategory,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Select a ticket to view the conversation',
        style: TextStyle(color: _deskMuted),
      ),
    );
  }
}

String _ticketSourceLabel(String type) {
  switch (type) {
    case 'client':
      return 'Client';
    case 'investor':
      return 'Investor';
    default:
      return 'Public';
  }
}

class _TicketStatusSteps extends StatelessWidget {
  const _TicketStatusSteps({
    required this.current,
    required this.onSelect,
  });

  final TicketStatus current;
  final ValueChanged<TicketStatus> onSelect;

  static const _path = <TicketStatus>[
    TicketStatus.open,
    TicketStatus.inProgress,
    TicketStatus.escalated,
    TicketStatus.resolved,
    TicketStatus.closed,
  ];

  @override
  Widget build(BuildContext context) {
    final steps = <TicketStatus>[
      if (current == TicketStatus.neu ||
          current == TicketStatus.pendingCustomer ||
          current == TicketStatus.waitingHdHomes)
        current,
      ..._path,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(step),
            ),
        ],
      ),
    );
  }

  Widget _chip(TicketStatus step) {
    final selected = step == current;
    final color = SupportDeskChrome.statusColor(step.slug);
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : const Color(0xFF10253A),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onSelect(step),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.7) : _deskBorder,
            ),
          ),
          child: Text(
            step.label,
            style: TextStyle(
              color: selected ? color : SupportDeskChrome.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

String _ticketPreview(CshopTicket t) {
  final desc = t.description?.trim();
  if (desc != null && desc.isNotEmpty) {
    return desc.length > 72 ? '${desc.substring(0, 72)}…' : desc;
  }
  return t.ticketNumber ?? '';
}

class _TicketPane extends StatelessWidget {
  const _TicketPane({
    required this.tickets,
    required this.selectedId,
    required this.onSelect,
    this.header,
  });

  final List<CshopTicket> tickets;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        Expanded(
          child: tickets.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No tickets yet. New customer tickets appear here in real time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _deskMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: tickets.length,
                  itemBuilder: (context, i) {
                    final t = tickets[i];
                    return SupportConversationTile(
                      title: t.customerName?.trim().isNotEmpty == true
                          ? t.customerName!.trim()
                          : 'Customer',
                      subtitle: t.subject,
                      preview: _ticketPreview(t),
                      time: SupportDeskChrome.timeLabel(
                        t.lastResponseAt ?? t.updatedAt ?? t.createdAt,
                      ),
                      status: t.status,
                      selected: t.id == selectedId,
                      onTap: () => onSelect(t.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TicketDetailPane extends ConsumerWidget {
  const _TicketDetailPane({
    required this.ticket,
    required this.composer,
    required this.composerFocus,
    required this.sending,
    required this.internalNote,
    required this.emojiOpen,
    required this.onToggleInternal,
    required this.onToggleEmoji,
    required this.onAttach,
    required this.onSend,
    required this.onStatus,
  });

  final CshopTicket ticket;
  final TextEditingController composer;
  final FocusNode composerFocus;
  final bool sending;
  final bool internalNote;
  final bool emojiOpen;
  final ValueChanged<bool> onToggleInternal;
  final VoidCallback onToggleEmoji;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final ValueChanged<TicketStatus> onStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(adminTicketMessagesProvider(ticket.id));
    final eventsAsync = ref.watch(supportTicketEventsProvider(ticket.id));
    final events = eventsAsync.valueOrNull ?? const <SupportTicketEvent>[];
    final eventCount = events.length;
    final customer =
        ticket.customerName?.trim().isNotEmpty == true
            ? ticket.customerName!.trim()
            : 'Customer';

    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 480;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Slim fixed chrome — never claim % of pane height (that crushed the chat).
            Material(
              color: _deskPanel,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SupportAvatar(name: customer, size: 38),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Row(
                                children: [
                                  Icon(
                                    LucideIcons.circle,
                                    size: 8,
                                    color: SupportDeskChrome.online,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: _deskMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (eventCount > 0)
                          IconButton(
                            tooltip: 'Timeline ($eventCount)',
                            onPressed: () => _showTicketTimeline(
                              context,
                              ticket,
                              events,
                            ),
                            icon: const Icon(
                              LucideIcons.moreVertical,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Ticket ${ticket.ticketNumber ?? '#${ticket.id.substring(0, 8)}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _deskMuted, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SupportStatusBadge(status: ticket.status),
                        const Spacer(),
                        Flexible(
                          flex: 2,
                          child: Text(
                            ticket.createdAt == null
                                ? _ticketSourceLabel(ticket.customerType)
                                : 'Created: ${SupportDeskChrome.dateTimeLabel(ticket.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: _deskMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _TicketStatusSteps(
                      current: ticket.statusEnum,
                      onSelect: onStatus,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: _deskBorder),
            if (!short && ticket.subject.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _deskBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if ((ticket.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ticket.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _deskMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: msgsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '$e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No replies yet — send the first response below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _deskMuted),
                        ),
                      ),
                    );
                  }
                  final session = ref.watch(identitySessionProvider);
                  final signedIn = session.profile?.displayName.trim();
                  return ListView.builder(
                    padding: SupportChatMetrics.messageListPadding,
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = m.isStaff;
                      final stored = m.senderName?.trim() ?? '';
                      final generic = stored.isEmpty ||
                          stored == 'Agent' ||
                          stored == 'User';
                      final mineReply = m.senderId != null &&
                          m.senderId == session.userId;
                      final label = !generic
                          ? stored
                          : (mineReply &&
                                  signedIn != null &&
                                  signedIn.isNotEmpty)
                              ? signedIn
                              : (mine
                                  ? (signedIn?.isNotEmpty == true
                                      ? signedIn!
                                      : 'Agent')
                                  : customer);
                      return SupportChatBubble(
                        body: m.body,
                        mine: mine,
                        senderLabel: m.isInternal ? null : label,
                        createdAt: m.createdAt,
                        isInternal: m.isInternal,
                        showChecks: mine && !m.isInternal,
                        isRead: mine,
                        showSideAvatar: !m.isInternal,
                        avatarName: label,
                      );
                    },
                  );
                },
              ),
            ),
            PermissionGateAny(
              permissions: const [
                PermissionSlugs.supportTickets,
                PermissionSlugs.supportWrite,
              ],
              child: SafeArea(
                top: false,
                child: SupportChatComposer(
                  controller: composer,
                  focusNode: composerFocus,
                  onSend: onSend,
                  sending: sending,
                  emojiInside: true,
                  emojiOpen: emojiOpen,
                  helperText: null,
                  hintText: internalNote
                      ? 'Add an internal note...'
                      : 'Type a message...',
                  onAttach: onAttach,
                  onToggleEmoji: onToggleEmoji,
                  emojiTray: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final e in const [
                        '👍',
                        '🙏',
                        '✅',
                        '🏠',
                        '😊',
                        '👋',
                        '💡',
                        '⭐',
                      ])
                        InkWell(
                          onTap: () {
                            final t = composer.text;
                            composer.text = '$t$e';
                            composer.selection = TextSelection.collapsed(
                              offset: composer.text.length,
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(e, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                    ],
                  ),
                  leading: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Internal note'),
                      selected: internalNote,
                      onSelected: onToggleInternal,
                      selectedColor: AppColors.gold.withValues(alpha: 0.25),
                      checkmarkColor: AppColors.gold,
                      labelStyle: TextStyle(
                        color: internalNote ? AppColors.gold : _deskMuted,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: internalNote
                            ? AppColors.gold.withValues(alpha: 0.5)
                            : _deskBorder,
                      ),
                      backgroundColor: Colors.transparent,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showTicketTimeline(
  BuildContext context,
  CshopTicket ticket,
  List<SupportTicketEvent> events,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF171C26),
      title: Row(
        children: [
          const Icon(LucideIcons.history, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${ticket.ticketNumber ?? 'Ticket'} timeline',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 460,
        child: ListView.separated(
          itemCount: events.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: _deskBorder),
          itemBuilder: (context, index) {
            final event = events[events.length - 1 - index];
            final transition = [
              if (event.fromStatus != null) event.fromStatus,
              if (event.toStatus != null) '→ ${event.toStatus}',
              if (event.fromPriority != null) event.fromPriority,
              if (event.toPriority != null) '→ ${event.toPriority}',
            ].join(' ');
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 4,
              ),
              leading: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: event.isInternal
                      ? Colors.amber.withValues(alpha: 0.14)
                      : AppColors.gold.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  event.isInternal ? LucideIcons.lock : LucideIcons.activity,
                  size: 14,
                  color: event.isInternal ? Colors.amber : AppColors.gold,
                ),
              ),
              title: Text(
                event.action
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map(
                      (word) => word.isEmpty
                          ? word
                          : '${word[0].toUpperCase()}${word.substring(1)}',
                    )
                    .join(' '),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                [
                  if ((event.actorLabel ?? '').isNotEmpty) event.actorLabel,
                  if (transition.isNotEmpty) transition,
                  if (event.createdAt != null)
                    event.createdAt!.toLocal().toString().split('.').first,
                ].whereType<String>().join(' · '),
                style: const TextStyle(color: _deskMuted, fontSize: 12),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _TicketContextRail extends ConsumerWidget {
  const _TicketContextRail({
    required this.ticket,
    this.onCreateTicket,
    required this.onAddNote,
    required this.onAssign,
    required this.onUnassign,
    required this.onMarkResolved,
    required this.onStatus,
    required this.onPriority,
    required this.onCategory,
  });

  final CshopTicket ticket;
  final VoidCallback? onCreateTicket;
  final VoidCallback onAddNote;
  final VoidCallback onAssign;
  final VoidCallback onUnassign;
  final VoidCallback onMarkResolved;
  final ValueChanged<TicketStatus> onStatus;
  final ValueChanged<TicketPriority> onPriority;
  final ValueChanged<SupportCategory> onCategory;

  void _msg(WidgetRef ref, String message) {
    ref.read(cshopControllerProvider.notifier).setMessage(message);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(supportTicketLinksProvider(ticket.id));
    final links = linksAsync.valueOrNull ?? const <SupportTicketLink>[];
    final categories =
        ref.watch(supportTicketCategoriesProvider).valueOrNull ??
            const <SupportCategory>[];
    final customer =
        ticket.customerName?.trim().isNotEmpty == true
            ? ticket.customerName!.trim()
            : 'Unknown';
    final ticketId = ticket.ticketNumber?.trim().isNotEmpty == true
        ? ticket.ticketNumber!.trim()
        : ticket.id;

    return ColoredBox(
      color: _deskPanel,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ticket Details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (ticket.assignedTo != null)
                TextButton(
                  onPressed: onUnassign,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Unassign'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SupportDetailField(label: 'Ticket ID', value: ticketId),
          SupportDetailField(label: 'Customer Name', value: customer),
          SupportDetailField(
            label: 'Email',
            value: ticket.customerEmail?.trim().isNotEmpty == true
                ? ticket.customerEmail!.trim()
                : '—',
          ),
          SupportDetailField(
            label: 'Phone',
            value: ticket.customerPhone?.trim().isNotEmpty == true
                ? ticket.customerPhone!.trim()
                : '—',
          ),
          SupportDetailField(label: 'Subject', value: ticket.subject),
          SupportDetailField(
            label: 'Source',
            value: _ticketSourceLabel(ticket.customerType),
          ),
          if (categories.isNotEmpty)
            SupportDetailField(
              label: 'Category',
              value: ticket.category ?? 'General',
              trailing: PopupMenuButton<SupportCategory>(
                tooltip: 'Change category',
                color: const Color(0xFF1A2030),
                onSelected: onCategory,
                itemBuilder: (context) => categories
                    .map(
                      (c) => PopupMenuItem(
                        value: c,
                        child: Text(
                          c.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                child: Text(
                  ticket.category ?? 'Set category',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          SupportDetailField(
            label: 'Priority',
            value: ticket.priorityEnum.label,
            trailing: PopupMenuButton<TicketPriority>(
              tooltip: 'Change priority',
              color: const Color(0xFF1A2030),
              onSelected: onPriority,
              itemBuilder: (context) => TicketPriority.values
                  .map(
                    (p) => PopupMenuItem(
                      value: p,
                      child: Text(
                        p.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              child: SupportStatusBadge(status: ticket.priority),
            ),
          ),
          SupportDetailField(
            label: 'Status',
            value: ticket.statusEnum.label,
            trailing: PopupMenuButton<TicketStatus>(
              tooltip: 'Change status',
              color: const Color(0xFF1A2030),
              onSelected: onStatus,
              itemBuilder: (context) => TicketStatus.actionable
                  .map(
                    (s) => PopupMenuItem(
                      value: s,
                      child: Text(
                        s.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              child: SupportStatusBadge(status: ticket.status),
            ),
          ),
          SupportDetailField(
            label: 'Created',
            value: SupportDeskChrome.timeLabel(ticket.createdAt).isEmpty
                ? '—'
                : SupportDeskChrome.timeLabel(ticket.createdAt),
          ),
          SupportDetailField(
            label: 'Last Update',
            value: SupportDeskChrome.timeLabel(
                      ticket.updatedAt ?? ticket.lastResponseAt,
                    )
                    .isEmpty
                ? '—'
                : SupportDeskChrome.timeLabel(
                    ticket.updatedAt ?? ticket.lastResponseAt,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          PermissionGateAny(
            permissions: const [
              PermissionSlugs.supportTickets,
              PermissionSlugs.supportWrite,
            ],
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SupportQuickActionButton(
                        label: 'Create Ticket',
                        icon: LucideIcons.plusCircle,
                        primary: true,
                        onPressed: onCreateTicket ??
                            () => _msg(ref, 'Ticket creation is unavailable'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: SupportQuickActionButton(
                        label: 'Add Note',
                        icon: LucideIcons.stickyNote,
                        onPressed: onAddNote,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: SupportQuickActionButton(
                        label: 'Assign to Agent',
                        icon: LucideIcons.user,
                        onPressed: onAssign,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: SupportQuickActionButton(
                        label: 'Mark as Resolved',
                        icon: LucideIcons.checkCircle,
                        onPressed: onMarkResolved,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Related Links',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (ticket.propertyId != null && ticket.propertyId!.isNotEmpty) ...[
            SupportRelatedLinkTile(
              label: 'View Property Details',
              icon: LucideIcons.home,
              onTap: () {
                final id = ticket.propertyId!;
                context.go(
                  RoutePaths.propertyDetails.replaceFirst(':id', id),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          SupportRelatedLinkTile(
            label: 'Customer Profile',
            icon: LucideIcons.user,
            onTap: () => context.go(RoutePaths.dashboardCrm),
          ),
          const SizedBox(height: 8),
          SupportRelatedLinkTile(
            label: 'Past Conversations',
            icon: LucideIcons.messagesSquare,
            onTap: () => context.go(
              '${RoutePaths.dashboardSupport}?tab=clientMessages',
            ),
          ),
          for (final link in links) ...[
            const SizedBox(height: 8),
            SupportRelatedLinkTile(
              label: link.label?.trim().isNotEmpty == true
                  ? link.label!.trim()
                  : '${link.entityType} · ${link.entityId}',
              icon: LucideIcons.link,
              onTap: () {
                final url = link.resourceUrl?.trim();
                if (url != null && url.isNotEmpty) {
                  if (url.startsWith('/')) {
                    context.go(url);
                  } else {
                    _msg(ref, 'Open: $url');
                  }
                } else {
                  _msg(
                    ref,
                    'Linked ${link.entityType}: ${link.entityId}',
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
