import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// KYC queue desk — approve / reject / request update via existing verify RPC.
class ImpKycDeskPanel extends StatelessWidget {
  const ImpKycDeskPanel({
    super.key,
    required this.items,
    required this.canManage,
    required this.onOpenInvestor,
    required this.onVerify,
  });

  final List<ImpWorkQueueItem> items;
  final bool canManage;
  final ValueChanged<String> onOpenInvestor;
  final Future<void> Function(String investorId, KycStatus status) onVerify;

  @override
  Widget build(BuildContext context) {
    if (!canManage) {
      return const Text(
        'You do not have permission to manage KYC.',
        style: TextStyle(color: AdminDeskColors.muted),
      );
    }
    if (items.isEmpty) {
      return const Text(
        'No KYC submissions require review.',
        style: TextStyle(color: AdminDeskColors.muted, height: 1.4),
      );
    }

    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(
              LucideIcons.shieldCheck,
              size: 18,
              color: AdminDeskColors.gold,
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              [
                if (item.subtitle != null && item.subtitle!.isNotEmpty)
                  item.subtitle!,
                item.status.replaceAll('_', ' '),
              ].join(' · '),
              style: const TextStyle(
                color: AdminDeskColors.muted,
                fontSize: 12,
              ),
            ),
            trailing: canManage
                ? PopupMenuButton<String>(
                    tooltip: 'KYC decision',
                    onSelected: (action) async {
                      final status = switch (action) {
                        'approved' => KycStatus.approved,
                        'rejected' => KycStatus.rejected,
                        'awaiting' => KycStatus.awaitingDocuments,
                        'resubmit' => KycStatus.needsResubmission,
                        _ => null,
                      };
                      if (status == null) {
                        onOpenInvestor(item.investorId);
                        return;
                      }
                      await onVerify(item.investorId, status);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'approved',
                        child: Text('Approve'),
                      ),
                      PopupMenuItem(
                        value: 'awaiting',
                        child: Text('Request documents'),
                      ),
                      PopupMenuItem(
                        value: 'resubmit',
                        child: Text('Needs resubmission'),
                      ),
                      PopupMenuItem(
                        value: 'rejected',
                        child: Text('Reject'),
                      ),
                      PopupMenuItem(
                        value: 'open',
                        child: Text('Open 360°'),
                      ),
                    ],
                  )
                : IconButton(
                    tooltip: 'Open investor',
                    onPressed: () => onOpenInvestor(item.investorId),
                    icon: const Icon(LucideIcons.chevronRight, size: 16),
                  ),
            onTap: () => onOpenInvestor(item.investorId),
          ),
      ],
    );
  }
}

/// Documents desk — vault for selected investor + publish from DDCMS catalog.
class ImpDocumentsDeskPanel extends StatefulWidget {
  const ImpDocumentsDeskPanel({
    super.key,
    required this.investors,
    required this.selectedInvestorId,
    required this.onSelectInvestor,
    required this.vaultDocuments,
    required this.publishableDocuments,
    required this.canPublish,
    required this.loadingVault,
    required this.onPublish,
    this.vaultError,
  });

  final List<ImpInvestor> investors;
  final String? selectedInvestorId;
  final ValueChanged<String> onSelectInvestor;
  final List<ImpVaultDocument> vaultDocuments;
  final List<({String id, String title})> publishableDocuments;
  final bool canPublish;
  final bool loadingVault;
  final String? vaultError;
  final Future<void> Function(String documentId, String title) onPublish;

  @override
  State<ImpDocumentsDeskPanel> createState() => _ImpDocumentsDeskPanelState();
}

class _ImpDocumentsDeskPanelState extends State<ImpDocumentsDeskPanel> {
  String? _docId;
  var _publishing = false;

  @override
  void didUpdateWidget(covariant ImpDocumentsDeskPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publishableDocuments != widget.publishableDocuments &&
        _docId != null &&
        widget.publishableDocuments.every((d) => d.id != _docId)) {
      _docId = null;
    }
  }

  Future<void> _publish() async {
    final investorId = widget.selectedInvestorId;
    final docId = _docId;
    if (investorId == null || docId == null) return;
    var title = 'Document';
    for (final d in widget.publishableDocuments) {
      if (d.id == docId) {
        title = d.title;
        break;
      }
    }
    setState(() => _publishing = true);
    try {
      await widget.onPublish(docId, title);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document published to investor vault')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.investors.isEmpty) {
      return const Text(
        'Add an investor before publishing documents.',
        style: TextStyle(color: AdminDeskColors.muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(widget.selectedInvestorId ?? 'investor'),
          initialValue: widget.selectedInvestorId ?? widget.investors.first.id,
          decoration: const InputDecoration(
            labelText: 'Investor',
            isDense: true,
          ),
          items: [
            for (final inv in widget.investors)
              DropdownMenuItem(
                value: inv.id,
                child: Text('${inv.fullName} (${inv.investorCode})'),
              ),
          ],
          onChanged: (id) {
            if (id != null) widget.onSelectInvestor(id);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Investor vault',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.loadingVault)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.vaultError != null)
          Text(
            widget.vaultError!,
            style: const TextStyle(color: AdminDeskColors.red),
          )
        else if (widget.vaultDocuments.isEmpty)
          const Text(
            'No documents in this investor vault yet.',
            style: TextStyle(color: AdminDeskColors.muted),
          )
        else
          ...widget.vaultDocuments.map(
            (doc) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                LucideIcons.fileText,
                size: 16,
                color: AdminDeskColors.gold,
              ),
              title: Text(
                doc.title,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                doc.documentType,
                style: const TextStyle(
                  color: AdminDeskColors.muted,
                  fontSize: 11,
                ),
              ),
              trailing: doc.fileUrl == null || doc.fileUrl!.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Open document',
                      onPressed: () => _openUrl(doc.fileUrl),
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                    ),
            ),
          ),
        if (widget.canPublish) ...[
          const SizedBox(height: 20),
          const Divider(color: AdminDeskColors.border),
          const SizedBox(height: 12),
          const Text(
            'Publish from documents library',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.publishableDocuments.isEmpty)
            const Text(
              'No publishable documents found in the library.',
              style: TextStyle(color: AdminDeskColors.muted),
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(_docId ?? 'doc'),
              initialValue: _docId,
              decoration: const InputDecoration(
                labelText: 'Document',
                isDense: true,
              ),
              items: [
                for (final doc in widget.publishableDocuments)
                  DropdownMenuItem(value: doc.id, child: Text(doc.title)),
              ],
              onChanged: (id) => setState(() => _docId = id),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _publishing || _docId == null ? null : _publish,
              icon: const Icon(LucideIcons.upload, size: 16),
              label: Text(_publishing ? 'Publishing…' : 'Publish to vault'),
            ),
          ],
        ],
      ],
    );
  }
}
