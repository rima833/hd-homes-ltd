import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_desk.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_shell.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestorSupportPage extends ConsumerStatefulWidget {
  const InvestorSupportPage({super.key});

  @override
  ConsumerState<InvestorSupportPage> createState() =>
      _InvestorSupportPageState();
}

class _InvestorSupportPageState extends ConsumerState<InvestorSupportPage> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _replyController = TextEditingController();
  var _priority = 'normal';
  bool _submitting = false;
  bool _showTicketForm = false;
  String? _selectedTicketId;
  InvestorMessageAttachment? _pendingAttachment;
  InvestorMessageAttachment? _replyAttachment;
  String? _pendingAttachmentName;
  String? _replyAttachmentName;
  PortalTicketHistoryFilter _filter = PortalTicketHistoryFilter.all;
  final List<_PendingReply> _pending = [];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  List<InvestorSupportTicket> _filtered(List<InvestorSupportTicket> tickets) {
    return switch (_filter) {
      PortalTicketHistoryFilter.all => tickets,
      PortalTicketHistoryFilter.open =>
        tickets.where((t) => !portalTicketStatusIsClosed(t.status)).toList(),
      PortalTicketHistoryFilter.closed =>
        tickets.where((t) => portalTicketStatusIsClosed(t.status)).toList(),
    };
  }

  Future<InvestorMessageAttachment?> _pickAttachment({
    required void Function(String name) onName,
  }) async {
    final media = ref.read(mediaServiceProvider);
    if (media == null) {
      showFriendlyError(
        context,
        null,
        fallback: 'Media upload is unavailable.',
      );
      return null;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return null;
      showFriendlyError(context, null, fallback: 'Could not read the file.');
      return null;
    }
    final record = await ref.read(investorRecordProvider.future);
    final asset = await media.upload(
      UploadMediaRequest(
        bytes: Uint8List.fromList(bytes),
        contentType: _mimeFor(file.extension) ?? 'application/octet-stream',
        originalFilename: file.name,
        entityType: MediaEntityType.investment,
        entityId: record?.id,
        folder: record == null
            ? null
            : 'hdhomes/investors/${record.id}/support',
        role: 'evidence',
        title: 'Support attachment',
      ),
    );
    onName(file.name);
    final url = asset.secureUrl ?? asset.fileUrl;
    if (url.isEmpty) {
      throw const NetworkException('Upload succeeded but no delivery URL.');
    }
    return InvestorMessageAttachment(
      url: url,
      name: file.name,
      mimeType: _mimeFor(file.extension),
      mediaId: asset.cloudinaryPublicId ?? asset.id,
    );
  }

  String? _mimeFor(String? ext) {
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
        return null;
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in subject and description')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(investorServiceProvider)
          .createTicket(
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim(),
            priority: _priority,
            attachments: _pendingAttachment == null
                ? const []
                : [_pendingAttachment!],
          );
      _subjectController.clear();
      _descriptionController.clear();
      setState(() {
        _priority = 'normal';
        _pendingAttachment = null;
        _pendingAttachmentName = null;
        _showTicketForm = false;
        _filter = PortalTicketHistoryFilter.open;
        _selectedTicketId = null;
      });
      ref.invalidate(investorTicketsProvider);
      ref.read(investorTicketsTickProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(
          context,
          e,
          fallback: 'Could not submit ticket. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendReply() async {
    final ticketId = _selectedTicketId;
    final message = _replyController.text.trim();
    if (ticketId == null || (message.isEmpty && _replyAttachment == null)) {
      return;
    }
    final body = message.isEmpty ? 'Attachment' : message;
    final pending = _PendingReply(ticketId, body, DateTime.now());
    final attachment = _replyAttachment;
    _replyController.clear();
    setState(() {
      _pending.add(pending);
      _replyAttachment = null;
      _replyAttachmentName = null;
    });
    try {
      await ref
          .read(investorServiceProvider)
          .sendTicketMessage(
            ticketId: ticketId,
            message: body,
            attachments: attachment == null ? const [] : [attachment],
          );
      ref.invalidate(investorTicketMessagesProvider(ticketId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        _replyAttachment = attachment;
      });
      if (_replyController.text.isEmpty) _replyController.text = message;
      showFriendlyError(
        context,
        e,
        fallback: 'Could not send reply. Please try again.',
      );
    }
  }

  Future<void> _transitionTicket(String action, {String? ticketId}) async {
    final targetId = ticketId ?? _selectedTicketId;
    if (targetId == null) return;
    try {
      await ref
          .read(investorServiceProvider)
          .transitionTicket(ticketId: targetId, action: action);
      ref.invalidate(investorTicketsProvider);
      ref.read(investorTicketsTickProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ticket status updated')));
      }
    } catch (e) {
      if (mounted) {
        showFriendlyError(context, e, fallback: 'Could not update the ticket.');
      }
    }
  }

  Future<void> _openAttachment(InvestorMessageAttachment a) async {
    final uri = Uri.tryParse(a.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get _initial {
    final name = ref.read(identitySessionProvider).profile?.displayName ?? '';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Y';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(investorPortalRealtimeHubProvider);
    final ticketsAsync = ref.watch(investorTicketsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    final tickets = ticketsAsync.valueOrNull;
    if (tickets == null) {
      if (ticketsAsync.hasError) {
        return InvestorErrorView(
          message: ticketsAsync.error!,
          onRetry: () => ref.invalidate(investorTicketsProvider),
        );
      }
      return const ColoredBox(
        color: PortalSupportDeskColors.canvas,
        child: InvestorPageSkeleton(showKpis: false, rows: 6),
      );
    }

    return () {
      final openCount = tickets
          .where((t) => !portalTicketStatusIsClosed(t.status))
          .length;
      final closedCount = tickets
          .where((t) => portalTicketStatusIsClosed(t.status))
          .length;
      final filtered = _filtered(tickets);

      if (wide &&
          filtered.isNotEmpty &&
          (_selectedTicketId == null ||
              !filtered.any((t) => t.id == _selectedTicketId))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedTicketId = filtered.first.id);
        });
      }
      if (filtered.isEmpty && _selectedTicketId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedTicketId = null);
        });
      }

      final selected = tickets
          .where((t) => t.id == _selectedTicketId)
          .firstOrNull;

      return PortalSupportDesk(
        filter: _filter,
        onFilter: (value) => setState(() {
          _filter = value;
          if (!wide) _selectedTicketId = null;
        }),
        allCount: tickets.length,
        openCount: openCount,
        closedCount: closedCount,
        onNewTicket: () => setState(() => _showTicketForm = !_showTicketForm),
        form: _showTicketForm ? _ticketForm() : null,
        tickets: [
          for (final t in filtered)
            PortalSupportDeskTicket(
              id: t.id,
              subject: t.subject,
              status: t.status,
              ticketNumber: t.ticketNumber,
              createdAt: t.createdAt,
              activityAt: t.updatedAt ?? t.createdAt,
              preview: t.description,
            ),
        ],
        selectedId: _selectedTicketId,
        onSelect: (id) => setState(() => _selectedTicketId = id),
        thread: _thread(selected, wide: wide),
      );
    }();
  }

  Widget _ticketForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PortalSupportDeskColors.line),
      ),
      child: Theme(
        data: _lightFormTheme(context),
        child: Column(
          children: [
            TextField(
              controller: _subjectController,
              cursorColor: PortalSupportDeskColors.ink,
              style: const TextStyle(color: PortalSupportDeskColors.ink),
              decoration: const InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: Color(0xFF5C564F)),
                filled: true,
                fillColor: PortalSupportDeskColors.canvas,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              cursorColor: PortalSupportDeskColors.ink,
              style: const TextStyle(color: PortalSupportDeskColors.ink),
              decoration: const InputDecoration(
                labelText: 'How can we help?',
                labelStyle: TextStyle(color: Color(0xFF5C564F)),
                filled: true,
                fillColor: PortalSupportDeskColors.canvas,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                labelStyle: TextStyle(color: Color(0xFF5C564F)),
                filled: true,
                fillColor: PortalSupportDeskColors.canvas,
              ),
              style: const TextStyle(color: PortalSupportDeskColors.ink),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) setState(() => _priority = value);
                    },
            ),
            if (_pendingAttachmentName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _pendingAttachmentName!,
                      style: const TextStyle(
                        color: PortalSupportDeskColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _pendingAttachment = null;
                      _pendingAttachmentName = null;
                    }),
                    style: IconButton.styleFrom(
                      foregroundColor: PortalSupportDeskColors.ink,
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: PortalSupportDeskColors.ink,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          try {
                            final attachment = await _pickAttachment(
                              onName: (name) =>
                                  setState(() => _pendingAttachmentName = name),
                            );
                            if (attachment != null) {
                              setState(() => _pendingAttachment = attachment);
                            }
                          } catch (e) {
                            if (mounted) {
                              showFriendlyError(
                                context,
                                e,
                                fallback: 'Could not attach the file.',
                              );
                            }
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: PortalSupportDeskColors.ink,
                  ),
                  child: const Text(
                    'Attach file',
                    style: TextStyle(
                      color: PortalSupportDeskColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _showTicketForm = false),
                  style: TextButton.styleFrom(
                    foregroundColor: PortalSupportDeskColors.ink,
                  ),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _submitting ? null : _submitTicket,
                  child: Text(_submitting ? 'Sending…' : 'Submit ticket'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ThemeData _lightFormTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: PortalSupportDeskColors.ink,
        onSurface: PortalSupportDeskColors.ink,
        onSurfaceVariant: Color(0xFF5C564F),
        surface: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF5C564F)),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PortalSupportDeskColors.ink,
        ),
      ),
    );
  }

  Widget _thread(InvestorSupportTicket? ticket, {required bool wide}) {
    if (ticket == null) {
      return PortalSupportDeskThread(
        ticket: null,
        messages: const [],
        loading: false,
        canReply: false,
        replyController: _replyController,
        onSend: _sendReply,
        sending: false,
      );
    }

    final deskTicket = PortalSupportDeskTicket(
      id: ticket.id,
      subject: ticket.subject,
      status: ticket.status,
      ticketNumber: ticket.ticketNumber,
      createdAt: ticket.createdAt,
      preview: ticket.description,
    );
    final closed = portalTicketStatusIsClosed(ticket.status);
    final messagesAsync = ref.watch(investorTicketMessagesProvider(ticket.id));

    Widget attachmentChip(InvestorMessageAttachment a) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: InkWell(
          onTap: () => _openAttachment(a),
          child: Text(
            a.name ?? 'Attachment',
            style: const TextStyle(
              decoration: TextDecoration.underline,
              color: Color(0xFF1C1915),
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final server = messagesAsync.valueOrNull ?? const <InvestorTicketMessage>[];
    final serverBodies = server.map((m) => m.message.trim()).toSet();
    final pending = [
      for (final p in _pending)
        if (p.ticketId == ticket.id && !serverBodies.contains(p.body)) p,
    ];
    final matched = _pending
        .where((p) => p.ticketId == ticket.id && serverBodies.contains(p.body))
        .toList();
    if (matched.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pending.removeWhere(matched.contains));
      });
    }

    return PortalSupportDeskThread(
      ticket: deskTicket,
      mineInitial: _initial,
      loading: messagesAsync.isLoading && server.isEmpty && pending.isEmpty,
      errorText: messagesAsync.hasError && server.isEmpty
          ? userFacingError(messagesAsync.error!)
          : null,
      messages: [
        for (final m in server)
          PortalSupportDeskMessage(
            body: m.message,
            isMine: m.isMine,
            senderName: m.senderName,
            createdAt: m.createdAt,
            attachment: m.attachments.isEmpty
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final a in m.attachments) attachmentChip(a),
                    ],
                  ),
          ),
        for (final p in pending)
          PortalSupportDeskMessage(
            body: p.body,
            isMine: true,
            createdAt: p.createdAt,
          ),
      ],
      canReply: !closed,
      replyController: _replyController,
      onSend: _sendReply,
      sending: false,
      onAttach: _attachReply,
      attachmentLabel: _replyAttachmentName,
      onClearAttachment: () => setState(() {
        _replyAttachment = null;
        _replyAttachmentName = null;
      }),
      onBack: wide ? null : () => setState(() => _selectedTicketId = null),
      onReopen: closed ? () => _transitionTicket('reopen') : null,
      onClose: closed ? null : () => _transitionTicket('close'),
      onConfirm: ticket.status == 'resolved'
          ? () => _transitionTicket('confirm_resolution')
          : null,
    );
  }

  Future<void> _attachReply() async {
    try {
      final attachment = await _pickAttachment(
        onName: (name) => setState(() => _replyAttachmentName = name),
      );
      if (attachment != null) setState(() => _replyAttachment = attachment);
    } catch (e) {
      if (mounted) {
        showFriendlyError(context, e, fallback: 'Could not attach the file.');
      }
    }
  }
}

class _PendingReply {
  _PendingReply(this.ticketId, this.body, this.createdAt);

  final String ticketId;
  final String body;
  final DateTime createdAt;
}
