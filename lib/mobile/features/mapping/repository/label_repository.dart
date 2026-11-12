// lib/features/label/repository/label_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../constants/api_constants.dart';
import '../../../utils/token_storage.dart';
import '../model/label_page_response.dart';

class LabelRepository {
  Future<LabelPageResponse> fetchLabels({
    required int page,
    int limit = 50,
    String? kategori,
    String? idLokasi,
    String? blok,
  }) async {
    final token = await TokenStorage.getToken();

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
      if (idLokasi != null && idLokasi.isNotEmpty) 'idlokasi': idLokasi,
      if (blok != null && blok.isNotEmpty) 'blok': blok,
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}/api/label/all')
        .replace(queryParameters: params);
    debugPrint('[HTTP] GET $uri');

    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });
    debugPrint('[HTTP] GET $uri -> ${res.statusCode}');

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      return LabelPageResponse.fromJson(body);
    }

    throw Exception(
        'Gagal mengambil label (status: ${res.statusCode}) • ${res.body}');
  }
}
