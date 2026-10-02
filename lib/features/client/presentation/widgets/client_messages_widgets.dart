import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/domain/entities/client_models.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_composer.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_messages_shell.dart';
import 'package:hdhomesproject/features/support_portal/presentation/portal_support_shell.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _msgBg = Color(0xFF0B0E14);
const _panel = Color(0xFF12161D);
const _panelSoft = Color(0xFF1A1F28);
const _bubbleIncoming = Color(0xFF232933);
const _muted = Color(0xFF8B929E);

String formatClientMessageListTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return DateFormat.jm().format(local);
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
  return DateFormat.MMMd().format(local);
}

Color teamAvatarColor(String category) => switch (category) {
      'sales' => const Color(0xFF2563EB),
      'support' => const Color(0xFF16A34A),
      'finance' => const Color(0xFF9333EA),
      'legal' => const Color(0xFFDC2626),
      'manager' => AppColors.gold,
      _ => const Color(0xFF475569),
    };

class ClientMessagesSearchField extends StatelessWidget {
  const ClientMessagesSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onFilter,
    this.categoryFilter,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;
  final String? categoryFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panelSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.manrope(color: AppColors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search conversations…',
          hintStyle: GoogleFonts.manrope(color: _muted, fontSize: 14),
          prefixIcon: const Icon(LucideIcons.search, size: 18, color: _muted),
          suffixIcon: IconButton(
            tooltip: categoryFilter == null
                ? 'Filter by team'
                : 'Filter: ${categoryFilter!.toUpperCase()}',
            onPressed: onFilter,
            icon: Icon(
              LucideIcons.slidersHorizontal,
              size: 18,
              color: categoryFilter == null ? _muted : AppColors.gold,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class ClientConversationTile extends StatelessWidget {
  const ClientConversationTile({
    super.key,
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final ClientConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = conversation.lastMessagePreview?.trim().isNotEmpty == true
        ? conversation.lastMessagePreview!.trim()
        : conversation.subject;
    final time = formatClientMessageListTime(conversation.lastMessageAt);
    final avatarColor = teamAvatarColor(conversation.category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _panelSoft : _panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.05),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: avatarColor.withValues(alpha: 0.18),
                    child: Text(
                      conversation.avatarInitial,
                      style: GoogleFonts.manrope(
                        color: avatarColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (conversation.staffIsTyping || conversation.clientIsTyping)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: _panel, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.teamLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: GoogleFonts.manrope(
                              color: _muted,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: _muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: GoogleFonts.manrope(
                                color: _msgBg,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClientChatHeader extends StatelessWidget {
  const ClientChatHeader({
    super.key,
    required this.conversation,
    this.onSearchInThread,
    this.supportPhone,
    this.supportOnline,
  });

  final ClientConversation conversation;
  final VoidCallback? onSearchInThread;
  final String? supportPhone;

  /// When set, shows real Concierge Online/Offline (agent presence).
  final bool? supportOnline;

  @override
  Widget build(BuildContext context) {
    final avatarColor = teamAvatarColor(conversation.category);
    final staffName = conversation.assignedStaffName;
    final presenceKnown = supportOnline != null;
    final online = supportOnline == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _panelSoft,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor.withValues(alpha: 0.18),
                child: Text(
                  conversation.avatarInitial,
                  style: GoogleFonts.manrope(
                    color: avatarColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (presenceKnown)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: online ? AppColors.success : Colors.white38,
                      shape: BoxShape.circle,
                      border: Border.all(color: _panelSoft, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.teamLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !presenceKnown
                      ? (staffName != null
                          ? 'Assigned · $staffName'
                          : 'Portal conversation')
                      : online
                          ? (staffName != null
                              ? '● Online — $staffName · Typically replies in a few minutes'
                              : '● Online — HD Homes is available now')
                          : '● Offline — leave a message; team will reply soon',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (presenceKnown)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (online ? const Color(0xFF1B5E20) : Colors.grey)
                    .withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                online ? 'Online' : 'Offline',
                style: GoogleFonts.manrope(
                  color: online ? const Color(0xFF69F0AE) : _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Search in conversation',
            onPressed: onSearchInThread,
            icon: const Icon(LucideIcons.search, size: 18, color: _muted),
          ),
          IconButton(
            tooltip: 'Call support',
            onPressed: supportPhone == null || supportPhone!.trim().isEmpty
                ? null
                : () async {
                    final digits =
                        supportPhone!.replaceAll(RegExp(r'[^0-9+]'), '');
                    if (digits.isEmpty) return;
                    final uri = Uri.parse('tel:$digits');
                    // ignore: use_build_context_synchronously
                    if (!await launchUrl(uri) && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open phone dialer'),
                        ),
                      );
                    }
                  },
            icon: const Icon(LucideIcons.phone, size: 18, color: _muted),
          ),
        ],
      ),
    );
  }
}

class ClientMessageBubble extends StatelessWidget {
  const ClientMessageBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.avatarInitial = 'H',
    this.avatarColor = AppColors.gold,
  });

  final ClientMessage message;
  final bool showAvatar;
  final String avatarInitial;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final time = DateFormat.jm().format(message.createdAt.toLocal());
    final maxW = MediaQuery.sizeOf(context).width * 0.52;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: IntrinsicWidth(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
          decoration: BoxDecoration(
            color: mine ? AppColors.gold : _bubbleIncoming,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(mine ? 12 : 4),
              bottomRight: Radius.circular(mine ? 4 : 12),
            ),
            border: mine
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine && (message.senderName?.trim().isNotEmpty == true)) ...[
                Text(
                  message.senderName!.trim(),
                  style: GoogleFonts.manrope(
                    color: AppColors.gold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message.body,
                style: GoogleFonts.manrope(
                  color: mine ? _msgBg : AppColors.white,
                  fontSize: 12.5,
                  height: 1.28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: GoogleFonts.manrope(
                      color: mine
                          ? _msgBg.withValues(alpha: 0.65)
                          : _muted,
                      fontSize: 9.5,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 3),
                    Icon(
                      message.isRead
                          ? LucideIcons.checkCheck
                          : LucideIcons.check,
                      size: 11,
                      color: message.isRead
                          ? _msgBg.withValues(alpha: 0.9)
                          : _msgBg.withValues(alpha: 0.55),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && showAvatar) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: avatarColor.withValues(alpha: 0.18),
              child: Text(
                avatarInitial,
                style: GoogleFonts.manrope(
                  color: avatarColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (!mine)
            const SizedBox(width: 30),
          // Avoid Flexible — it stretches IntrinsicWidth bubbles.
          bubble,
        ],
      ),
    );
  }
}

class ClientMessagesDateSeparator extends StatelessWidget {
  const ClientMessagesDateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _panelSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(color: _muted, fontSize: 11.5),
          ),
        ),
      ),
    );
  }
}

class ClientMessagesComposer extends StatelessWidget {
  const ClientMessagesComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.onChanged,
    this.onAttach,
    this.attachmentLabel,
    this.onClearAttachment,
    this.sending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttach;
  final String? attachmentLabel;
  final VoidCallback? onClearAttachment;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: _panelSoft,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: PortalSupportReplyComposer(
        controller: controller,
        onSend: onSend,
        onChanged: onChanged,
        onAttach: onAttach,
        attachmentLabel: attachmentLabel,
        onClearAttachment: onClearAttachment,
        sending: sending,
        hintText: 'Type your message…',
      ),
    );
  }
}

class ClientMessagesTypingRow extends StatelessWidget {
  const ClientMessagesTypingRow({super.key, required this.teamLabel});

  final String teamLabel;

  @override
  Widget build(BuildContext context) {
    return LiveChatTypingIndicator(
      label: '$teamLabel is typing…',
      compact: true,
    );
  }
}

class ClientMessagesEmptyThread extends StatelessWidget {
  const ClientMessagesEmptyThread({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.messagesSquare,
            size: 42,
            color: _muted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Select a conversation',
            style: GoogleFonts.manrope(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a thread on the left, or switch to Live chat.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class ClientMessagesPanelShell extends StatelessWidget {
  const ClientMessagesPanelShell({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return PortalMessagesPanelShell(padding: padding, child: child);
  }
}

String clientMessageDayLabel(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
  return DateFormat.yMMMMd().format(local);
}
