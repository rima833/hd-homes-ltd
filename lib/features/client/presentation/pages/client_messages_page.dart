import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_portal_realtime_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_messages_widgets.dart';
import 'package:hdhomesproject/features/shared/presentation/messaging/portal_inbox_models.dart';
import 'package:hdhomesproject/features/shared/presentation/messaging/portal_inbox_tile.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_portal_widgets.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_messages_shell.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ClientMessagesPage extends ConsumerStatefulWidget {
  const ClientMessagesPage({super.key, this.openLiveChat = false});

  /// When true (e.g. `?live=1`), open on the Live chat tab.
  final bool openLiveChat;

  @override
  ConsumerState<ClientMessagesPage> createState() =>
      _ClientMessagesPageState();
}

class _ClientMessagesPageState extends ConsumerState<ClientMessagesPage> {
  String? _selectedConversationId;
  PortalInboxKind _selectedKind = PortalInboxKind.conversation;
  // Messages page is portal threads only (tickets live under Support).
  static const _channelFilter = PortalInboxFilter.messages;
  late PortalMessagesMode _mode = widget.openLiveChat
      ? PortalMessagesMode.liveChat
      : PortalMessagesMode.threads;
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _threadScrollController = ScrollController();
  Timer? _typingDebounce;
  Timer? _typingIdle;
  Timer? _typingUiTick;
  bool _localTyping = false;
  bool _sending = false;
  String _searchQuery = '';
  String? _categoryFilter;
  int _lastScrolledMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingIdle?.cancel();
    _typingUiTick?.cancel();
    _clearTyping();
    _messageController.dispose();
    _searchController.dispose();
    _threadScrollController.dispose();
    super.dispose();
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

  List<ClientConversation> _filterConversations(
    List<ClientConversation> conversations,
  ) {
    var list = conversations;
    if (_categoryFilter != null) {
      list = list.where((c) => c.category == _categoryFilter).toList();
    }
    if (_searchQuery.isEmpty) return list;
    return list.where((c) {
      final hay = [
        c.subject,
        c.teamLabel,
        c.lastMessagePreview ?? '',
        c.category,
      ].join(' ').toLowerCase();
      return hay.contains(_searchQuery);
    }).toList();
  }

  Future<void> _pickCategoryFilter() async {
    const categories = <String?, String>{
      null: 'All teams',
      'sales': 'Sales',
      'support': 'Support',
      'finance': 'Finance',
      'legal': 'Legal',
      'manager': 'Manager',
    };
    final picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: const Color(0xFF12161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in categories.entries)
              ListTile(
                title: Text(entry.value),
                trailing: _categoryFilter == entry.key
                    ? const Icon(LucideIcons.check, color: AppColors.gold)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == _categoryFilter) return;
    setState(() => _categoryFilter = picked);
  }

