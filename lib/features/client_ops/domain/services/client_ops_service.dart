import 'package:hdhomesproject/features/client_ops/domain/entities/client_ops_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientOpsService {
  ClientOpsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final c = _client;
    if (c == null) {
      throw StateError('Supabase is not configured');
    }
    return c;
  }

  Future<ClientOpsPage> listClientsPage({
    String? search,
    String? relationshipStatus,
    String? customerType,
    String? assignedStaffId,
    bool unassignedOnly = false,
    bool portalOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _requireClient.rpc(
      'admin_list_clients',
      params: {
        'p_search': ?search,
        'p_relationship_status': ?relationshipStatus,
        'p_customer_type': ?customerType,
        'p_assigned_staff_id': ?assignedStaffId,
        'p_unassigned_only': unassignedOnly,
        'p_portal_only': portalOnly,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (result is! Map) {
      throw const FormatException('Invalid client directory response');
    }
    return ClientOpsPage.fromJson(Map<String, dynamic>.from(result));
  }

  Future<ClientDeskKpis> loadDeskKpis() async {
    final result = await _requireClient.rpc('admin_get_client_desk_kpis');
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return ClientDeskKpis.fromJson(map);
  }

  Future<ClientOpsWorkQueues> loadWorkQueues() async {
    final result = await _requireClient.rpc('admin_get_client_work_queues');
    if (result is! Map) {
      throw const FormatException('Invalid client work-queue response');
    }
    return ClientOpsWorkQueues.fromJson(Map<String, dynamic>.from(result));
  }

  Future<ClientOpsDetail> loadClient360(String clientId) async {
    final result = await _requireClient.rpc(
      'admin_get_client_360',
      params: {'p_client_id': clientId},
    );
    if (result is! Map) {
      throw const FormatException('Invalid client detail response');
    }
    return ClientOpsDetail.fromJson(Map<String, dynamic>.from(result));
  }

  Future<List<ClientOpsStaffOption>> listManagers() async {
    final result = await _requireClient.rpc('admin_list_client_managers');
    final rows = switch (result) {
      final List list => list,
      final Map map => (map['items'] ?? map['data']) is List
          ? (map['items'] ?? map['data']) as List
          : const [],
      _ => const [],
    };
    return rows
        .whereType<Map>()
        .map((r) => ClientOpsStaffOption.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> assignOwner({
    required String clientId,
    required String staffId,
  }) async {
    await _requireClient.rpc(
      'admin_assign_client_owner',
      params: {'p_client_id': clientId, 'p_staff_id': staffId},
    );
  }
}
