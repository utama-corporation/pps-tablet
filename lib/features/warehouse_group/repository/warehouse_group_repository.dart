// lib/features/warehouse_group/repository/warehouse_group_repository.dart
import 'package:pps_tablet/core/network/api_client.dart';

import '../model/warehouse_group_model.dart';

class WarehouseGroupRepository {
  final ApiClient api;

  WarehouseGroupRepository({required this.api});

  // ── Group (dbo.MstWarehouseGroup) ────────────────────────────────────────

  Future<List<WarehouseGroup>> fetchGroups({bool includeInactive = true}) async {
    final body = await api.getJson(
      '/api/mst/warehouse-group',
      query: {if (includeInactive) 'includeInactive': '1'},
    );
    final data = body['data'];
    if (data is! List) throw Exception('Format data group tidak sesuai');
    return data
        .map((e) => WarehouseGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WarehouseGroup> createGroup({
    required String namaGroup,
    String? keterangan,
  }) async {
    final body = await api.postJson(
      '/api/mst/warehouse-group',
      body: {
        'namaGroup': namaGroup,
        if (keterangan != null && keterangan.trim().isNotEmpty)
          'keterangan': keterangan.trim(),
      },
    );
    return WarehouseGroup.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<WarehouseGroup> updateGroup({
    required int id,
    required String namaGroup,
    String? keterangan,
    required bool aktif,
  }) async {
    final body = await api.putJson(
      '/api/mst/warehouse-group/$id',
      body: {
        'namaGroup': namaGroup,
        'keterangan': (keterangan == null || keterangan.trim().isEmpty)
            ? null
            : keterangan.trim(),
        'aktif': aktif,
      },
    );
    return WarehouseGroup.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteGroup(int id) async {
    await api.deleteJson('/api/mst/warehouse-group/$id');
  }

  // ── Warehouse ↔ group assignment ─────────────────────────────────────────

  Future<List<WarehouseGroupAssignment>> fetchWarehouses() async {
    final body = await api.getJson(
      '/api/mst/warehouse',
      query: {'includeDisabled': '1', 'orderBy': 'NamaWarehouse'},
    );
    final data = body['data'];
    if (data is! List) throw Exception('Format data warehouse tidak sesuai');
    return data
        .map(
          (e) => WarehouseGroupAssignment.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// [idWarehouseGroup] null = lepas warehouse dari group.
  Future<void> setWarehouseGroup({
    required int idWarehouse,
    required int? idWarehouseGroup,
  }) async {
    await api.putJson(
      '/api/mst/warehouse/$idWarehouse/group',
      body: {'idWarehouseGroup': idWarehouseGroup},
    );
  }
}
