import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/auth/policies/role_nav_policy.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/theme/tokens/app_colors.dart';
import 'package:hdhomesproject/core/widgets/buttons/primary_button.dart';
import 'package:hdhomesproject/features/ddcms/domain/entities/ddcms_models.dart';
import 'package:hdhomesproject/features/ddcms/domain/services/ddcms_service.dart';
import 'package:hdhomesproject/features/inspection/presentation/widgets/inspection_admin_shared.dart';
import 'package:lucide_icons/lucide_icons.dart';

typedef IssueDocumentSubmit =
    Future<void> Function({
      required DocumentRecipient person,
      required String title,
      required String documentType,
      PlatformFile? file,
    });

/// Staff dialog for searching a client or investor and issuing a file.
class IssueDocumentDialog extends StatefulWidget {
  const IssueDocumentDialog({
    super.key,
    required this.people,
    required this.audience,
    required this.onSubmit,
    this.existing,
  });

  final List<DocumentRecipient> people;
  final StaffDocumentAudience audience;
  final DdcmsDocument? existing;
  final IssueDocumentSubmit onSubmit;

  @override
  State<IssueDocumentDialog> createState() => _IssueDocumentDialogState();
}

class _IssueDocumentDialogState extends State<IssueDocumentDialog> {
  static const _types = <({String id, String label, IconData icon})>[
    (id: 'allocation', label: 'Allocation', icon: LucideIcons.fileText),
    (id: 'contract', label: 'Agreement', icon: LucideIcons.fileSignature),
    (id: 'receipt', label: 'Receipt', icon: LucideIcons.receipt),
    (id: 'certificate', label: 'Certificate', icon: LucideIcons.award),
    (id: 'shared', label: 'Shared file', icon: LucideIcons.files),
  ];

