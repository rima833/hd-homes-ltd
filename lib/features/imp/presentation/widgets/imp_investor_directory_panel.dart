import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Professional investor directory: table + optional right preview panel.
class ImpInvestorDirectoryPanel extends StatelessWidget {
  const ImpInvestorDirectoryPanel({
    super.key,
    required this.investors,
    required this.selectedInvestorId,
    required this.onPreview,
    required this.onOpen360,
    this.onCreate,
    this.onEdit,
    this.onArchive,
    this.total = 0,
    this.offset = 0,
    this.limit = 25,
    this.hasMore = false,
    this.onPrevPage,
    this.onNextPage,
  });

  final List<ImpInvestor> investors;
  final String? selectedInvestorId;
  final ValueChanged<String> onPreview;
  final ValueChanged<String> onOpen360;
  final VoidCallback? onCreate;
  final ValueChanged<ImpInvestor>? onEdit;
  final ValueChanged<ImpInvestor>? onArchive;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    if (investors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _DirEmpty(
          onCreate: onCreate,
        ),
      );
    }

    ImpInvestor? selected;
    for (final inv in investors) {
      if (inv.id == selectedInvestorId) {
        selected = inv;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSide = constraints.maxWidth >= 1080;
        final table = _DirectoryTable(
          investors: investors,
          selectedInvestorId: selectedInvestorId,
          onPreview: onPreview,
          onOpen360: onOpen360,
          onCreate: onCreate,
          onEdit: onEdit,
          onArchive: onArchive,
          total: total,
          offset: offset,
          hasMore: hasMore,
          onPrevPage: onPrevPage,
          onNextPage: onNextPage,
        );

        if (!showSide) {
          return table;
        }

        final preview = selected;
        final VoidCallback? open360 = preview == null
            ? null
            : () => onOpen360(preview.id);
        final VoidCallback? edit = preview == null || onEdit == null
            ? null
            : () => onEdit!(preview);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: table),
            const SizedBox(width: 12),
            SizedBox(
              width: 340,
              child: _InvestorPreviewCard(
                investor: preview,
                onOpen360: open360,
                onEdit: edit,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DirEmpty extends StatelessWidget {
  const _DirEmpty({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.users, color: AdminDeskColors.gold, size: 36),
          const SizedBox(height: 12),
          const Text(
            'No investors yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No investors have been added yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AdminDeskColors.muted),
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: const Text('Add Investor'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectoryTable extends StatelessWidget {
  const _DirectoryTable({
    required this.investors,
    required this.selectedInvestorId,
    required this.onPreview,
    required this.onOpen360,
    this.onCreate,
    this.onEdit,
    this.onArchive,
    required this.total,
    required this.offset,
    required this.hasMore,
    this.onPrevPage,
    this.onNextPage,
  });

  final List<ImpInvestor> investors;
  final String? selectedInvestorId;
  final ValueChanged<String> onPreview;
  final ValueChanged<String> onOpen360;
  final VoidCallback? onCreate;
  final ValueChanged<ImpInvestor>? onEdit;
  final ValueChanged<ImpInvestor>? onArchive;
  final int total;
  final int offset;
  final bool hasMore;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminDeskColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'Investor directory',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (onCreate != null)
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Add Investor'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminDeskColors.border),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 720),
              child: Theme(
                data: ThemeData.dark().copyWith(
                  dividerColor: AdminDeskColors.border,
                  dataTableTheme: const DataTableThemeData(
                    headingTextStyle: TextStyle(
                      color: AdminDeskColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    dataTextStyle: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AdminDeskColors.elevated,
                ),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text('Investor')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('KYC')),
                  DataColumn(label: Text('AUM'), numeric: true),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final inv in investors)
                    DataRow(
                      selected: inv.id == selectedInvestorId,
                      onSelectChanged: (_) => onPreview(inv.id),
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    AdminDeskColors.gold.withValues(alpha: 0.18),
                                child: Text(
                                  inv.fullName.isNotEmpty
                                      ? inv.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AdminDeskColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      inv.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      [
                                        inv.investorCode,
                                        if (inv.email != null &&
                                            inv.email!.isNotEmpty)
                                          inv.email!,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AdminDeskColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(_Pill(inv.investorType.label)),
                        DataCell(
                          _Pill(
                            inv.lifecycleStatus.label,
                            tone: _statusTone(inv.lifecycleStatus),
                          ),
                        ),
                        DataCell(
                          _Pill(
                            inv.kycStatus.label,
                            tone: _kycTone(inv.kycStatus),
                          ),
                        ),
                        DataCell(
                          Text(
                            inv.aumDisplay,
                            style: const TextStyle(
                              color: AdminDeskColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Open 360°',
                                onPressed: () => onOpen360(inv.id),
                                icon: const Icon(
                                  LucideIcons.eye,
                                  size: 16,
                                  color: AdminDeskColors.muted,
                                ),
                              ),
                              if (onEdit != null || onArchive != null)
                                PopupMenuButton<String>(
                                  tooltip: 'More',
                                  onSelected: (action) {
                                    if (action == 'edit') onEdit?.call(inv);
                                    if (action == 'archive') {
                                      onArchive?.call(inv);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (onEdit != null)
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                    if (onArchive != null)
                                      const PopupMenuItem(
                                        value: 'archive',
                                        child: Text('Archive'),
                                      ),
                                  ],
                                  icon: const Icon(
                                    LucideIcons.moreHorizontal,
                                    size: 16,
                                    color: AdminDeskColors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              children: [
                Text(
                  '${total == 0 ? 0 : offset + 1}–'
                  '${(offset + investors.length).clamp(0, total)} of $total',
                  style: const TextStyle(
                    color: AdminDeskColors.muted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: offset == 0 ? null : onPrevPage,
                  icon: const Icon(LucideIcons.chevronLeft, size: 18),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: !hasMore ? null : onNextPage,
                  icon: const Icon(LucideIcons.chevronRight, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusTone(InvestorLifecycleStatus status) => switch (status) {
        InvestorLifecycleStatus.active || InvestorLifecycleStatus.vip =>
          AdminDeskColors.green,
        InvestorLifecycleStatus.suspended => AdminDeskColors.red,
        InvestorLifecycleStatus.onboarding => AdminDeskColors.amber,
        _ => AdminDeskColors.muted,
      };

  Color _kycTone(KycStatus status) => switch (status) {
        KycStatus.approved || KycStatus.partiallyApproved =>
          AdminDeskColors.green,
        KycStatus.rejected || KycStatus.suspended || KycStatus.expired =>
          AdminDeskColors.red,
        _ => AdminDeskColors.amber,
      };
}

class _InvestorPreviewCard extends StatelessWidget {
  const _InvestorPreviewCard({
    required this.investor,
    this.onOpen360,
    this.onEdit,
  });

  final ImpInvestor? investor;
  final VoidCallback? onOpen360;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    if (investor == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminDeskColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminDeskColors.border),
        ),
        child: const Text(
          'Select an investor to preview profile, KYC, and book value.',
          style: TextStyle(color: AdminDeskColors.muted, height: 1.4),
        ),
      );
    }

    final inv = investor!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminDeskColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AdminDeskColors.gold.withValues(alpha: 0.18),
                child: Text(
                  inv.fullName.isNotEmpty ? inv.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AdminDeskColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      inv.investorCode,
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(inv.lifecycleStatus.label, tone: AdminDeskColors.green),
              _Pill(inv.investorType.label),
              _Pill('KYC ${inv.kycStatus.label}', tone: AdminDeskColors.amber),
            ],
          ),
          const SizedBox(height: 16),
          _kv('Email', inv.email ?? '—'),
          _kv('Phone', inv.phone ?? '—'),
          _kv('Owner', inv.assignedStaffName ?? 'Unassigned'),
          _kv('AUM', inv.aumDisplay, emphasize: true),
          _kv('Committed', formatImpMoney(inv.totalCommitted)),
          const SizedBox(height: 16),
          if (onOpen360 != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen360,
                icon: const Icon(LucideIcons.userCircle, size: 16),
                label: const Text('Open 360°'),
              ),
            ),
          if (onEdit != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.edit3, size: 16),
                label: const Text('Edit investor'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: emphasize ? AdminDeskColors.gold : Colors.white,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.tone = AdminDeskColors.muted});
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
