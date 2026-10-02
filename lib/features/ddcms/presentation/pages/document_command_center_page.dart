import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/constants/permissions.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/auth_controller.dart';
import 'package:hdhomesproject/features/authentication/presentation/widgets/permission_gate.dart';
import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:hdhomesproject/features/ddcms/presentation/providers/ddcms_controller.dart';
import 'package:hdhomesproject/features/ddcms/presentation/widgets/issue_document_dialog.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Volume 4 Part 12 — Document Command Center (production UI).
///
/// Real flow:
/// 1) Staff uploads into enterprise vault (`documents` + storage)
/// 2) Staff issues / publishes to a client → `client_documents`
/// 3) Client portal lists + opens via signed URL (realtime)
class DocumentCommandCenterPage extends ConsumerStatefulWidget {
  const DocumentCommandCenterPage({super.key});

  @override
  ConsumerState<DocumentCommandCenterPage> createState() =>
      _DocumentCommandCenterPageState();
}

class _DocumentCommandCenterPageState
    extends ConsumerState<DocumentCommandCenterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || !mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(ddcmsSnapshotProvider);
  }

  Future<void> _openDoc(DdcmsDocument doc) async {
    try {
      final url = await ref.read(ddcmsServiceProvider).resolveDocumentUrl(doc);
      final uri = Uri.tryParse(url);
      if (uri == null) throw const DatabaseException('Invalid document URL.');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      showFriendlyError(context, e);
    }
  }

  Future<void> _showUpload() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var category = 'general';
    PlatformFile? picked;
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: InspectionAdminUi.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Upload to vault',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Store the file in the enterprise vault. You can issue it to a client next.',
                    style: TextStyle(
                      color: InspectionAdminUi.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration('Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InspectionAdminUi.fieldDecoration(
                      'Description (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    dropdownColor: InspectionAdminUi.surfaceElevated,
                    decoration: InspectionAdminUi.fieldDecoration('Category'),
                    items: const [
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General'),
                      ),
                      DropdownMenuItem(
                        value: 'allocation',
                        child: Text('Allocation letter'),
                      ),
                      DropdownMenuItem(
                        value: 'contract',
                        child: Text('Purchase / contract'),
                      ),
                      DropdownMenuItem(
                        value: 'finance-invoice',
                        child: Text('Finance / invoice'),
                      ),
                      DropdownMenuItem(
                        value: 'marketing-brochure',
                        child: Text('Marketing brochure'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? 'general'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final result = await FilePicker.pickFiles(
                              withData: true,
                              type: FileType.custom,
                              allowedExtensions: const [
                                'pdf',
                                'png',
                                'jpg',
                                'jpeg',
                                'doc',
                                'docx',
                              ],
                            );
                            if (result == null || result.files.isEmpty) return;
                            setLocal(() {
                              picked = result.files.first;
                              if (titleCtrl.text.trim().isEmpty) {
                                titleCtrl.text = picked!.name;
                              }
                            });
                          },
                    icon: const Icon(LucideIcons.paperclip, size: 16),
                    label: Text(picked?.name ?? 'Choose file'),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Upload',
                    loadingLabel: 'Uploading…',
                    isLoading: busy,
                    expand: true,
                    icon: LucideIcons.upload,
                    onPressed: () async {
                      final file = picked;
                      final bytes = file?.bytes;
                      if (file == null || bytes == null) {
                        showFriendlyError(
                          ctx,
                          null,
                          fallback: 'Choose a file to upload.',
                        );
                        return;
                      }
                      if (titleCtrl.text.trim().isEmpty) {
                        showFriendlyError(
                          ctx,
                          null,
                          fallback: 'Enter a document title.',
                        );
                        return;
                      }
                      setLocal(() => busy = true);
                      try {
                        await ref
                            .read(ddcmsControllerProvider.notifier)
                            .uploadDocument(
                              title: titleCtrl.text,
                              fileName: file.name,
                              bytes: bytes,
                              description: descCtrl.text,
                              category: category,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) _tabs.index = 0;
                      } catch (e) {
                        if (!ctx.mounted) return;
                        showFriendlyError(ctx, e);
                      } finally {
                        if (ctx.mounted) setLocal(() => busy = false);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showIssueToClient({DdcmsDocument? existing}) async {
    final session = ref.read(identitySessionProvider);
    final audience = RoleNavPolicy.documentAudienceFor(session);
    final people = await ref
        .read(ddcmsServiceProvider)
        .listRecipients(
          includeClients: audience != StaffDocumentAudience.investors,
          includeInvestors: audience != StaffDocumentAudience.clients,
        );
    if (!mounted) return;
    if (people.isEmpty) {
      final who = switch (audience) {
        StaffDocumentAudience.clients => 'clients',
        StaffDocumentAudience.investors => 'investors',
        StaffDocumentAudience.both => 'clients or investors',
      };
      showFriendlyError(
        context,
        null,
        fallback: 'No $who found to issue a document to.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (ctx) {
        return IssueDocumentDialog(
          people: people,
          audience: audience,
          existing: existing,
          onSubmit:
              ({
                required person,
                required title,
                required documentType,
                file,
              }) async {
                if (existing != null) {
                  await ref
                      .read(ddcmsControllerProvider.notifier)
                      .publishDocument(
                        document: existing,
                        audience: person.audience,
                        targetId: person.id,
                        documentType: documentType,
                      );
                } else {
                  final bytes = file?.bytes;
                  if (file == null || bytes == null) {
                    throw const ValidationException('Choose a file to issue.');
                  }
                  await ref
                      .read(ddcmsServiceProvider)
                      .issueToRecipient(
                        audience: person.audience,
                        targetId: person.id,
                        title: title,
                        fileName: file.name,
                        bytes: bytes,
                        documentType: documentType,
                      );
                  ref.invalidate(ddcmsSnapshotProvider);
                  ref
                      .read(ddcmsControllerProvider.notifier)
                      .setMessage(
                        'Issued “$title” to the ${person.audience} portal.',
                      );
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Document issued. They will see it live under Documents.',
                      ),
                    ),
                  );
                }
              },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = ref.watch(ddcmsSnapshotProvider);
    final ui = ref.watch(ddcmsControllerProvider);
    final liveTick = DateTime.now().millisecondsSinceEpoch;

    return Scaffold(
      backgroundColor: InspectionAdminUi.bg,
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userFacingError(e),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Try again', onPressed: _refresh),
              ],
            ),
          ),
        ),
        data: (snap) {
          final docs = snap.documents.where((d) {
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            return d.title.toLowerCase().contains(q) ||
                (d.code?.toLowerCase().contains(q) ?? false) ||
                (d.category?.toLowerCase().contains(q) ?? false);
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(
                          fromRemote: snap.fromRemote,
                          liveTick: liveTick,
                          message: ui.lastMessage,
                          onClearMessage: () => ref
                              .read(ddcmsControllerProvider.notifier)
                              .clearMessage(),
                          onRefresh: _refresh,
                          onUpload: _showUpload,
                          onIssue: () => _showIssueToClient(),
                        ),
                        const SizedBox(height: 14),
                        _KpiRow(snap: snap),
                        const SizedBox(height: 12),
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: InspectionAdminUi.border,
                              ),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabs,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            indicatorColor: InspectionAdminUi.gold,
                            labelColor: InspectionAdminUi.gold,
                            unselectedLabelColor: Colors.white54,
                            tabs: const [
                              Tab(text: 'Vault'),
                              Tab(text: 'Issue & share'),
                              Tab(text: 'Contracts'),
                              Tab(text: 'Activity'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        switch (_tabs.index) {
                          0 => _VaultTab(
                            documents: docs,
                            search: _search,
                            onSearch: (v) => setState(() => _search = v),
                            onUpload: _showUpload,
                            onOpen: _openDoc,
                            onIssue: (d) => _showIssueToClient(existing: d),
                          ),
                          1 => _IssueGuideTab(
                            onIssue: () => _showIssueToClient(),
                          ),
                          2 => _ContractsTab(contracts: snap.contracts),
                          _ => _ActivityTab(activities: snap.activities),
                        },
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.fromRemote,
    required this.liveTick,
    required this.onRefresh,
    required this.onUpload,
    required this.onIssue,
    this.message,
    this.onClearMessage,
  });

  final bool fromRemote;
  final int liveTick;
  final String? message;
  final VoidCallback? onClearMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onUpload;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                InspectionAdminUi.surfaceElevated,
                InspectionAdminUi.surface,
                InspectionAdminUi.gold.withValues(alpha: 0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: InspectionAdminUi.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'DOCUMENTS',
                          style: TextStyle(
                            color: InspectionAdminUi.gold,
                            letterSpacing: 2.4,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        InspectionLiveBadge(tick: liveTick),
                        if (!fromRemote) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'Offline',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Document command center',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload once → issue to clients → they see it live in the portal.',
                      style: TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white70,
                  backgroundColor: InspectionAdminUi.bg,
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    PermissionGateAny(
                      permissions: const [
                        PermissionSlugs.documentsUpload,
                        PermissionSlugs.documentsWrite,
                      ],
                      child: OutlinedButton.icon(
                        onPressed: onUpload,
                        icon: const Icon(LucideIcons.upload, size: 16),
                        label: const Text('Upload'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: InspectionAdminUi.gold,
                          side: BorderSide(
                            color: InspectionAdminUi.gold.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    PermissionGateAny(
                      permissions: const [
                        PermissionSlugs.documentsShare,
                        PermissionSlugs.documentsWrite,
                      ],
                      child: FilledButton.icon(
                        onPressed: onIssue,
                        icon: const Icon(LucideIcons.send, size: 16),
                        label: const Text('Issue document'),
                        style: FilledButton.styleFrom(
                          backgroundColor: InspectionAdminUi.gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 10),
          Material(
            color: InspectionAdminUi.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              dense: true,
              leading: const Icon(
                LucideIcons.checkCircle2,
                color: InspectionAdminUi.gold,
              ),
              title: Text(
                message!,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: onClearMessage,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.snap});
  final DdcmsCommandCenterSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Vault files', '${snap.documents.length}', LucideIcons.folderOpen),
      ('Contracts', '${snap.contracts.length}', LucideIcons.fileSignature),
      (
        'Signatures',
        '${snap.signatures.where((s) => {'pending', 'sent', 'partially_signed'}.contains(s.status)).length}',
        LucideIcons.penTool,
      ),
      (
        'Approvals',
        '${snap.approvals.where((a) => a.status == 'pending').length}',
        LucideIcons.checkCircle,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 4 : 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: (c.maxWidth - (8 * (cols - 1))) / cols,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: InspectionAdminUi.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: InspectionAdminUi.border),
                  ),
                  child: Row(
                    children: [
                      Icon(item.$3, size: 16, color: InspectionAdminUi.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(
                                color: InspectionAdminUi.muted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VaultTab extends StatelessWidget {
  const _VaultTab({
    required this.documents,
    required this.search,
    required this.onSearch,
    required this.onUpload,
    required this.onOpen,
    required this.onIssue,
  });

  final List<DdcmsDocument> documents;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onUpload;
  final ValueChanged<DdcmsDocument> onOpen;
  final ValueChanged<DdcmsDocument> onIssue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onSearch,
          style: const TextStyle(color: Colors.white),
          decoration: InspectionAdminUi.fieldDecoration(
            'Search',
            hint: 'Search vault by title, code, or category…',
            prefix: const Icon(
              LucideIcons.search,
              size: 16,
              color: InspectionAdminUi.muted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        documents.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.folderOpen,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vault is empty',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Upload a PDF, then issue it to a client to deliver it live.',
                      style: TextStyle(color: InspectionAdminUi.muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PermissionGateAny(
                      permissions: const [
                        PermissionSlugs.documentsUpload,
                        PermissionSlugs.documentsWrite,
                      ],
                      child: FilledButton.icon(
                        onPressed: onUpload,
                        icon: const Icon(LucideIcons.upload, size: 16),
                        label: const Text('Upload first document'),
                        style: FilledButton.styleFrom(
                          backgroundColor: InspectionAdminUi.gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: documents.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = documents[i];
                  final when = d.updatedAt == null
                      ? '—'
                      : DateFormat('d MMM yyyy').format(d.updatedAt!.toLocal());
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: InspectionAdminUi.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: InspectionAdminUi.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: InspectionAdminUi.gold.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.fileText,
                            color: InspectionAdminUi.gold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${d.category ?? 'general'} · ${d.status.replaceAll('_', ' ')} · $when'
                                '${d.hasFile ? '' : ' · missing file'}',
                                style: const TextStyle(
                                  color: InspectionAdminUi.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Open',
                          onPressed: d.hasFile ? () => onOpen(d) : null,
                          icon: const Icon(LucideIcons.externalLink, size: 18),
                        ),
                        PermissionGateAny(
                          permissions: const [
                            PermissionSlugs.documentsShare,
                            PermissionSlugs.documentsWrite,
                          ],
                          child: IconButton(
                            tooltip: 'Issue document',
                            onPressed: d.hasFile ? () => onIssue(d) : null,
                            icon: const Icon(LucideIcons.send, size: 18),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class _IssueGuideTab extends StatelessWidget {
  const _IssueGuideTab({required this.onIssue});
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        '1. Prepare the letter',
        'Create the allocation letter or purchase agreement as a PDF.',
        LucideIcons.filePlus,
      ),
      (
        '2. Issue to the client',
        'Choose the client, document type, and file. HD Homes stores it in the vault and publishes it to their portal.',
        LucideIcons.send,
      ),
      (
        '3. Client opens it live',
        'It appears instantly under Client → Documents with a secure download link.',
        LucideIcons.smartphone,
      ),
    ];
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        InspectionAdminCard(
          title: 'How clients receive documents',
          subtitle:
              'Master plan flow: reservation / allocation → documentation → handover. Letters are issued by staff — never seeded placeholders.',
          child: Column(
            children: [
              for (final s in steps) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(s.$3, color: InspectionAdminUi.gold),
                  title: Text(
                    s.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    s.$2,
                    style: const TextStyle(color: InspectionAdminUi.muted),
                  ),
                ),
                const Divider(color: InspectionAdminUi.border),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: PermissionGateAny(
                  permissions: const [
                    PermissionSlugs.documentsShare,
                    PermissionSlugs.documentsWrite,
                  ],
                  child: FilledButton.icon(
                    onPressed: onIssue,
                    icon: const Icon(LucideIcons.send, size: 16),
                    label: const Text('Issue document now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: InspectionAdminUi.gold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContractsTab extends StatelessWidget {
  const _ContractsTab({required this.contracts});
  final List<DdcmsContract> contracts;

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) {
      return const Center(
        child: Text(
          'No live contracts yet.',
          style: TextStyle(color: InspectionAdminUi.muted),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contracts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = contracts[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: InspectionAdminUi.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: InspectionAdminUi.border),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              LucideIcons.fileSignature,
              color: InspectionAdminUi.gold,
            ),
            title: Text(
              c.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${c.contractNumber} · ${c.status.replaceAll('_', ' ')}'
              '${c.counterpartyName != null ? ' · ${c.counterpartyName}' : ''}',
              style: const TextStyle(color: InspectionAdminUi.muted),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.activities});
  final List<DdcmsActivity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const Center(
        child: Text(
          'No document activity yet. Uploads and client issues will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: InspectionAdminUi.muted),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = activities[i];
        final when = a.occurredAt == null
            ? ''
            : DateFormat('d MMM, HH:mm').format(a.occurredAt!.toLocal());
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: InspectionAdminUi.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: InspectionAdminUi.border),
          ),
          child: Text(
            '${a.action.replaceAll('_', ' ')} · ${a.summary.isEmpty ? (a.actorLabel ?? '') : a.summary}'
            '${when.isEmpty ? '' : ' · $when'}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        );
      },
    );
  }
}