  late final TextEditingController _titleCtrl;
  late final TextEditingController _searchCtrl;
  late String _docType;
  String _query = '';
  String _filter = 'all';
  DocumentRecipient? _selected;
  PlatformFile? _picked;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _searchCtrl = TextEditingController();
    _titleCtrl.addListener(_onTitleChanged);
    var type = existing?.category ?? 'allocation';
    if (type == 'general' || type.isEmpty) type = 'allocation';
    _docType = type;
    if (widget.people.length == 1) _selected = widget.people.first;
    if (widget.audience == StaffDocumentAudience.clients) _filter = 'client';
    if (widget.audience == StaffDocumentAudience.investors) {
      _filter = 'investor';
    }
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _titleCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_busy || _selected == null) return false;
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (widget.existing == null && _picked?.bytes == null) return false;
    return true;
  }

  List<DocumentRecipient> get _matches {
    final query = _query;
    final matches = [
      for (final person in widget.people)
        if ((_filter == 'all' || person.audience == _filter) &&
            (query.isEmpty || person.searchText.contains(query)))
          person,
    ];
    matches.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    final cap = query.isEmpty ? 8 : 20;
    return matches.take(cap).toList();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _picked = file;
      if (_titleCtrl.text.trim().isEmpty) _titleCtrl.text = file.name;
    });
  }

  Future<void> _submit() async {
    final person = _selected;
    if (person == null || !_canSubmit) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        person: person,
        title: _titleCtrl.text.trim(),
        documentType: _docType,
        file: _picked,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showFriendlyError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.size.width >= 720;
    final listHeight = (media.size.height * 0.28).clamp(168.0, 248.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: wide ? 32 : 16,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: media.size.height * 0.92,
        ),
        child: Material(
          color: InspectionAdminUi.surface,
          elevation: 24,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(onClose: _busy ? null : () => Navigator.pop(context)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionLabel('Recipient'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InspectionAdminUi.fieldDecoration(
                            'Search',
                            hint: 'Name, email, or code',
                            prefix: const Icon(
                              LucideIcons.search,
                              size: 16,
                              color: InspectionAdminUi.muted,
                            ),
                          ),
                          onChanged: (value) => setState(() {
                            _query = value.trim().toLowerCase();
                            final selected = _selected;
                            if (selected != null &&
                                !selected.searchText.contains(_query)) {
                              _selected = null;
                            }
                          }),
                        ),
                        if (widget.audience == StaffDocumentAudience.both) ...[
                          const SizedBox(height: 10),
                          _FilterRow(
                            filter: _filter,
                            onChanged: (value) => setState(() {
                              _filter = value;
                              final selected = _selected;
                              if (selected != null &&
                                  value != 'all' &&
                                  selected.audience != value) {
                                _selected = null;
                              }
                            }),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          height: listHeight,
                          child: _RecipientList(
                            people: _matches,
                            selected: _selected,
                            onSelect: (person) =>
                                setState(() => _selected = person),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _SectionLabel('Document'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in _types)
                              _TypeChip(
                                label: type.label,
                                icon: type.icon,
                                selected: _docType == type.id,
                                onTap: () => setState(() => _docType = type.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InspectionAdminUi.fieldDecoration(
                            'Title',
                            hint: 'What they will see in Documents',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.existing == null)
                          _FileCard(
                            file: _picked,
                            onPick: _busy ? null : _pickFile,
                          )
                        else
                          _VaultFileCard(document: widget.existing!),
                      ],
                    ),
                  ),
                ),
                _Footer(
                  person: _selected,
                  busy: _busy,
                  enabled: _canSubmit,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: const Icon(
              LucideIcons.send,
              color: AppColors.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue a document',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Search the person, then send the file to their portal.',
                  style: TextStyle(
                    color: InspectionAdminUi.muted,
                    fontSize: 13,
                  ),
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
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onChanged});

  final String filter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: 'Everyone',
          selected: filter == 'all',
          onTap: () => onChanged('all'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Clients',
          selected: filter == 'client',
          onTap: () => onChanged('client'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Investors',
          selected: filter == 'investor',
          onTap: () => onChanged('investor'),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      color: selected ? AppColors.gold : InspectionAdminUi.bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.charcoal : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientList extends StatelessWidget {
  const _RecipientList({
    required this.people,
    required this.selected,
    required this.onSelect,
  });

  final List<DocumentRecipient> people;
  final DocumentRecipient? selected;
  final ValueChanged<DocumentRecipient> onSelect;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const Center(
        child: Text(
          'No match. Try another name, email, or code.',
          style: TextStyle(color: InspectionAdminUi.muted),
        ),
      );
    }
    return ListView.separated(
      itemCount: people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final person = people[index];
        final isSelected =
            selected?.id == person.id && selected?.audience == person.audience;
        return _RecipientCard(
          person: person,
          selected: isSelected,
          onTap: () => onSelect(person),
        );
      },
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final DocumentRecipient person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInvestor = person.audience == 'investor';
    final accent = isInvestor ? const Color(0xFF7DD3C0) : AppColors.gold;
    final detail = [
      if (person.code.isNotEmpty) person.code,
      if (person.email.isNotEmpty) person.email,
    ].join('  ·  ');

    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.1)
          : InspectionAdminUi.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.16),
                child: Text(
                  person.initials,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
                        Flexible(
                          child: Text(
                            person.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AudiencePill(label: person.kindLabel, color: accent),
                      ],
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: InspectionAdminUi.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  LucideIcons.checkCircle2,
                  color: AppColors.gold,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudiencePill extends StatelessWidget {
  const _AudiencePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : InspectionAdminUi.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.charcoal : AppColors.gold,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.charcoal : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file, required this.onPick});

  final PlatformFile? file;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final picked = file;
    return Material(
      color: InspectionAdminUi.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: picked == null
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.gold.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  picked == null ? LucideIcons.upload : LucideIcons.fileCheck2,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      picked?.name ?? 'Choose a PDF or file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      picked == null
                          ? 'PDF, image, or Word document'
                          : 'Tap to choose a different file',
                      style: const TextStyle(
                        color: InspectionAdminUi.muted,
                        fontSize: 12,
                      ),
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

class _VaultFileCard extends StatelessWidget {
  const _VaultFileCard({required this.document});

  final DdcmsDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InspectionAdminUi.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.archive, color: AppColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vault file · ${document.fileName ?? document.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.person,
    required this.busy,
    required this.enabled,
    required this.onSubmit,
  });

  final DocumentRecipient? person;
  final bool busy;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final selected = person;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selected == null
                ? 'Select who receives this file.'
                : 'Sending to ${selected.displayName} · ${selected.kindLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: InspectionAdminUi.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Issue document',
            loadingLabel: 'Issuing…',
            isLoading: busy,
            expand: true,
            icon: LucideIcons.send,
            onPressed: enabled ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
