import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/website/seo/seo_config.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_portal_chrome.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/cshop_models.dart';
import 'package:hdhomesproject/features/cshop/domain/entities/support_foundation_models.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/support_desk_chrome.dart';
import 'package:hdhomesproject/features/live_chat/domain/entities/live_chat_models.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_composer.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Light live-chat workspace aligned to the HD Homes agent mockup.
class LiveChatLightDesk extends ConsumerWidget {
  const LiveChatLightDesk({
    super.key,
    required this.chats,
    required this.selected,
    required this.onSelect,
    required this.searchController,
    required this.composer,
    required this.sending,
    required this.presenceOnline,
    this.presenceError,
    required this.onTogglePresence,
    required this.onSend,
    required this.onEnd,
    required this.onComposerChanged,
    required this.pending,
    required this.emojiOpen,
    required this.onToggleEmoji,
    required this.onPickFiles,
    required this.onRemovePending,
    required this.onInsertEmoji,
    required this.onClaim,
    required this.onCreateTicket,
    required this.onAddToCrm,
    required this.onSendProperty,
    required this.onShareBrochure,
    required this.onScheduleCall,
    this.deskNav,
  });

  final List<CshopLiveChat> chats;
  final CshopLiveChat? selected;
  final ValueChanged<String?> onSelect;
  final TextEditingController searchController;
  final TextEditingController composer;
  final bool sending;
  final bool presenceOnline;
  final String? presenceError;
  final VoidCallback onTogglePresence;
  final VoidCallback onSend;
  final VoidCallback onEnd;
  final ValueChanged<String> onComposerChanged;
  final List<LiveChatAttachment> pending;
  final bool emojiOpen;
  final VoidCallback onToggleEmoji;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemovePending;
  final ValueChanged<String> onInsertEmoji;
  final VoidCallback onClaim;
  final VoidCallback onCreateTicket;
  final VoidCallback onAddToCrm;
  final VoidCallback onSendProperty;
  final VoidCallback onShareBrochure;
  final VoidCallback onScheduleCall;
  final Widget? deskNav;

  static const page = Color(0xFFF3F5F8);
  static const ink = Color(0xFF1C1E24);
  static const muted = Color(0xFF8A909A);
  static const line = Color(0xFFE6E8EE);
  static const goldBubble = Color(0xFFF3C453);
  static const selectedWash = Color(0xFFFFF6E3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(identitySessionProvider).profile;
    final agentName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName.trim()
        : 'Support Agent';
    final openCount = chats.where((chat) => chat.isOpen).length;
    final navCollapsed = ref.watch(adminSidebarCollapsedProvider);

    return ColoredBox(
      color: page,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          final medium = constraints.maxWidth >= 860;
          final list = _ChatListCard(
            chats: chats,
            selectedId: selected?.id,
            openCount: openCount,
            searchController: searchController,
            onSelect: onSelect,
          );
          final agentStatus = _AgentStatus(
            agentName: agentName,
            online: presenceOnline,
            presenceError: presenceError,
            onTogglePresence: onTogglePresence,
            waiting: chats
                .where((c) => c.isOpen && c.agentUnreadCount > 0)
                .toList(),
            onOpenWaiting: onSelect,
          );
          final leftColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (deskNav != null) deskNav!,
              if (deskNav != null) const SizedBox(height: 8),
              _ChatSearchField(controller: searchController),
              const SizedBox(height: 8),
              Expanded(child: list),
            ],
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _AdaptiveColumns(
                    navCollapsed: navCollapsed,
                    wide: wide,
                    medium: medium,
                    hasSelection: selected != null,
                    list: leftColumn,
                    listWidth: wide ? 340 : 300,
                    rail: _rail(),
                    thread: (customerVisible, onToggleCustomer) => _thread(
                      customerVisible: customerVisible,
                      onToggleCustomer: onToggleCustomer,
                      headerTrailing: agentStatus,
                    ),
                    narrowThread: selected == null
                        ? leftColumn
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => onSelect(null),
                                  icon: const Icon(LucideIcons.arrowLeft, size: 16),
                                  label: const Text('All chats'),
                                ),
                              ),
                              Expanded(
                                child: _thread(headerTrailing: agentStatus),
                              ),
                            ],
                          ),
                  ),
          );
        },
      ),
    );
  }

  Widget _thread({
    bool customerVisible = false,
    VoidCallback? onToggleCustomer,
    Widget? headerTrailing,
  }) {
    final session = selected;
    if (session == null) {
      return const _Panel(
        child: Center(
          child: Text(
            'Select a chat to reply',
            style: TextStyle(color: muted, fontSize: 14),
          ),
        ),
      );
    }
    return _ThreadPane(
      session: session,
      composer: composer,
      sending: sending,
      onSend: onSend,
      onEnd: onEnd,
      onComposerChanged: onComposerChanged,
      pending: pending,
      emojiOpen: emojiOpen,
      onToggleEmoji: onToggleEmoji,
      onPickFiles: onPickFiles,
      onRemovePending: onRemovePending,
      onInsertEmoji: onInsertEmoji,
      customerVisible: customerVisible,
      onToggleCustomer: onToggleCustomer,
      headerTrailing: headerTrailing,
    );
  }

  Widget _rail() {
    final session = selected;
    if (session == null) return const SizedBox.shrink();
    return _ContextRail(
      session: session,
      onClaim: onClaim,
      onCreateTicket: onCreateTicket,
      onAddToCrm: onAddToCrm,
      onSendProperty: onSendProperty,
      onShareBrochure: onShareBrochure,
      onScheduleCall: onScheduleCall,
    );
  }
}

