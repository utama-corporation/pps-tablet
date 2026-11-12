import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';
import '../../utils/token_storage.dart';
import 'lokasi_model.dart';

class LokasiRepository {
  /// [idWarehouse] bisa:
  ///  - null / kosong  → semua lokasi aktif
  ///  - "5"            → hanya warehouse 5
  ///  - "1,2,3,5,4"    → warehouse 1/2/3/5/4
  Future<List<Lokasi>> fetchLokasiList({String? idWarehouse}) async {
    final token = await TokenStorage.getToken();

    // base URL tanpa query dulu
    final baseUri = Uri.parse('${ApiConstants.baseUrl}/api/mst-lokasi');

    // kalau ada filter idWarehouse, tambahkan jadi query param
    final url = (idWarehouse != null && idWarehouse.trim().isNotEmpty)
        ? baseUri.replace(queryParameters: {
      'idWarehouse': idWarehouse.trim(),
    })
        : baseUri;
    debugPrint('[HTTP] GET $url');

    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });
    debugPrint('[HTTP] GET $url -> ${res.statusCode}');

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List)
            .map((e) => Lokasi.fromJson(e))
            .toList();
      }
      throw Exception(body['message'] ?? 'Format data tidak sesuai');
    }
    throw Exception('Gagal mengambil lokasi (status: ${res.statusCode})');
  }
}
