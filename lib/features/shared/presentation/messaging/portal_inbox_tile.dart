import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/client/presentation/widgets/client_messages_widgets.dart';
import 'package:hdhomesproject/features/shared/presentation/messaging/portal_inbox_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _panel = Color(0xFF12161D);
const _panelSoft = Color(0xFF1A1F28);
const _muted = Color(0xFF8B929E);
const _msgBg = Color(0xFF0B0E14);

class PortalInboxFilterBar extends StatelessWidget {
  const PortalInboxFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    this.messageCount = 0,
    this.ticketCount = 0,
  });

  final PortalInboxFilter filter;
  final ValueChanged<PortalInboxFilter> onChanged;
  final int messageCount;
  final int ticketCount;

  @override
  Widget build(BuildContext context) {
    Widget chip(PortalInboxFilter value, String label) {
      final selected = filter == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onChanged(value),
        selectedColor: AppColors.gold.withValues(alpha: 0.22),
        backgroundColor: _panelSoft,
        labelStyle: GoogleFonts.manrope(
          color: selected ? AppColors.gold : _muted,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.06),
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(PortalInboxFilter.all, 'All'),
        chip(PortalInboxFilter.messages, 'Messages ($messageCount)'),
        chip(PortalInboxFilter.tickets, 'Tickets ($ticketCount)'),
      ],
    );
  }
}

class PortalInboxItemTile extends StatelessWidget {
  const PortalInboxItemTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PortalInboxItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = formatClientMessageListTime(item.updatedAt);
    final accent = item.isTicket
        ? const Color(0xFFD97706)
        : teamAvatarColor(item.category ?? 'support');
    final initial = item.isTicket
        ? 'T'
        : (item.title.trim().isEmpty
              ? 'H'
              : item.title.trim()[0].toUpperCase());

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
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withValues(alpha: 0.18),
                child: item.isTicket
                    ? Icon(LucideIcons.ticket, size: 18, color: accent)
                    : Text(
                        initial,
                        style: GoogleFonts.manrope(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
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
                            item.title,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.isTicket ? 'Ticket' : 'Message',
                            style: GoogleFonts.manrope(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: _muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (item.unreadCount > 0) ...[
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
                              '${item.unreadCount}',
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
