import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/config/ai_features.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/core/widgets/offline_updates_note.dart';
import 'package:hdhomesproject/features/esp/domain/entities/esp_models.dart';
import 'package:hdhomesproject/features/esp/domain/services/esp_service.dart';
import 'package:hdhomesproject/features/esp/presentation/providers/esp_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Volume 4 Part 19 — Enterprise Security Command Center.
class SecurityCommandCenterPage extends ConsumerWidget {
  const SecurityCommandCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(espSnapshotProvider);
    final ui = ref.watch(espControllerProvider);
    final controller = ref.read(espControllerProvider.notifier);
    return Scaffold(
      body: asyncSnapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Failed to load Security Command Center: $error'),
        ),
        data: (snapshot) {
          final ticker = snapshot.kpis[ui.tickerIndex % snapshot.kpis.length];
          final visibleTabs = kAiFeaturesEnabled
              ? EspCommandTab.values
              : EspCommandTab.values.where((t) => t.name != 'ai').toList();
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(
                  live: snapshot.fromRemote,
                  ticker: '${ticker.label}: ${ticker.displayValue}',
                  onRefresh: controller.refresh,
                ),
                const SizedBox(height: 12),
                _Kpis(items: snapshot.kpis),
                const SizedBox(height: 12),
                _FeatureStrip(onSelect: controller.setTab),
                const SizedBox(height: 12),
                TextField(
                  onChanged: controller.setSearch,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.search, size: 18),
                    hintText:
                        'Search alerts, identities, incidents, privacy, recovery…',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: ui.severityFilter == null,
                      onSelected: (_) => controller.setSeverity(null),
                    ),
                    for (final severity in [
                      EspSeverity.high,
                      EspSeverity.critical,
                    ])
                      FilterChip(
                        label: Text(severity.name),
                        selected: ui.severityFilter == severity,
                        onSelected: (_) => controller.setSeverity(severity),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: visibleTabs
                        .map(
                          (tab) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(tab.label),
                              selected: tab == ui.selectedTab,
                              onSelected: (_) => controller.setTab(tab),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                ..._content(context, ref, snapshot, ui.selectedTab, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    EspCommandCenterSnapshot snapshot,
    EspCommandTab tab,
    EspController controller,
  ) {
    List<EspRecord> records;
    String title;
    IconData icon;
    switch (tab) {
      case EspCommandTab.overview:
        final briefing =
            ref.read(espServiceProvider).generateSecurityBriefing(snapshot);
        return [
          _Card(
            title: 'Enterprise Security Command Center™',
            icon: LucideIcons.shield,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kAiFeaturesEnabled
                      ? briefing
                      : briefing
                          .replaceAll(snapshot.aiDisclaimer, '')
                          .trimRight(),
                ),
                const Divider(height: 24),
                ...EspService.detectSecuritySignals(snapshot).map(
                  (signal) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.radio, size: 16),
                    title: Text(signal),
                  ),
                ),
                const Divider(height: 24),
                _Records(items: snapshot.activity),
              ],
            ),
          ),
        ];
      case EspCommandTab.iam:
        (title, icon, records) = (
          'Adaptive Identity & Trust Platform™',
          LucideIcons.users,
          snapshot.sessions,
        );
      case EspCommandTab.mfa:
        (title, icon, records) = (
          'MFA posture',
          LucideIcons.keyRound,
          snapshot.mfa,
        );
      case EspCommandTab.threats:
        (title, icon, records) = (
          'Intelligent Threat Intelligence Engine™',
          LucideIcons.radar,
          [...snapshot.alerts, ...snapshot.threats],
        );
      case EspCommandTab.incidents:
        (title, icon, records) = (
          'Security incidents & evidence',
          LucideIcons.siren,
          snapshot.incidents,
        );
      case EspCommandTab.audit:
        (title, icon, records) = (
          'Audit & compliance trail',
          LucideIcons.scrollText,
          snapshot.audit,
        );
      case EspCommandTab.privacy:
        (title, icon, records) = (
          'Enterprise Privacy & Data Protection Center™',
          LucideIcons.userCheck,
          snapshot.privacy,
        );
      case EspCommandTab.secrets:
        (title, icon, records) = (
          'Encryption, keys & secrets registry',
          LucideIcons.lock,
          snapshot.secrets,
        );
      case EspCommandTab.backup:
        (title, icon, records) = (
          'Backup operations',
          LucideIcons.databaseBackup,
          snapshot.backups,
        );
      case EspCommandTab.dr:
        (title, icon, records) = (
          'Digital Resilience & Recovery Center™',
          LucideIcons.lifeBuoy,
          snapshot.disasterRecovery,
        );
      case EspCommandTab.analytics:
        return [
          _Card(
            title: 'Security analytics',
            icon: LucideIcons.barChart3,
            child: _Kpis(items: snapshot.kpis),
          ),
        ];
      case EspCommandTab.ai:
        return [
          _Card(
            title: 'AI security intelligence',
            icon: LucideIcons.sparkles,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.aiDisclaimer,
                  style: const TextStyle(color: AppColors.gold),
                ),
                const SizedBox(height: 8),
                _Records(items: snapshot.aiSecurity),
                const Divider(height: 24),
                ...snapshot.insights.map(
                  (insight) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.sparkles),
                    title: Text(insight.title),
                    subtitle: Text(
                      '${insight.body}\n${insight.disclaimer} · ${insight.confidencePct?.toStringAsFixed(0) ?? '—'}%',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ],
            ),
          ),
        ];
    }
    return [
      _Card(
        title: title,
        icon: icon,
        child: _Records(items: controller.filter(records)),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.live,
    required this.ticker,
    required this.onRefresh,
  });
  final bool live;
  final String ticker;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.deepBlack, AppColors.charcoal],
      ),
      borderRadius: AppRadius.cardBorder,
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.shieldCheck, color: AppColors.gold, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Command Center',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!live)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: OfflineUpdatesNote(),
                ),
              Text(
                ticker,
                style: TextStyle(color: AppColors.white.withValues(alpha: .75)),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(LucideIcons.refreshCw, color: AppColors.white),
        ),
      ],
    ),
  );
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip({required this.onSelect});
  final ValueChanged<EspCommandTab> onSelect;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children:
        const [
              (
                EspCommandTab.overview,
                'Security Command Center™',
                LucideIcons.shield,
              ),
              (
                EspCommandTab.threats,
                'Threat Intelligence™',
                LucideIcons.radar,
              ),
              (EspCommandTab.iam, 'Identity & Trust™', LucideIcons.users),
              (EspCommandTab.privacy, 'Privacy Center™', LucideIcons.userCheck),
              (
                EspCommandTab.dr,
                'Resilience & Recovery™',
                LucideIcons.lifeBuoy,
              ),
            ]
            .map(
              (item) => ActionChip(
                avatar: Icon(item.$3, size: 16),
                label: Text(item.$2),
                onPressed: () => onSelect(item.$1),
              ),
            )
            .toList(),
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.items});
  final List<EspKpi> items;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 92,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) => Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.cardBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              items[index].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              items[index].displayValue,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: AppRadius.cardBorder,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Records extends StatelessWidget {
  const _Records({required this.items});
  final List<EspRecord> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No matching security records.');
    return Column(
      children: items
          .map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.severity == EspSeverity.critical
                    ? LucideIcons.alertOctagon
                    : LucideIcons.shield,
                color: item.severity == EspSeverity.critical
                    ? AppColors.gold
                    : null,
              ),
              title: Text(item.title),
              subtitle: Text(
                [
                  item.category,
                  if (item.summary.isNotEmpty) item.summary,
                ].join(' · '),
              ),
              trailing: Text(item.status),
            ),
          )
          .toList(),
    );
  }
}
