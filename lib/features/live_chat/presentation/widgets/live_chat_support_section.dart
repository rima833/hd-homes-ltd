import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/extensions/context_extensions.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/contact/data/providers/contact_cms_provider.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_composer.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_resume_prompt.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

String _portalMessagesLivePath(AuthSessionSnapshot session) {
  if (session.isInvestor || session.canAccessInvestorPortal) {
    return RoutePaths.investorMessagesLive();
  }
  return RoutePaths.clientMessagesLive();
}

const _bg = Color(0xFF0A0A0A);
const _panel = Color(0xFF141414);
const _panelSoft = Color(0xFF1A1A1A);
const _border = Color(0x33D4AF37);
const _muted = Color(0xFF9A9A9A);

/// Premium HD Homes Concierge live-chat section for Contact / Support.
/// Wired to the existing visitor live-chat session + message providers.
///
/// Set [embedded] for portal pages — chat panel only, no marketing chrome.
/// Set [hubCompact] on Contact Hub to keep the 3-column shell mockup-height.
class LiveChatSupportSection extends ConsumerStatefulWidget {
  const LiveChatSupportSection({
    super.key,
    this.embedded = false,
    this.hubCompact = false,
  });

  /// Compact layout for authenticated portal support pages.
  final bool embedded;

  /// Constrained height for Contact Hub (avoids oversized vertical stretch).
  final bool hubCompact;

  @override
  ConsumerState<LiveChatSupportSection> createState() =>
      _LiveChatSupportSectionState();
}

