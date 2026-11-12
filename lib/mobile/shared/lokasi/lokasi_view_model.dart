import 'package:flutter/material.dart';
import 'lokasi_model.dart';
import 'lokasi_repository.dart';

class LokasiViewModel extends ChangeNotifier {
  final LokasiRepository repository;
  LokasiViewModel({required this.repository});

  List<Lokasi> lokasiList = [];
  bool isLoading = false;
  String errorMessage = '';

  String? _lastIdWarehouseFilter; // ⬅️ opsional, kalau mau di-remember

  Future<void> fetchLokasiList({String? idWarehouse}) async {
    isLoading = true;
    errorMessage = '';
    _lastIdWarehouseFilter = idWarehouse;
    notifyListeners();

    try {
      lokasiList = await repository.fetchLokasiList(
        idWarehouse: idWarehouse,
      );
    } catch (e, st) {
      errorMessage = e.toString();
      lokasiList = [];
      debugPrint('LokasiViewModel ERROR → $errorMessage');
      debugPrint('StackTrace: $st');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// (opsional) buat refresh pakai filter terakhir
  Future<void> refresh() async {
    return fetchLokasiList(idWarehouse: _lastIdWarehouseFilter);
  }
}
