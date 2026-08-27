import 'package:flutter/foundation.dart';

import '../model/goods_transfer_header_model.dart';
import '../model/goods_transfer_item_model.dart';
import '../repository/goods_transfer_repository.dart';

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

  Future<void> load({String? status}) async {
    isLoading = true;
    error = '';
    notifyListeners();

    try {
      items = await repository.fetchAll(status: status);
    } catch (e) {
      error = e.toString();
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
      detailError = e.toString();
      selectedDetail = null;
    } finally {
      isLoadingDetail = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    selectedNoTransfer = null;
    selectedDetail = null;
    detailError = '';
    notifyListeners();
  }

  Future<bool> cancelSelected() async {
    if (selectedNoTransfer == null) return false;
    try {
      await repository.cancelTransfer(selectedNoTransfer!);
      await load();
      await selectTransfer(selectedNoTransfer!);
      return true;
    } catch (e) {
      detailError = e.toString();
      notifyListeners();
      return false;
    }
  }
}
