import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/media/cloudinary_media_service.dart';
import 'package:hdhomesproject/core/media/media_models.dart';
import 'package:hdhomesproject/core/media/media_service.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';

final mediaServiceProvider = Provider<MediaService?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) return null;
  final client = ref.watch(supabaseClientProvider);
  return CloudinaryMediaService(client);
});

/// True when Supabase is connected — Cloudinary credentials come from Edge Functions.
final cloudinaryEnabledProvider = Provider<bool>((ref) {
  return ref.watch(supabaseConfiguredProvider);
});

/// All library media (optionally filtered by folder name).
final mediaLibraryProvider =
    FutureProvider.family<List<MediaAsset>, String?>((ref, folderName) async {
  if (!ref.watch(supabaseConfiguredProvider)) return const [];
  final client = ref.watch(supabaseClientProvider);
  var query = client.from('media_library').select();
  if (folderName != null && folderName.isNotEmpty) {
    query = query.eq('folder_name', folderName);
  }
  final rows = await query.order('created_at', ascending: false);
  return rows
      .map((e) => MediaAsset.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

/// Entity-scoped media (property gallery, construction, etc.).
final entityMediaProvider = FutureProvider.family<List<MediaAsset>,
    ({MediaEntityType type, String id})>((ref, key) async {
  final service = ref.watch(mediaServiceProvider);
  if (service == null) return const [];
  return service.getMediaForEntity(entityType: key.type, entityId: key.id);
});
