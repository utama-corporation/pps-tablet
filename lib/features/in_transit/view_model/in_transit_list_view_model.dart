import 'package:flutter/foundation.dart';

import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_header_model.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_item_model.dart';

import '../repository/in_transit_repository.dart';

class InTransitListViewModel extends ChangeNotifier {
  final InTransitRepository repository;

  InTransitListViewModel({required this.repository});

  List<GoodsTransferHeader> items = [];
  bool isLoading = false;
  String error = '';

  String? selectedNoTransfer;
  GoodsTransferDetail? selectedDetail;
  bool isLoadingDetail = false;
  String detailError = '';

  /// Menu In Transit khusus menampilkan transfer yang sudah ditandai "Kirim"
  /// (Status = SHIPPED). Transfer yang sudah diterima penuh otomatis pindah
  /// ke Status RECEIVED dan hilang dari daftar ini.
  static const _statusFilter = 'SHIPPED';

  Future<void> load() async {
    isLoading = true;
    error = '';
    notifyListeners();

    try {
      items = await repository.fetchAll(status: _statusFilter);
    } catch (e) {
      error = e.toString();
      items = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    await load();
    final sel = selectedNoTransfer;
    if (sel == null) return;
    // Kalau transfer terpilih sudah tidak SHIPPED lagi (mis. baru saja
    // diterima penuh), lepas seleksinya — kartunya sudah hilang dari daftar.
    if (items.any((h) => h.noTransfer == sel)) {
      await selectTransfer(sel);
    } else {
      selectedNoTransfer = null;
      selectedDetail = null;
      detailError = '';
      notifyListeners();
    }
  }

  Future<void> selectTransfer(String noTransfer) async {
    selectedNoTransfer = noTransfer;
    isLoadingDetail = true;
    detailError = '';
    notifyListeners();

    try {
      selectedDetail = await repository.fetchDetail(noTransfer);
    } catch (e) {
      detailError = e.toString();
      selectedDetail = null;
    } finally {
      isLoadingDetail = false;
      notifyListeners();
    }
  }
}
