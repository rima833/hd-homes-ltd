import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/email/email.dart';
import 'package:hdhomesproject/core/email/email_preview_html.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/email_html_preview.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/admin/presentation/widgets/admin_desk_shell.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/communication_controller.dart';
import 'package:hdhomesproject/features/settings/presentation/widgets/pcc_widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';

enum _EmailPane { overview, branding, templates, logs, test }

/// Admin Settings → Email (AdminDesk / PCC dark theme).
class AdminEmailSettingsPanel extends ConsumerStatefulWidget {
  const AdminEmailSettingsPanel({super.key});

  @override
  ConsumerState<AdminEmailSettingsPanel> createState() =>
      _AdminEmailSettingsPanelState();
}

class _AdminEmailSettingsPanelState
    extends ConsumerState<AdminEmailSettingsPanel> {
  _EmailPane _pane = _EmailPane.overview;
  EmailBrandConfig _brand = const EmailBrandConfig();
  EmailSystemStatus _status = const EmailSystemStatus();
  List<EmailTemplateRecord> _templates = const [];
  List<EmailDeliveryRecord> _deliveries = const [];
  EmailTemplateRecord? _selected;
  bool _previewMobile = false;
  bool _loading = true;
  bool _savingBrand = false;
  bool _sendingTest = false;
  String? _error;
  String? _notice;
  final _testTo = TextEditingController();
  final _logoUrl = TextEditingController();
  final _senderName = TextEditingController();
  final _senderEmail = TextEditingController();
  final _replyTo = TextEditingController();
  final _supportEmail = TextEditingController();
  final _websiteUrl = TextEditingController();
  final _privacyUrl = TextEditingController();
  final _termsUrl = TextEditingController();
  final _primaryColor = TextEditingController();
  RealtimeChannel? _deliveryChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _deliveryChannel?.unsubscribe();
    _testTo.dispose();
    _logoUrl.dispose();
    _senderName.dispose();
    _senderEmail.dispose();
    _replyTo.dispose();
    _supportEmail.dispose();
    _websiteUrl.dispose();
    _privacyUrl.dispose();
    _termsUrl.dispose();
    _primaryColor.dispose();
    super.dispose();
  }

  EmailService get _email => ref.read(emailServiceProvider);

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _email.loadSystemStatus();
      final templates = await _email.listTemplates();
      final deliveries = await _email.listDeliveries(limit: 75);
      if (!mounted) return;
      setState(() {
        _status = status;
        _brand = status.brand;
        _templates = templates;
        _deliveries = deliveries;
        _selected ??= templates.isEmpty ? null : templates.first;
        _hydrateBrand(_brand);
        _loading = false;
      });
      _bindRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(e);
      });
    }
  }

  void _hydrateBrand(EmailBrandConfig b) {
    _logoUrl.text = b.logoUrl;
    _senderName.text = b.senderName;
    _senderEmail.text = b.senderEmail;
    _replyTo.text = b.replyTo;
    _supportEmail.text = b.supportEmail;
    _websiteUrl.text = b.websiteUrl;
    _privacyUrl.text = b.privacyUrl;
    _termsUrl.text = b.termsUrl;
    _primaryColor.text = b.primaryColor;
  }

  void _bindRealtime() {
    _deliveryChannel?.unsubscribe();
    _deliveryChannel = _email.subscribeDeliveries(() async {
      final deliveries = await _email.listDeliveries(limit: 75);
      final status = await _email.loadSystemStatus();
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
        _status = status;
      });
    });
  }

  Future<void> _saveBrand() async {
    setState(() {
      _savingBrand = true;
      _notice = null;
      _error = null;
    });
    try {
      final next = EmailBrandConfig(
        logoUrl: _logoUrl.text.trim(),
        senderName: _senderName.text.trim(),
        senderEmail: _senderEmail.text.trim(),
        replyTo: _replyTo.text.trim(),
        supportEmail: _supportEmail.text.trim(),
        websiteUrl: _websiteUrl.text.trim(),
        privacyUrl: _privacyUrl.text.trim(),
        termsUrl: _termsUrl.text.trim(),
        primaryColor: _primaryColor.text.trim().isEmpty
            ? '#D4A34E'
            : _primaryColor.text.trim(),
        companyName: _senderName.text.trim().isEmpty
            ? 'HD Homes Limited'
            : _senderName.text.trim(),
        tagline: _brand.tagline,
      );
      await _email.saveBrand(next);
      if (!mounted) return;
      setState(() {
        _brand = next;
        _savingBrand = false;
        _notice = 'Email branding saved.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingBrand = false;
        _error = userFacingError(e);
      });
    }
  }

  Future<void> _runHealth() async {
    setState(() {
      _notice = null;
      _error = null;
    });
    final res = await _email.checkProviderHealth();
    await _reload();
    if (!mounted) return;
    setState(() {
      if (res['configured'] == true) {
        _notice = 'Resend health check passed.';
      } else {
        _error =
            '${res['error'] ?? res['domain_error'] ?? 'Provider not configured. Set RESEND_API_KEY as an Edge secret.'}';
      }
    });
  }

  Future<void> _drainQueue() async {
    final res = await _email.processQueue();
    await _reload();
    if (!mounted) return;
    setState(() {
      if (res['error'] != null) {
        _error = '${res['error']}';
      } else {
        _notice = 'Queue processed: ${res['processed'] ?? 0} item(s).';
      }
    });
  }

  Future<void> _sendTest() async {
    final to = _testTo.text.trim();
    final slug = _selected?.slug ?? EmailTemplateKeys.welcome;
    if (!to.contains('@')) {
      setState(() => _error = 'Enter a valid test recipient email.');
      return;
    }
    setState(() {
      _sendingTest = true;
      _error = null;
      _notice = null;
    });
    final res = await _email.sendTestEmail(
      to: to,
      templateSlug: slug,
      variables: {
        'first_name': 'there',
        'cta_url': _brand.websiteUrl,
        'message': 'This is a test security message from Admin Settings.',
        'payment_amount': '₦1,000,000',
        'property_name': 'Sample Residence',
        'ticket_reference': 'HD-TEST-001',
        'booking_reference': 'BK-TEST-001',
        'scheduled_at': 'Tomorrow 10:00',
        'document_title': 'Sample document',
        'verification_status': 'approved',
        'status': 'verified',
        'title': 'Test announcement',
        'body': 'This is a test announcement body.',
        'portal_name': 'Client',
        'role_name': 'Staff',
      },
    );
    await _reload();
    if (!mounted) return;
    setState(() {
      _sendingTest = false;
      if (res['ok'] == true) {
        _notice =
            'Test email sent to $to (${res['provider_message_id'] ?? 'ok'}).';
      } else {
        _error = '${res['error'] ?? 'Test send failed'}';
      }
    });
  }

  Future<void> _toggleTemplate(EmailTemplateRecord t, bool active) async {
    if (t.isSecurity && !active) {
      setState(() => _error = 'Security templates cannot be disabled.');
      return;
    }
    final updated = await _email.upsertTemplate(
      slug: t.slug,
      name: t.name,
      subject: t.subject,
      bodyHtml: t.bodyHtml ?? '',
      textBody: t.textBody,
      category: t.category,
      variables: t.variables,
      isActive: active,
    );
    if (updated == null) {
      setState(() => _error = 'Unable to update template.');
      return;
    }
    await _reload();
    setState(() => _notice = 'Template ${t.slug} updated.');
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(supabaseConfiguredProvider);
    if (!configured) {
      return const PccPanel(
        title: 'Email',
        subtitle: 'Connect Supabase to manage the email system.',
        child: Text(
          'Supabase is not configured.',
          style: TextStyle(color: AdminDeskColors.amber),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(color: AdminDeskColors.gold),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) _banner(_error!, isError: true),
        if (_notice != null) _banner(_notice!, isError: false),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pane in _EmailPane.values)
              ChoiceChip(
                label: Text(_paneLabel(pane)),
                selected: _pane == pane,
                onSelected: (_) => setState(() => _pane = pane),
                selectedColor: AdminDeskColors.gold.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  color: _pane == pane ? AdminDeskColors.gold : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: AdminDeskColors.elevated,
                side: BorderSide(
                  color: _pane == pane
                      ? AdminDeskColors.gold.withValues(alpha: 0.5)
                      : AdminDeskColors.border,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        switch (_pane) {
          _EmailPane.overview => _overview(),
          _EmailPane.branding => _branding(),
          _EmailPane.templates => _templatesPane(),
          _EmailPane.logs => _logs(),
          _EmailPane.test => _testSend(),
        },
      ],
    );
  }

  String _paneLabel(_EmailPane p) => switch (p) {
        _EmailPane.overview => 'Overview',
        _EmailPane.branding => 'Branding',
        _EmailPane.templates => 'Templates',
        _EmailPane.logs => 'Logs',
        _EmailPane.test => 'Test send',
      };

  Widget _banner(String text, {required bool isError}) {
    final color = isError ? AdminDeskColors.red : AdminDeskColors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  Widget _overview() {
    return PccPanel(
      title: 'Email system',
      subtitle: 'Resend via Edge workers. Secrets stay server-side.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statChip(
                'Provider',
                _status.configured ? 'Resend · ready' : 'Resend · not ready',
                _status.configured ? AdminDeskColors.green : AdminDeskColors.amber,
              ),
              _statChip('Queued', '${_status.queued}', AdminDeskColors.muted),
              _statChip('Sent', '${_status.sent}', AdminDeskColors.green),
              _statChip('Failed', '${_status.failed}', AdminDeskColors.red),
              _statChip(
                'Form outbox',
                '${_status.outboxQueued}',
                AdminDeskColors.muted,
              ),
              _statChip(
                'Templates',
                '${_status.templateCount}',
                AdminDeskColors.muted,
              ),
            ],
          ),
          if (_status.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _status.notes,
              style: const TextStyle(color: AdminDeskColors.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _runHealth,
                icon: const Icon(LucideIcons.heartPulse, size: 16),
                label: const Text('Run health check'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminDeskColors.gold,
                  foregroundColor: Colors.black,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _drainQueue,
                icon: const Icon(LucideIcons.mail, size: 16),
                label: const Text('Process queue now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AdminDeskColors.border),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AdminDeskColors.border),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AdminDeskColors.elevated,
        border: Border.all(color: AdminDeskColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminDeskColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _branding() {
    return PccPanel(
      title: 'Email branding',
      subtitle: 'Public-safe fields only. Never paste API keys here.',
      trailing: FilledButton.icon(
        onPressed: _savingBrand ? null : _saveBrand,
        icon: const Icon(LucideIcons.save, size: 16),
        label: Text(_savingBrand ? 'Saving…' : 'Save branding'),
        style: FilledButton.styleFrom(
          backgroundColor: AdminDeskColors.gold,
          foregroundColor: Colors.black,
        ),
      ),
      child: Column(
        children: [
          _deskField(_logoUrl, 'Logo URL (Cloudinary public URL)'),
          _deskField(_senderName, 'Sender name'),
          _deskField(_senderEmail, 'Sender email'),
          _deskField(_replyTo, 'Reply-To'),
          _deskField(_supportEmail, 'Support email'),
          _deskField(_websiteUrl, 'Website URL'),
          _deskField(_privacyUrl, 'Privacy URL'),
          _deskField(_termsUrl, 'Terms URL'),
          _deskField(_primaryColor, 'Primary color'),
        ],
      ),
    );
  }

  Widget _deskField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminDeskColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AdminDeskColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AdminDeskColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AdminDeskColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AdminDeskColors.gold.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templatesPane() {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final list = Container(
      decoration: BoxDecoration(
        color: AdminDeskColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminDeskColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _templates.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AdminDeskColors.border),
        itemBuilder: (context, i) {
          final t = _templates[i];
          final selected = _selected?.slug == t.slug;
          return ListTile(
            dense: true,
            selected: selected,
            selectedTileColor: AdminDeskColors.gold.withValues(alpha: 0.08),
            title: Text(
              t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              '${t.category} · ${t.slug}',
              style: const TextStyle(color: AdminDeskColors.muted, fontSize: 11),
            ),
            trailing: t.isSecurity
                ? const Icon(
                    LucideIcons.shield,
                    size: 14,
                    color: AdminDeskColors.gold,
                  )
                : Switch.adaptive(
                    value: t.isActive,
                    activeThumbColor: AdminDeskColors.gold,
                    onChanged: (v) => _toggleTemplate(t, v),
                  ),
            onTap: () => setState(() => _selected = t),
          );
        },
      ),
    );

    final preview = _selected == null
        ? const PccPanel(
            title: 'Template preview',
            subtitle: 'Select a template from the list.',
            child: Text(
              'No template selected.',
              style: TextStyle(color: AdminDeskColors.muted),
            ),
          )
        : PccPanel(
            title: _selected!.subject,
            subtitle: 'Variables: ${_selected!.variables.join(', ')}',
            trailing: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Desktop')),
                ButtonSegment(value: true, label: Text('Mobile')),
              ],
              selected: {_previewMobile},
              onSelectionChanged: (s) =>
                  setState(() => _previewMobile = s.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.black;
                  }
                  return AdminDeskColors.muted;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AdminDeskColors.gold;
                  }
                  return AdminDeskColors.elevated;
                }),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _previewMobile ? 390 : 680,
                ),
                child: EmailHtmlPreview(
                  html: buildEmailPreviewHtml(
                    bodyHtml: _selected!.bodyHtml,
                    textBody: _selected!.textBody,
                    brand: _brand,
                    variables: _selected!.variables,
                  ),
                ),
              ),
            ),
          );

    return PccPanel(
      title: 'Templates',
      subtitle:
          'Security templates stay enabled. Preview shows the email customers receive.',
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: list),
                const SizedBox(width: 14),
                Expanded(child: preview),
              ],
            )
          : Column(
              children: [
                list,
                const SizedBox(height: 14),
                preview,
              ],
            ),
    );
  }

  Widget _logs() {
    return PccPanel(
      title: 'Delivery logs',
      subtitle: 'Live from notification_delivery (email channel).',
      child: _deliveries.isEmpty
          ? const Text(
              'No email deliveries yet.',
              style: TextStyle(color: AdminDeskColors.muted),
            )
          : Column(
              children: [
                for (var i = 0; i < _deliveries.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AdminDeskColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      _deliveries[i].title ??
                          _deliveries[i].templateSlug ??
                          'Email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${_deliveries[i].recipientEmail ?? '—'} · ${_deliveries[i].status.slug}'
                      '${_deliveries[i].errorMessage != null ? ' · ${_deliveries[i].errorMessage}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    trailing: Text(
                      _deliveries[i]
                          .createdAt
                          .toLocal()
                          .toString()
                          .split('.')
                          .first,
                      style: const TextStyle(
                        color: AdminDeskColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _testSend() {
    return PccPanel(
      title: 'Send test email',
      subtitle:
          'Uses the Edge send-test-email function + Resend. No fake success.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Template',
            style: TextStyle(
              color: AdminDeskColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selected?.slug,
            dropdownColor: AdminDeskColors.elevated,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AdminDeskColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AdminDeskColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AdminDeskColors.border),
              ),
            ),
            items: _templates
                .map(
                  (t) => DropdownMenuItem(
                    value: t.slug,
                    child: Text('${t.name} (${t.slug})'),
                  ),
                )
                .toList(),
            onChanged: (slug) {
              setState(() {
                _selected = _templates.firstWhere(
                  (t) => t.slug == slug,
                  orElse: () => _templates.first,
                );
              });
            },
          ),
          const SizedBox(height: 12),
          _deskField(_testTo, 'Recipient email'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _sendingTest ? null : _sendTest,
            icon: const Icon(LucideIcons.send, size: 16),
            label: Text(_sendingTest ? 'Sending…' : 'Send test'),
            style: FilledButton.styleFrom(
              backgroundColor: AdminDeskColors.gold,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
