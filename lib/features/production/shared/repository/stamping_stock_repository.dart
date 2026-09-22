import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../models/inject_stok_item.dart';
import '../models/inject_stok_label.dart';

class StampingStokRepository {
  static const _timeout = Duration(seconds: 25);

  Future<List<InjectStokItem>> fetchStok() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(ApiConstants.wipStampingStok);

    late http.Response res;
    try {
      res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data stok stamping');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data stok stamping (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => InjectStokItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<InjectStokLabel>> fetchLabel(int idStamping) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(ApiConstants.wipStampingStokLabel(idStamping));

    late http.Response res;
    try {
      res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data label stamping');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data label stamping (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => InjectStokLabel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}