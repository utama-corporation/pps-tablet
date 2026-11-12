import '../../../core/network/api_client.dart';
import '../model/master_formula_models.dart';

/// Master Formula Produksi — backend `/api/mst-formula`:
///   GET    /api/mst-formula/kategori     daftar kategori (IsWaste menandai kategori waste)
///   GET    /api/mst-formula/items?idKategori=
///   GET    /api/mst-formula?q=
///   GET    /api/mst-formula/detail?idFormula=
///   POST   /api/mst-formula              {mainKategoriId, mainOutputId, inputs[], secondarys[]}
///   PUT    /api/mst-formula              {idFormula, mainKategoriId, mainOutputId, inputs[], secondarys[]}
///   DELETE /api/mst-formula?idFormula=
///
/// Aturan dari backend: minimal 1 input atau 1 secondary; tidak boleh duplikat
/// persis; secondary tidak boleh sama dengan output utama; secondary hanya boleh
/// kategori Waste (IsWaste = 1). Formula untuk kategori+output yang sama
/// ditolak 409 saat create.
class MasterFormulaRepository {
  const MasterFormulaRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-formula';

  Future<List<FormulaKategori>> fetchKategori() async {
    final body = await api.getJson('$path/kategori');
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          FormulaKategori.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<FormulaItemOption>> fetchItems(int idKategori) async {
    final body = await api.getJson(
      '$path/items',
      query: {'idKategori': '$idKategori'},
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          FormulaItemOption.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<FormulaListRow>> fetchAll({String? q}) async {
    final body = await api.getJson(
      path,
      query: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          FormulaListRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<FormulaDetail> fetchDetail(int idFormula) async {
    final body = await api.getJson(
      '$path/detail',
      query: {'idFormula': '$idFormula'},
    );
    final data = body['data'];
    if (data is! Map) {
      throw const FormatException('Detail formula tidak valid');
    }
    return FormulaDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> create({
    required int mainKategoriId,
    required int mainOutputId,
    required List<Map<String, int>> inputs,
    required List<Map<String, int>> secondarys,
  }) async {
    await api.postJson(
      path,
      body: {
        'mainKategoriId': mainKategoriId,
        'mainOutputId': mainOutputId,
        'inputs': inputs,
        'secondarys': secondarys,
      },
    );
  }

  Future<void> update({
    required int idFormula,
    required int mainKategoriId,
    required int mainOutputId,
    required List<Map<String, int>> inputs,
    required List<Map<String, int>> secondarys,
  }) async {
    await api.putJson(
      path,
      body: {
        'idFormula': idFormula,
        'mainKategoriId': mainKategoriId,
        'mainOutputId': mainOutputId,
        'inputs': inputs,
        'secondarys': secondarys,
      },
    );
  }

  Future<void> delete(int idFormula) async {
    await api.deleteJson(path, query: {'idFormula': '$idFormula'});
  }
}
