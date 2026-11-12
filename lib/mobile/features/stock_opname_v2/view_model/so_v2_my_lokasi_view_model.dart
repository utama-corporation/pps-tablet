import 'package:flutter/foundation.dart';

import '../../../core/network/api_errors.dart';
import '../model/so_v2_models.dart';
import '../repository/so_v2_repository.dart';

class SoV2MyLokasiViewModel extends ChangeNotifier {
  SoV2MyLokasiViewModel({SoV2Repository? repository})
    : repository = repository ?? SoV2Repository();

  final SoV2Repository repository;

  List<SoV2MyLokasi> items = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      items = await repository.fetchMyLokasi();
    } catch (e) {
      error = _message(e);
      items = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static String _message(Object error) {
    if (error is ApiFailure) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
