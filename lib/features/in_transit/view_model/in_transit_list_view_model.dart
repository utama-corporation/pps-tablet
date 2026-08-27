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

  Future<void> reload() async {
    await load();
    if (selectedNoTransfer != null) await selectTransfer(selectedNoTransfer!);
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
