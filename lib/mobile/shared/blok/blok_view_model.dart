import 'package:flutter/material.dart';
import 'blok_model.dart';
import 'blok_repository.dart';

class BlokViewModel extends ChangeNotifier {
  final BlokRepository repository;

  BlokViewModel({required this.repository});

  List<Blok> blokList = [];
  bool isLoading = false;
  String errorMessage = '';

  Future<void> fetchBlokList() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      blokList = await repository.fetchBlokList();

      // 🔍 LOG hasil fetch
      debugPrint("BlokViewModel LOG → fetched ${blokList.length} blok");
      for (var blok in blokList) {
        debugPrint("  - Blok: ${blok.blok}, IdWarehouse: ${blok.idWarehouse}");
      }

    } catch (e, stack) {
      errorMessage = e.toString();
      blokList = [];
      debugPrint("BlokViewModel ERROR → $errorMessage");
      debugPrint("StackTrace: $stack");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
