import 'package:flutter/material.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CmsEditableLink {
  CmsEditableLink({this.label = '', this.url = ''});

  String label;
  String url;
}

/// Label and path rows for a menu or footer column. No JSON.
class CmsLinkListEditor extends StatefulWidget {
  const CmsLinkListEditor({super.key, required this.initial});

  final List<CmsEditableLink> initial;

  @override
  CmsLinkListEditorState createState() => CmsLinkListEditorState();
}

class CmsLinkListEditorState extends State<CmsLinkListEditor> {
  late final List<_Draft> _drafts;

  @override
  void initState() {
    super.initState();
    final source = widget.initial.isEmpty
        ? [CmsEditableLink()]
        : widget.initial;
    _drafts = [for (final link in source) _Draft(link)];
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  /// Rows with both a label and a URL. Throws [StateError] if a row is half filled.
  List<Map<String, String>> validatedLinks() {
    final links = <Map<String, String>>[];
    for (final draft in _drafts) {
      final label = draft.label.text.trim();
      final url = draft.url.text.trim();
      if (label.isEmpty && url.isEmpty) continue;
      if (label.isEmpty || url.isEmpty) {
        throw StateError('Each link needs a label and a path.');
      }
      links.add({'label': label, 'url': url});
    }
    if (links.isEmpty) {
      throw StateError('Add at least one link.');
    }
    return links;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _drafts.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _drafts[i].label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _drafts[i].url,
                  decoration: const InputDecoration(
                    labelText: 'Path',
                    hintText: '/about or https://…',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove link',
                onPressed: _drafts.length == 1
                    ? null
                    : () {
                        final removed = _drafts.removeAt(i);
                        removed.dispose();
                        setState(() {});
                      },
                icon: const Icon(LucideIcons.x, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _drafts.add(_Draft(CmsEditableLink()))),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add link'),
          ),
        ),
        Text(
          'Use an app path such as /properties, or a full https URL.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.slate500),
        ),
      ],
    );
  }
}

class _Draft {
  _Draft(CmsEditableLink link)
    : label = TextEditingController(text: link.label),
      url = TextEditingController(text: link.url);

  final TextEditingController label;
  final TextEditingController url;

  void dispose() {
    label.dispose();
    url.dispose();
  }
}
