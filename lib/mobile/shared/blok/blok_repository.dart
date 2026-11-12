import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';
import '../../utils/token_storage.dart';
import 'blok_model.dart';

class BlokRepository {
  Future<List<Blok>> fetchBlokList() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('${ApiConstants.baseUrl}/api/blok');
    debugPrint('[HTTP] GET $url');

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });
    debugPrint('[HTTP] GET $url -> ${response.statusCode}');

    if (response.statusCode == 200) {
      final body = json.decode(response.body);

      if (body['success'] == true && body['data'] is List) {
        return (body['data'] as List).map((e) => Blok.fromJson(e)).toList();
      } else {
        throw Exception(body['message'] ?? 'Format data tidak sesuai');
      }
    }

    throw Exception('Gagal mengambil blok (status: ${response.statusCode})');
  }
}
