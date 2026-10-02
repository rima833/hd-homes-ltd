import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/features/authentication/presentation/providers/identity_provider.dart';
import 'package:hdhomesproject/features/client/presentation/providers/client_providers.dart';
import 'package:hdhomesproject/features/properties/data/providers/marketplace_controller.dart';

/// Keeps marketplace heart icons in sync with the client portal saved list.
final marketplaceFavoritesBootstrapProvider = Provider<void>((ref) {
  final userId = ref.watch(identitySessionProvider).userId;
  if (userId == null) return;

  ref.listen(clientSavedPropertyIdsProvider, (_, next) {
    next.whenData((ids) {
      ref.read(marketplaceFavoritesProvider.notifier).state = ids;
    });
  });
});

Future<void> toggleMarketplaceFavorite(
  WidgetRef ref, {
  required String propertyId,
  String title = 'Property',
}) async {
  final userId = ref.read(identitySessionProvider).userId;
  final set = {...ref.read(marketplaceFavoritesProvider)};

  if (userId != null) {
    await ref.read(clientServiceProvider).toggleSavedProperty(
          propertyId,
          title: title,
        );
    ref.invalidate(clientSavedPropertiesProvider);
    ref.invalidate(clientSavedPropertyIdsProvider);
  }

  if (set.contains(propertyId)) {
    set.remove(propertyId);
  } else {
    set.add(propertyId);
  }
  ref.read(marketplaceFavoritesProvider.notifier).state = set;
}
