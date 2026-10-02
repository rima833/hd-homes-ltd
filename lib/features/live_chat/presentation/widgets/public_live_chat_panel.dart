import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/auth/models/auth_session_snapshot.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/live_chat/presentation/providers/live_chat_providers.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_composer.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_resume_prompt.dart';
import 'package:lucide_icons/lucide_icons.dart';

String _portalMessagesLivePath(AuthSessionSnapshot session) {
  if (session.isInvestor || session.canAccessInvestorPortal) {
    return RoutePaths.investorMessagesLive();
  }
  return RoutePaths.clientMessagesLive();
}

const _panel = Color(0xFF141414);
const _panelSoft = Color(0xFF1A1A1A);
const _border = Color(0x33D4AF37);
const _muted = Color(0xFF9A9A9A);
const _bg = Color(0xFF0A0A0A);

/// Compact Concierge live-chat panel opened from the sitewide chat FAB.
class PublicLiveChatPanel extends ConsumerStatefulWidget {
  const PublicLiveChatPanel({super.key});

  @override
  ConsumerState<PublicLiveChatPanel> createState() =>
      _PublicLiveChatPanelState();
}

class _PublicLiveChatPanelState extends ConsumerState<PublicLiveChatPanel> {
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

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identitySessionProvider);
    final controller = ref.read(liveChatVisitorControllerProvider.notifier);
    if (!_identityBound && identity.isAuthenticated) {
      _identityBound = true;
      final profileName = [
        identity.profile?.firstName,
        identity.profile?.lastName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      final email = identity.email;
      controller.bindIdentity(
        name: profileName.isEmpty ? null : profileName,
        email: email,
      );
      if (profileName.isNotEmpty && _nameController.text.isEmpty) {
        _nameController.text = profileName;
      }
    }

    final state = ref.watch(liveChatVisitorControllerProvider);

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

    final width = MediaQuery.sizeOf(context).width;
    final media = MediaQuery.of(context);
    final panelWidth = width < 420 ? (width - 32).clamp(280.0, 420.0) : 380.0;
    // Match Contact Hub chat panel (`minHeight: 520`), shrink only on short viewports.
    const contactHubHeight = 520.0;
    final reservedTop = media.padding.top + 82; // public nav under extendBodyBehindAppBar
    final reservedBottom = media.padding.bottom + 72; // FABs below panel
    final available = media.size.height - reservedTop - reservedBottom;
    final panelHeight = available >= contactHubHeight
        ? contactHubHeight
        : available.clamp(400.0, contactHubHeight);
    final presence = ref.watch(liveChatSupportPresenceProvider).valueOrNull;
    final online = presence?.online == true;
    final agentsPresent = presence?.agentsPresent ?? 0;

    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(18),
      color: _panel,
      child: Container(
        width: panelWidth,
        height: panelHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 28,
                    child: Stack(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Positioned(
                            left: i * 14.0,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: i.isEven
                                  ? AppColors.gold
                                  : const Color(0xFF2A2A2A),
                              child: Icon(
                                LucideIcons.user,
                                size: 12,
                                color: i.isEven ? _bg : AppColors.gold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
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
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.badgeCheck,
                              color: AppColors.gold,
                              size: 14,
                            ),
                          ],
                        ),
                        Text(
                          online
                              ? (agentsPresent > 1
                                  ? '$agentsPresent agents online'
                                  : 'Support online — reply from desk')
                              : 'Support offline — message still saved',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color: _muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  if (state.session?.isOpen == true)
                    IconButton(
                      tooltip: 'End chat',
                      onPressed: controller.endChat,
                      icon: const Icon(
                        LucideIcons.logOut,
                        size: 16,
                        color: _muted,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => ref
                        .read(liveChatPanelOpenProvider.notifier)
                        .state = false,
                    icon: const Icon(LucideIcons.x, size: 18, color: _muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x22FFFFFF)),
            if (identity.isAuthenticated)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(liveChatPanelOpenProvider.notifier).state = false;
                    ref.read(portalMessagesOpenLiveChatProvider.notifier).state =
                        true;
                    context.go(_portalMessagesLivePath(identity));
                  },
                  child: Text(
                    'Continue in your portal Messages',
                    style: GoogleFonts.manrope(
                      color: AppColors.gold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (!state.awaitingChoice)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  _Chip(
                    label: 'Properties',
                    onTap: () {
                      ref.read(liveChatPanelOpenProvider.notifier).state =
                          false;
                      context.go(RoutePaths.properties);
                    },
                  ),
                  _Chip(
                    label: 'Inspection',
                    onTap: () {
                      ref.read(liveChatPanelOpenProvider.notifier).state =
                          false;
                      context.go(RoutePaths.bookInspection);
                    },
                  ),
                  _Chip(
                    label: 'Investment',
                    onTap: () {
                      ref.read(liveChatPanelOpenProvider.notifier).state =
                          false;
                      context.go(RoutePaths.investment);
                    },
                  ),
                  _Chip(
                    label: 'Talk to Sales',
                    onTap: () => controller.send(
                      'Hi — I would like to speak with Sales.',
                    ),
                  ),
                ],
              ),
            ),
            if (state.error != null)
              Container(
                width: double.infinity,
                color: AppColors.error.withValues(alpha: 0.12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            if (state.session == null && !state.awaitingChoice)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Your name (optional)',
                    hintStyle: const TextStyle(color: _muted, fontSize: 13),
                    filled: true,
                    fillColor: _panelSoft,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  onChanged: controller.setDisplayName,
                ),
              ),
            Expanded(
              child: state.awaitingChoice
                  ? LiveChatResumePrompt(
                      state: state,
                      compact: true,
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
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Say hello to start a live conversation with HD Homes Concierge.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: _muted,
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          itemCount: state.messages.length +
                              (state.peerIsTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.messages.length) {
                              return const LiveChatTypingIndicator(
                                compact: true,
                              );
                            }
                            return LiveChatMessageBubble(
                              message: state.messages[index],
                              compact: true,
                            );
                          },
                        ),
            ),
            if (state.awaitingChoice)
              const SizedBox(height: 8)
            else if (state.session != null && state.session!.isOpen == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: OutlinedButton(
                  onPressed: controller.startNewChat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: _border),
                  ),
                  child: const Text('Start new chat'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: LiveChatComposer(
                  controller: _messageController,
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: _panelSoft,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
