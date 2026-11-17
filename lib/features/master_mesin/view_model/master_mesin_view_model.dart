import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';
import '../model/uom_option.dart';
import '../repository/master_mesin_repository.dart';

class MasterMesinViewModel extends ChangeNotifier {
  MasterMesinViewModel(this.repository);

  final MasterMesinRepository repository;

  List<MstMesin> _items = [];
  String query = '';
  int bagianFilter = 2; // default Broker
  bool loading = false;
  String error = '';

  List<MstMesin> get items {
    final q = query.trim().toLowerCase();
    return List.unmodifiable(
      _items.where((m) {
        if (m.idBagianMesin != bagianFilter) {
          return false;
        }
        if (q.isEmpty) return true;
        final bagian = m.bagian.isNotEmpty
            ? m.bagian
            : bagianMesinLabel(m.idBagianMesin);
        return '${m.idMesin} ${m.namaMesin} $bagian'
            .toLowerCase()
            .contains(q);
      }),
    );
  }

  int get totalCount => _items.length;

  List<UomOption> _uomOptions = const [];
  bool uomLoading = false;
  String uomError = '';

  List<UomOption> get uomOptions => List.unmodifiable(_uomOptions);

  /// Nama UOM untuk ditampilkan; fallback ke id mentah bila belum termuat.
  String uomLabel(int? id) {
    if (id == null) return '—';
    for (final o in _uomOptions) {
      if (o.idUom == id) return o.namaUom;
    }
    return '$id';
  }

  Future<void> loadUom() async {
    uomLoading = true;
    uomError = '';
    notifyListeners();
    try {
      _uomOptions = await repository.fetchUomOptions();
    } catch (e) {
      uomError = apiErrorMessage(e);
      _uomOptions = const [];
    } finally {
      uomLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    if (query == value.trim()) return;
    query = value.trim();
    notifyListeners();
  }

  Future<void> setBagianFilter(int value) async {
    if (bagianFilter == value) return;
    bagianFilter = value;
    await load();
  }

  Future<void> load() async {
    loading = true;
    error = '';
    notifyListeners();
    try {
      _items = await repository.fetchByBagian(bagianFilter);
    } catch (e) {
      error = apiErrorMessage(e);
      _items = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> save({
    int? idMesin,
    required String namaMesin,
    required int idBagianMesin,
    num? kapasitas,
    int? idUom,
    required bool enable,
    num? shortWeightPs,
    num? klemLebar,
    num? klemTinggi,
  }) async {
    final name = namaMesin.trim();
    if (idMesin == null) {
      await repository.create(
        namaMesin: name,
        idBagianMesin: idBagianMesin,
        kapasitas: kapasitas,
        idUom: idUom,
        enable: enable,
        shortWeightPs: shortWeightPs,
        klemLebar: klemLebar,
        klemTinggi: klemTinggi,
      );
    } else {
      await repository.update(
        idMesin: idMesin,
        namaMesin: name,
        idBagianMesin: idBagianMesin,
        kapasitas: kapasitas,
        idUom: idUom,
        enable: enable,
        shortWeightPs: shortWeightPs,
        klemLebar: klemLebar,
        klemTinggi: klemTinggi,
      );
    }
    // Baris bisa pindah bagian (dropdown Bagian saat edit) — ikuti
    // bagian baris supaya tetap terlihat setelah simpan.
    bagianFilter = idBagianMesin;
    await load();
    return name;
  }

  /// Nonaktifkan mesin (Enable = 0), bukan hapus permanen.
  Future<void> delete(int idMesin, {required int idBagianMesin}) async {
    await repository.delete(idMesin, idBagianMesin: idBagianMesin);
    await load();
  }
}
