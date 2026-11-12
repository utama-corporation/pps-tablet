import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/stock_opname_model.dart';
import '../../../constants/api_constants.dart';


class StockOpnameViewModel extends ChangeNotifier {
  List<StockOpname> _stockOpnameList = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<StockOpname> get stockOpnameList => _stockOpnameList;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Fungsi untuk mengambil token dari SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token'); // Mengambil token yang disimpan
  }

  // Fungsi untuk mengambil data stock opname
  Future<void> fetchStockOpname() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Ambil token dari SharedPreferences
      String? token = await _getToken();

      if (token == null) {
        _errorMessage = 'No token found';
        _stockOpnameList = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final uri = Uri.parse(ApiConstants.listNoSO);
      debugPrint('[HTTP] GET $uri');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token', // Menambahkan token di header Authorization
        },
      );
      debugPrint('[HTTP] GET $uri -> ${response.statusCode}');

      if (response.statusCode == 200) {
        // API lama: langsung List
        // API baru: object { data, total, page, limit }
        final decoded = json.decode(response.body);
        final List<dynamic> data;

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          data = decoded['data'] as List<dynamic>;
        } else {
          throw Exception('Format response stock opname tidak dikenali');
        }

        _stockOpnameList =
            data.map((item) => StockOpname.fromJson(item as Map<String, dynamic>)).toList();
        _errorMessage = ''; // Kosongkan pesan error jika sukses
      } else if (response.statusCode == 401) {
        // Jika token tidak valid atau kadaluarsa
        _errorMessage = 'Unauthorized: Token is invalid or expired';
        _stockOpnameList = [];
      } else {
        // Jika status code bukan 200 atau 401, coba ambil pesan error dari API
        final responseBody = json.decode(response.body);
        _errorMessage = responseBody['message'] ?? 'Tidak ada Jadwal Stock Opname saat ini';
        _stockOpnameList = [];
      }
    } catch (error) {
      // Menangani parsing/format response maupun koneksi
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      _stockOpnameList = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
