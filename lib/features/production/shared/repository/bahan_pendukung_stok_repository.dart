import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../models/bahan_pendukung_stok_item.dart';
import '../models/bahan_pendukung_stok_label.dart';

class BahanPendukungStokRepository {
  static const _timeout = Duration(seconds: 25);

  Future<List<BahanPendukungStokItem>> fetchStok() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(ApiConstants.mstBahanPendukungStok);

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
      throw Exception('Timeout mengambil data stok bahan pendukung');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data stok bahan pendukung (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => BahanPendukungStokItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BahanPendukungStokLabel>> fetchLabel(int idCabinetMaterial) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(
      ApiConstants.mstBahanPendukungStokLabel(idCabinetMaterial),
    );

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
      throw Exception('Timeout mengambil data label bahan pendukung');
    }

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data label bahan pendukung (${res.statusCode})',
      );
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => BahanPendukungStokLabel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}