import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_desk.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_shell.dart';

class ClientSupportPage extends ConsumerStatefulWidget {
  const ClientSupportPage({super.key});

  @override
  ConsumerState<ClientSupportPage> createState() => _ClientSupportPageState();
}

class _ClientSupportPageState extends ConsumerState<ClientSupportPage> {
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _replyController = TextEditingController();
  bool _submitting = false;
  bool _showTicketForm = false;
  String? _selectedTicketId;
  PortalTicketHistoryFilter _filter = PortalTicketHistoryFilter.all;
  final List<_PendingReply> _pending = [];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  List<ClientSupportTicket> _filtered(List<ClientSupportTicket> tickets) {
    return switch (_filter) {
      PortalTicketHistoryFilter.all => tickets,
      PortalTicketHistoryFilter.open =>
        tickets.where((t) => !portalTicketStatusIsClosed(t.status)).toList(),
      PortalTicketHistoryFilter.closed =>
        tickets.where((t) => portalTicketStatusIsClosed(t.status)).toList(),
    };
  }

  String get _initial {
    final name = ref.read(identitySessionProvider).profile?.displayName ?? '';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Y';
    return trimmed[0].toUpperCase();
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in subject and details')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(clientServiceProvider)
          .createTicket(
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim(),
            priority: 'normal',
          );
      _subjectController.clear();
      _descriptionController.clear();
      ref.invalidate(clientTicketsProvider);
      ref.read(clientTicketMessagesTickProvider.notifier).state++;
      if (mounted) {
        setState(() {
          _showTicketForm = false;
          _filter = PortalTicketHistoryFilter.open;
          _selectedTicketId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendReply() async {
    final ticketId = _selectedTicketId;
    final message = _replyController.text.trim();
    if (ticketId == null || message.isEmpty) return;
    final pending = _PendingReply(ticketId, message, DateTime.now());
    _replyController.clear();
    setState(() => _pending.add(pending));
    try {
      await ref
          .read(clientServiceProvider)
          .sendTicketMessage(ticketId: ticketId, message: message);
      ref.invalidate(clientTicketMessagesProvider(ticketId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _pending.remove(pending));
      if (_replyController.text.isEmpty) _replyController.text = message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userFacingError(
              e,
              fallback: 'Could not send reply. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _transitionTicket(String action, {String? ticketId}) async {
    final targetId = ticketId ?? _selectedTicketId;
    if (targetId == null) return;
    try {
      await ref
          .read(clientServiceProvider)
          .transitionTicket(ticketId: targetId, action: action);
      ref.invalidate(clientTicketsProvider);
      ref.read(clientTicketMessagesTickProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ticket status updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(clientTicketsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1080;
    final tickets = ticketsAsync.valueOrNull;
    if (tickets == null) {
      if (ticketsAsync.hasError) {
        return ClientErrorView(
          message: ticketsAsync.error!,
          onRetry: () => ref.invalidate(clientTicketsProvider),
        );
      }
      return const ColoredBox(
        color: PortalSupportDeskColors.canvas,
        child: ClientPageSkeleton(showKpis: false),
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
            Row(
              children: [
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

  Widget _thread(ClientSupportTicket? ticket, {required bool wide}) {
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
    final messagesAsync = ref.watch(clientTicketMessagesProvider(ticket.id));
    final server = messagesAsync.valueOrNull ?? const <ClientTicketMessage>[];
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
      onBack: wide ? null : () => setState(() => _selectedTicketId = null),
      onReopen: closed ? () => _transitionTicket('reopen') : null,
      onClose: closed ? null : () => _transitionTicket('close'),
      onConfirm: ticket.status == 'resolved'
          ? () => _transitionTicket('confirm_resolution')
          : null,
    );
  }
}

class _PendingReply {
  _PendingReply(this.ticketId, this.body, this.createdAt);

  final String ticketId;
  final String body;
  final DateTime createdAt;
}
