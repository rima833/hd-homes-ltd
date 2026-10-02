import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/fapms/domain/entities/payment_verification_models.dart';
import 'package:hdhomesproject/features/fapms/presentation/providers/payment_verification_providers.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin queue for verifying client bank-transfer payment intents.
/// Historical completed/rejected intents are view-only — no silent edits.
class PaymentVerificationPage extends ConsumerWidget {
  const PaymentVerificationPage({
    super.key,
    this.embedded = false,
  });

  /// When true, omits outer Scaffold so it can sit inside Finance Command Center.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _VerificationBody(embedded: embedded);
    if (embedded) return body;
    return Scaffold(body: body);
  }
}

class _VerificationBody extends ConsumerWidget {
  const _VerificationBody({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentsAsync = ref.watch(paymentIntentsProvider);
    final pendingCount = ref.watch(pendingVerificationCountProvider);
    final search = ref.watch(paymentIntentSearchProvider);
    final statusFilter = ref.watch(paymentIntentStatusFilterProvider);
    final selectedId = ref.watch(selectedPaymentIntentIdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final listPane = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QueueHeader(
              pendingCount: pendingCount.valueOrNull ?? 0,
              onRefresh: () {
                ref.invalidate(paymentIntentsProvider);
                ref.invalidate(pendingPaymentIntentsProvider);
              },
            ),
            const SizedBox(height: 12),
            _QueueFilters(
              statusFilter: statusFilter,
              onSearch: (v) =>
                  ref.read(paymentIntentSearchProvider.notifier).set(v),
              onStatus: (v) =>
                  ref.read(paymentIntentStatusFilterProvider.notifier).set(v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: intentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Failed to load payment intents: $e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (rows) {
                  final filtered = filterPaymentIntents(rows, search);
                  if (filtered.isEmpty) {
                    return const _EmptyQueue();
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final row = filtered[i];
                      final selected = row.id == selectedId;
                      return _IntentListTile(
                        row: row,
                        selected: selected,
                        onTap: () {
                          ref
                              .read(selectedPaymentIntentIdProvider.notifier)
                              .set(row.id);
                          if (!wide) {
                            _showDetailSheet(context, ref, row.id);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );

        final content = DecoratedBox(
          decoration: BoxDecoration(
            color: embedded
                ? const Color(0xFF12141A)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(embedded ? 16 : 0),
            border: embedded
                ? Border.all(color: const Color(0x22FFFFFF))
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: listPane),
                      VerticalDivider(
                        width: 24,
                        color: embedded
                            ? const Color(0x22FFFFFF)
                            : null,
                      ),
                      Expanded(
                        flex: 4,
                        child: selectedId == null
                            ? const _DetailPlaceholder()
                            : _IntentDetailPanel(intentId: selectedId),
                      ),
                    ],
                  )
                : listPane,
          ),
        );

        if (embedded) {
          return SizedBox(
            height: (constraints.maxHeight.isFinite && constraints.maxHeight > 0)
                ? constraints.maxHeight
                : 640,
            child: content,
          );
        }
        return SafeArea(child: content);
      },
    );
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref, String intentId) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        builder: (ctx) {
          return Dialog(
            backgroundColor: const Color(0xFF12141A),
            insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 860,
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
              ),
              child: _PaymentDetailFrame(
                onClose: () => Navigator.pop(ctx),
                child: _IntentDetailPanel(intentId: intentId),
              ),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF12141A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.92,
          child: _PaymentDetailFrame(
            onClose: () => Navigator.pop(ctx),
            child: _IntentDetailPanel(intentId: intentId),
          ),
        );
      },
    );
  }
}

class _PaymentDetailFrame extends StatelessWidget {
  const _PaymentDetailFrame({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.badgeCheck, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Check the transfer, then approve, ask, or reject.',
                      style: TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x22FFFFFF)),
        Expanded(child: child),
      ],
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({
    required this.pendingCount,
    required this.onRefresh,
  });

  final int pendingCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(LucideIcons.badgeCheck, size: 18, color: AppColors.gold),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Payment verification',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.18),
            borderRadius: AppRadius.cardBorder,
          ),
          child: Text(
            '$pendingCount pending',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(LucideIcons.rotateCcw, size: 18, color: Color(0xFFC8CDD4)),
        ),
      ],
    );
  }
}

class _QueueFilters extends StatelessWidget {
  const _QueueFilters({
    required this.statusFilter,
    required this.onSearch,
    required this.onStatus,
  });

