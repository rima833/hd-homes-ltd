import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/investor/domain/entities/investor_models.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:hdhomesproject/features/investor/presentation/widgets/investor_portal_widgets.dart';
import 'package:hdhomesproject/features/shared/presentation/messaging/portal_inbox_models.dart';
import 'package:hdhomesproject/features/shared/presentation/messaging/portal_inbox_tile.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_messages_shell.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_shell.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class InvestorMessagesPage extends ConsumerStatefulWidget {
  const InvestorMessagesPage({super.key, this.openLiveChat = false});

  /// When true (e.g. `?live=1`), open on the Live chat tab.
  final bool openLiveChat;

  @override
  ConsumerState<InvestorMessagesPage> createState() =>
      _InvestorMessagesPageState();
}

class _InvestorMessagesPageState extends ConsumerState<InvestorMessagesPage> {
  String? _selectedConversationId;
  PortalInboxKind _selectedKind = PortalInboxKind.conversation;
  // Messages page is portal threads only (tickets live under Support).
  static const _channelFilter = PortalInboxFilter.messages;
  late PortalMessagesMode _mode = widget.openLiveChat
      ? PortalMessagesMode.liveChat
      : PortalMessagesMode.threads;
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _scrollController = ScrollController();
  bool _sending = false;
  int _lastScrolledCount = -1;
  InvestorMessageAttachment? _pendingAttachment;
  String? _pendingAttachmentName;
  Timer? _typingIdle;
  bool _localTyping = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
    _messageController.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _typingIdle?.cancel();
    unawaited(_setTyping(false));
    _messageController.removeListener(_onComposerChanged);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setTyping(bool isTyping) async {
    final id = _selectedConversationId;
    if (id == null || _localTyping == isTyping) return;
    _localTyping = isTyping;
    try {
      await ref.read(investorServiceProvider).setConversationTyping(
            conversationId: id,
            isTyping: isTyping,
            actor: 'investor',
          );
    } catch (_) {}
  }

