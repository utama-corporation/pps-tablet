import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_profile_model.dart';
import '../../../constants/api_constants.dart';


class UserProfileViewModel extends ChangeNotifier {
  String _errorMessage = '';
  String _successMessage = '';
  bool _isLoading = false;

  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  bool get isLoading => _isLoading;

  // Fungsi untuk mengambil token dari SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token'); // Mengambil token yang disimpan
  }

  // Fungsi untuk mengganti password
  Future<void> changePassword({
    required UserProfileModel userProfile,
  }) async {
    _isLoading = true;
    notifyListeners();

    String? token = await _getToken(); // Ambil token dari SharedPreferences

    if (token == null) {
      _errorMessage = 'No token found';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final uri = Uri.parse(ApiConstants.changePassword);
      debugPrint('[HTTP] POST $uri');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token', // Menambahkan token di header Authorization
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'oldPassword': userProfile.oldPassword,
          'newPassword': userProfile.newPassword,
          'confirmPassword': userProfile.confirmPassword,
        }),
      );
      debugPrint('[HTTP] POST $uri -> ${response.statusCode}');

      if (response.statusCode == 200) {
        _successMessage = 'Password berhasil diganti';
        _errorMessage = ''; // Kosongkan pesan error jika berhasil
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized: Token is invalid or expired';
      } else {
        final responseBody = json.decode(response.body);
        _errorMessage = responseBody['message'] ?? 'Terjadi kesalahan saat mengganti password';
      }
    } catch (error) {
      _errorMessage = 'Failed to connect to the server';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
