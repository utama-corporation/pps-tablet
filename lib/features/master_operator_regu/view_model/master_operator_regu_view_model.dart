import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../operator/model/operator_model.dart';
import '../../regu/model/regu_model.dart';
import '../repository/master_operator_regu_repository.dart';

class MasterOperatorReguViewModel extends ChangeNotifier {
  MasterOperatorReguViewModel(this.repository);

  final MasterOperatorReguRepository repository;

  // ── Operator tab ─────────────────────────────────────────
  List<MstOperator> _operators = [];
  String operatorQuery = '';
  bool operatorLoading = false;
  String operatorError = '';

  // Opsi dropdown Bagian pada form operator
  List<OperatorBagian>? bagianOptions;
  bool bagianLoading = false;
  String bagianError = '';

  List<MstOperator> get operators {
    final q = operatorQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_operators);
    return List.unmodifiable(
      _operators.where(
        (o) =>
            '${o.idOperator} ${o.namaOperator} ${o.namaBagianMesin}'
                .toLowerCase()
                .contains(q),
      ),
    );
  }

  int get operatorTotal => _operators.length;

  /// Semua operator tanpa filter pencarian — dipakai dropdown Kepala Regu.
  List<MstOperator> get allOperators => List.unmodifiable(_operators);

  // ── Regu tab ─────────────────────────────────────────────
  List<MstRegu> _regus = [];
  String reguQuery = '';
  bool reguLoading = false;
  String reguError = '';

  List<MstRegu> get regus {
    final q = reguQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_regus);
    return List.unmodifiable(
      _regus.where(
        (r) =>
            '${r.idRegu} ${r.namaRegu} ${r.idBagian} ${r.namaBagianMesin} ${r.namaKepalaRegu ?? ''} ${r.kepalaRegu ?? ''}'
                .toLowerCase()
                .contains(q),
      ),
    );
  }

  int get reguTotal => _regus.length;

  void setOperatorQuery(String value) {
    if (operatorQuery == value.trim()) return;
    operatorQuery = value.trim();
    notifyListeners();
  }

  void setReguQuery(String value) {
    if (reguQuery == value.trim()) return;
    reguQuery = value.trim();
    notifyListeners();
  }

  Future<void> load() async {
    await Future.wait([loadOperators(), loadRegu(), loadBagianOptions()]);
  }

  /// Opsi dropdown Bagian (GET /api/mst-operator/bagian) — dimuat sekali.
  Future<void> loadBagianOptions({bool force = false}) async {
    if (bagianLoading) return;
    if (bagianOptions != null && !force) return;
    bagianLoading = true;
    bagianError = '';
    notifyListeners();
    try {
      bagianOptions = await repository.fetchBagianOptions();
    } catch (e) {
      bagianError = apiErrorMessage(e);
    } finally {
      bagianLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOperators() async {
    operatorLoading = true;
    operatorError = '';
    notifyListeners();
    try {
      _operators = await repository.fetchOperators(includeDisabled: true);
      _operators = List.of(_operators)
        ..sort(
          (a, b) => a.namaOperator.toLowerCase().compareTo(
            b.namaOperator.toLowerCase(),
          ),
        );
    } catch (e) {
      operatorError = apiErrorMessage(e);
    } finally {
      operatorLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRegu() async {
    reguLoading = true;
    reguError = '';
    notifyListeners();
    try {
      _regus = await repository.fetchRegu();
      _regus = List.of(_regus)
        ..sort(
          (a, b) => a.namaRegu.toLowerCase().compareTo(
            b.namaRegu.toLowerCase(),
          ),
        );
    } catch (e) {
      reguError = apiErrorMessage(e);
    } finally {
      reguLoading = false;
      notifyListeners();
    }
  }

  Future<String> saveOperator({
    int? idOperator,
    required String namaOperator,
    required int idBagian,
    required bool enable,
  }) async {
    final name = namaOperator.trim();
    if (idOperator == null) {
      await repository.createOperator(
        namaOperator: name,
        idBagian: idBagian,
        enable: enable,
      );
    } else {
      await repository.updateOperator(
        idOperator: idOperator,
        namaOperator: name,
        idBagian: idBagian,
        enable: enable,
      );
    }
    await loadOperators();
    return name;
  }

  Future<void> deleteOperator(int idOperator) async {
    await repository.deleteOperator(idOperator);
    await loadOperators();
  }

  Future<ReguDetail?> fetchReguDetail(int idRegu) =>
      repository.fetchReguDetail(idRegu);

  Future<String> saveRegu({
    int? idRegu,
    required String namaRegu,
    required int idBagian,
    required List<int> operatorIds,
  }) async {
    final name = namaRegu.trim();
    if (idRegu == null) {
      await repository.createRegu(
        namaRegu: name,
        idBagian: idBagian,
        operatorIds: operatorIds,
      );
    } else {
      await repository.updateRegu(
        idRegu: idRegu,
        namaRegu: name,
        idBagian: idBagian,
        operatorIds: operatorIds,
      );
    }
    await loadRegu();
    return name;
  }

  Future<void> deleteRegu(int idRegu) async {
    await repository.deleteRegu(idRegu);
    await loadRegu();
  }
}