class _LiveChatSupportSectionState
    extends ConsumerState<LiveChatSupportSection> {
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _identityBound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(liveChatVisitorControllerProvider.notifier).ensureStarted(),
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openTel(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(identitySessionProvider);
    final controller = ref.read(liveChatVisitorControllerProvider.notifier);
    if (!_identityBound && session.isAuthenticated) {
      _identityBound = true;
      final profileName = [
        session.profile?.firstName,
        session.profile?.lastName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.bindIdentity(
          name: profileName.isEmpty ? null : profileName,
          email: session.email,
        );
      });
    }

    final cms = ref.watch(contactHubCmsProvider);
    final state = ref.watch(liveChatVisitorControllerProvider);
    final mobile = context.isMobile;
    final hubCompact = widget.hubCompact;
    // Hub compact keeps the mockup's 3-column shell on desktop web.
    // Portal / full-page web still stacks to avoid Expanded-in-scroll issues.
    final stacked = mobile || (kIsWeb && !hubCompact);

    ref.listen(liveChatVisitorControllerProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.peerIsTyping != next.peerIsTyping) {
        _scrollToEnd();
      }
      if (_nameController.text.isEmpty &&
          next.displayName.isNotEmpty &&
          _nameController.text != next.displayName) {
        _nameController.text = next.displayName;
      }
    });

    final presence = widget.hubCompact
        ? null
        : ref.watch(liveChatSupportPresenceProvider).valueOrNull;
    final online = presence?.online == true;

    if (widget.embedded) {
      return _ChatPanel(
        state: state,
        controller: controller,
        nameController: _nameController,
        messageController: _messageController,
        scrollController: _scrollController,
        online: online,
        agentsPresent: presence?.agentsPresent ?? 0,
        embedded: true,
        fillHeight: true,
        hideNameField: session.isAuthenticated,
      );
    }

    final titleSize = hubCompact
        ? (mobile ? 26.0 : 32.0)
        : (mobile ? 32.0 : 42.0);

    Widget shell;
    if (stacked) {
      shell = Column(
        children: [
          _HelpCard(compact: hubCompact, hours: cms.supportHours),
          const SizedBox(height: 14),
          SizedBox(
            height: hubCompact ? 420 : null,
            child: _ChatPanel(
              state: state,
              controller: controller,
              nameController: _nameController,
              messageController: _messageController,
              scrollController: _scrollController,
              online: online,
              agentsPresent: presence?.agentsPresent ?? 0,
              fillHeight: hubCompact,
            ),
          ),
          const SizedBox(height: 14),
          _StatusCard(
            phone: cms.phone,
            whatsapp: cms.whatsapp,
            hours: cms.supportHours,
            online: online,
            agentsPresent: presence?.agentsPresent ?? 0,
            onCall: () => _openTel(cms.phone),
            onWhatsApp: () => _openWhatsApp(cms.whatsapp),
            onBook: () => context.go(RoutePaths.bookInspection),
            compact: hubCompact,
          ),
        ],
      );
    } else {
      shell = SizedBox(
        height: hubCompact ? 520 : 560,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _HelpCard(compact: hubCompact, hours: cms.supportHours)),
            const SizedBox(width: 14),
            Expanded(
              flex: 6,
              child: _ChatPanel(
                state: state,
                controller: controller,
                nameController: _nameController,
                messageController: _messageController,
                scrollController: _scrollController,
                online: online,
                agentsPresent: presence?.agentsPresent ?? 0,
                fillHeight: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: _StatusCard(
                phone: cms.phone,
                whatsapp: cms.whatsapp,
                hours: cms.supportHours,
                online: online,
                agentsPresent: presence?.agentsPresent ?? 0,
                onCall: () => _openTel(cms.phone),
                onWhatsApp: () => _openWhatsApp(cms.whatsapp),
                onBook: () => context.go(RoutePaths.bookInspection),
                compact: hubCompact,
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: _bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Text(
              'LIVE CHAT',
              style: GoogleFonts.manrope(
                color: AppColors.gold,
                fontSize: 11,
                letterSpacing: 3.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Live chat Support',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                hubCompact
                    ? 'Real-time messaging with file sharing — AI chatbot in future release.'
                    : 'Chat with HD Homes support. Messages appear on the Live Chat desk in real time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: _muted,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
            ),
            SizedBox(height: hubCompact ? 14 : 16),
            if (session.isAuthenticated)
              TextButton(
                onPressed: () {
                  ref.read(portalMessagesOpenLiveChatProvider.notifier).state =
                      true;
                  context.go(_portalMessagesLivePath(session));
                },
                child: Text(
                  'Continue in your portal Messages',
                  style: GoogleFonts.manrope(
                    color: AppColors.gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (session.isAuthenticated) const SizedBox(height: 8),
            shell,
            SizedBox(height: hubCompact ? 12 : 18),
            const _TrustFooter(),
          ],
        ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (online ? const Color(0xFF1B5E20) : Colors.grey)
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: online
              ? const Color(0xFF69F0AE).withValues(alpha: 0.45)
              : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF69F0AE) : _muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'Online' : 'Offline',
            style: GoogleFonts.manrope(
              color: online ? const Color(0xFF69F0AE) : _muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    this.compact = false,
    this.hours = 'Mon–Fri 8:00 AM – 5:00 PM',
  });

  final bool compact;
  final String hours;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        LucideIcons.zap,
        'Instant Response',
        'Typically replies in under 1 minute.'
      ),
      (
        LucideIcons.shieldCheck,
        'Secure & Private',
        'Your data is safe with us.'
      ),
      (
        LucideIcons.paperclip,
        'File Sharing',
        'Share documents and images easily.'
      ),
      (
        LucideIcons.clock,
        'Available $hours',
        'Reach our concierge during support hours.'
      ),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageCircle, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "We're here to help you!",
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 18),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 28 : 34,
                  height: compact ? 28 : 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                  ),
                  child: Icon(item.$1, color: AppColors.gold, size: compact ? 13 : 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12.5 : 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        style: GoogleFonts.manrope(
                          color: _muted,
                          fontSize: compact ? 11 : 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 14),
          ],
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.state,
    required this.controller,
    required this.nameController,
    required this.messageController,
    required this.scrollController,
    required this.online,
    this.agentsPresent = 0,
    this.embedded = false,
    this.hideNameField = false,
    this.fillHeight = false,
  });

  final LiveChatVisitorState state;
  final LiveChatVisitorController controller;
  final TextEditingController nameController;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final bool online;
  final int agentsPresent;
  final bool embedded;
  final bool hideNameField;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      constraints: fillHeight
          ? const BoxConstraints(minHeight: 0)
          : BoxConstraints(minHeight: embedded ? 420 : 520),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, embedded ? 10 : 16, 10, embedded ? 8 : 12),
            child: Row(
              children: [
                if (!embedded)
                  SizedBox(
                    width: 72,
                    height: 32,
                    child: Stack(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Positioned(
                            left: i * 18.0,
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: i.isEven
                                  ? AppColors.gold
                                  : const Color(0xFF2A2A2A),
                              child: Icon(
                                LucideIcons.user,
                                size: 14,
                                color: i.isEven ? _bg : AppColors.gold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.messageCircle,
                      color: AppColors.gold,
                      size: 16,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'HD Homes Concierge',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: embedded ? 13.5 : 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            LucideIcons.badgeCheck,
                            color: AppColors.gold,
                            size: 15,
                          ),
                        ],
                      ),
                      Text(
                        online
                            ? (agentsPresent > 1
                                ? '$agentsPresent agents online — replies here'
                                : 'Online — an agent will reply here')
                            : 'Offline — leave a message or try later',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          color: _muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _OnlineBadge(online: online),
                if (state.session?.isOpen == true)
                  TextButton(
                    onPressed: controller.endChat,
                    child: Text(
                      'End',
                      style: GoogleFonts.manrope(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          if (!embedded && !state.awaitingChoice)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _QuickChip(
                    icon: LucideIcons.home,
                    label: 'Browse Properties',
                    onTap: () => context.go(RoutePaths.properties),
                  ),
                  _QuickChip(
                    icon: LucideIcons.calculator,
                    label: 'Payment Plans',
                    onTap: () => context.go(RoutePaths.home),
                  ),
                  _QuickChip(
                    icon: LucideIcons.calendarCheck,
                    label: 'Schedule Inspection',
                    onTap: () => context.go(RoutePaths.bookInspection),
                  ),
                  _QuickChip(
                    icon: LucideIcons.trendingUp,
                    label: 'Investment',
                    onTap: () => context.go(RoutePaths.investment),
                  ),
                  _QuickChip(
                    icon: LucideIcons.headphones,
                    label: 'Talk to Sales',
                    onTap: () async {
                      await controller.send(
                        'Hi — I would like to speak with Sales about a property.',
                      );
                    },
                  ),
                ],
              ),
            ),
          if (state.error != null)
            Container(
              width: double.infinity,
              color: AppColors.error.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                state.error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          if (state.session == null && !hideNameField && !state.awaitingChoice)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Your name (optional)',
                  hintStyle: const TextStyle(color: _muted),
                  filled: true,
                  fillColor: _panelSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  isDense: true,
                ),
                onChanged: controller.setDisplayName,
              ),
            ),
          Builder(
            builder: (context) {
              final messages = state.awaitingChoice
                  ? LiveChatResumePrompt(
                      state: state,
                      onContinue: controller.continueSavedChat,
                      onStartNew: controller.startNewChat,
                    )
                  : state.loading && state.messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : state.messages.isEmpty && !state.peerIsTyping
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Say hello to start a live conversation with HD Homes Concierge.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: _muted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          itemCount: state.messages.length +
                              (state.peerIsTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.messages.length) {
                              return const LiveChatTypingIndicator();
                            }
                            return LiveChatMessageBubble(
                              message: state.messages[index],
                            );
                          },
                        );
              if (fillHeight) {
                return Expanded(child: messages);
              }
              return SizedBox(height: embedded ? 320 : 280, child: messages);
            },
          ),
          if (state.awaitingChoice)
            const SizedBox(height: 8)
          else if (state.session != null && !state.session!.isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: controller.startNewChat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _border),
                  ),
                  child: const Text('Start new chat'),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: LiveChatComposer(
                controller: messageController,
                showSendLabel: true,
              ),
            ),
        ],
      ),
    );

    if (fillHeight) {
      return SizedBox.expand(child: panel);
    }
    return panel;
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: _panelSoft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.phone,
    required this.whatsapp,
    required this.online,
    required this.onCall,
    required this.onWhatsApp,
    required this.onBook,
    this.hours = 'Mon–Fri 8:00 AM – 5:00 PM',
    this.agentsPresent = 0,
    this.compact = false,
  });

  final String phone;
  final String whatsapp;
  final String hours;
  final bool online;
  final int agentsPresent;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onBook;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Support Status',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
              _OnlineBadge(online: online),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          _meta(
            LucideIcons.users,
            'Sales & Support Team',
            agentsPresent > 0
                ? '$agentsPresent agent(s) available'
                : 'HD Homes Concierge',
          ),
          _meta(
            LucideIcons.timer,
            'Average Reply Time',
            online ? 'Under 2 minutes' : 'Next business day',
          ),
          _meta(
            LucideIcons.clock,
            'Working Hours',
            hours,
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            'Need faster assistance?',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12.5 : 13,
            ),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: LucideIcons.phone,
            title: 'Call Sales',
            subtitle: phone,
            onTap: onCall,
          ),
          _ActionTile(
            icon: LucideIcons.messageCircle,
            title: 'Chat on WhatsApp',
            subtitle: whatsapp,
            onTap: onWhatsApp,
          ),
          _ActionTile(
            icon: LucideIcons.calendar,
            title: 'Book Appointment',
            subtitle: 'Schedule a meeting',
            onTap: onBook,
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String title, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _panelSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(color: _muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: _muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.lock, 'Your conversation is private and stored securely'),
      (LucideIcons.heart, 'Human support — real agents on the HD Homes desk'),
      (LucideIcons.messageCircle, 'Same live chat as the public site and client portal'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: context.isMobile
          ? Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _footerItem(items[i].$1, items[i].$2),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  Expanded(child: _footerItem(items[i].$1, items[i].$2)),
                ],
              ],
            ),
    );
  }

  Widget _footerItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(color: _muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