  final String? statusFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search client, property, reference…',
              hintStyle: const TextStyle(color: Color(0xFF9AA1AB)),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF9AA1AB)),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF0E1014),
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
                borderSide: const BorderSide(color: Color(0x22FFFFFF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
                borderSide: const BorderSide(color: Color(0x22FFFFFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.cardBorder,
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<String?>(
          value: statusFilter ?? 'all',
          dropdownColor: const Color(0xFF1A1D26),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'actionable', child: Text('Needs action')),
            DropdownMenuItem(
              value: 'pending_verification',
              child: Text('Pending'),
            ),
            DropdownMenuItem(
              value: 'info_requested',
              child: Text('Info requested'),
            ),
            DropdownMenuItem(value: 'completed', child: Text('Completed')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            DropdownMenuItem(value: 'all', child: Text('All')),
          ],
          onChanged: (v) {
            if (v == null || v == 'all') {
              onStatus('all');
            } else {
              onStatus(v);
            }
          },
        ),
      ],
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.inbox,
              size: 40,
              color: AppColors.gold.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            const Text(
              'No payments in this filter',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Client bank transfers waiting for review will show up here.',
              style: TextStyle(color: Color(0xFF9AA1AB), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: const Text(
        'Select a payment to review the receipt, then approve, ask, or reject.',
        style: TextStyle(color: Color(0xFF9AA1AB)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _IntentListTile extends StatelessWidget {
  const _IntentListTile({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final PaymentIntentRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (row.status) {
      PaymentIntentStatus.completed => const Color(0xFF86EFAC),
      PaymentIntentStatus.rejected => const Color(0xFFFCA5A5),
      PaymentIntentStatus.infoRequested => const Color(0xFFFDE68A),
      _ => AppColors.gold,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFF1C2118) : const Color(0xFF0E1014),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.7)
                    : const Color(0x18FFFFFF),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.amountDisplay,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.clientDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.propertyDisplay} · ${row.submittedDisplay}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        row.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      row.hasProof ? LucideIcons.fileCheck : LucideIcons.fileWarning,
                      size: 15,
                      color: row.hasProof
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFDE68A),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntentDetailPanel extends ConsumerWidget {
  const _IntentDetailPanel({required this.intentId});

  final String intentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentIntentDetailProvider(intentId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load detail: $e')),
      data: (intent) => _IntentDetailBody(intent: intent),
    );
  }
}

class _IntentDetailBody extends ConsumerStatefulWidget {
  const _IntentDetailBody({required this.intent});

  final PaymentIntentRow intent;

  @override
  ConsumerState<_IntentDetailBody> createState() => _IntentDetailBodyState();
}

class _IntentDetailBodyState extends ConsumerState<_IntentDetailBody> {
  bool _busy = false;

  PaymentIntentRow get intent => widget.intent;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(paymentIntentsProvider);
      ref.invalidate(pendingPaymentIntentsProvider);
      ref.invalidate(paymentIntentDetailProvider(intent.id));
      if (mounted && ModalRoute.of(context) is PopupRoute) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D26),
          title: const Text(
            'Confirm payment approval',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This posts the payment, allocates the amount, and issues a receipt.',
                style: TextStyle(color: Color(0xFFC8CDD4)),
              ),
              const SizedBox(height: 16),
              _ConfirmLine(label: 'Amount', value: intent.amountDisplay),
              _ConfirmLine(label: 'Property', value: intent.propertyDisplay),
              _ConfirmLine(label: 'Reference', value: intent.referenceDisplay),
              _ConfirmLine(label: 'Client', value: intent.clientDisplay),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                decoration: _reviewField('Reviewer notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFC8CDD4))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.deepBlack,
              ),
              child: const Text('Confirm approve'),
            ),
          ],
        );
      },
    );
    final notes = notesController.text.trim();
    notesController.dispose();
    if (confirmed != true) return;
    if (!mounted) return;

    await _run(() async {
      final service = ref.read(paymentVerificationServiceProvider);
      await service.approve(
        intent.id,
        notes: notes.isEmpty ? null : notes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment approved and receipt issued.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    });
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D26),
          title: const Text(
            'Reject payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white),
            decoration: _reviewField('Reason the client will see'),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFC8CDD4))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true) return;
    if (!mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A rejection reason is required.')),
      );
      return;
    }
    await _run(() async {
      await ref.read(paymentVerificationServiceProvider).reject(intent.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment rejected.')),
        );
      }
    });
  }

  Future<void> _requestInfo() async {
    final messageController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D26),
          title: const Text(
            'Request more information',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: messageController,
            style: const TextStyle(color: Colors.white),
            decoration: _reviewField('What should the client send?'),
            maxLines: 4,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFC8CDD4))),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.deepBlack,
              ),
              child: const Text('Send request'),
            ),
          ],
        );
      },
    );
    final message = messageController.text.trim();
    messageController.dispose();
    if (ok != true) return;
    if (!mounted) return;
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A message is required.')),
      );
      return;
    }
    await _run(() async {
      await ref
          .read(paymentVerificationServiceProvider)
          .requestInfo(intent.id, message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Information requested from client.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: split
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                            child: _ProofViewer(
                              proofPath: intent.proofStoragePath,
                              expand: true,
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Color(0x22FFFFFF)),
                        Expanded(flex: 6, child: _factsList(includeProof: false)),
                      ],
                    )
                  : _factsList(includeProof: true),
            ),
            _actionBar(),
          ],
        );
      },
    );
  }

  Widget _factsList({required bool includeProof}) {
    final fmt = DateFormat.yMMMd();
    final statusColor = switch (intent.status) {
      PaymentIntentStatus.completed => const Color(0xFF86EFAC),
      PaymentIntentStatus.rejected => const Color(0xFFFCA5A5),
      PaymentIntentStatus.infoRequested => const Color(0xFFFDE68A),
      _ => AppColors.gold,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                intent.amountDisplay,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                intent.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          intent.propertyDisplay,
          style: const TextStyle(color: Color(0xFFC8CDD4), fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (includeProof) ...[
          const _SectionLabel('Receipt'),
          const SizedBox(height: 8),
          _ProofViewer(proofPath: intent.proofStoragePath),
          const SizedBox(height: 14),
        ],
        const _SectionLabel('Who paid'),
        _DetailLine(label: 'Client', value: intent.clientDisplay),
        if (intent.clientEmail != null)
          _DetailLine(label: 'Email', value: intent.clientEmail!),
        if (intent.clientCode != null)
          _DetailLine(label: 'Client code', value: intent.clientCode!),
        const SizedBox(height: 8),
        const _SectionLabel('Transfer'),
        _DetailLine(label: 'Reference', value: intent.referenceDisplay),
        _DetailLine(label: 'Method', value: _prettyLabel(intent.provider)),
        _DetailLine(label: 'Submitted', value: intent.submittedDisplay),
        if (intent.transferDate != null)
          _DetailLine(
            label: 'Transfer date',
            value: fmt.format(intent.transferDate!),
          ),
        _DetailLine(label: 'Sender', value: intent.senderName ?? '—'),
        _DetailLine(label: 'Sender bank', value: intent.senderBank ?? '—'),
        _DetailLine(
          label: 'Txn reference',
          value: intent.transactionReference ?? '—',
        ),
        _DetailLine(label: 'Note', value: intent.transferNote ?? '—'),
        _DetailLine(
          label: 'Receiving',
          value: intent.receivingAccountLabel ?? '—',
        ),
        if (intent.rejectionReason != null)
          _DetailLine(label: 'Rejection', value: intent.rejectionReason!),
        if (intent.infoRequestMessage != null)
          _DetailLine(label: 'Info request', value: intent.infoRequestMessage!),
        if (intent.verifiedAt != null)
          _DetailLine(
            label: 'Verified',
            value: DateFormat.yMMMd().add_jm().format(intent.verifiedAt!.toLocal()),
          ),
        if (intent.verifications.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel('History'),
          const SizedBox(height: 8),
          ...intent.verifications.map((v) {
            final when = v.decidedAt == null
                ? null
                : DateFormat.yMMMd().add_jm().format(v.decidedAt!.toLocal());
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1014),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x18FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _prettyLabel(v.status),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (when != null)
                        Text(
                          when,
                          style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
                        ),
                    ],
                  ),
                  if ((v.reviewerNotes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      v.reviewerNotes!.trim(),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
        if (!intent.status.isActionable) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'This payment is already decided. The amount and ledger stay as recorded.',
              style: TextStyle(color: Color(0xFFC8CDD4), fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionBar() {
    if (!intent.status.isActionable) return const SizedBox.shrink();
    return PermissionGateAny(
      permissions: const [
        PermissionSlugs.financeApprovals,
        PermissionSlugs.financePayments,
        PermissionSlugs.financeWrite,
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF12141A),
          border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.gold,
                  backgroundColor: Color(0x22FFFFFF),
                ),
              ),
            FilledButton.icon(
              onPressed: _busy ? null : _approve,
              icon: const Icon(LucideIcons.checkCircle, size: 16),
              label: const Text('Approve payment'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.deepBlack,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _requestInfo,
                    icon: const Icon(LucideIcons.messageSquare, size: 16),
                    label: const Text('Request info'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _reject,
                    icon: const Icon(LucideIcons.xCircle, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFCA5A5),
                      side: const BorderSide(color: Color(0x55FCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _prettyLabel(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '—';
  return value
      .split(RegExp(r'[_\-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

InputDecoration _reviewField(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF9AA1AB)),
    filled: true,
    fillColor: const Color(0xFF0E1014),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x33FFFFFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.gold),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofViewer extends ConsumerWidget {
  const _ProofViewer({required this.proofPath, this.expand = false});

  final String? proofPath;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = proofPath?.trim();
    if (path == null || path.isEmpty) {
      return _ProofFrame(
        expand: expand,
        child: const Text(
          'No receipt uploaded yet.',
          style: TextStyle(color: Color(0xFF9AA1AB)),
        ),
      );
    }

    final urlAsync = ref.watch(proofSignedUrlProvider(path));
    return urlAsync.when(
      loading: () => _ProofFrame(
        expand: expand,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
        ),
      ),
      error: (_, _) => _ProofFrame(
        expand: expand,
        child: const Text(
          'The receipt could not be loaded. Refresh and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFFCA5A5)),
        ),
      ),
      data: (url) {
        if (url == null || url.isEmpty) {
          return _ProofFrame(
            expand: expand,
            child: const Text(
              'The receipt link is not ready yet.',
              style: TextStyle(color: Color(0xFF9AA1AB)),
            ),
          );
        }
        final lower = path.toLowerCase();
        final isImage = lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.gif');
        if (!isImage) {
          return _ProofFrame(
            expand: expand,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.fileText, color: AppColors.gold, size: 28),
                const SizedBox(height: 10),
                const Text(
                  'Receipt document',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openProof(context, url, isImage: false),
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  label: const Text('Open receipt'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.deepBlack,
                  ),
                ),
              ],
            ),
          );
        }

        final image = GestureDetector(
          onTap: () => _openProof(context, url, isImage: true),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    'Unable to preview this receipt.',
                    style: TextStyle(color: Color(0xFFFCA5A5)),
                  ),
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xCC000000),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.maximize2, size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Enlarge',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (expand) {
          return _ProofFrame(expand: true, child: image);
        }
        return SizedBox(height: 220, child: _ProofFrame(expand: true, child: image));
      },
    );
  }
}

class _ProofFrame extends StatelessWidget {
  const _ProofFrame({required this.child, this.expand = false});

  final Widget child;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E1014),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: expand
            ? SizedBox.expand(child: Center(child: child))
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: child),
              ),
      ),
    );
  }
}