  void _onComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    _typingIdle?.cancel();
    if (!hasText) {
      unawaited(_setTyping(false));
      return;
    }
    unawaited(_setTyping(true));
    _typingIdle = Timer(const Duration(milliseconds: 1800), () {
      unawaited(_setTyping(false));
    });
  }

  EdgeInsets _padding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.fromLTRB(
      w >= AppBreakpoints.tablet ? 8 : 8,
      4,
      8,
      4,
    );
  }

  InvestorConversation? _selectedOf(List<InvestorConversation> conversations) {
    final id = _selectedConversationId;
    if (id == null) return null;
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _selectItem(PortalInboxItem item) async {
    if (!item.isConversation) return;
    setState(() {
      _selectedConversationId = item.id;
      _selectedKind = PortalInboxKind.conversation;
      _lastScrolledCount = -1;
    });
    try {
      await ref.read(investorServiceProvider).markConversationRead(item.id);
      ref.read(investorMessagesTickProvider.notifier).state++;
      ref.invalidate(investorConversationsProvider);
    } catch (_) {}
  }

  Future<void> _selectConversation(String conversationId) async {
    await _selectItem(
      PortalInboxItem(
        id: conversationId,
        kind: PortalInboxKind.conversation,
        title: 'Conversation',
        preview: '',
        status: 'open',
      ),
    );
  }

  Future<void> _pickAttachment() async {
    final media = ref.read(mediaServiceProvider);
    if (media == null) {
      showFriendlyError(context, null, fallback: 'Media upload is unavailable.');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showFriendlyError(context, null, fallback: 'Could not read the file.');
      return;
    }
    setState(() => _sending = true);
    try {
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
              : 'hdhomes/investors/${record.id}/messages',
          role: 'evidence',
          title: 'Chat attachment',
        ),
      );
      final url = asset.secureUrl ?? asset.fileUrl ?? '';
      if (url.isEmpty) {
        throw const NetworkException('Upload succeeded but no delivery URL.');
      }
      if (!mounted) return;
      setState(() {
        _pendingAttachment = InvestorMessageAttachment(
          url: url,
          name: file.name,
          mimeType: _mimeFor(file.extension),
          mediaId: asset.cloudinaryPublicId ?? asset.id,
        );
        _pendingAttachmentName = file.name;
        _sending = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showFriendlyError(context, e, fallback: 'Attachment upload failed.');
      }
    }
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

  Future<void> _openAttachment(InvestorMessageAttachment a) async {
    final uri = Uri.tryParse(a.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    final convId = _selectedConversationId;
    final userId = ref.read(identitySessionProvider).userId;
    if ((body.isEmpty && _pendingAttachment == null) ||
        convId == null ||
        userId == null ||
        _sending) {
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(investorServiceProvider).sendMessage(
            conversationId: convId,
            senderId: userId,
            body: body.isEmpty ? 'Attachment' : body,
            attachments: _pendingAttachment == null
                ? const []
                : [_pendingAttachment!],
          );
      await _setTyping(false);
      _messageController.clear();
      setState(() {
        _pendingAttachment = null;
        _pendingAttachmentName = null;
      });
      ref.read(investorMessagesTickProvider.notifier).state++;
      ref.invalidate(investorConversationsProvider);
      ref.invalidate(investorConversationMessagesProvider(convId));
    } catch (e) {
      if (mounted) {
        showFriendlyError(context, e, fallback: 'Message failed to send.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom(int messageCount) {
    if (messageCount == _lastScrolledCount) return;
    _lastScrolledCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _showNewConversationDialog() async {
    final record = await ref.read(investorRecordProvider.future);
    final userId = ref.read(identitySessionProvider).userId;
    if (record == null || userId == null || !mounted) return;

    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    var category = 'support';
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.charcoal,
          title: const Text('New conversation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: 'portfolio',
                      child: Text('Portfolio'),
                    ),
                    DropdownMenuItem(value: 'finance', child: Text('Finance')),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                    DropdownMenuItem(value: 'legal', child: Text('Legal')),
                    DropdownMenuItem(
                      value: 'compliance',
                      child: Text('Compliance'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => category = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.charcoal,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      if (subjectController.text.trim().isEmpty ||
                          messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Subject and message are required'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final id = await ref
                            .read(investorServiceProvider)
                            .startConversation(
                              investorId: record.id,
                              subject: subjectController.text.trim(),
                              category: category,
                              senderId: userId,
                              initialMessage: messageController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.read(investorMessagesTickProvider.notifier).state++;
                        ref.invalidate(investorConversationsProvider);
                        await _selectConversation(id);
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(userFacingError(e))),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start'),
            ),
          ],
        ),
      ),
    );
    subjectController.dispose();
    messageController.dispose();
  }


  Future<void> _showComposeChooser() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12161D),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.messageCircle, color: AppColors.gold),
              title: const Text('New message'),
              subtitle: const Text('Account thread with IR'),
              onTap: () => Navigator.pop(ctx, 'message'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.messageSquare, color: AppColors.gold),
              title: const Text('Live chat'),
              subtitle: const Text('Talk to Concierge now'),
              onTap: () => Navigator.pop(ctx, 'live'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.ticket, color: AppColors.gold),
              title: const Text('Open a ticket'),
              subtitle: const Text('Tracked case on Support'),
              onTap: () => Navigator.pop(ctx, 'ticket'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'ticket') {
      context.go(RoutePaths.investorSupport);
    } else if (choice == 'live') {
      setState(() => _mode = PortalMessagesMode.liveChat);
    } else {
      setState(() => _mode = PortalMessagesMode.threads);
      await _showNewConversationDialog();
    }
  }

  Widget _conversationList(List<InvestorConversation> conversations) {
    final items = PortalInboxItem.merge(
      conversations: conversations
          .map(PortalInboxItem.fromInvestorConversation)
          .toList(),
      tickets: const [],
      filter: _channelFilter,
      query: _searchQuery,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMessagesPageHeader(
          onOpenSupport: () => context.go(RoutePaths.investorSupport),
          onNew: _showComposeChooser,
          mode: _mode,
          onModeChanged: (m) => setState(() => _mode = m),
          subtitle: _mode == PortalMessagesMode.liveChat
              ? 'Live chat with HD Homes Concierge.'
              : '${items.length} thread${items.length == 1 ? '' : 's'} · account messages with IR.',
        ),
        SizedBox(
          height: _mode == PortalMessagesMode.liveChat
              ? PortalMessagesSpacing.afterHeaderLive
              : PortalMessagesSpacing.afterHeader,
        ),
        if (_mode == PortalMessagesMode.liveChat)
          const Expanded(child: PortalMessagesLiveChatBlock())
        else ...[
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search messages…',
              prefixIcon: Icon(LucideIcons.search, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? InvestorEmptyState(
                    title: 'No messages yet',
                    message:
                        'Start a thread with investor relations, or switch to Live chat.',
                    icon: LucideIcons.messageSquare,
                    action: FilledButton.icon(
                      onPressed: _showComposeChooser,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('New'),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return PortalInboxItemTile(
                        item: item,
                        selected: item.id == _selectedConversationId &&
                            item.kind == _selectedKind,
                        onTap: () => _selectItem(item),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  Widget _messageThread(
    InvestorConversation? selected,
    AsyncValue<List<InvestorMessage>> messagesAsync,
  ) {
    if (_selectedConversationId == null) {
      return Center(
        child: InvestorEmptyState(
          title: 'Select a conversation',
          message: 'Choose a thread on the left or start a new one.',
          icon: LucideIcons.messagesSquare,
          action: FilledButton.icon(
            onPressed: _showNewConversationDialog,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('New conversation'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.charcoal,
            ),
          ),
        ),
      );
    }

    return messagesAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const InvestorPageSkeleton(showKpis: false, rows: 6),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () => ref.invalidate(
          investorConversationMessagesProvider(_selectedConversationId!),
        ),
      ),
      data: (messages) {
        _scrollToBottom(messages.length);
        return Column(
          children: [
            if (selected != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.neutral700.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${selected.category} · ${selected.status} · live',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate400,
                          ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? const InvestorEmptyState(
                      title: 'No messages yet',
                      message:
                          'Send the first message to get a reply from the team.',
                      icon: LucideIcons.messageCircle,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        return Align(
                          alignment: m.isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 420),
                            decoration: BoxDecoration(
                              color: m.isMine
                                  ? AppColors.gold
                                  : AppColors.darkSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: m.isMine
                                    ? AppColors.gold.withValues(alpha: 0.3)
                                    : AppColors.neutral700
                                        .withValues(alpha: 0.45),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!m.isMine &&
                                    (m.senderName?.trim().isNotEmpty == true)) ...[
                                  Text(
                                    m.senderName!.trim(),
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  m.body,
                                  style: TextStyle(
                                    color: m.isMine
                                        ? const Color(0xFF0B0E14)
                                        : AppColors.white,
                                  ),
                                ),
                                if (m.attachments.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...m.attachments.map(
                                    (a) => InkWell(
                                      onTap: () => _openAttachment(a),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.paperclip,
                                              size: 14,
                                              color: m.isMine
                                                  ? const Color(0xFF0B0E14)
                                                  : AppColors.gold,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                a.name ?? 'Attachment',
                                                style: TextStyle(
                                                  color: m.isMine
                                                      ? const Color(0xFF0B0E14)
                                                      : AppColors.gold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat.MMMd()
                                      .add_jm()
                                      .format(m.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                    color: m.isMine
                                        ? const Color(0xFF0B0E14)
                                            .withValues(alpha: 0.65)
                                        : AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: PortalSupportReplyComposer(
                controller: _messageController,
                onChanged: (_) => _onComposerChanged(),
                onSend: _sendMessage,
                sending: _sending,
                hintText: 'Type your message…',
                onAttach: _sending ? null : _pickAttachment,
                attachmentLabel: _pendingAttachmentName,
                onClearAttachment: _pendingAttachmentName == null
                    ? null
                    : () => setState(() {
                          _pendingAttachment = null;
                          _pendingAttachmentName = null;
                        }),
              ),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    ref.watch(investorPortalRealtimeHubProvider);
    final preferLive = ref.watch(portalMessagesOpenLiveChatProvider);
    if (preferLive && _mode != PortalMessagesMode.liveChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(portalMessagesOpenLiveChatProvider.notifier).state = false;
        setState(() => _mode = PortalMessagesMode.liveChat);
      });
    }
    final conversationsAsync = ref.watch(investorConversationsProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final pad = _padding(context);
    final messagesAsync = _selectedConversationId == null
        ? null
        : ref.watch(
            investorConversationMessagesProvider(_selectedConversationId!),
          );

    return conversationsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const InvestorPageSkeleton(showKpis: false, rows: 6),
      error: (e, _) => InvestorErrorView(
        message: e,
        onRetry: () => ref.invalidate(investorConversationsProvider),
      ),
      data: (conversations) {
        final selected = _selectedOf(conversations);
        final thread = _messageThread(
          selected,
          messagesAsync ?? const AsyncValue.data([]),
        );

        if (isDesktop) {
          if (_mode == PortalMessagesMode.liveChat) {
            return Padding(
              padding: pad,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PortalMessagesPageHeader(
                    onOpenSupport: () => context.go(RoutePaths.investorSupport),
                    onNew: _showComposeChooser,
                    mode: _mode,
                    onModeChanged: (m) => setState(() => _mode = m),
                    subtitle: 'Live chat with HD Homes Concierge.',
                  ),
                  const SizedBox(height: PortalMessagesSpacing.afterHeaderLive),
                  const Expanded(child: PortalMessagesLiveChatBlock()),
                ],
              ),
            );
          }
          return Padding(
            padding: pad,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: _conversationList(conversations),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: PortalMessagesPanelShell(child: thread),
                ),
              ],
            ),
          );
        }

        if (_mode == PortalMessagesMode.liveChat) {
          return Padding(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PortalMessagesPageHeader(
                  onOpenSupport: () => context.go(RoutePaths.investorSupport),
                  onNew: _showComposeChooser,
                  mode: _mode,
                  onModeChanged: (m) => setState(() => _mode = m),
                  subtitle: 'Live chat with HD Homes Concierge.',
                ),
                const SizedBox(height: PortalMessagesSpacing.afterHeaderLive),
                const Expanded(child: PortalMessagesLiveChatBlock()),
              ],
            ),
          );
        }

        if (_selectedConversationId != null) {
          return Padding(
            padding: pad,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() {
                        _selectedConversationId = null;
                        _lastScrolledCount = -1;
                      }),
                      icon: const Icon(LucideIcons.arrowLeft),
                    ),
                    Expanded(
                      child: Text(
                        selected?.subject ?? 'Conversation',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PortalMessagesPanelShell(child: thread),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: pad,
          child: _conversationList(conversations),
        );
      },
    );
  }
}
