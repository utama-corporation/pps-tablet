// lib/features/label/repository/label_mapping_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../../../utils/token_storage.dart';

class LabelUpdateResult {
  final bool success;
  final String message;

  LabelUpdateResult({required this.success, required this.message});

  factory LabelUpdateResult.fromJson(Map<String, dynamic> json) {
    return LabelUpdateResult(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class LabelMappingRepository {
  Future<LabelUpdateResult> updateLabelLocation({
    required String labelCode,
    required String idLokasi,
    required String blok
  }) async {
    final token = await TokenStorage.getToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/label/update-lokasi');
    debugPrint('[HTTP] POST $uri');

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'labelCode': labelCode,
        'idLokasi': idLokasi,
        'blok': blok,
      }),
    );
    debugPrint('[HTTP] POST $uri -> ${res.statusCode}');

    // Backend kamu bisa return 200 (sukses) atau 404 (label tidak ditemukan)
    if (res.statusCode == 200 || res.statusCode == 404) {
      final body = json.decode(res.body);
      return LabelUpdateResult.fromJson(body);
    }

    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
