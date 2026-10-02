import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/layout/portal_shell.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/auth/policies/admin_access_policy.dart';
import 'package:hdhomesproject/core/auth/policies/dashboard_access_policy.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/dashboard/domain/entities/executive_dashboard_models.dart';
import 'package:hdhomesproject/features/dashboard/presentation/providers/executive_dashboard_controller.dart';
import 'package:hdhomesproject/features/dashboard/presentation/widgets/executive_dashboard_cards.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 1 — Executive Mission Control™ dashboard.
enum ExecutiveDashboardScope {
  /// Full boardroom Mission Control (Super Admin only).
  superAdmin,

  /// Daily operations overview for Admin — no super-admin KPI surfaces.
  adminOperations,
}

class ExecutiveDashboardPage extends ConsumerWidget {
  const ExecutiveDashboardPage({
    super.key,
    this.scope = ExecutiveDashboardScope.superAdmin,
  });

  final ExecutiveDashboardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnap = ref.watch(executiveDashboardSnapshotProvider);
    final ui = ref.watch(executiveDashboardControllerProvider);
    final controller = ref.read(executiveDashboardControllerProvider.notifier);
    final session = ref.watch(identitySessionProvider);
    final permissions = session.permissions;
    final profile = session.profile;
    final name = [
      profile?.firstName,
      profile?.lastName,
    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ');
    final displayName = name.isEmpty ? (session.email ?? 'Executive') : name;
    final role = session.primaryRole?.displayName ?? 'Administrator';
    final isSuperAdminScope = scope == ExecutiveDashboardScope.superAdmin;
    final dashboardTitle =
        isSuperAdminScope ? 'Mission Control' : 'Operations Dashboard';

    bool visible(String moduleKey) {
      if (_hidden(ui, moduleKey)) return false;
      if (isSuperAdminScope) return true;
      if (DashboardAccessPolicy.superAdminOnlyModules.contains(moduleKey)) {
        return false;
      }
      return _adminModuleAllowed(moduleKey, permissions);
    }

    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: asyncSnap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load Mission Control: $e')),
        data: (snap) {
          final greeting = _greeting(DateTime.now());
          final dateLabel = DateFormat('EEEE, d MMMM y').format(DateTime.now());
          final timeLabel = DateFormat('HH:mm').format(DateTime.now());
          final tickerKpis = visible('kpis') ? snap.kpis : const <KpiCard>[];
          final ticker = tickerKpis.isEmpty
              ? '$dashboardTitle live'
              : '${tickerKpis[ui.tickerIndex % tickerKpis.length].label}: '
                  '${tickerKpis[ui.tickerIndex % tickerKpis.length].displayValue}';

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ExecutiveDashHeader(
                    greeting: '$greeting, $displayName',
                    role: role,
                    dashboardTitle: dashboardTitle,
                    dateLabel: dateLabel,
                    timeLabel: timeLabel,
                    ticker: ticker,
                    presentationMode: ui.presentationMode,
                    autoRefresh: ui.autoRefresh,
                    fromRemote: snap.fromRemote,
                    showPresentationControls: isSuperAdminScope,
                    showAiShortcut: isSuperAdminScope &&
                        AdminAccessPolicy.canAny(session, AdminAccessPolicy.aiHub),
                    onTogglePresentation: controller.togglePresentationMode,
                    onToggleAutoRefresh: () =>
                        controller.setAutoRefresh(!ui.autoRefresh),
                    onSearch: () =>
                        CommandPaletteScope.maybeOf(context)?.open(),
                    onAi: () => context.go(RoutePaths.aiGovernance),
                    onRefresh: controller.refresh,
                  ),
                ),
                if (ui.lastReportMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Material(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.cardBorder,
                        child: ListTile(
                          leading: const Icon(
                            LucideIcons.fileCheck,
                            color: AppColors.gold,
                          ),
                          title: Text(ui.lastReportMessage!),
                          dense: true,
                        ),
                      ),
                    ),
                  ),
                if (visible('briefing') && snap.briefingSummary != null)
                  SliverToBoxAdapter(
                    child: ExecutiveDashBriefing(
                      text: snap.briefingSummary!,
                      live: snap.fromRemote,
                    ),
                  ),
                if (visible('health'))
                  SliverToBoxAdapter(
                    child: ExecutiveDashHealth(health: snap.health),
                  ),
                if (visible('kpis'))
                  SliverToBoxAdapter(
                    child: ExecutiveDashKpis(kpis: snap.kpis),
                  ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('sales')
                        ? ExecutiveDashMetrics(
                            block: snap.sales,
                            icon: LucideIcons.trendingUp,
                          )
                        : null,
                    right: visible('finance')
                        ? ExecutiveDashMetrics(
                            block: snap.finance,
                            icon: LucideIcons.wallet,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('properties')
                        ? ExecutiveDashMetrics(
                            block: snap.properties,
                            icon: LucideIcons.building2,
                          )
                        : null,
                    right: visible('investors')
                        ? ExecutiveDashMetrics(
                            block: snap.investors,
                            icon: LucideIcons.lineChart,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('crm')
                        ? ExecutiveDashMetrics(
                            block: snap.crm,
                            icon: LucideIcons.users,
                          )
                        : null,
                    right: visible('construction')
                        ? ExecutiveDashMetrics(
                            block: snap.construction,
                            icon: LucideIcons.hardHat,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('marketing')
                        ? ExecutiveDashMetrics(
                            block: snap.marketing,
                            icon: LucideIcons.megaphone,
                          )
                        : null,
                    right: visible('support')
                        ? ExecutiveDashMetrics(
                            block: snap.support,
                            icon: LucideIcons.lifeBuoy,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('insights')
                        ? ExecutiveDashInsights(insights: snap.insights)
                        : null,
                    right: visible('risks')
                        ? ExecutiveDashRisks(risks: snap.risks)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('activity')
                        ? ExecutiveDashActivity(items: snap.activity)
                        : null,
                    right: visible('notifications')
                        ? ExecutiveDashNotifications(
                            items: snap.notifications,
                            onRead: controller.markRead,
                          )
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ExecutiveDashTwoCol(
                    left: visible('schedule')
                        ? ExecutiveDashSchedule(items: snap.schedule)
                        : null,
                    right: visible('forecasts')
                        ? ExecutiveDashForecasts(forecasts: snap.forecasts)
                        : null,
                  ),
                ),
                if (visible('actions'))
                  SliverToBoxAdapter(
                    child: ExecutiveDashQuickActions(
                      actions: snap.quickActions
                          .where((a) => a.allowedFor(permissions))
                          .toList(),
                      onTap: (path) => context.go(path),
                    ),
                  ),
                if (visible('reports'))
                  SliverToBoxAdapter(
                    child: ExecutiveDashReports(
                      types: snap.reportTypes,
                      onGenerate: (id) => controller.generateReport(id),
                      onBriefing: isSuperAdminScope
                          ? () {
                        final text = controller.briefingText(snap);
                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Executive Briefing Generator™'),
                            content: SingleChildScrollView(child: Text(text)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  controller.generateReport('briefing');
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Queue export'),
                              ),
                            ],
                          ),
                        );
                      }
                          : null,
                    ),
                  ),
                if (visible('strategy'))
                  SliverToBoxAdapter(
                    child: ExecutiveDashStrategy(initiatives: snap.initiatives),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _hidden(ExecutiveDashboardUiState ui, String key) =>
      ui.hiddenModules.contains(key);

  static bool _adminModuleAllowed(String moduleKey, Set<String> permissions) {
    final sessionPerms = permissions;
    bool any(List<String> slugs) {
      for (final slug in slugs) {
        if (sessionPerms.contains(slug)) return true;
      }
      return false;
    }

    return switch (moduleKey) {
      'sales' || 'crm' => any(AdminAccessPolicy.sales),
      'finance' => any(AdminAccessPolicy.finance),
      'properties' => any(AdminAccessPolicy.properties),
      'investors' => any(AdminAccessPolicy.investors),
      'construction' => any(AdminAccessPolicy.construction),
      'marketing' => any(AdminAccessPolicy.marketingHub),
      'support' => any(AdminAccessPolicy.support),
      'documents' => any(AdminAccessPolicy.documents),
      'activity' || 'notifications' || 'actions' => true,
      _ => false,
    };
  }

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
