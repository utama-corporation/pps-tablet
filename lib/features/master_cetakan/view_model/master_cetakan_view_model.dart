import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/master_cetakan_models.dart';
import '../repository/master_cetakan_repository.dart';

class MasterCetakanViewModel extends ChangeNotifier {
  MasterCetakanViewModel(this.repository);

  final MasterCetakanRepository repository;

  List<CetakanWarnaMaterialRow> _items = [];
  String query = '';
  bool loading = false;
  String error = '';

  MasterCetakanOptions? options;
  bool optionsLoading = false;
  String optionsError = '';

  // notifyListeners() pada ChangeNotifier yang sudah di-dispose melempar
  // error dari dalam listener provider, membuat elemen provider/dependents
  // tidak konsisten saat tree dibongkar (assert framework _dependents.isEmpty).
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

  List<CetakanWarnaMaterialRow> get items {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where(
        (row) =>
            '${row.namaCetakan} ${row.warna} ${row.namaMaterial}'
                .toLowerCase()
                .contains(q),
      ),
    );
  }

  int get totalCount => _items.length;

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
      _items = await repository.fetchAll(top: 500);
      if (_disposed) return;
      _items = List.of(_items)
        ..sort((a, b) {
          final byCetakan = a.namaCetakan.toLowerCase().compareTo(
            b.namaCetakan.toLowerCase(),
          );
          if (byCetakan != 0) return byCetakan;
          final byWarna = a.warna.toLowerCase().compareTo(b.warna.toLowerCase());
          if (byWarna != 0) return byWarna;
          return a.namaMaterial.toLowerCase().compareTo(
            b.namaMaterial.toLowerCase(),
          );
        });
    } catch (e) {
      if (!_disposed) error = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  /// Opsi dropdown — dimuat sekali, disegarkan setelah quick-add.
  Future<void> loadOptions() async {
    if (_disposed) return;
    if (optionsLoading) return;
    optionsLoading = true;
    optionsError = '';
    _notify();
    try {
      options = await repository.fetchOptions();
    } catch (e) {
      if (!_disposed) optionsError = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        optionsLoading = false;
        _notify();
      }
    }
  }

  Future<CetakanDetail> fetchDetail(CetakanWarnaMaterialRow row) =>
      repository.fetchDetail(
        idCetakan: row.idCetakan,
        idWarna: row.idWarna,
        idMaterial: row.idMaterial,
      );

  /// Simpan (create bila [edit] null, update bila ada) lalu reload list.
  /// Mengembalikan label untuk notifikasi.
  Future<String> save({
    CetakanWarnaMaterialRow? edit,
    required int idCetakan,
    required int idWarna,
    required int idMaterial,
    required List<int> barangJadi,
    required List<int> furnitureWip,
    required String label,
  }) async {
    if (edit == null) {
      await repository.create(
        idCetakan: idCetakan,
        idWarna: idWarna,
        idMaterial: idMaterial,
        barangJadi: barangJadi,
        furnitureWip: furnitureWip,
      );
    } else {
      await repository.update(
        oldKey: edit,
        idCetakan: idCetakan,
        idWarna: idWarna,
        idMaterial: idMaterial,
        barangJadi: barangJadi,
        furnitureWip: furnitureWip,
      );
    }
    if (_disposed) return label;
    await load();
    return label;
  }

  Future<void> delete(CetakanWarnaMaterialRow row) async {
    await repository.delete(
      idCetakan: row.idCetakan,
      idWarna: row.idWarna,
      idMaterial: row.idMaterial,
    );
    if (_disposed) return;
    await load();
  }

  /// Tambah master Cetakan baru (IdBJ dikosongkan) lalu refresh opsi.
  Future<LookupOption> addCetakan(String nama) async {
    final created = await repository.createCetakan(nama);
    if (_disposed) return created;
    await loadOptions();
    return created;
  }

  /// Tambah master Warna baru lalu refresh opsi.
  Future<LookupOption> addWarna(String warna) async {
    final created = await repository.createWarna(warna);
    if (_disposed) return created;
    await loadOptions();
    return created;
  }
}
