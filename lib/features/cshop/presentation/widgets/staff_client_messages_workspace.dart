import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_providers.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_portal_chrome.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_messages_widgets.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/staff_portal_conversation.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/support_desk_chrome.dart';
import 'package:hdhomesproject/features/investor/presentation/providers/investor_providers.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum _PortalFilter { all, client, investor }

/// Staff reply surface for portal account conversations (client + investor).
class StaffClientMessagesWorkspace extends ConsumerStatefulWidget {
  const StaffClientMessagesWorkspace({
    super.key,
    required this.selectedConversationId,
    required this.onSelect,
    this.deskNav,
  });

  /// Composite selection key: `client:<uuid>` or `investor:<uuid>`.
  final String? selectedConversationId;
  final ValueChanged<String?> onSelect;

  /// Tickets / Live Chat / Portal Messages, sized to this left column.
  final Widget? deskNav;

  @override
  ConsumerState<StaffClientMessagesWorkspace> createState() =>
      _StaffClientMessagesWorkspaceState();
}

class _StaffClientMessagesWorkspaceState
    extends ConsumerState<StaffClientMessagesWorkspace> {
  final _composer = TextEditingController();
  final _search = TextEditingController();
  Timer? _typingIdle;
  Timer? _typingUiTick;
  bool _localTyping = false;
  bool _sending = false;
  bool _emojiOpen = false;
  bool _attaching = false;
  _PortalFilter _filter = _PortalFilter.all;

  @override
  void dispose() {
    _typingIdle?.cancel();
    _typingUiTick?.cancel();
    unawaited(_setTyping(false));
    _composer.dispose();
    _search.dispose();
    super.dispose();
  }

  StaffPortalKind? get _selectedKind {
    return StaffPortalConversation.parseSelectionKey(
      widget.selectedConversationId,
    )?.$1;
  }

  String? get _selectedId {
    return StaffPortalConversation.parseSelectionKey(
      widget.selectedConversationId,
    )?.$2;
  }

  Future<void> _setTyping(bool isTyping) async {
    final kind = _selectedKind;
    final id = _selectedId;
    if (id == null || kind == null) return;
    if (_localTyping == isTyping) return;
    _localTyping = isTyping;
    try {
      if (kind == StaffPortalKind.client) {
        await ref
            .read(clientServiceProvider)
            .setConversationTyping(
              conversationId: id,
              isTyping: isTyping,
              actor: 'staff',
            );
      } else {
        await ref
            .read(investorServiceProvider)
            .setConversationTyping(
              conversationId: id,
              isTyping: isTyping,
              actor: 'staff',
            );
      }
    } catch (_) {}
  }

  void _onChanged(String text) {
    final hasText = text.trim().isNotEmpty;
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

  void _onSelect(StaffPortalConversation conversation) {
    widget.onSelect(conversation.selectionKey);
    unawaited(_markRead(conversation));
  }

  Future<void> _markRead(StaffPortalConversation conversation) async {
    try {
      if (conversation.kind == StaffPortalKind.client) {
        await ref
            .read(clientServiceProvider)
            .markConversationRead(conversation.id);
      } else {
        await ref
            .read(investorServiceProvider)
            .markConversationRead(conversation.id);
      }
      ref.invalidate(staffPortalConversationsProvider);
    } catch (_) {}
  }

  Future<void> _send() async {
    final kind = _selectedKind;
    final id = _selectedId;
    final body = _composer.text.trim();
    final userId = ref.read(identitySessionProvider).userId;
    if (kind == null ||
        id == null ||
        body.isEmpty ||
        userId == null ||
        _sending) {
      return;
    }
    setState(() => _sending = true);
    await _setTyping(false);
    try {
      if (kind == StaffPortalKind.client) {
        await ref
            .read(clientServiceProvider)
            .sendMessage(
              conversationId: id,
              senderId: userId,
              body: body,
              actor: 'staff',
            );
        ref.read(clientMessagesTickProvider.notifier).state++;
      } else {
        await ref
            .read(investorServiceProvider)
            .sendMessage(
              conversationId: id,
              senderId: userId,
              body: body,
              actor: 'staff',
            );
        ref.read(investorMessagesTickProvider.notifier).state++;
      }
      _composer.clear();
      setState(() => _emojiOpen = false);
      ref.invalidate(staffPortalConversationsProvider);
      ref.invalidate(
        staffPortalMessagesProvider(widget.selectedConversationId!),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
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
      setState(() => _attaching = true);
      final conversationId = _selectedId;
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
          entityId: conversationId,
          folder: conversationId == null
              ? 'hdhomes/support/portal'
              : 'hdhomes/support/portal/$conversationId',
          role: 'evidence',
          title: 'Portal message attachment',
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
      final prefix = _composer.text.trim();
      final link = '[${file.name}]($url)';
      _composer.text = prefix.isEmpty ? link : '$prefix\n$link';
      _composer.selection = TextSelection.collapsed(
        offset: _composer.text.length,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachment added — send to include the link'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  void _tickIfTyping(bool peerTyping) {
    if (peerTyping && (_typingUiTick == null || !_typingUiTick!.isActive)) {
      _typingUiTick?.cancel();
      _typingUiTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!peerTyping) {
      _typingUiTick?.cancel();
      _typingUiTick = null;
    }
  }

  List<StaffPortalConversation> _filtered(List<StaffPortalConversation> all) {
    final byKind = switch (_filter) {
      _PortalFilter.all => all,
      _PortalFilter.client =>
        all.where((c) => c.kind == StaffPortalKind.client).toList(),
      _PortalFilter.investor =>
        all.where((c) => c.kind == StaffPortalKind.investor).toList(),
    };
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return byKind;
    return all.where((c) => _matchesQuery(c, query)).toList();
  }

  bool _matchesQuery(StaffPortalConversation conversation, String query) {
    final haystack = [
      conversation.listTitle,
      conversation.subject,
      conversation.category,
      conversation.kindLabel,
      conversation.channelLabel,
      conversation.status,
      conversation.lastMessagePreview ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  Widget _deskSearch() {
    return TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search clients and investors',
        hintStyle: const TextStyle(
          color: SupportDeskChrome.muted,
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          LucideIcons.search,
          size: 16,
          color: SupportDeskChrome.muted,
        ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0F1218),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SupportDeskChrome.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: SupportDeskChrome.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }

  bool _peerTyping(StaffPortalConversation conversation) {
    final overrides = ref.read(portalPeerTypingAtProvider);
    if (overrides.containsKey(conversation.selectionKey)) {
      final at = overrides[conversation.selectionKey];
      if (at == null) return false;
      return DateTime.now().difference(at) < const Duration(seconds: 4);
    }
    return conversation.peerTyping;
  }

  @override
  Widget build(BuildContext context) {
    final sidebarCollapsed = ref.watch(adminSidebarCollapsedProvider);
    ref.watch(portalPeerTypingAtProvider);
    final conversationsAsync = ref.watch(staffPortalConversationsProvider);
    final loaded = conversationsAsync.valueOrNull;
    if (loaded == null) {
      return _PortalDeskShell(
        sidebarCollapsed: sidebarCollapsed,
        deskNav: widget.deskNav,
        search: _deskSearch(),
        loading: !conversationsAsync.hasError,
        message: conversationsAsync.hasError
            ? userFacingError(conversationsAsync.error!)
            : 'Loading portal conversations',
        onRetry: conversationsAsync.hasError
            ? () => ref.invalidate(staffPortalConversationsProvider)
            : null,
      );
    }
    final allConversations = loaded;
    if (allConversations.isEmpty) {
      return _PortalDeskShell(
        sidebarCollapsed: sidebarCollapsed,
        deskNav: widget.deskNav,
        search: _deskSearch(),
        message:
            'No portal conversations yet. Threads appear here when a client or investor starts one from Messages.',
      );
    }
    {
      final conversations = _filtered(allConversations);

      final selectedKey =
          widget.selectedConversationId ??
          (conversations.isNotEmpty
              ? conversations.first.selectionKey
              : allConversations.first.selectionKey);

      if (widget.selectedConversationId == null && conversations.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onSelect(conversations.first);
        });
      }

      StaffPortalConversation? selectedMatch;
      for (final c in allConversations) {
        if (c.selectionKey == selectedKey) {
          selectedMatch = c;
          break;
        }
      }
      final selected =
          selectedMatch ??
          (conversations.isNotEmpty
              ? conversations.first
              : allConversations.first);

      final messagesAsync = ref.watch(
        staffPortalMessagesProvider(selected.selectionKey),
      );
      final peerTyping = _peerTyping(selected);
      _tickIfTyping(peerTyping);

      return LayoutBuilder(
        builder: (context, constraints) {
          final showRail = sidebarCollapsed && constraints.maxWidth >= 760;
          final listWidth = showRail
              ? 260.0
              : (constraints.maxWidth >= 900 ? 300.0 : 240.0);
          return ColoredBox(
            color: SupportDeskChrome.bg,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: listWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: SupportDeskChrome.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SupportDeskChrome.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.deskNav != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  0,
                                ),
                                child: widget.deskNav,
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                              child: _deskSearch(),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.goldGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      LucideIcons.messagesSquare,
                                      size: 14,
                                      color: Color(0xFF0B0E14),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Portal Messages',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        Text(
                                          'Client & investor threads · ${conversations.length} of ${allConversations.length}',
                                          style: const TextStyle(
                                            color: SupportDeskChrome.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1218),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: SupportDeskChrome.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    for (final f in _PortalFilter.values)
                                      Expanded(
                                        child: _PortalKindSeg(
                                          label: switch (f) {
                                            _PortalFilter.all => 'All',
                                            _PortalFilter.client => 'Client',
                                            _PortalFilter.investor =>
                                              'Investor',
                                          },
                                          selected: _filter == f,
                                          onTap: () =>
                                              setState(() => _filter = f),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              color: SupportDeskChrome.border,
                            ),
                            Expanded(
                              child: conversations.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          _search.text.trim().isEmpty
                                              ? 'No conversations in this filter.'
                                              : 'No client or investor threads match that search.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: SupportDeskChrome.muted,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        12,
                                      ),
                                      itemCount: conversations.length,
                                      itemBuilder: (_, i) {
                                        final c = conversations[i];
                                        final typing = _peerTyping(c);
                                        final preview = typing
                                            ? '${c.kindLabel} is typing…'
                                            : (c.lastMessagePreview
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? c.lastMessagePreview!.trim()
                                                  : c.subject);
                                        return SupportConversationTile(
                                          title: c.listTitle,
                                          subtitle: c.channelLabel,
                                          tag: c.kindLabel,
                                          tagColor:
                                              c.kind == StaffPortalKind.investor
                                              ? AppColors.info
                                              : AppColors.gold,
                                          preview: preview,
                                          time: SupportDeskChrome.timeLabel(
                                            c.lastMessageAt,
                                          ),
                                          status: c.status,
                                          unread: c.unreadCount > 0
                                              ? c.unreadCount
                                              : null,
                                          online: typing || c.status == 'open',
                                          selected:
                                              c.selectionKey == selectedKey,
                                          onTap: () => _onSelect(c),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SupportPaneGutter(),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: SupportDeskChrome.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SupportDeskChrome.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          children: [
                            SupportThreadHeader(
                              title: selected.subject.trim().isNotEmpty
                                  ? selected.subject
                                  : selected.listTitle,
                              subtitle:
                                  selected.displayName?.trim().isNotEmpty ==
                                      true
                                  ? '${selected.displayName} · ${selected.channelLabel}'
                                  : selected.channelLabel,
                              online: selected.status == 'open',
                              trailing: SupportStatusBadge(
                                status: selected.status,
                              ),
                            ),
                            Expanded(
                              child: messagesAsync.when(
                                skipLoadingOnReload: true,
                                skipLoadingOnRefresh: true,
                                loading: () => const _ThreadLoadingHint(
                                  label: 'Loading messages',
                                ),
                                error: (e, _) =>
                                    Center(child: Text(userFacingError(e))),
                                data: (messages) {
                                  return ListView.builder(
                                    padding:
                                        SupportChatMetrics.messageListPadding,
                                    itemCount:
                                        messages.length + (peerTyping ? 1 : 0),
                                    itemBuilder: (_, i) {
                                      if (peerTyping && i == messages.length) {
                                        return ClientMessagesTypingRow(
                                          teamLabel: selected!.kindLabel,
                                        );
                                      }
                                      final m = messages[i];
                                      final signedIn = ref
                                          .watch(identitySessionProvider)
                                          .profile
                                          ?.displayName
                                          .trim();
                                      final stored = m.senderName?.trim() ?? '';
                                      final staffName = stored.isNotEmpty
                                          ? stored
                                          : (signedIn != null &&
                                                  signedIn.isNotEmpty
                                              ? signedIn
                                              : 'Staff');
                                      final label = m.isMine
                                          ? staffName
                                          : selected!.listTitle;
                                      return SupportChatBubble(
                                        body: m.body,
                                        mine: m.isMine,
                                        senderLabel: label,
                                        createdAt: m.createdAt,
                                        isRead: m.isRead,
                                        showChecks: m.isMine,
                                        showSideAvatar: true,
                                        avatarName: label,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            SupportChatComposer(
                              controller: _composer,
                              onChanged: _onChanged,
                              onSend: _send,
                              sending: _sending || _attaching,
                              emojiOpen: _emojiOpen,
                              onToggleEmoji: () =>
                                  setState(() => _emojiOpen = !_emojiOpen),
                              onAttach: _attachFile,
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
                                        final t = _composer.text;
                                        _composer.text = '$t$e';
                                        _composer.selection =
                                            TextSelection.collapsed(
                                              offset: _composer.text.length,
                                            );
                                        _onChanged(_composer.text);
                                      },
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showRail) ...[
                    const SupportPaneGutter(),
                    SizedBox(
                      width: constraints.maxWidth >= 1200 ? 300 : 268,
                      child: _PortalContextRail(conversation: selected),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }
  }
}

class _ThreadLoadingHint extends StatelessWidget {
  const _ThreadLoadingHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: SupportDeskChrome.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalDeskShell extends StatelessWidget {
  const _PortalDeskShell({
    required this.sidebarCollapsed,
    required this.message,
    this.deskNav,
    this.search,
    this.loading = false,
    this.countLabel = 'No threads',
    this.onRetry,
  });

  final bool sidebarCollapsed;
  final String message;
  final Widget? deskNav;
  final Widget? search;
  final bool loading;
  final String countLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = sidebarCollapsed && constraints.maxWidth >= 760;
        final listWidth = showRail
            ? 260.0
            : (constraints.maxWidth >= 900 ? 300.0 : 240.0);
        return ColoredBox(
          color: SupportDeskChrome.bg,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: listWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SupportDeskChrome.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SupportDeskChrome.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (deskNav != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                            child: deskNav,
                          ),
                        if (search != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: search,
                          ),
                        _PortalListChrome(
                          countLabel: loading ? 'Loading' : countLabel,
                        ),
                      ],
                    ),
                  ),
                ),
                const SupportPaneGutter(),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SupportDeskChrome.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SupportDeskChrome.border),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (loading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 14),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: SupportDeskChrome.muted,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            if (onRetry != null) ...[
                              const SizedBox(height: 14),
                              TextButton(
                                onPressed: onRetry,
                                child: const Text('Try again'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (showRail) ...[
                  const SupportPaneGutter(),
                  SizedBox(
                    width: constraints.maxWidth >= 1200 ? 300 : 268,
                    child: const _PortalContextRail(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PortalListChrome extends StatelessWidget {
  const _PortalListChrome({required this.countLabel});

  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.messagesSquare,
              size: 14,
              color: Color(0xFF0B0E14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portal Messages',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  countLabel,
                  style: const TextStyle(
                    color: SupportDeskChrome.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalContextRail extends StatelessWidget {
  const _PortalContextRail({this.conversation});

  final StaffPortalConversation? conversation;

  @override
  Widget build(BuildContext context) {
    final selected = conversation;
    if (selected == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: SupportDeskChrome.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SupportDeskChrome.border),
        ),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conversation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Select a conversation to see the person, portal, and subject.',
                style: TextStyle(
                  color: SupportDeskChrome.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final name = selected.listTitle;
    final subject = selected.subject.trim().isNotEmpty
        ? selected.subject.trim()
        : '—';
    final category = selected.category.trim().isNotEmpty
        ? selected.category.trim()
        : '—';
    final preview = selected.lastMessagePreview?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SupportDeskChrome.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SupportDeskChrome.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Text(
              'Conversation',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              selected.channelLabel,
              style: const TextStyle(
                color: SupportDeskChrome.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SupportStatusBadge(status: selected.status),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SupportDetailField(label: 'Name', value: name),
            SupportDetailField(label: 'Portal', value: selected.kindLabel),
            SupportDetailField(label: 'Subject', value: subject),
            SupportDetailField(label: 'Category', value: category),
            SupportDetailField(label: 'Status', value: selected.status),
            SupportDetailField(
              label: 'Last active',
              value: selected.lastMessageAt == null
                  ? '—'
                  : SupportDeskChrome.timeLabel(selected.lastMessageAt),
            ),
            SupportDetailField(
              label: 'Unread',
              value: selected.unreadCount > 0
                  ? '${selected.unreadCount}'
                  : 'None',
            ),
            if (preview != null && preview.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Last message',
                style: TextStyle(
                  color: SupportDeskChrome.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                preview,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortalKindSeg extends StatelessWidget {
  const _PortalKindSeg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: AppColors.gold.withValues(alpha: 0.4))
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.gold : SupportDeskChrome.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
