import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';
import '../repository/master_mesin_repository.dart';

class MasterMesinViewModel extends ChangeNotifier {
  MasterMesinViewModel(this.repository);

  final MasterMesinRepository repository;

  List<MstMesin> _items = [];
  String query = '';
  int? bagianFilter; // null = semua bagian
  bool loading = false;
  String error = '';

  List<MstMesin> get items {
    final q = query.trim().toLowerCase();
    return List.unmodifiable(
      _items.where((m) {
        if (bagianFilter != null && m.idBagianMesin != bagianFilter) {
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

  void setQuery(String value) {
    if (query == value.trim()) return;
    query = value.trim();
    notifyListeners();
  }

  void setBagianFilter(int? value) {
    if (bagianFilter == value) return;
    bagianFilter = value;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = '';
    notifyListeners();
    try {
      _items = await repository.fetchAll(includeDisabled: true);
    } catch (e) {
      error = apiErrorMessage(e);
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
  }) async {
    final name = namaMesin.trim();
    if (idMesin == null) {
      await repository.create(
        namaMesin: name,
        idBagianMesin: idBagianMesin,
        kapasitas: kapasitas,
        idUom: idUom,
        enable: enable,
      );
    } else {
      await repository.update(
        idMesin: idMesin,
        namaMesin: name,
        idBagianMesin: idBagianMesin,
        kapasitas: kapasitas,
        idUom: idUom,
        enable: enable,
      );
    }
    await load();
    return name;
  }

  Future<void> delete(int idMesin) async {
    await repository.delete(idMesin);
    await load();
  }
}