Future<void> _openProof(
  BuildContext context,
  String url, {
  required bool isImage,
}) async {
  if (!isImage) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      return Dialog(
        backgroundColor: const Color(0xFF0E1014),
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: size.width * 0.86,
          height: size.height * 0.86,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: size.width * 0.86,
                    height: size.height * 0.86,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xCC000000)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bank accounts, client payment methods, and late-fee rule management.
class ClientPaymentsSettingsPanel extends ConsumerWidget {
  const ClientPaymentsSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReceivingAccountsSection(),
        const SizedBox(height: 16),
        const Divider(color: Color(0x22FFFFFF)),
        const SizedBox(height: 16),
        _PaymentMethodsSection(),
        const SizedBox(height: 16),
        const Divider(color: Color(0x22FFFFFF)),
        const SizedBox(height: 16),
        _LateFeeRulesSection(),
      ],
    );
  }
}

class _ReceivingAccountsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receivingAccountsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Company receiving accounts',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openAccountEditor(context, ref),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load accounts: $e'),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const Text('No receiving accounts configured.');
            }
            return Column(
              children: accounts.map((a) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    a.accountName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${a.bankName} · ${a.accountNumber}'
                    '${a.isDefault ? ' · DEFAULT' : ''}'
                    '${a.isActive ? '' : ' · inactive'}',
                    style: const TextStyle(color: Color(0x99FFFFFF)),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (!a.isDefault)
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(paymentVerificationServiceProvider)
                                .setDefaultAccount(a.id);
                            ref.invalidate(receivingAccountsProvider);
                          },
                          child: const Text('Set default'),
                        ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () =>
                            _openAccountEditor(context, ref, existing: a),
                        icon: const Icon(LucideIcons.pencil, size: 16),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openAccountEditor(
    BuildContext context,
    WidgetRef ref, {
    CompanyReceivingAccount? existing,
  }) async {
    final name = TextEditingController(text: existing?.accountName ?? '');
    final bank = TextEditingController(text: existing?.bankName ?? '');
    final number = TextEditingController(text: existing?.accountNumber ?? '');
    final instructions =
        TextEditingController(text: existing?.paymentInstructions ?? '');
    var isDefault = existing?.isDefault ?? false;
    var isActive = existing?.isActive ?? true;
    var available = existing?.availableForClients ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(existing == null ? 'Add account' : 'Edit account'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Account name'),
                      ),
                      TextField(
                        controller: bank,
                        decoration:
                            const InputDecoration(labelText: 'Bank name'),
                      ),
                      TextField(
                        controller: number,
                        decoration:
                            const InputDecoration(labelText: 'Account number'),
                      ),
                      TextField(
                        controller: instructions,
                        decoration: const InputDecoration(
                          labelText: 'Payment instructions',
                        ),
                        maxLines: 3,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Default account'),
                        value: isDefault,
                        onChanged: (v) => setLocal(() => isDefault = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setLocal(() => isActive = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available for clients'),
                        value: available,
                        onChanged: (v) => setLocal(() => available = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      name.dispose();
      bank.dispose();
      number.dispose();
      instructions.dispose();
      return;
    }

    try {
      await ref.read(paymentVerificationServiceProvider).upsertReceivingAccount(
            CompanyReceivingAccount(
              id: existing?.id ?? '',
              accountName: name.text.trim(),
              bankName: bank.text.trim(),
              accountNumber: number.text.trim(),
              paymentInstructions: instructions.text.trim().isEmpty
                  ? null
                  : instructions.text.trim(),
              isDefault: isDefault,
              isActive: isActive,
              availableForClients: available,
              sortOrder: existing?.sortOrder ?? 0,
              currency: existing?.currency ?? 'NGN',
              branch: existing?.branch,
              accountReference: existing?.accountReference,
            ),
          );
      ref.invalidate(receivingAccountsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      name.dispose();
      bank.dispose();
      number.dispose();
      instructions.dispose();
    }
  }
}

class _PaymentMethodsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentMethodsConfigProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client payment methods',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load methods: $e'),
          data: (methods) {
            if (methods.isEmpty) {
              return const Text(
                'No payment methods found.',
                style: TextStyle(color: Color(0x99FFFFFF)),
              );
            }
            return Column(
              children: methods.map((m) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.gold,
                  title: Text(
                    m.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    [
                      m.slug,
                      if (m.isRecommended) 'recommended',
                      if (!m.isActive) 'inactive',
                    ].join(' · '),
                    style: const TextStyle(color: Color(0x99FFFFFF)),
                  ),
                  value: m.clientEnabled,
                  onChanged: (enabled) async {
                    await ref
                        .read(paymentVerificationServiceProvider)
                        .updateMethodClientEnabled(m.id, enabled);
                    ref.invalidate(paymentMethodsConfigProvider);
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LateFeeRulesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lateFeeRulesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Late fee rules',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final result = await ref
                      .read(paymentVerificationServiceProvider)
                      .applyOverdueLateFees();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Late fees applied: ${result['applied'] ?? 0}',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Apply failed: $e')),
                    );
                  }
                }
              },
              icon: const Icon(LucideIcons.play, size: 16),
              label: const Text('Apply overdue'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.deepBlack,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load late fee rules: $e'),
          data: (rules) {
            if (rules.isEmpty) {
              return const Text('No late fee rules configured.');
            }
            return Column(
              children: rules.map((r) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name),
                  subtitle: Text(
                    '${r.calculationType} · ${r.valueDisplay} · '
                    'grace ${r.gracePeriodDays}d',
                  ),
                  value: r.enabled,
                  onChanged: (enabled) async {
                    await ref
                        .read(paymentVerificationServiceProvider)
                        .updateLateFeeRuleEnabled(id: r.id, enabled: enabled);
                    ref.invalidate(lateFeeRulesProvider);
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
