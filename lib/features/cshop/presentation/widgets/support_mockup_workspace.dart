import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cshop/presentation/providers/cshop_controller.dart';
import 'package:hdhomesproject/features/cshop/presentation/widgets/support_desk_chrome.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Mockup-aligned Support workspace card: tabs + body, height-safe.
/// Gold segmented control used inside the ticket column.
class SupportDeskTabs extends StatelessWidget {
  const SupportDeskTabs({
    super.key,
    required this.selected,
    required this.openChats,
    required this.ticketCount,
    required this.onSelect,
  });

  final CshopCommandTab selected;
  final int openChats;
  final int ticketCount;
  final ValueChanged<CshopCommandTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0B2037),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final tab in CshopCommandTab.primary)
            Expanded(
              child: _Tab(
                label: tab == CshopCommandTab.liveChat && openChats > 0
                    ? '${tab.label} ($openChats)'
                    : tab == CshopCommandTab.tickets && ticketCount > 0
                    ? '${tab.label} ($ticketCount)'
                    : tab.label,
                active: selected == tab,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? SupportDeskChrome.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: active ? Colors.black : const Color(0xFFB7C5D5),
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class SupportMockupWorkspace extends StatelessWidget {
  const SupportMockupWorkspace({
    super.key,
    required this.selectedTab,
    required this.openChats,
    required this.ticketCount,
    required this.onSelectTab,
    required this.body,
    this.message,
    this.onDismissMessage,
  });

  final CshopCommandTab selectedTab;
  final int openChats;
  final int ticketCount;
  final ValueChanged<CshopCommandTab> onSelectTab;
  final Widget body;
  final String? message;
  final VoidCallback? onDismissMessage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SupportDeskChrome.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SupportDeskChrome.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in CshopCommandTab.primary) ...[
                      _MockupTabPill(
                        label: tab == CshopCommandTab.liveChat && openChats > 0
                            ? '${tab.label} ($openChats)'
                            : tab == CshopCommandTab.tickets && ticketCount > 0
                            ? '${tab.label} ($ticketCount)'
                            : tab.label,
                        selected: selectedTab == tab,
                        onTap: () => onSelectTab(tab),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Material(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    minVerticalPadding: 0,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(
                      LucideIcons.info,
                      color: AppColors.gold,
                      size: 14,
                    ),
                    title: Text(
                      message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        LucideIcons.x,
                        size: 14,
                        color: Colors.white70,
                      ),
                      onPressed: onDismissMessage,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            const Divider(height: 1, color: SupportDeskChrome.border),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _MockupTabPill extends StatelessWidget {
  const _MockupTabPill({
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
      color: selected ? AppColors.gold : const Color(0xFF1A1F28),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.22),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.charcoal : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact ticket filters meant to live inside the left list pane.
class SupportTicketListFilters extends StatefulWidget {
  const SupportTicketListFilters({
    super.key,
    required this.searchQuery,
    required this.statusFilter,
    required this.onSearch,
    required this.onStatus,
  });

  final String searchQuery;
  final String? statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  State<SupportTicketListFilters> createState() =>
      _SupportTicketListFiltersState();
}

class _SupportTicketListFiltersState extends State<SupportTicketListFilters> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant SupportTicketListFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _search.text &&
        widget.searchQuery != oldWidget.searchQuery) {
      _search.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: TextField(
              controller: _search,
              onChanged: widget.onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search tickets...',
                hintStyle: const TextStyle(
                  color: SupportDeskChrome.muted,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 14,
                  color: SupportDeskChrome.muted,
                ),
                suffixIcon: const Icon(
                  LucideIcons.slidersHorizontal,
                  size: 14,
                  color: SupportDeskChrome.muted,
                ),
                filled: true,
                fillColor: const Color(0xFF12161E),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: SupportDeskChrome.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: SupportDeskChrome.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                'All',
                widget.statusFilter == null,
                () => widget.onStatus(null),
              ),
              _chip(
                'Open',
                widget.statusFilter == 'open',
                () => widget.onStatus(
                  widget.statusFilter == 'open' ? null : 'open',
                ),
              ),
              _chip(
                'In Progress',
                widget.statusFilter == 'in_progress',
                () => widget.onStatus(
                  widget.statusFilter == 'in_progress' ? null : 'in_progress',
                ),
              ),
              _chip(
                'Escalated',
                widget.statusFilter == 'escalated',
                () => widget.onStatus(
                  widget.statusFilter == 'escalated' ? null : 'escalated',
                ),
              ),
              _chip(
                'Resolved',
                widget.statusFilter == 'resolved',
                () => widget.onStatus(
                  widget.statusFilter == 'resolved' ? null : 'resolved',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: selected ? SupportDeskChrome.gold : const Color(0xFF10253A),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.black : SupportDeskChrome.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
