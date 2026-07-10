import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/growth/models/growth_models.dart';
import 'package:hdhomesproject/core/growth/providers/growth_cms_provider.dart';

/// Third-party integration registry — abstracted service connectors.
final integrationRegistryProvider = Provider((ref) => ref.watch(growthHubCmsProvider).integrations);

bool isIntegrationActive(WidgetRef ref, String integrationId) {
  final integrations = ref.read(integrationRegistryProvider);
  return integrations.any((i) => i.id == integrationId && i.status == IntegrationStatus.active);
}
