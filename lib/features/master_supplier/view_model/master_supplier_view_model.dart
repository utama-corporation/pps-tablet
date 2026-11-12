import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/supplier_item.dart';
import '../repository/master_supplier_repository.dart';

class MasterSupplierViewModel extends ChangeNotifier {
  MasterSupplierViewModel(this.repository);

  final MasterSupplierRepository repository;

  List<SupplierItem> _items = [];
  String query = '';
  bool loading = false;
  String error = '';

  List<SupplierItem> get items {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where(
        (s) =>
            '${s.idSupplier} ${s.namaSupplier} ${s.initial} ${s.noTlp}'
                .toLowerCase()
                .contains(q),
      ),
    );
  }

  int get totalCount => _items.length;

  void setQuery(String value) {
    if (query == value.trim()) return;
    query = value.trim();
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = '';
    notifyListeners();
    try {
      _items = await repository.fetchAll(status: 'all');
      _items = List.of(_items)
        ..sort(
          (a, b) => a.namaSupplier.toLowerCase().compareTo(
            b.namaSupplier.toLowerCase(),
          ),
        );
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> save({
    int? id,
    required String namaSupplier,
    required String initial,
    required String noTlp,
    required bool enable,
  }) async {
    final name = namaSupplier.trim();
    if (id == null) {
      await repository.create(
        namaSupplier: name,
        initial: initial.trim(),
        noTlp: noTlp.trim(),
        enable: enable,
      );
    } else {
      await repository.update(
        id: id,
        namaSupplier: name,
        initial: initial.trim(),
        noTlp: noTlp.trim(),
        enable: enable,
      );
    }
    await load();
    return name;
  }

  Future<void> delete(int id) async {
    await repository.delete(id);
    await load();
  }
}
