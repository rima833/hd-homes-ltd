import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/live_chat/presentation/widgets/live_chat_support_section.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Shared spacing for portal Messages page shells.
abstract final class PortalMessagesSpacing {
  static const double afterSubtitle = 4;
  static const double afterHeader = 8;
  static const double afterHeaderLive = 6;
  static const double actionGap = 8;
}

/// Threads (account) vs Live chat (Concierge) on portal Messages.
enum PortalMessagesMode { threads, liveChat }

/// Segment control: account threads | live chat with Concierge.
class PortalMessagesModeToggle extends StatelessWidget {
  const PortalMessagesModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    this.compact = false,
  });

  final PortalMessagesMode mode;
  final ValueChanged<PortalMessagesMode> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required PortalMessagesMode value,
      required IconData icon,
      required String label,
    }) {
      final selected = mode == value;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.45)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: compact ? 14 : 15,
                    color: selected ? AppColors.gold : AppColors.slate400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.gold : AppColors.slate400,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          chip(
            value: PortalMessagesMode.threads,
            icon: LucideIcons.messagesSquare,
            label: 'Threads',
          ),
          chip(
            value: PortalMessagesMode.liveChat,
            icon: LucideIcons.messageCircle,
            label: 'Live chat',
          ),
        ],
      ),
    );
  }
}

/// Live Concierge panel for portal Messages — fills remaining viewport height.
class PortalMessagesLiveChatBlock extends StatelessWidget {
  const PortalMessagesLiveChatBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF14171E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: LiveChatSupportSection(embedded: true),
        ),
      ),
    );
  }
}

/// Page header for client / investor Messages.
///
/// In live-chat mode this collapses to a slim toggle + actions so the chat
/// panel can use almost the full viewport.
class PortalMessagesPageHeader extends StatelessWidget {
  const PortalMessagesPageHeader({
    super.key,
    required this.onOpenSupport,
    required this.onNew,
    this.subtitle = 'Chat with HD Homes in real time.',
    this.newLabel = 'New',
    this.newIsIconOnly = false,
    this.mode,
    this.onModeChanged,
  });

  final VoidCallback onOpenSupport;
  final VoidCallback onNew;
  final String subtitle;
  final String newLabel;

  /// When true, New is a compact gold + icon (client list chrome).
  final bool newIsIconOnly;

  /// Optional Threads / Live chat toggle under the subtitle.
  final PortalMessagesMode? mode;
  final ValueChanged<PortalMessagesMode>? onModeChanged;

  bool get _live => mode == PortalMessagesMode.liveChat;

  Widget _newButton() {
    if (newIsIconOnly || _live) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onNew,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: _live ? 36 : 42,
            height: _live ? 36 : 42,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              LucideIcons.plus,
              color: const Color(0xFF0B0E14),
              size: _live ? 16 : 20,
            ),
          ),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onNew,
      icon: const Icon(LucideIcons.plus, size: 16),
      label: Text(newLabel),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF0B0E14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _ticketsButton({bool iconOnly = false}) {
    if (iconOnly) {
      return IconButton(
        tooltip: 'Open a ticket',
        onPressed: onOpenSupport,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(LucideIcons.ticket, size: 18),
      );
    }
    return OutlinedButton.icon(
      onPressed: onOpenSupport,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(LucideIcons.ticket, size: 16),
      label: const Text('Tickets'),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.messagesSquare,
            color: Color(0xFF0B0E14),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Messages',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  /// Slim bar used while Live chat is active — maximises chat height.
  Widget _liveChrome(BuildContext context) {
    return Row(
      children: [
        if (mode != null && onModeChanged != null)
          Expanded(
            child: PortalMessagesModeToggle(
              mode: mode!,
              onChanged: onModeChanged!,
              compact: true,
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 8),
        _ticketsButton(iconOnly: true),
        const SizedBox(width: PortalMessagesSpacing.actionGap),
        _newButton(),
      ],
    );
  }

  Widget _threadsChrome(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    final showMode = mode != null && onModeChanged != null;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ticketsButton(),
        const SizedBox(width: PortalMessagesSpacing.actionGap),
        _newButton(),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          _titleRow(context),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ticketsButton()),
              const SizedBox(width: PortalMessagesSpacing.actionGap),
              _newButton(),
            ],
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _titleRow(context)),
              actions,
            ],
          ),
        const SizedBox(height: PortalMessagesSpacing.afterSubtitle),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.slate400,
            height: 1.35,
          ),
        ),
        if (showMode) ...[
          const SizedBox(height: 12),
          PortalMessagesModeToggle(mode: mode!, onChanged: onModeChanged!),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - t)),
          child: child,
        ),
      ),
      child: _live ? _liveChrome(context) : _threadsChrome(context),
    );
  }
}

/// List / thread pane chrome for client Messages workspace.
class PortalMessagesPanelShell extends StatelessWidget {
  const PortalMessagesPanelShell({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF171C26),
            AppColors.darkSurface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