  Future<void> _searchInThread(List<ClientMessage> messages) async {
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF12161D),
          title: const Text('Search in conversation'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search message text…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Find'),
            ),
          ],
        );
      },
    );
    if (q == null || q.isEmpty || !mounted) return;
    final needle = q.toLowerCase();
    final hit = messages.indexWhere((m) => m.body.toLowerCase().contains(needle));
    if (hit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No messages matching "$q"')),
      );
      return;
    }
    if (_threadScrollController.hasClients) {
      await _threadScrollController.animateTo(
        _threadScrollController.position.maxScrollExtent * (hit / messages.length),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _selectItem(PortalInboxItem item) async {
    if (_selectedConversationId == item.id && _selectedKind == item.kind) return;
    if (!item.isConversation) return;
    await _clearTyping();
    setState(() {
      _selectedConversationId = item.id;
      _selectedKind = PortalInboxKind.conversation;
      _lastScrolledMessageCount = -1;
    });
    try {
      await ref.read(clientServiceProvider).markConversationRead(item.id);
      ref.invalidate(clientConversationsProvider);
      ref.read(clientMessagesTickProvider.notifier).state++;
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

  Future<void> _showComposeChooser() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF12161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.messageCircle, color: AppColors.gold),
              title: const Text('New message'),
              subtitle: const Text('Account thread with HD Homes'),
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
      context.go(RoutePaths.clientSupport);
    } else if (choice == 'live') {
      setState(() => _mode = PortalMessagesMode.liveChat);
    } else {
      setState(() => _mode = PortalMessagesMode.threads);
      await _showNewConversationDialog();
    }
  }

  void _scrollThreadToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_threadScrollController.hasClients) return;
      _threadScrollController.animateTo(
        _threadScrollController.position.maxScrollExtent,
        duration: AppDurations.normal,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearTyping() async {
    final convId = _selectedConversationId;
    if (convId == null || !_localTyping) return;
    _localTyping = false;
    await ref.read(clientServiceProvider).setConversationTyping(
          conversationId: convId,
          isTyping: false,
        );
  }

  void _onComposerChanged(String text) {
    final convId = _selectedConversationId;
    if (convId == null) return;

    final hasText = text.trim().isNotEmpty;
    _typingIdle?.cancel();

    if (!hasText) {
      unawaited(_clearTyping());
      return;
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!_localTyping) {
        _localTyping = true;
        unawaited(
          ref.read(clientServiceProvider).setConversationTyping(
                conversationId: convId,
                isTyping: true,
              ),
        );
      }
    });

    _typingIdle = Timer(const Duration(milliseconds: 1800), () {
      unawaited(_clearTyping());
    });
  }

  void _ensureTypingTicker(bool staffIsTyping) {
    if (staffIsTyping && (_typingUiTick == null || !_typingUiTick!.isActive)) {
      _typingUiTick?.cancel();
      _typingUiTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!staffIsTyping) {
      _typingUiTick?.cancel();
      _typingUiTick = null;
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    final convId = _selectedConversationId;
    final userId = ref.read(identitySessionProvider).userId;
    if (body.isEmpty || convId == null || userId == null || _sending) return;

    setState(() => _sending = true);
    await _clearTyping();
    _messageController.clear();

    try {
      await ref.read(clientServiceProvider).sendMessage(
            conversationId: convId,
            senderId: userId,
            body: body,
          );
      ref.read(clientMessagesTickProvider.notifier).state++;
      ref.invalidate(clientConversationsProvider);
      ref.invalidate(clientConversationMessagesProvider(convId));
      ref.invalidate(clientConversationDetailProvider(convId));
      _scrollThreadToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachFile() async {
    final media = ref.read(mediaServiceProvider);
    if (media == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media upload is unavailable')),
      );
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the file')),
        );
        return;
      }
      setState(() => _sending = true);
      final asset = await media.upload(
        UploadMediaRequest(
          bytes: Uint8List.fromList(bytes),
          contentType: switch (file.extension?.toLowerCase()) {
            'pdf' => 'application/pdf',
            'png' => 'image/png',
            'webp' => 'image/webp',
            'jpg' || 'jpeg' => 'image/jpeg',
            _ => 'application/octet-stream',
          },
          originalFilename: file.name,
          entityType: MediaEntityType.crm,
          entityId: _selectedConversationId,
          folder: _selectedConversationId == null
              ? 'hdhomes/clients/messages'
              : 'hdhomes/clients/messages/$_selectedConversationId',
          role: 'evidence',
          title: 'Client message attachment',
        ),
      );
      final url = asset.secureUrl ?? asset.fileUrl ?? '';
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload succeeded but no delivery URL')),
        );
        return;
      }
      final prefix = _messageController.text.trim();
      final link = '[${file.name}]($url)';
      _messageController.text = prefix.isEmpty ? link : '$prefix\n$link';
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
      _onComposerChanged(_messageController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment added — send to include the link'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showNewConversationDialog() async {
    final record = await ref.read(clientRecordProvider.future);
    final userId = ref.read(identitySessionProvider).userId;
    if (record == null || userId == null || !mounted) return;

    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    var category = 'sales';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF12161D),
          title: const Text('Start a new conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: const Color(0xFF1A1F28),
                decoration: const InputDecoration(labelText: 'Team'),
                items: const [
                  DropdownMenuItem(value: 'sales', child: Text('Sales Team')),
                  DropdownMenuItem(value: 'support', child: Text('Support Team')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance Team')),
                  DropdownMenuItem(value: 'legal', child: Text('Legal Team')),
                  DropdownMenuItem(value: 'manager', child: Text('Account Manager')),
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
                decoration: const InputDecoration(labelText: 'First message'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (subjectController.text.isEmpty ||
                    messageController.text.isEmpty) {
                  return;
                }
                try {
                  final id = await ref
                      .read(clientServiceProvider)
                      .startConversation(
                        clientId: record.id,
                        subject: subjectController.text,
                        category: category,
                        senderId: userId,
                        initialMessage: messageController.text,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(clientConversationsProvider);
                  await _selectConversation(id);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(userFacingError(e))),
                    );
                  }
                }
              },
              child: const Text('Start conversation'),
            ),
          ],
        ),
      ),
    );
    subjectController.dispose();
    messageController.dispose();
  }

  Widget _listHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalMessagesPageHeader(
          onOpenSupport: () => context.go(RoutePaths.clientSupport),
          onNew: _showComposeChooser,
          newIsIconOnly: true,
          mode: _mode,
          onModeChanged: (m) => setState(() => _mode = m),
          subtitle: _mode == PortalMessagesMode.liveChat
              ? 'Live chat with HD Homes Concierge.'
              : 'Account threads and live chat with HD Homes.',
        ),
        if (_mode == PortalMessagesMode.threads) ...[
          const SizedBox(height: PortalMessagesSpacing.afterHeader),
          ClientMessagesSearchField(
            controller: _searchController,
            onFilter: _pickCategoryFilter,
            categoryFilter: _categoryFilter,
          ),
        ],
      ],
    );
  }

  Widget _conversationList(List<ClientConversation> conversations) {
    final filteredConversations = _filterConversations(conversations);
    final items = PortalInboxItem.merge(
      conversations: filteredConversations
          .map(PortalInboxItem.fromClientConversation)
          .toList(),
      tickets: const [],
      filter: _channelFilter,
      query: _searchQuery,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _listHeader(),
        SizedBox(
          height: _mode == PortalMessagesMode.liveChat
              ? PortalMessagesSpacing.afterHeaderLive
              : 12,
        ),
        if (_mode == PortalMessagesMode.liveChat)
          const Expanded(child: PortalMessagesLiveChatBlock())
        else
          Expanded(
            child: items.isEmpty
                ? ClientEmptyState(
                    title: 'No messages yet',
                    message:
                        'Start a thread with HD Homes, or switch to Live chat.',
                    icon: LucideIcons.messageSquare,
                    action: TextButton(
                      onPressed: () =>
                          setState(() => _mode = PortalMessagesMode.liveChat),
                      child: const Text('Open Live chat'),
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
    );
  }

  Widget _buildMessageThread(
    ClientConversation? conversation,
    List<ClientMessage> messages, {
    bool loading = false,
  }) {
    if (_selectedConversationId == null) {
      return const ClientMessagesEmptyThread();
    }
    if (loading) {
      return const ClientCardSkeleton(height: 160);
    }

    final conv = conversation;
    final staffTyping = conv?.staffIsTyping ?? false;
    _ensureTypingTicker(staffTyping);

    if (messages.length != _lastScrolledMessageCount) {
      _lastScrolledMessageCount = messages.length;
      _scrollThreadToBottom();
    }

    return Column(
      children: [
        if (conv != null)
          ClientChatHeader(
            conversation: conv,
            supportPhone: ref.watch(contactHubCmsProvider).phone,
            supportOnline:
                ref.watch(liveChatSupportPresenceProvider).valueOrNull?.online,
            onSearchInThread: messages.isEmpty
                ? null
                : () => _searchInThread(messages),
          ),
        Expanded(
          child: messages.isEmpty
              ? const ClientEmptyState(
                  title: 'No messages yet',
                  message: 'Send a message to start the conversation.',
                  icon: LucideIcons.messageCircle,
                )
              : ListView.builder(
                  controller: _threadScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  itemCount: messages.length + (staffTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (staffTyping && index == messages.length) {
                      return ClientMessagesTypingRow(
                        teamLabel: conv?.teamLabel ?? 'Team',
                      );
                    }

                    final m = messages[index];
                    final showAvatar = index == 0 ||
                        messages[index - 1].isMine != m.isMine ||
                        m.createdAt
                                .difference(messages[index - 1].createdAt)
                                .inMinutes >
                            15;

                    final showDay = index == 0 ||
                        clientMessageDayLabel(m.createdAt) !=
                            clientMessageDayLabel(messages[index - 1].createdAt);

                    return Column(
                      children: [
                        if (showDay)
                          ClientMessagesDateSeparator(
                            label: clientMessageDayLabel(m.createdAt),
                          ),
                        ClientMessageBubble(
                          message: m,
                          showAvatar: !m.isMine && showAvatar,
                          avatarInitial: conv?.avatarInitial ?? 'H',
                          avatarColor: teamAvatarColor(conv?.category ?? ''),
                        ),
                      ],
                    );
                  },
                ),
        ),
        Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.enter): const _SendIntent(),
          },
          child: Actions(
            actions: {
              _SendIntent: CallbackAction<_SendIntent>(
                onInvoke: (_) {
                  _sendMessage();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: false,
              child: ClientMessagesComposer(
                controller: _messageController,
                onChanged: _onComposerChanged,
                onSend: _sendMessage,
                onAttach: _attachFile,
                sending: _sending,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clientPortalRealtimeHubProvider);
    ref.watch(clientRecordProvider);
    final preferLive = ref.watch(portalMessagesOpenLiveChatProvider);
    if (preferLive && _mode != PortalMessagesMode.liveChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(portalMessagesOpenLiveChatProvider.notifier).state = false;
        setState(() => _mode = PortalMessagesMode.liveChat);
      });
    }

    final conversationsAsync = ref.watch(clientConversationsProvider);
    final selectedId = _selectedConversationId;
    final messagesAsync = selectedId == null
        ? null
        : ref.watch(clientConversationMessagesProvider(selectedId));
    final conversationAsync = selectedId == null
        ? null
        : ref.watch(clientConversationDetailProvider(selectedId));
    final isDesktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;

    return conversationsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const ClientPageSkeleton(showKpis: false),
      error: (e, _) => ClientErrorView(
        message: e,
        onRetry: () => ref.invalidate(clientConversationsProvider),
      ),
      data: (conversations) {
        final inboxItems = PortalInboxItem.merge(
          conversations: conversations
              .map(PortalInboxItem.fromClientConversation)
              .toList(),
          tickets: const [],
          filter: _channelFilter,
          query: _searchQuery,
        );

        if (_selectedConversationId == null &&
            inboxItems.isNotEmpty &&
            isDesktop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedConversationId == null) {
              _selectItem(inboxItems.first);
            }
          });
        }

        Widget threadPane() {
          if (selectedId == null) {
            return _buildMessageThread(null, const []);
          }
          return conversationAsync!.when(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            loading: () => _buildMessageThread(null, const [], loading: true),
            error: (_, __) => messagesAsync!.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => _buildMessageThread(null, const [], loading: true),
              error: (e, _) => ClientErrorView(
                message: e,
                onRetry: () {
                  ref.invalidate(clientConversationMessagesProvider(selectedId));
                  ref.invalidate(clientConversationDetailProvider(selectedId));
                },
              ),
              data: (messages) => _buildMessageThread(null, messages),
            ),
            data: (conversation) => messagesAsync!.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () =>
                  _buildMessageThread(conversation, const [], loading: true),
              error: (e, _) => ClientErrorView(
                message: e,
                onRetry: () {
                  ref.invalidate(clientConversationMessagesProvider(selectedId));
                  ref.invalidate(clientConversationDetailProvider(selectedId));
                },
              ),
              data: (messages) =>
                  _buildMessageThread(conversation, messages),
            ),
          );
        }

        if (isDesktop) {
          if (_mode == PortalMessagesMode.liveChat) {
            return Padding(
              padding: _padding(context),
              child: _conversationList(conversations),
            );
          }
          return Padding(
            padding: _padding(context),
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
                  child: ClientMessagesPanelShell(child: threadPane()),
                ),
              ],
            ),
          );
        }

        if (_mode == PortalMessagesMode.liveChat) {
          return Padding(
            padding: _padding(context),
            child: _conversationList(conversations),
          );
        }

        if (selectedId != null) {
          return Padding(
            padding: _padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        await _clearTyping();
                        setState(() => _selectedConversationId = null);
                      },
                      icon: const Icon(LucideIcons.arrowLeft),
                    ),
                    Text(
                      'Messages',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                Expanded(
                  child: ClientMessagesPanelShell(child: threadPane()),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: _padding(context),
          child: _conversationList(conversations),
        );
      },
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}
