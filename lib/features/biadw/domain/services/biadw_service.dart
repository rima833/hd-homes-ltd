import 'package:hdhomesproject/features/biadw/domain/entities/biadw_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BiadwService {
  BiadwService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<BiadwCommandCenterSnapshot> loadCommandCenter({int days = 30}) async {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Live operational analytics require a configured Supabase client.',
      );
    }

    final result = await client.rpc(
      'get_admin_operational_analytics',
      params: {'p_days': days.clamp(7, 365)},
    );
    if (result is! Map) {
      throw const FormatException(
        'Operational analytics returned an invalid response.',
      );
    }
    return BiadwCommandCenterSnapshot.fromJson(
      Map<String, dynamic>.from(result),
    );
  }
}
