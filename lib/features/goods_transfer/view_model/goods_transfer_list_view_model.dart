import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/goods_transfer_header_model.dart';
import '../model/goods_transfer_item_model.dart';
import '../repository/goods_transfer_repository.dart';

/// Rekomendasi partial dari backend saat pcs label melebihi sisa kebutuhan
/// baris — belum ada data yang diubah, murni informasi untuk konfirmasi.
class GoodsTransferPartialSuggestion {
  final String labelCode;
  final int availablePcs;
  final int pcsNeeded;
  final String message;

  const GoodsTransferPartialSuggestion({
    required this.labelCode,
    required this.availablePcs,
    required this.pcsNeeded,
    required this.message,
  });

  factory GoodsTransferPartialSuggestion.fromJson(Map<String, dynamic> j) {
    return GoodsTransferPartialSuggestion(
      labelCode: (j['noLabel'] ?? j['labelCode'] ?? '').toString(),
      availablePcs: (j['availablePcs'] as num?)?.toInt() ?? 0,
      pcsNeeded: (j['pcsNeeded'] as num?)?.toInt() ?? 0,
      message: (j['message'] ?? '').toString(),
    );
  }
}

class GoodsTransferScanResult {
  final bool success;
  final GoodsTransferPartialSuggestion? suggestion;
  final String? error;

  const GoodsTransferScanResult.success()
    : success = true,
      suggestion = null,
      error = null;

  const GoodsTransferScanResult.needsConfirmation(this.suggestion)
    : success = false,
      error = null;

  const GoodsTransferScanResult.error(this.error)
    : success = false,
      suggestion = null;

  bool get needsConfirmation => suggestion != null;
}

class GoodsTransferListViewModel extends ChangeNotifier {
  final GoodsTransferRepository repository;

  GoodsTransferListViewModel({required this.repository});

  List<GoodsTransferHeader> items = [];
  bool isLoading = false;
  String error = '';

  String? selectedNoTransfer;
  GoodsTransferDetail? selectedDetail;
  bool isLoadingDetail = false;
  String detailError = '';

  bool get selectedAllComplete => selectedDetail?.allLinesComplete ?? false;

  Future<void> load({String? status}) async {
    isLoading = true;
    error = '';
    notifyListeners();

    try {
      items = await repository.fetchAll(status: status);
    } catch (e) {
      error = apiErrorMessage(e);
      items = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<void> selectTransfer(String noTransfer) async {
    selectedNoTransfer = noTransfer;
    isLoadingDetail = true;
    detailError = '';
    notifyListeners();

    try {
      selectedDetail = await repository.fetchDetail(noTransfer);
    } catch (e) {
      detailError = apiErrorMessage(e);
      selectedDetail = null;
    } finally {
      isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> _refreshSelected() async {
    if (selectedNoTransfer != null) {
      await selectTransfer(selectedNoTransfer!);
    }
  }

  void clearSelection() {
    selectedNoTransfer = null;
    selectedDetail = null;
    detailError = '';
    notifyListeners();
  }

  /// Percobaan scan pertama. Kalau pcs label melebihi sisa kebutuhan, backend
  /// mengembalikan rekomendasi partial (tanpa mengubah data).
  Future<GoodsTransferScanResult> attemptScan(String labelCode) async {
    final no = selectedNoTransfer;
    if (no == null) {
      return const GoodsTransferScanResult.error('Belum ada transfer dipilih');
    }
    try {
      final body = await repository.scan(no, labelCode);
      if (body['needsConfirmation'] == true) {
        final data = body['data'] as Map<String, dynamic>? ?? {};
        return GoodsTransferScanResult.needsConfirmation(
          GoodsTransferPartialSuggestion.fromJson(data),
        );
      }
      await _refreshSelected();
      return const GoodsTransferScanResult.success();
    } catch (e) {
      return GoodsTransferScanResult.error(apiErrorMessage(e));
    }
  }

  /// Setelah user menyetujui rekomendasi partial — catat sisa kebutuhan saja.
  Future<GoodsTransferScanResult> confirmPartialScan(String labelCode) async {
    final no = selectedNoTransfer;
    if (no == null) {
      return const GoodsTransferScanResult.error('Belum ada transfer dipilih');
    }
    try {
      await repository.scan(no, labelCode, confirmPartial: true);
      await _refreshSelected();
      return const GoodsTransferScanResult.success();
    } catch (e) {
      return GoodsTransferScanResult.error(apiErrorMessage(e));
    }
  }

  Future<String?> undoScan(int idScan) async {
    try {
      await repository.undoScan(idScan);
      await _refreshSelected();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Tandai transfer terpilih "Kirim". Return null kalau sukses, atau pesan
  /// error. Menyegarkan list + detail supaya status ikut ter-update.
  Future<String?> markKirim() async {
    final no = selectedNoTransfer;
    if (no == null) return 'Belum ada transfer dipilih';
    try {
      await repository.markKirim(no);
      await load();
      await _refreshSelected();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }
}
