import 'package:flutter/material.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/features/imp/domain/entities/imp_models.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Alerts-adjacent desk: recent investor notifications + publish form.
class ImpNotificationsDeskPanel extends StatefulWidget {
  const ImpNotificationsDeskPanel({
    super.key,
    required this.notifications,
    required this.investors,
    required this.selectedInvestorId,
    required this.onSelectInvestor,
    required this.canPublish,
    required this.onPublish,
    this.loading = false,
    this.error,
    this.onOpenInvestor,
  });

  final List<ImpNotificationRow> notifications;
  final List<ImpInvestor> investors;
  final String? selectedInvestorId;
  final ValueChanged<String?> onSelectInvestor;
  final bool canPublish;
  final Future<void> Function({
    required String investorId,
    required String title,
    String? body,
    String? route,
  })
  onPublish;
  final bool loading;
  final String? error;
  final ValueChanged<String>? onOpenInvestor;

  @override
  State<ImpNotificationsDeskPanel> createState() =>
      _ImpNotificationsDeskPanelState();
}

class _ImpNotificationsDeskPanelState extends State<ImpNotificationsDeskPanel> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _route = '/investor';
  bool _publishing = false;

  static const _routes = <(String, String)>[
    ('/investor', 'Dashboard'),
    ('/investor/portfolio', 'Portfolio'),
    ('/investor/payments', 'Payments'),
    ('/investor/documents', 'Documents'),
    ('/investor/construction', 'Construction'),
    ('/investor/messages', 'Messages'),
    ('/investor/notifications', 'Notifications'),
    ('/investor/support', 'Support'),
    ('/investor/reports', 'Reports'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final investorId = widget.selectedInvestorId;
    final title = _titleCtrl.text.trim();
    if (investorId == null || title.isEmpty) return;
    setState(() => _publishing = true);
    try {
      await widget.onPublish(
        investorId: investorId,
        title: title,
        body: _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
        route: _route,
      );
      if (!mounted) return;
      _titleCtrl.clear();
      _bodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification published')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(error))),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.canPublish) ...[
          const Text(
            'Send investor notification',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: widget.selectedInvestorId,
            decoration: const InputDecoration(
              labelText: 'Investor',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final inv in widget.investors)
                DropdownMenuItem(
                  value: inv.id,
                  child: Text(
                    '${inv.fullName} (${inv.investorCode})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.onSelectInvestor,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Title',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Body (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _route,
            decoration: const InputDecoration(
              labelText: 'Deep link',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final route in _routes)
                DropdownMenuItem(value: route.$1, child: Text(route.$2)),
            ],
            onChanged: _publishing
                ? null
                : (v) {
                    if (v != null) setState(() => _route = v);
                  },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _publishing ||
                    widget.selectedInvestorId == null ||
                    _titleCtrl.text.trim().isEmpty
                ? null
                : _submit,
            icon: const Icon(LucideIcons.bellRing, size: 16),
            label: Text(_publishing ? 'Sending…' : 'Send notification'),
          ),
          if (_publishing) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 20),
          const Divider(color: AdminDeskColors.border),
          const SizedBox(height: 12),
        ],
        const Text(
          'Recent notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.error != null)
          Text(
            widget.error!,
            style: const TextStyle(color: AdminDeskColors.muted),
          )
        else if (widget.notifications.isEmpty)
          const Text(
            'No investor notifications have been sent yet.',
            style: TextStyle(color: AdminDeskColors.muted),
          )
        else
          for (final n in widget.notifications)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                n.isRead ? LucideIcons.bellOff : LucideIcons.bell,
                size: 18,
                color: n.isRead ? AdminDeskColors.muted : AdminDeskColors.gold,
              ),
              title: Text(n.title),
              subtitle: Text(
                [
                  if (n.investorName != null) n.investorName!,
                  n.channel,
                  if (n.route != null) n.route!,
                  if (n.sentAt != null)
                    DateFormat.yMMMd().add_jm().format(n.sentAt!),
                  if (n.body != null && n.body!.isNotEmpty) n.body!,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: widget.onOpenInvestor == null
                  ? null
                  : () => widget.onOpenInvestor!(n.investorId),
            ),
      ],
    );
  }
}
