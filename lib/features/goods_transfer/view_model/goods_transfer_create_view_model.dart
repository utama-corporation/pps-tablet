import 'package:flutter/foundation.dart';

import 'package:pps_tablet/core/network/api_client.dart';

import '../model/goods_transfer_scanned_label.dart';
import '../repository/goods_transfer_repository.dart';

class GoodsTransferCreateViewModel extends ChangeNotifier {
  final GoodsTransferRepository repository;

  GoodsTransferCreateViewModel({required this.repository});

  int? idWarehouseAsal;
  int? idWarehouseTujuan;
  String? catatan;

  final List<GoodsTransferScannedLabel> scannedLabels = [];

  bool isSubmitting = false;
  String? lookupError;
  String error = '';
  String? createdNoTransfer;

  void setWarehouseAsal(int? idWarehouse) {
    if (idWarehouse == idWarehouseAsal) return;
    idWarehouseAsal = idWarehouse;
    // Label yang sudah discan divalidasi terhadap warehouse asal sebelumnya —
    // kalau warehouse asal berubah, validasinya sudah tidak berlaku lagi.
    scannedLabels.clear();
    notifyListeners();
  }

  void setWarehouseTujuan(int? idWarehouse) {
    idWarehouseTujuan = idWarehouse;
    notifyListeners();
  }

  void setCatatan(String? value) {
    catatan = value;
  }

  /// Dipanggil dari [ScanLabelDialog.onLookup]. Return null kalau sukses
  /// (dialog otomatis ditutup), atau pesan error untuk ditampilkan inline.
  Future<String?> lookupLabel(String code) async {
    if (idWarehouseAsal == null) {
      lookupError = 'Pilih warehouse asal terlebih dahulu';
      notifyListeners();
      return lookupError;
    }
    if (scannedLabels.any((l) => l.labelCode == code)) {
      lookupError = 'Label $code sudah ditambahkan';
      notifyListeners();
      return lookupError;
    }

    try {
      final info = await repository.inspectLabel(
        labelCode: code,
        idWarehouseAsal: idWarehouseAsal!,
      );
      scannedLabels.add(info);
      lookupError = null;
      return null;
    } on ApiException catch (e) {
      lookupError = e.friendlyMessage;
      return lookupError;
    } catch (e) {
      lookupError = e.toString();
      return lookupError;
    } finally {
      notifyListeners();
    }
  }

  void removeLabel(String labelCode) {
    scannedLabels.removeWhere((l) => l.labelCode == labelCode);
    notifyListeners();
  }

  Future<bool> submit() async {
    error = '';
    if (idWarehouseAsal == null || idWarehouseTujuan == null) {
      error = 'Warehouse asal dan tujuan wajib dipilih';
      notifyListeners();
      return false;
    }
    if (idWarehouseAsal == idWarehouseTujuan) {
      error = 'Warehouse asal dan tujuan tidak boleh sama';
      notifyListeners();
      return false;
    }
    if (scannedLabels.isEmpty) {
      error = 'Scan minimal 1 label untuk ditransfer';
      notifyListeners();
      return false;
    }

    isSubmitting = true;
    notifyListeners();

    try {
      createdNoTransfer = await repository.createTransfer(
        idWarehouseAsal: idWarehouseAsal!,
        idWarehouseTujuan: idWarehouseTujuan!,
        labelCodes: scannedLabels.map((l) => l.labelCode).toList(),
        catatan: catatan,
      );
      return true;
    } on ApiException catch (e) {
      error = e.friendlyMessage;
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
