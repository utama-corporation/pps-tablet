import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/master_formula_models.dart';
import '../repository/master_formula_repository.dart';

class MasterFormulaViewModel extends ChangeNotifier {
  MasterFormulaViewModel(this.repository);

  final MasterFormulaRepository repository;

  List<FormulaListRow> _items = [];
  String query = '';
  bool loading = false;
  String error = '';

  List<FormulaKategori>? kategoriList;
  bool kategoriLoading = false;
  String kategoriError = '';

  // null value = gagal memuat (dipakai untuk membedakan "belum dimuat"
  // vs "gagal").
  final Map<int, List<FormulaItemOption>?> _itemCache = {};
  final Map<int, bool> _itemsLoading = {};

  // notifyListeners() pada ChangeNotifier yang sudah di-dispose melempar
  // error dari dalam listener provider saat tree dibongkar
  // (assert framework _dependents.isEmpty).
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Daftar terfilter client-side (dataset formula kecil; satu fetch penuh).
  List<FormulaListRow> get items {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where(
        (row) =>
            '${row.idFormula} ${row.mainKategori} ${row.mainOutputNama}'
                .toLowerCase()
                .contains(q),
      ),
    );
  }

  int get totalCount => _items.length;

  /// Items ter-cache untuk kategori; null bila belum dimuat.
  List<FormulaItemOption>? itemsFor(int? idKategori) {
    if (idKategori == null) return null;
    return _itemCache[idKategori];
  }

  bool isItemsFailed(int? idKategori) =>
      idKategori != null && _itemCache[idKategori] == null &&
      _itemCache.containsKey(idKategori);

  bool isItemsLoading(int? idKategori) =>
      idKategori != null && (_itemsLoading[idKategori] ?? false);

  void setQuery(String value) {
    if (query == value.trim()) return;
    query = value.trim();
    _notify();
  }

  Future<void> load() async {
    if (_disposed) return;
    loading = true;
    error = '';
    _notify();
    try {
      _items = await repository.fetchAll();
    } catch (e) {
      if (!_disposed) error = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadKategori() async {
    if (_disposed) return;
    if (kategoriLoading) return;
    kategoriLoading = true;
    kategoriError = '';
    _notify();
    try {
      kategoriList = await repository.fetchKategori();
    } catch (e) {
      if (!_disposed) kategoriError = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        kategoriLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadItems(int idKategori, {bool force = false}) async {
    if (_disposed) return;
    if (!force && _itemCache.containsKey(idKategori)) return;
    if (_itemsLoading[idKategori] == true) return;
    _itemsLoading[idKategori] = true;
    _notify();
    try {
      _itemCache[idKategori] = await repository.fetchItems(idKategori);
    } catch (e) {
      // Biarkan cache kosong — UI menampilkan "gagal memuat" lewat itemsFor
      // null + pesan di field.
      if (!_disposed) _itemCache[idKategori] = null;
    } finally {
      if (!_disposed) {
        _itemsLoading[idKategori] = false;
        _notify();
      }
    }
  }

  Future<FormulaDetail> fetchDetail(int idFormula) =>
      repository.fetchDetail(idFormula);

  /// Simpan (create bila [idFormula] null, update bila ada) lalu reload list.
  /// Mengembalikan label untuk notifikasi.
  Future<String> save({
    int? idFormula,
    required int mainKategoriId,
    required int mainOutputId,
    required List<Map<String, int>> inputs,
    required List<Map<String, int>> secondarys,
    required String label,
  }) async {
    if (idFormula == null) {
      await repository.create(
        mainKategoriId: mainKategoriId,
        mainOutputId: mainOutputId,
        inputs: inputs,
        secondarys: secondarys,
      );
    } else {
      await repository.update(
        idFormula: idFormula,
        mainKategoriId: mainKategoriId,
        mainOutputId: mainOutputId,
        inputs: inputs,
        secondarys: secondarys,
      );
    }
    if (!_disposed) await load();
    return label;
  }

  Future<void> delete(int idFormula) async {
    await repository.delete(idFormula);
    if (!_disposed) await load();
  }
}
