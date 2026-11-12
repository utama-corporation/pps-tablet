import 'package:flutter/material.dart';
import '../../../constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../model/bj_jual_input_model.dart';

class BjJualDetailViewModel extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  BjJualInputData? _inputData;
  bool _isLoading = false;
  String _errorMessage = '';

  BjJualInputData? get inputData => _inputData;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> deleteInput(
    String noBJJual,
    String noLabel,
    String tableName,
  ) async {
    final Map<String, dynamic> body;
    if (tableName == 'BarangJadi') {
      body = {
        'barangJadi': [
          {'noBJ': noLabel}
        ],
      };
    } else if (tableName == 'BarangJadiPartial') {
      body = {
        'barangJadiPartial': [
          {'noBJPartial': noLabel}
        ],
      };
    } else {
      body = {
        'furnitureWip': [
          {'noFurnitureWIP': noLabel}
        ],
      };
    }
    await _apiClient.deleteJson(
      ApiConstants.bjJualInputs(noBJJual),
      body: body,
      useAuth: true,
    );
  }

  Future<void> fetchInputs(String noBJJual) async {
    _isLoading = true;
    _errorMessage = '';
    _inputData = null;
    notifyListeners();

    try {
      final url = ApiConstants.bjJualInputs(noBJJual);
      final response = await _apiClient.getJson(url, useAuth: true);

      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        _inputData = BjJualInputData.fromJson(data);
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
