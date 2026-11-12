import '../../../core/network/api_client.dart';
import '../model/supplier_item.dart';

/// Master Supplier — backend `/api/mst-supplier`:
///   GET    /api/mst-supplier?q=&status=all|active|inactive
///   POST   /api/mst-supplier          {namaSupplier, initial, noTlp, enable}
///   PUT    /api/mst-supplier/:id
///   DELETE /api/mst-supplier/:id      hard delete; FK 547 → 409
///                                     "Supplier sudah dipakai di transaksi
///                                     dan tidak bisa dihapus. Nonaktifkan saja."
class MasterSupplierRepository {
  const MasterSupplierRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-supplier';

  Future<List<SupplierItem>> fetchAll({String? q, String status = 'all'}) async {
    final body = await api.getJson(
      path,
      query: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'status': status,
      },
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) SupplierItem.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, dynamic>> create({
    required String namaSupplier,
    required String initial,
    required String noTlp,
    required bool enable,
  }) => api.postJson(
    path,
    body: {
      'namaSupplier': namaSupplier,
      'initial': initial,
      'noTlp': noTlp,
      'enable': enable ? 1 : 0,
    },
  );

  Future<Map<String, dynamic>> update({
    required int id,
    required String namaSupplier,
    required String initial,
    required String noTlp,
    required bool enable,
  }) => api.putJson(
    '$path/$id',
    body: {
      'namaSupplier': namaSupplier,
      'initial': initial,
      'noTlp': noTlp,
      'enable': enable ? 1 : 0,
    },
  );

  Future<void> delete(int id) async {
    await api.deleteJson('$path/$id');
  }
}
