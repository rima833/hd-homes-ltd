import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';

class CommandAction {
  const CommandAction({
    required this.label,
    required this.path,
    this.icon,
    this.keywords = const [],
    this.section = 'Navigation',
  });

  final String label;
  final String path;
  final IconData? icon;
  final List<String> keywords;
  final String section;
}

final commandActionsProvider = Provider<List<CommandAction>>((ref) {
  return const [
    CommandAction(label: 'Home', path: RoutePaths.home, icon: Icons.home_rounded),
    CommandAction(label: 'Properties', path: RoutePaths.properties, icon: Icons.apartment_rounded, keywords: ['search', 'listings']),
    CommandAction(label: 'Estates', path: RoutePaths.estates, icon: Icons.location_city_rounded),
    CommandAction(label: 'Blog', path: RoutePaths.blog, icon: Icons.article_rounded),
    CommandAction(label: 'Contact', path: RoutePaths.contact, icon: Icons.mail_rounded),
    CommandAction(label: 'Login', path: RoutePaths.login, icon: Icons.login_rounded, section: 'Account'),
    CommandAction(label: 'Admin Dashboard', path: RoutePaths.dashboard, icon: Icons.dashboard_rounded, section: 'Portals'),
    CommandAction(label: 'Client Portal', path: RoutePaths.client, icon: Icons.person_rounded, section: 'Portals'),
    CommandAction(label: 'Investor Portal', path: RoutePaths.investor, icon: Icons.account_balance_rounded, section: 'Portals'),
    CommandAction(label: 'Create Property', path: RoutePaths.dashboardProperties, icon: Icons.add_home_rounded, section: 'Quick Actions', keywords: ['add', 'new']),
    CommandAction(label: 'CRM', path: RoutePaths.dashboardCrm, icon: Icons.contact_phone_rounded, section: 'Quick Actions'),
    CommandAction(label: 'Reports', path: RoutePaths.dashboardReports, icon: Icons.assessment_rounded, section: 'Quick Actions'),
    CommandAction(label: 'Settings', path: RoutePaths.dashboardSettings, icon: Icons.settings_rounded, section: 'Quick Actions'),
  ];
});

/// Global command palette — Ctrl+K / Cmd+K.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _searchController = TextEditingController();
  bool _visible = false;

  void _open() => setState(() => _visible = true);
  void _close() {
    setState(() => _visible = false);
    _searchController.clear();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(commandActionsProvider);
    final query = _searchController.text.toLowerCase();
    final filtered = actions.where((a) {
      if (query.isEmpty) return true;
      return a.label.toLowerCase().contains(query) ||
          a.keywords.any((k) => k.contains(query));
    }).toList();

    return CommandPaletteScope(
      open: _open,
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
              const _OpenCommandPaletteIntent(),
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
              const _OpenCommandPaletteIntent(),
        },
        child: Actions(
          actions: {
            _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
              onInvoke: (_) {
                _open();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                widget.child,
                if (_visible) ...[
                  ModalBarrier(
                    color: AppColors.deepBlack.withValues(alpha: 0.6),
                    onDismiss: _close,
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.dialogBorder,
                        elevation: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.base),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Search properties, clients, settings...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) {
                                  if (filtered.isNotEmpty) {
                                    _navigate(filtered.first.path);
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 1),
                            Flexible(
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final action in filtered)
                                    ListTile(
                                      leading: Icon(action.icon ?? Icons.arrow_forward_rounded),
                                      title: Text(action.label),
                                      subtitle: Text(action.section),
                                      onTap: () => _navigate(action.path),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}
