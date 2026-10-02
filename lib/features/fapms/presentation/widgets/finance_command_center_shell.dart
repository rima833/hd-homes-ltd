import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/fapms_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/fapms_controller.dart';
import 'package:hdhomesproject/features/fapms/presentation/widgets/finance_admin_shared.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Desk tokens aligned with CRM Sales Command Center.
abstract final class FinanceDeskColors {
  static const bg = Color(0xFF0B0E14);
  static const sidebar = Color(0xFF0F1218);
  static const surface = Color(0xFF141820);
  static const elevated = Color(0xFF1A1F28);
  static const border = Color(0x18FFFFFF);
  static const muted = Color(0xFF8B929E);
  static const gold = AppColors.primaryGold;
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);
}

class FinanceNavSection {
  const FinanceNavSection({required this.title, required this.items});

  final String title;
  final List<FinanceNavItem> items;
}

class FinanceNavItem {
  const FinanceNavItem({
    required this.tab,
    required this.icon,
    this.badge,
    this.urgent = false,
  });

  final FapmsCommandTab tab;
  final IconData icon;
  final int? badge;
  final bool urgent;
}

List<FinanceNavSection> buildFinanceNavSections(
  FapmsCommandCenterSnapshot snap,
) {
  final pendingVerify = snap.pendingClientVerifications;
  final pendingInvestor = snap.pendingInvestorIntents;
  final pendingApprovals = snap.pendingApprovals.length;
  final overdueInstallments = snap.overdueInstallmentCount;

  return [
    const FinanceNavSection(
      title: 'Command',
      items: [
        FinanceNavItem(
          tab: FapmsCommandTab.overview,
          icon: LucideIcons.layoutDashboard,
        ),
      ],
    ),
    FinanceNavSection(
      title: 'Money in',
      items: [
        FinanceNavItem(
          tab: FapmsCommandTab.verification,
          icon: LucideIcons.shieldCheck,
          badge: pendingVerify > 0 ? pendingVerify : null,
          urgent: pendingVerify > 0,
        ),
        FinanceNavItem(
          tab: FapmsCommandTab.payments,
          icon: LucideIcons.banknote,
          badge: snap.paymentTxs.isNotEmpty ? snap.paymentTxs.length : null,
        ),
        FinanceNavItem(
          tab: FapmsCommandTab.installments,
          icon: LucideIcons.calendarDays,
          badge: overdueInstallments > 0 ? overdueInstallments : null,
          urgent: overdueInstallments > 0,
        ),
      ],
    ),
    FinanceNavSection(
      title: 'Ledger',
      items: [
        FinanceNavItem(
          tab: FapmsCommandTab.invoices,
          icon: LucideIcons.fileText,
          badge: snap.invoices.isNotEmpty ? snap.invoices.length : null,
        ),
        FinanceNavItem(
          tab: FapmsCommandTab.expenses,
          icon: LucideIcons.receipt,
          badge: pendingApprovals > 0 ? pendingApprovals : null,
          urgent: pendingApprovals > 0,
        ),
        FinanceNavItem(
          tab: FapmsCommandTab.banking,
          icon: LucideIcons.landmark,
        ),
      ],
    ),
    FinanceNavSection(
      title: 'Site flows',
      items: [
        FinanceNavItem(
          tab: FapmsCommandTab.investor,
          icon: LucideIcons.trendingUp,
          badge: pendingInvestor > 0 ? pendingInvestor : null,
          urgent: pendingInvestor > 0,
        ),
        FinanceNavItem(
          tab: FapmsCommandTab.leads,
          icon: LucideIcons.calculator,
          badge: snap.openLeadCount > 0 ? snap.openLeadCount : null,
        ),
        FinanceNavItem(
          tab: FapmsCommandTab.commissions,
          icon: LucideIcons.percent,
          badge: snap.openCommissionCount > 0 ? snap.openCommissionCount : null,
        ),
      ],
    ),
    const FinanceNavSection(
      title: 'System',
      items: [
        FinanceNavItem(
          tab: FapmsCommandTab.setup,
          icon: LucideIcons.settings2,
        ),
      ],
    ),
  ];
}

bool financeTabUsesSearch(FapmsCommandTab tab) => switch (tab) {
      FapmsCommandTab.payments ||
      FapmsCommandTab.installments ||
      FapmsCommandTab.invoices ||
      FapmsCommandTab.expenses ||
      FapmsCommandTab.leads ||
      FapmsCommandTab.commissions =>
        true,
      _ => false,
    };

bool financeTabUsesStatusFilter(FapmsCommandTab tab) =>
    tab == FapmsCommandTab.invoices || tab == FapmsCommandTab.expenses;