class _AdaptiveColumns extends StatelessWidget {
  const _AdaptiveColumns({
    required this.navCollapsed,
    required this.wide,
    required this.medium,
    required this.hasSelection,
    required this.list,
    required this.listWidth,
    required this.rail,
    required this.thread,
    required this.narrowThread,
  });

  final bool navCollapsed;
  final bool wide;
  final bool medium;
  final bool hasSelection;
  final Widget list;
  final double listWidth;
  final Widget rail;
  final Widget Function(bool customerVisible, VoidCallback? onToggleCustomer)
  thread;
  final Widget narrowThread;

  @override
  Widget build(BuildContext context) {
    if (!medium) {
      return hasSelection ? narrowThread : list;
    }

    // Open sidebar keeps the reply area clear. Customer details return
    // beside the thread only after the sidebar is collapsed.
    final showRail = navCollapsed && hasSelection;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: showRail ? 280 : listWidth, child: list),
        const SizedBox(width: 14),
        Expanded(child: thread(showRail, null)),
        if (showRail) ...[
          const SizedBox(width: 14),
          SizedBox(width: wide ? 320 : 280, child: rail),
        ],
      ],
    );
  }
}

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: LiveChatLightDesk.ink),
      decoration: InputDecoration(
        hintText: 'Search by name, phone number or message…',
        hintStyle: const TextStyle(color: LiveChatLightDesk.muted, fontSize: 13),
        prefixIcon: const Icon(
          LucideIcons.search,
          size: 18,
          color: LiveChatLightDesk.muted,
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: LiveChatLightDesk.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: LiveChatLightDesk.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}

class _AgentStatus extends StatelessWidget {
  const _AgentStatus({
    required this.agentName,
    required this.online,
    this.presenceError,
    required this.onTogglePresence,
    required this.waiting,
    required this.onOpenWaiting,
  });

  final String agentName;
  final bool online;
  final String? presenceError;
  final VoidCallback onTogglePresence;
  final List<CshopLiveChat> waiting;
  final ValueChanged<String?> onOpenWaiting;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PresenceChip(
          online: online,
          error: presenceError,
          onTap: onTogglePresence,
        ),
        PopupMenuButton<String>(
          tooltip: 'Waiting chats',
          offset: const Offset(0, 42),
          onSelected: onOpenWaiting,
          itemBuilder: (context) {
            if (waiting.isEmpty) {
              return const [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('No unread chats'),
                ),
              ];
            }
            return [
              for (final chat in waiting.take(8))
                PopupMenuItem<String>(
                  value: chat.id,
                  child: Text(
                    '${chat.displayName} · ${chat.agentUnreadCount}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ];
          },
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(LucideIcons.bell, color: LiveChatLightDesk.ink, size: 18),
          ),
        ),
        _Avatar(name: agentName, size: 32),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                agentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: LiveChatLightDesk.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresenceChip extends StatelessWidget {
  const _PresenceChip({required this.online, required this.onTap, this.error});

  final bool online;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF22C55E) : LiveChatLightDesk.muted;
    final hint = error?.trim();
    return Tooltip(
      message: online
          ? 'Tap to go offline'
          : (hint != null && hint.isNotEmpty ? hint : 'Tap to go online'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                online ? 'Online' : 'Offline',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Icon(LucideIcons.chevronDown, size: 14, color: color),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LiveChatLightDesk.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _ChatListCard extends StatelessWidget {
  const _ChatListCard({
    required this.chats,
    required this.selectedId,
    required this.openCount,
    required this.searchController,
    required this.onSelect,
  });

  final List<CshopLiveChat> chats;
  final String? selectedId;
  final int openCount;
  final TextEditingController searchController;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: [
                const Text(
                  'Live Chats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LiveChatLightDesk.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$openCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LiveChatLightDesk.line),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) {
                final query = value.text.trim().toLowerCase();
                final visible = query.isEmpty
                    ? chats
                    : chats.where((chat) {
                        final haystack = [
                          chat.displayName,
                          chat.customerEmail,
                          chat.phone,
                          chat.sessionCode,
                          chat.lastMessagePreview,
                        ].whereType<String>().join(' ').toLowerCase();
                        return haystack.contains(query);
                      }).toList();
                if (visible.isEmpty) {
                  return const Center(
                    child: Text(
                      'No chats match',
                      style: TextStyle(color: LiveChatLightDesk.muted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final chat = visible[index];
                    return _ChatRow(
                      chat: chat,
                      selected: chat.id == selectedId,
                      onTap: () => onSelect(chat.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.selected,
    required this.onTap,
  });

  final CshopLiveChat chat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = chat.agentUnreadCount;
    final preview = chat.visitorIsTyping
        ? 'Visitor is typing…'
        : (chat.lastMessagePreview?.trim().isNotEmpty == true
              ? chat.lastMessagePreview!.trim()
              : chat.sessionCode);
    return Material(
      color: selected ? LiveChatLightDesk.selectedWash : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Avatar(name: chat.displayName, size: 42, online: chat.isOpen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: unread > 0
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: LiveChatLightDesk.ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: chat.visitorIsTyping
                            ? AppColors.gold
                            : LiveChatLightDesk.muted,
                        fontSize: 12.5,
                        fontStyle: chat.visitorIsTyping
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    SupportDeskChrome.timeLabel(
                      chat.lastMessageAt ?? chat.startedAt,
                    ),
                    style: const TextStyle(
                      color: LiveChatLightDesk.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (unread > 0)
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadPane extends ConsumerStatefulWidget {
  const _ThreadPane({
    required this.session,
    required this.composer,
    required this.sending,
    required this.onSend,
    required this.onEnd,
    required this.onComposerChanged,
    required this.pending,
    required this.emojiOpen,
    required this.onToggleEmoji,
    required this.onPickFiles,
    required this.onRemovePending,
    required this.onInsertEmoji,
    this.customerVisible = false,
    this.onToggleCustomer,
    this.headerTrailing,
  });

  final CshopLiveChat session;
  final TextEditingController composer;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onEnd;
  final ValueChanged<String> onComposerChanged;
  final List<LiveChatAttachment> pending;
  final bool emojiOpen;
  final VoidCallback onToggleEmoji;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemovePending;
  final ValueChanged<String> onInsertEmoji;
  final bool customerVisible;
  final VoidCallback? onToggleCustomer;
  final Widget? headerTrailing;

  @override
  ConsumerState<_ThreadPane> createState() => _ThreadPaneState();
}

class _ThreadPaneState extends ConsumerState<_ThreadPane> {
  final _scroll = ScrollController();
  int _lastCount = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _stickToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final messages = ref.watch(adminLiveChatMessagesProvider(session.id));
    final property = session.propertyInterest;
    return _Panel(
      child: Column(
        children: [
          _ThreadHeader(
            session: session,
            onEnd: widget.onEnd,
            customerVisible: widget.customerVisible,
            onToggleCustomer: widget.onToggleCustomer,
            headerTrailing: widget.headerTrailing,
          ),
          if (property != null) _PropertyBanner(property: property),
          Expanded(
            child: messages.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (error, _) => Center(
                child: Text(
                  '$error',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              data: (items) {
                if (items.length != _lastCount) {
                  final grew = _lastCount >= 0 && items.length > _lastCount;
                  _lastCount = items.length;
                  if (grew) _stickToEnd();
                }
                if (items.isEmpty && !session.visitorIsTyping) {
                  return const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: LiveChatLightDesk.muted),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: items.length + (session.visitorIsTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= items.length) {
                      return const _TypingBubble();
                    }
                    final message = items[index];
                    final previous = index > 0 ? items[index - 1] : null;
                    final showDay =
                        previous == null ||
                        !_sameDay(previous.createdAt, message.createdAt);
                    return Column(
                      children: [
                        if (showDay) _DayChip(when: message.createdAt),
                        _MessageBubble(
                          message: message,
                          visitorName: session.displayName,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (session.isOpen)
            _Composer(
              controller: widget.composer,
              sending: widget.sending,
              onSend: widget.onSend,
              onChanged: widget.onComposerChanged,
              pending: widget.pending,
              emojiOpen: widget.emojiOpen,
              onToggleEmoji: widget.onToggleEmoji,
              onPickFiles: widget.onPickFiles,
              onRemovePending: widget.onRemovePending,
              onInsertEmoji: widget.onInsertEmoji,
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This chat has ended',
                style: TextStyle(color: LiveChatLightDesk.muted),
              ),
            ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.session,
    required this.onEnd,
    this.customerVisible = false,
    this.onToggleCustomer,
    this.headerTrailing,
  });

  final CshopLiveChat session;
  final VoidCallback onEnd;
  final bool customerVisible;
  final VoidCallback? onToggleCustomer;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final phone = session.phone;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LiveChatLightDesk.line)),
      ),
      child: Row(
        children: [
          _Avatar(name: session.displayName, size: 42, online: session.isOpen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: LiveChatLightDesk.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (phone != null) ...[
                      Flexible(
                        child: Text(
                          phone,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LiveChatLightDesk.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: session.isOpen
                            ? const Color(0xFF22C55E)
                            : LiveChatLightDesk.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.isOpen
                          ? 'Online'
                          : SupportDeskChrome.prettyStatus(session.status),
                      style: TextStyle(
                        color: session.isOpen
                            ? const Color(0xFF16A34A)
                            : LiveChatLightDesk.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (headerTrailing != null) ...[
            const SizedBox(width: 8),
            Flexible(child: headerTrailing!),
          ],
          if (onToggleCustomer != null)
            IconButton(
              tooltip: customerVisible
                  ? 'Hide customer information'
                  : 'Show customer information',
              onPressed: onToggleCustomer,
              icon: Icon(
                customerVisible
                    ? LucideIcons.panelRightClose
                    : LucideIcons.panelRightOpen,
                size: 18,
              ),
            ),
          IconButton(
            tooltip: phone == null ? 'No phone number yet' : 'Call $phone',
            onPressed: phone == null
                ? null
                : () => launchUrl(Uri(scheme: 'tel', path: phone)),
            icon: const Icon(LucideIcons.phone, size: 18),
          ),
          IconButton(
            tooltip: 'Video calls are not set up',
            onPressed: null,
            icon: const Icon(LucideIcons.video, size: 18),
          ),
          if (session.isOpen)
            IconButton(
              tooltip: 'End chat',
              onPressed: onEnd,
              icon: const Icon(
                LucideIcons.phoneOff,
                size: 18,
                color: Color(0xFFEF4444),
              ),
            ),
        ],
      ),
    );
  }
}

class _PropertyBanner extends StatelessWidget {
  const _PropertyBanner({required this.property});

  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final title = property['title']?.toString() ?? 'Property';
    final subtitle = property['subtitle']?.toString() ?? '';
    final image = property['image_url']?.toString();
    final slug = property['slug']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LiveChatLightDesk.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 52,
                child: image != null && image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFE8EAEE),
                          child: Icon(LucideIcons.home, size: 18),
                        ),
                      )
                    : const ColoredBox(
                        color: Color(0xFFE8EAEE),
                        child: Icon(LucideIcons.home, size: 18),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interested in:',
                    style: TextStyle(
                      color: LiveChatLightDesk.muted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LiveChatLightDesk.ink,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LiveChatLightDesk.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (slug.isNotEmpty)
              OutlinedButton(
                onPressed: () => launchUrl(
                  Uri.parse(SeoConfig.canonicalFor('/properties/$slug')),
                  mode: LaunchMode.externalApplication,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LiveChatLightDesk.ink,
                  side: const BorderSide(color: LiveChatLightDesk.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('View Property'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.when});

  final DateTime? when;

  @override
  Widget build(BuildContext context) {
    final label = _label(when);
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: LiveChatLightDesk.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label(DateTime? when) {
    if (when == null) return '';
    final local = when.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.visitorName});

  final LiveChatMessage message;
  final String visitorName;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          message.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LiveChatLightDesk.muted,
            fontSize: 12.5,
          ),
        ),
      );
    }
    final mine = message.isAgent;
    final name = mine
        ? (message.senderName?.trim().isNotEmpty == true
              ? message.senderName!.trim()
              : 'Agent')
        : visitorName;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: mine ? LiveChatLightDesk.goldBubble : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine ? null : Border.all(color: LiveChatLightDesk.line),
        boxShadow: mine
            ? null
            : const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: LiveChatLightDesk.ink.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.body,
            style: const TextStyle(
              color: LiveChatLightDesk.ink,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (message.attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final file in message.attachments)
              LiveChatAttachmentTile(attachment: file, onGold: true),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SupportDeskChrome.timeLabel(message.createdAt),
                style: TextStyle(
                  color: LiveChatLightDesk.ink.withValues(alpha: 0.45),
                  fontSize: 10.5,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.checkCheck,
                  size: 12,
                  color: LiveChatLightDesk.ink.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            _Avatar(name: name, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
          if (mine) ...[
            const SizedBox(width: 8),
            _Avatar(name: name, size: 28),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _Avatar(name: 'Visitor', size: 28),
          SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                '•••',
                style: TextStyle(
                  color: LiveChatLightDesk.muted,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onChanged,
    required this.pending,
    required this.emojiOpen,
    required this.onToggleEmoji,
    required this.onPickFiles,
    required this.onRemovePending,
    required this.onInsertEmoji,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final List<LiveChatAttachment> pending;
  final bool emojiOpen;
  final VoidCallback onToggleEmoji;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemovePending;
  final ValueChanged<String> onInsertEmoji;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          if (pending.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pending.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => InputChip(
                  label: Text(pending[index].name),
                  onDeleted: () => onRemovePending(index),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach file',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: sending ? null : onPickFiles,
                icon: const Icon(
                  LucideIcons.paperclip,
                  color: LiveChatLightDesk.muted,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: LiveChatLightDesk.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !sending,
                          onChanged: onChanged,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                            hintStyle: TextStyle(
                              color: LiveChatLightDesk.muted,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Emoji',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: sending ? null : onToggleEmoji,
                        icon: Icon(
                          LucideIcons.smile,
                          color: emojiOpen
                              ? AppColors.gold
                              : LiveChatLightDesk.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.gold,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: sending ? null : onSend,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            LucideIcons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (emojiOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 4,
                children: [
                  for (final emoji in liveChatEmojis)
                    InkWell(
                      onTap: () => onInsertEmoji(emoji),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Press Enter to send · Shift + Enter for new line',
            style: TextStyle(color: LiveChatLightDesk.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ContextRail extends StatelessWidget {
  const _ContextRail({
    required this.session,
    required this.onClaim,
    required this.onCreateTicket,
    required this.onAddToCrm,
    required this.onSendProperty,
    required this.onShareBrochure,
    required this.onScheduleCall,
  });

  final CshopLiveChat session;
  final VoidCallback onClaim;
  final VoidCallback onCreateTicket;
  final VoidCallback onAddToCrm;
  final VoidCallback onSendProperty;
  final VoidCallback onShareBrochure;
  final VoidCallback onScheduleCall;

  @override
  Widget build(BuildContext context) {
    final property = session.propertyInterest;
    final email = session.customerEmail?.trim();
    final lastSeen = session.visitorIsTyping
        ? 'Just now'
        : SupportDeskChrome.timeLabel(
            session.lastMessageAt ?? session.endedAt ?? session.startedAt,
          );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Panel(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: LiveChatLightDesk.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Name', value: session.displayName),
                _InfoRow(
                  label: 'Phone',
                  value: session.phone ?? 'Not provided',
                ),
                _InfoRow(
                  label: 'Email',
                  value: email != null && email.isNotEmpty
                      ? email
                      : 'Not provided',
                ),
                _InfoRow(
                  label: 'Location',
                  value: session.locationLabel ?? 'Not provided',
                ),
                _InfoRow(
                  label: 'Last seen',
                  value: lastSeen.isEmpty ? '—' : lastSeen,
                ),
                _InfoRow(label: 'Source', value: session.sourceLabel),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: property == null
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No property linked yet. Send property details to attach one.',
                    style: TextStyle(
                      color: LiveChatLightDesk.muted,
                      fontSize: 13,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: _PropertyInterestCard(property: property),
                ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Row(
                    children: [
                      Icon(LucideIcons.zap, size: 16, color: AppColors.gold),
                      SizedBox(width: 6),
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: LiveChatLightDesk.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionButton(
                  label: 'Send Property Details',
                  icon: LucideIcons.send,
                  filled: true,
                  onPressed: session.isOpen ? onSendProperty : null,
                ),
                _ActionButton(
                  label: 'Share Brochure',
                  icon: LucideIcons.fileText,
                  onPressed: session.isOpen ? onShareBrochure : null,
                ),
                _ActionButton(
                  label: 'Schedule a Call',
                  icon: LucideIcons.calendar,
                  onPressed: session.isOpen ? onScheduleCall : null,
                ),
                _ActionButton(
                  label: 'Add to CRM',
                  icon: LucideIcons.userPlus,
                  onPressed: onAddToCrm,
                ),
                _ActionButton(
                  label: session.isClaimed ? 'Assigned' : 'Assign to Agent',
                  icon: LucideIcons.userCheck,
                  onPressed: !session.isClaimed && session.isOpen
                      ? onClaim
                      : null,
                ),
                _ActionButton(
                  label: 'Create Ticket',
                  icon: LucideIcons.ticket,
                  onPressed: onCreateTicket,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logos/hd_homes_logo.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 42,
                      height: 42,
                      child: ColoredBox(color: Color(0xFF111111)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real People. Real Homes.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: LiveChatLightDesk.ink,
                        ),
                      ),
                      Text(
                        'HD Homes Limited',
                        style: TextStyle(
                          color: LiveChatLightDesk.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyInterestCard extends StatelessWidget {
  const _PropertyInterestCard({required this.property});

  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final title = property['title']?.toString() ?? 'Property';
    final subtitle = property['subtitle']?.toString() ?? '';
    final image = property['image_url']?.toString();
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 72,
            height: 56,
            child: image != null && image.isNotEmpty
                ? Image.network(image, fit: BoxFit.cover)
                : const ColoredBox(
                    color: Color(0xFFE8EAEE),
                    child: Icon(LucideIcons.home),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Property Interest',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: LiveChatLightDesk.ink,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LiveChatLightDesk.muted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: LiveChatLightDesk.muted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: LiveChatLightDesk.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: filled ? Colors.white : LiveChatLightDesk.ink,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : LiveChatLightDesk.ink,
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                side: const BorderSide(color: LiveChatLightDesk.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: child,
            ),
    );
  }
}

Future<LiveChatPropertyOption?> showLiveChatPropertyPicker(
  BuildContext context,
  List<LiveChatPropertyOption> properties,
) {
  return showDialog<LiveChatPropertyOption>(
    context: context,
    builder: (context) => _PropertyPickerDialog(properties: properties),
  );
}

class _PropertyPickerDialog extends StatefulWidget {
  const _PropertyPickerDialog({required this.properties});

  final List<LiveChatPropertyOption> properties;

  @override
  State<_PropertyPickerDialog> createState() => _PropertyPickerDialogState();
}

class _PropertyPickerDialogState extends State<_PropertyPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.properties
        : widget.properties
              .where(
                (property) =>
                    property.title.toLowerCase().contains(query) ||
                    property.subtitle.toLowerCase().contains(query),
              )
              .toList();
    return AlertDialog(
      title: const Text('Send property details'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search properties',
                prefixIcon: Icon(LucideIcons.search, size: 18),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final property = visible[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 40,
                        child: property.imageUrl == null
                            ? const ColoredBox(
                                color: Color(0xFFE8EAEE),
                                child: Icon(LucideIcons.home, size: 16),
                              )
                            : Image.network(
                                property.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Color(0xFFE8EAEE),
                                  child: Icon(LucideIcons.home, size: 16),
                                ),
                              ),
                      ),
                    ),
                    title: Text(property.title),
                    subtitle: Text(property.subtitle),
                    onTap: () => Navigator.pop(context, property),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size, this.online = false});

  final String name;
  final double size;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SupportDeskChrome.avatarColor(name),
              shape: BoxShape.circle,
            ),
            child: Text(
              SupportDeskChrome.initials(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
