import 'package:flutter/foundation.dart';

import 'package:pps_tablet/core/network/api_client.dart';

import '../model/warehouse_group_model.dart';
import '../repository/warehouse_group_repository.dart';

class WarehouseGroupViewModel extends ChangeNotifier {
  final WarehouseGroupRepository repository;

  WarehouseGroupViewModel({required this.repository});

  List<WarehouseGroup> groups = [];
  List<WarehouseGroupAssignment> warehouses = [];

  bool isLoading = false;
  String error = '';

  /// true selagi ada aksi tulis (create/update/delete/assign) berjalan.
  bool busy = false;

  List<WarehouseGroup> get activeGroups =>
      groups.where((g) => g.aktif).toList(growable: false);

  /// Warehouse aktif dulu (urut nama), warehouse disabled ditaruh paling bawah.
  List<WarehouseGroupAssignment> get warehousesSorted {
    final list = [...warehouses];
    list.sort((a, b) {
      if (a.enable != b.enable) return a.enable ? -1 : 1;
      return a.namaWarehouse.toLowerCase().compareTo(
        b.namaWarehouse.toLowerCase(),
      );
    });
    return list;
  }

  Future<void> load() async {
    isLoading = true;
    error = '';
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.fetchGroups(),
        repository.fetchWarehouses(),
      ]);
      groups = results[0] as List<WarehouseGroup>;
      warehouses = results[1] as List<WarehouseGroupAssignment>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> saveGroup({
    int? id,
    required String namaGroup,
    String? keterangan,
    bool aktif = true,
  }) async {
    busy = true;
    notifyListeners();
    try {
      if (id == null) {
        await repository.createGroup(
          namaGroup: namaGroup,
          keterangan: keterangan,
        );
      } else {
        await repository.updateGroup(
          id: id,
          namaGroup: namaGroup,
          keterangan: keterangan,
          aktif: aktif,
        );
      }
      await _reloadSilently();
      return null;
    } catch (e) {
      return _friendly(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> deleteGroup(int id) async {
    busy = true;
    notifyListeners();
    try {
      await repository.deleteGroup(id);
      await _reloadSilently();
      return null;
    } catch (e) {
      return _friendly(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> assignWarehouse({
    required int idWarehouse,
    required int? idWarehouseGroup,
  }) async {
    busy = true;
    notifyListeners();
    try {
      await repository.setWarehouseGroup(
        idWarehouse: idWarehouse,
        idWarehouseGroup: idWarehouseGroup,
      );
      await _reloadSilently();
      return null;
    } catch (e) {
      return _friendly(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _reloadSilently() async {
    final results = await Future.wait([
      repository.fetchGroups(),
      repository.fetchWarehouses(),
    ]);
    groups = results[0] as List<WarehouseGroup>;
    warehouses = results[1] as List<WarehouseGroupAssignment>;
  }

  String _friendly(Object e) {
    if (e is ApiException) return e.friendlyMessage;
    return e.toString().replaceFirst('Exception: ', '');
  }
}