bool financeTabShowsKpis(FapmsCommandTab tab) =>
    tab == FapmsCommandTab.overview;

class FinanceDeskSidebar extends StatelessWidget {
  const FinanceDeskSidebar({
    super.key,
    required this.sections,
    required this.selected,
    required this.onSelect,
    required this.live,
    this.onClose,
  });

  final List<FinanceNavSection> sections;
  final FapmsCommandTab selected;
  final ValueChanged<FapmsCommandTab> onSelect;
  final bool live;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FinanceDeskColors.sidebar,
        border: Border(right: BorderSide(color: FinanceDeskColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINANCE DESK',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: FinanceDeskColors.gold,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Command Center',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(LucideIcons.x, color: FinanceDeskColors.muted),
                  ),
              ],
            ),
          ),
          if (!live)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: OfflineUpdatesNote(color: FinanceDeskColors.muted),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                    child: Text(
                      section.title.toUpperCase(),
                      style: const TextStyle(
                        color: FinanceDeskColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  for (final item in section.items)
                    _FinanceNavTile(
                      item: item,
                      selected: selected == item.tab,
                      onTap: () => onSelect(item.tab),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceNavTile extends StatelessWidget {
  const _FinanceNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FinanceNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? FinanceDeskColors.gold.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? FinanceDeskColors.gold.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? FinanceDeskColors.gold : FinanceDeskColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.tab.label,
                    style: TextStyle(
                      color: selected ? Colors.white : FinanceDeskColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.urgent
                          ? FinanceDeskColors.amber.withValues(alpha: 0.18)
                          : FinanceDeskColors.elevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: item.urgent
                            ? FinanceDeskColors.amber.withValues(alpha: 0.55)
                            : FinanceDeskColors.border,
                      ),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: TextStyle(
                        color: item.urgent
                            ? FinanceDeskColors.amber
                            : FinanceDeskColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
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

class FinanceDeskTopBar extends StatelessWidget {
  const FinanceDeskTopBar({
    super.key,
    required this.tab,
    required this.live,
    required this.loadedAt,
    required this.onRefresh,
    required this.pendingVerify,
    this.showMenu = false,
    this.onMenu,
    this.onOpenVerification,
    this.onCreateInvoice,
    this.onCreateExpense,
  });

  final FapmsCommandTab tab;
  final bool live;
  final DateTime? loadedAt;
  final Future<void> Function() onRefresh;
  final int pendingVerify;
  final bool showMenu;
  final VoidCallback? onMenu;
  final VoidCallback? onOpenVerification;
  final VoidCallback? onCreateInvoice;
  final VoidCallback? onCreateExpense;

  @override
  Widget build(BuildContext context) {
    final synced = loadedAt == null
        ? null
        : 'Synced ${DateFormat.jm().format(loadedAt!.toLocal())}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: const BoxDecoration(
        color: FinanceDeskColors.surface,
        border: Border(bottom: BorderSide(color: FinanceDeskColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          return Row(
            children: [
              if (showMenu && onMenu != null)
                IconButton(
                  onPressed: onMenu,
                  icon: const Icon(
                    LucideIcons.panelLeft,
                    color: FinanceDeskColors.muted,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (synced != null)
                      Text(
                        synced,
                        style: const TextStyle(
                          color: FinanceDeskColors.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (!narrow && pendingVerify > 0 && onOpenVerification != null)
                PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.financeApprovals,
                    PermissionSlugs.financePayments,
                    PermissionSlugs.financeWrite,
                  ],
                  child: OutlinedButton.icon(
                    onPressed: onOpenVerification,
                    icon: const Icon(LucideIcons.shieldCheck, size: 15),
                    label: Text('Verify ($pendingVerify)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FinanceDeskColors.amber,
                      side: BorderSide(
                        color: FinanceDeskColors.amber.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              if (!narrow && pendingVerify > 0) const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: Icon(
                  LucideIcons.refreshCw,
                  size: 18,
                  color: live ? FinanceDeskColors.green : FinanceDeskColors.muted,
                ),
              ),
              if (narrow)
                _FinanceOverflowMenu(
                  pendingVerify: pendingVerify,
                  onOpenVerification: onOpenVerification,
                  onCreateInvoice: onCreateInvoice,
                  onCreateExpense: onCreateExpense,
                )
              else ...[
                if (tab == FapmsCommandTab.invoices && onCreateInvoice != null)
                  PermissionGateAny(
                    permissions: const [
                      PermissionSlugs.financeInvoices,
                      PermissionSlugs.financeWrite,
                    ],
                    child: OutlinedButton.icon(
                      onPressed: onCreateInvoice,
                      icon: const Icon(LucideIcons.filePlus, size: 15),
                      label: const Text('Invoice'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FinanceDeskColors.gold,
                        side: BorderSide(
                          color: FinanceDeskColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                if (tab == FapmsCommandTab.invoices) const SizedBox(width: 8),
                if (tab == FapmsCommandTab.expenses && onCreateExpense != null)
                  PermissionGateAny(
                    permissions: const [
                      PermissionSlugs.financeExpenses,
                      PermissionSlugs.financeWrite,
                    ],
                    child: FilledButton.icon(
                      onPressed: onCreateExpense,
                      icon: const Icon(LucideIcons.plus, size: 15),
                      label: const Text('Expense'),
                      style: FilledButton.styleFrom(
                        backgroundColor: FinanceDeskColors.gold,
                        foregroundColor: FinanceDeskColors.bg,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class FinanceDeskKpiStrip extends StatelessWidget {
  const FinanceDeskKpiStrip({
    super.key,
    required this.kpis,
    this.scrollController,
    this.onKpi,
  });

  final List<FapmsKpi> kpis;
  final ScrollController? scrollController;
  final ValueChanged<String>? onKpi;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 82,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: false,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2),
          itemCount: kpis.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final k = kpis[i];
            return _FinanceKpiTile(
              kpi: k,
              onTap: onKpi == null ? null : () => onKpi!(k.label),
            );
          },
        ),
      ),
    );
  }
}

class _FinanceKpiTile extends StatelessWidget {
  const _FinanceKpiTile({required this.kpi, this.onTap});

  final FapmsKpi kpi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FinanceDeskColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 132, maxWidth: 168),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinanceDeskColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                kpi.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FinanceDeskColors.muted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 22,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kpi.displayValue,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceDeskSearchBar extends StatelessWidget {
  const FinanceDeskSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    this.statusFilter,
    required this.onStatus,
    required this.showStatus,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final String? statusFilter;
  final ValueChanged<String?> onStatus;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: FinanceAdminUi.fieldDecoration(
              'Search',
              hint: 'Invoice, party, provider, expense…',
              prefix: const Icon(
                LucideIcons.search,
                size: 18,
                color: FinanceDeskColors.muted,
              ),
            ).copyWith(isDense: true),
          ),
        ),
        if (showStatus) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String?>(
              initialValue: statusFilter,
              dropdownColor: FinanceDeskColors.elevated,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: FinanceAdminUi.fieldDecoration('Status').copyWith(
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'sent', child: Text('Sent')),
                DropdownMenuItem(value: 'paid', child: Text('Paid')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
              ],
              onChanged: onStatus,
            ),
          ),
        ],
      ],
    );
  }
}

class _FinanceOverflowMenu extends ConsumerWidget {
  const _FinanceOverflowMenu({
    required this.pendingVerify,
    required this.onOpenVerification,
    required this.onCreateInvoice,
    required this.onCreateExpense,
  });

  final int pendingVerify;
  final VoidCallback? onOpenVerification;
  final VoidCallback? onCreateInvoice;
  final VoidCallback? onCreateExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <PopupMenuEntry<String>>[];
    if (pendingVerify > 0 &&
        onOpenVerification != null &&
        evaluatePermissionAny(ref, const [
          PermissionSlugs.financeApprovals,
          PermissionSlugs.financePayments,
          PermissionSlugs.financeWrite,
        ])) {
      items.add(
        PopupMenuItem(
          value: 'verify',
          child: Text('Verify ($pendingVerify)'),
        ),
      );
    }
    if (onCreateInvoice != null &&
        evaluatePermissionAny(ref, const [
          PermissionSlugs.financeInvoices,
          PermissionSlugs.financeWrite,
        ])) {
      items.add(
        const PopupMenuItem(value: 'invoice', child: Text('New invoice')),
      );
    }
    if (onCreateExpense != null &&
        evaluatePermissionAny(ref, const [
          PermissionSlugs.financeExpenses,
          PermissionSlugs.financeWrite,
        ])) {
      items.add(
        const PopupMenuItem(value: 'expense', child: Text('New expense')),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(
        LucideIcons.moreVertical,
        color: FinanceDeskColors.muted,
      ),
      color: FinanceDeskColors.elevated,
      onSelected: (v) {
        switch (v) {
          case 'verify':
            onOpenVerification?.call();
          case 'invoice':
            onCreateInvoice?.call();
          case 'expense':
            onCreateExpense?.call();
        }
      },
      itemBuilder: (_) => items,
    );
  }
}
