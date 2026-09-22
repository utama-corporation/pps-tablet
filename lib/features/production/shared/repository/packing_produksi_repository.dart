import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../models/packing_stok_item.dart';
import '../models/packing_stok_label.dart';

class PackingProduksiRepository {
  static const _timeout = Duration(seconds: 25);

  Future<List<PackingStokItem>> fetchStok({String type = 'ENAMEL'}) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(ApiConstants.packingStok(type));

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
      throw Exception('Timeout mengambil data stok packing');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data stok packing (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => PackingStokItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PackingStokLabel>> fetchLabel(
    int idPacking, {
    String type = 'ENAMEL',
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(ApiConstants.packingStokLabel(idPacking, type));

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
      throw Exception('Timeout mengambil data label packing');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data label packing (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => PackingStokLabel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}