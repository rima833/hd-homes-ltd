import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/authentication/domain/entities/enterprise_search_models.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/enterprise_search_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Global Command Center — Ctrl+K / Cmd+K (Enterprise Search Part 14).
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _open() {
    ref.read(commandCenterControllerProvider.notifier).setOpen(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _close() {
    ref.read(commandCenterControllerProvider.notifier).setOpen(false);
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Only watch open/closed at the root so typing/search results don't
    // rebuild the entire MaterialApp child tree.
    final isOpen = ref.watch(
      commandCenterControllerProvider.select((s) => s.isOpen),
    );

    return CommandPaletteScope(
      open: _open,
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
              const _OpenCommandPaletteIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
              const _OpenCommandPaletteIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape):
              const _CloseCommandPaletteIntent(),
        },
        child: Actions(
          actions: {
            _OpenCommandPaletteIntent:
                CallbackAction<_OpenCommandPaletteIntent>(
                  onInvoke: (_) {
                    _open();
                    return null;
                  },
                ),
            _CloseCommandPaletteIntent:
                CallbackAction<_CloseCommandPaletteIntent>(
                  onInvoke: (_) {
                    if (isOpen) _close();
                    return null;
                  },
                ),
          },
          child: Stack(
            children: [
              widget.child,
              if (isOpen)
                _CommandPaletteOverlay(
                  searchController: _searchController,
                  focusNode: _focusNode,
                  onClose: _close,
                  onNavigate: _navigate,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(String path) {
    _close();
    context.go(path);
  }
}

class _CommandPaletteOverlay extends ConsumerStatefulWidget {
  const _CommandPaletteOverlay({
    required this.searchController,
    required this.focusNode,
    required this.onClose,
    required this.onNavigate,
  });

  final TextEditingController searchController;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final void Function(String path) onNavigate;

  @override
  ConsumerState<_CommandPaletteOverlay> createState() =>
      _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState
    extends ConsumerState<_CommandPaletteOverlay> {
  final _overlayKey = GlobalKey<OverlayState>();
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(builder: _buildPalette);
  }

  @override
  void dispose() {
    // Overlay unmount removes the entry; avoid double-remove.
    super.dispose();
  }

  Widget _buildPalette(BuildContext overlayContext) {
    final ui = ref.read(commandCenterControllerProvider);
    final controller = ref.read(commandCenterControllerProvider.notifier);
    final snap = ref.read(enterpriseSearchSnapshotProvider).valueOrNull;
    final result = ui.result;
    final isMobile = MediaQuery.sizeOf(overlayContext).width < 600;
    final queryEmpty = ui.query.trim().isEmpty;

    return Stack(
      children: [
        ModalBarrier(
          color: AppColors.deepBlack.withValues(alpha: 0.65),
          onDismiss: widget.onClose,
        ),
        Align(
          alignment: isMobile ? Alignment.topCenter : Alignment.center,
          child: Padding(
            padding: EdgeInsets.only(
              top: isMobile ? 24 : 0,
              left: 12,
              right: 12,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 720,
                maxHeight: MediaQuery.sizeOf(overlayContext).height *
                    (isMobile ? 0.92 : 0.78),
              ),
              child: Material(
                color: Theme.of(overlayContext)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: AppRadius.dialogBorder,
                elevation: 20,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.search, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: widget.searchController,
                              focusNode: widget.focusNode,
                              autofocus: true,
                              onChanged: controller.setQuery,
                              decoration: const InputDecoration(
                                hintText:
                                    'Search everything or run a command…',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (v) {
                                final submitted = controller.submitSearch(v);
                                final items = submitted?.groups
                                        .expand((g) => g.items)
                                        .toList() ??
                                    const [];
                                final cmds = submitted?.commands ?? const [];
                                if (items.isNotEmpty) {
                                  widget.onNavigate(items.first.path);
                                } else if (cmds.isNotEmpty) {
                                  widget.onNavigate(cmds.first.routeOrKey);
                                }
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: widget.onClose,
                            icon: const Icon(LucideIcons.x),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          for (final mode in SearchMode.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(mode.label),
                                selected: ui.mode == mode,
                                onSelected: (_) => controller.setMode(mode),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    Expanded(
                      child: _CommandCenterBody(
                        ui: ui,
                        snap: snap,
                        onToggle: controller.toggleModule,
                        onNavigate: widget.onNavigate,
                        onResultOpen: (path) {
                          controller.recordResultOpen();
                          widget.onNavigate(path);
                        },
                        onSuggestion: (q) {
                          widget.searchController.text = q;
                          controller.setQuery(q);
                        },
                        onClearHistory: controller.clearHistory,
                      ),
                    ),
                    if (result != null)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          queryEmpty
                              ? 'Type to search anything · ${result.latencyMs}ms'
                              : result.zeroResults
                                  ? 'No authorized results · ${result.latencyMs}ms'
                                  : '${result.totalCount} results · ${result.latencyMs}ms'
                                      '${result.intent?.location != null ? ' · intent: ${result.intent!.location}' : ''}',
                          style: Theme.of(overlayContext).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stable Overlay so Close tooltips work (palette sits above Navigator
    // Overlay in MaterialApp.router builder) without remounting on keystrokes.
    ref.listen(commandCenterControllerProvider, (previous, next) {
      _entry.markNeedsBuild();
    });
    ref.listen(enterpriseSearchSnapshotProvider, (previous, next) {
      _entry.markNeedsBuild();
    });
    return Overlay(
      key: _overlayKey,
      initialEntries: [_entry],
    );
  }
}

class _CommandCenterBody extends StatelessWidget {
  const _CommandCenterBody({
    required this.ui,
    required this.snap,
    required this.onToggle,
    required this.onNavigate,
    required this.onResultOpen,
    required this.onSuggestion,
    required this.onClearHistory,
  });

  final CommandCenterUiState ui;
  final EnterpriseSearchSnapshot? snap;
  final void Function(SearchResultModule) onToggle;
  final void Function(String path) onNavigate;
  final void Function(String path) onResultOpen;
  final void Function(String query) onSuggestion;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final result = ui.result;
    final queryEmpty = ui.query.trim().isEmpty;

    if (queryEmpty) {
      final portalCommands = result?.commands ?? const [];
      final portalGroups = result?.groups ?? const [];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (portalCommands.isNotEmpty || portalGroups.isNotEmpty) ...[
            Text(
              'Go to',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            if (portalCommands.isNotEmpty)
              for (final c in portalCommands.take(14))
                ListTile(
                  dense: true,
                  leading: const Icon(LucideIcons.cornerDownRight, size: 18),
                  title: Text(c.label),
                  subtitle: Text(c.category),
                  onTap: () => onNavigate(c.routeOrKey),
                )
            else
              for (final group in portalGroups)
                for (final item in group.items.take(8))
                  ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.arrowRight, size: 18),
                    title: Text(item.title),
                    subtitle: Text(item.entry.subtitle ?? group.module.label),
                    onTap: () => onResultOpen(item.path),
                  ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          if (snap?.favoriteCommands.isNotEmpty == true) ...[
            Text(
              'Pinned commands',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final f in snap!.favoriteCommands)
                  ActionChip(
                    avatar: const Icon(LucideIcons.pin, size: 14),
                    label: Text(f.label),
                    onPressed: () => onNavigate(f.path),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (snap?.pinnedWorkspaces.isNotEmpty == true) ...[
            Text(
              'Intelligent Workspace Launcher',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ...snap!.pinnedWorkspaces.map(
              (w) => ListTile(
                dense: true,
                leading: const Icon(LucideIcons.layoutDashboard, size: 18),
                title: Text(w.title),
                subtitle: Text(w.subtitle ?? 'Workspace'),
                onTap: () => onNavigate(w.path),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                'Recent searches',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton(onPressed: onClearHistory, child: const Text('Clear')),
            ],
          ),
          ...(snap?.history ?? const <SearchHistoryItem>[]).map(
            (h) => ListTile(
              dense: true,
              leading: const Icon(LucideIcons.history, size: 18),
              title: Text(h.query),
              onTap: () => onSuggestion(h.query),
            ),
          ),
          if (result?.suggestions.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
            ...result!.suggestions.map(
              (s) => ListTile(
                dense: true,
                leading: Icon(
                  s.kind == 'command'
                      ? LucideIcons.zap
                      : s.kind == 'saved'
                      ? LucideIcons.bookmark
                      : LucideIcons.sparkles,
                  size: 18,
                ),
                title: Text(s.label),
                onTap: () => onSuggestion(s.query),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
            ...EnterpriseSearchCatalog.suggest('').map(
              (s) => ListTile(
                dense: true,
                leading: Icon(
                  s.kind == 'command'
                      ? LucideIcons.zap
                      : s.kind == 'saved'
                      ? LucideIcons.bookmark
                      : LucideIcons.sparkles,
                  size: 18,
                ),
                title: Text(s.label),
                onTap: () => onSuggestion(s.query),
              ),
            ),
          ],
        ],
      );
    }

    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (result.suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                for (final s in result.suggestions.take(4))
                  ActionChip(
                    label: Text(s.label),
                    onPressed: () => onSuggestion(s.query),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (result.commands.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Commands',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final c in result.commands.take(8))
            ListTile(
              leading: const Icon(LucideIcons.terminal, size: 18),
              title: Text(c.label),
              subtitle: Text(c.category),
              trailing: const Text('↵'),
              onTap: () => onResultOpen(c.routeOrKey),
            ),
        ],
        for (final group in result.groups) ...[
          ListTile(
            dense: true,
            title: Text(
              group.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            trailing: Icon(
              ui.expandedModules.contains(group.module)
                  ? LucideIcons.chevronDown
                  : LucideIcons.chevronRight,
              size: 16,
            ),
            onTap: () => onToggle(group.module),
          ),
          if (ui.expandedModules.contains(group.module))
            for (final item in group.items)
              ListTile(
                leading: Icon(_iconFor(item.module), size: 18),
                title: Text(item.title),
                subtitle: Text(
                  [
                    if (item.entry.subtitle != null) item.entry.subtitle!,
                    if (item.entry.preview.isNotEmpty)
                      item.entry.preview.entries
                          .take(2)
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' · '),
                  ].where((e) => e.isNotEmpty).join(' · '),
                ),
                onTap: () => onResultOpen(item.path),
              ),
        ],
        if (result.related.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Cross-module smart links',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final r in result.related)
            ListTile(
              dense: true,
              leading: const Icon(LucideIcons.link, size: 16),
              title: Text(r.title),
              subtitle: Text(r.module.label),
              onTap: () => onResultOpen(r.path),
            ),
        ],
        if (result.zeroResults)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No matching results for your permissions. Try another term or mode.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  IconData _iconFor(SearchResultModule m) => switch (m) {
    SearchResultModule.property ||
    SearchResultModule.estate => LucideIcons.building2,
    SearchResultModule.client ||
    SearchResultModule.investor ||
    SearchResultModule.staff ||
    SearchResultModule.user ||
    SearchResultModule.lead => LucideIcons.user,
    SearchResultModule.document => LucideIcons.fileText,
    SearchResultModule.report => LucideIcons.barChart3,
    SearchResultModule.command => LucideIcons.zap,
    SearchResultModule.ticket => LucideIcons.lifeBuoy,
    SearchResultModule.blog => LucideIcons.newspaper,
    SearchResultModule.workspace => LucideIcons.layoutDashboard,
    _ => LucideIcons.search,
  };
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _CloseCommandPaletteIntent extends Intent {
  const _CloseCommandPaletteIntent();
}
