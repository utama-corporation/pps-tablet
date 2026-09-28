// lib/features/production/broker/repository/broker_repository.dart
import 'dart:math';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_formatter.dart';

import '../model/broker_header_model.dart';
import '../model/broker_detail_model.dart';
import '../model/broker_partial_model.dart';

class BrokerRepository {
  final ApiClient api;

  BrokerRepository({required this.api});

  /// Ambil daftar broker header dengan pagination & search
  Future<Map<String, dynamic>> fetchHeaders({
    int page = 1,
    int limit = 20,
    String search = '',
    bool includeUsed = false,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search,
      if (includeUsed) 'includeUsed': true,
    };
    final body = await api.getJson('/api/labels/broker', query: query);

    final List<dynamic> data = body['data'] ?? [];
    final items = data
        .map((e) => BrokerHeader.fromJson(e as Map<String, dynamic>))
        .toList();

    final int total = (body['total'] is num)
        ? (body['total'] as num).toInt()
        : (body['meta']?['total'] ?? items.length);

    final int pageOut = body['meta']?['page'] ?? page;
    final int limitOut = body['meta']?['limit'] ?? limit;

    final int totalPages = (limitOut > 0)
        ? ((total + limitOut - 1) ~/ limitOut)
        : 1;

    return {
      'items': items,
      'page': pageOut,
      'limit': limitOut,
      'total': total,
      'totalPages': max(totalPages, 1),
    };
  }

  /// Ambil detail broker berdasarkan NoBroker
  Future<List<BrokerDetail>> fetchDetails(String noBroker) async {
    final body = await api.getJson('/api/labels/broker/$noBroker');

    final List<dynamic> details = body['data']?['details'] ?? [];
    return details
        .map((e) => BrokerDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create broker (header + details)
  Future<Map<String, dynamic>> createBroker({
    required BrokerHeader header,
    required List<BrokerDetail> details,
  }) async {
    final hasNoProduksi =
        (header.noProduksi != null && header.noProduksi!.trim().isNotEmpty);
    final hasNoBongkar =
        (header.noBongkarSusun != null &&
        header.noBongkarSusun!.trim().isNotEmpty);

    if (!hasNoProduksi && !hasNoBongkar) {
      throw ArgumentError(
        'NoProduksi atau NoBongkarSusun harus diisi minimal salah satu.',
      );
    }

    final refKey = hasNoProduksi ? 'NoProduksi' : 'NoBongkarSusun';
    final refVal = hasNoProduksi ? header.noProduksi : header.noBongkarSusun;

    final body = <String, dynamic>{
      'header': {
        'IdJenisPlastik': header.idJenisPlastik,
        'DateCreate': toDbDateString(header.dateCreate),
        'IdWarehouse': 3,
      },
      'details': details
          .map((d) => {'NoSak': d.noSak, 'Berat': d.berat})
          .toList(),
      refKey: refVal,
    };

    return api.postJson('/api/labels/broker', body: body);
  }

  Future<Map<String, dynamic>> updateBroker({
    required String noBroker,
    required BrokerHeader header,
    required List<BrokerDetail> details,
  }) async {
    final hasNoProduksi =
        (header.noProduksi != null && header.noProduksi!.trim().isNotEmpty);
    final hasNoBongkar =
        (header.noBongkarSusun != null &&
        header.noBongkarSusun!.trim().isNotEmpty);

    if (!hasNoProduksi && !hasNoBongkar) {
      throw ArgumentError(
        'NoProduksi atau NoBongkarSusun harus diisi minimal salah satu (EDIT).',
      );
    }

    final refKey = hasNoProduksi ? 'NoProduksi' : 'NoBongkarSusun';
    final refVal = hasNoProduksi ? header.noProduksi : header.noBongkarSusun;

    final headerMap = <String, dynamic>{
      'IdJenisPlastik': header.idJenisPlastik,
      'IdWarehouse': 3,
      'DateCreate': header.dateCreate, // ✅ FIX
    }..removeWhere((k, v) => v == null);

    final body = <String, dynamic>{
      'header': headerMap,
      'details': details
          .map(
            (d) => {'NoSak': d.noSak, 'Berat': d.berat, 'IdLokasi': d.idLokasi},
          )
          .toList(),
      refKey: refVal,
    };

    return api.putJson('/api/labels/broker/$noBroker', body: body);
  }

  /// Update QC broker (header-only) by NoBroker.
  /// [dateQc] dikirim sebagai 'yyyy-MM-dd' dan boleh lampau (backdate) —
  /// server yang memvalidasi agar tidak melebihi hari ini.
  Future<Map<String, dynamic>> updateBrokerQc({
    required String noBroker,
    required double? density1,
    required double? density2,
    required double? density3,
    required double? moisture1,
    required double? moisture2,
    required double? moisture3,
    required double? maxMeltTemp,
    required double? minMeltTemp,
    required double? mfi,
    required String? visualNote,
    DateTime? dateQc,
  }) async {
    final body = <String, dynamic>{
      'header': {
        'Density': density1,
        'Density2': density2,
        'Density3': density3,
        'Moisture': moisture1,
        'Moisture2': moisture2,
        'Moisture3': moisture3,
        'MaxMeltTemp': maxMeltTemp,
        'MinMeltTemp': minMeltTemp,
        'MFI': mfi,
        'VisualNote': visualNote,
        if (dateQc != null) 'DateQc': toDbDateString(dateQc),
      },
    };

    return api.putJson('/api/labels/broker/$noBroker', body: body);
  }

  /// Delete broker by NoBroker
  Future<void> deleteBroker(String noBroker) async {
    await api.deleteJson('/api/labels/broker/$noBroker');
  }

  /// Ambil list NoBroker yang sudah dibuat untuk suatu NoBongkarSusun
  Future<List<BrokerOutputItem>> fetchOutputsByNoBongkarSusun(
    String noBongkarSusun,
  ) async {
    final body = await api.getJson(
      '/api/bongkar-susun/$noBongkarSusun/outputs/broker',
    );
    final List<dynamic> data = body['data'] ?? [];
    return data
        .map((e) => BrokerOutputItem.fromJson(e as Map<String, dynamic>))
        .where((o) => o.noBroker.isNotEmpty)
        .toList();
  }

  /// Ambil list NoBroker yang sudah dibuat untuk suatu NoProduksi
  Future<List<BrokerOutputItem>> fetchOutputsByNoProduksi(
    String noProduksi,
  ) async {
    final body = await api.getJson(
      '/api/production/broker/$noProduksi/outputs',
    );
    final List<dynamic> data = body['data'] ?? [];
    return data
        .map((e) => BrokerOutputItem.fromJson(e as Map<String, dynamic>))
        .where((o) => o.noBroker.isNotEmpty)
        .toList();
  }

  /// Tandai broker sudah dicetak
  Future<int?> markAsPrinted(String noBroker) async {
    final body = await api.patchJson('/api/labels/broker/$noBroker/print');
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final raw = data['HasBeenPrinted'] ?? data['hasBeenPrinted'];
      if (raw is num) return raw.toInt();
      if (raw != null) return int.tryParse('$raw');
    }
    return null;
  }

  Future<BrokerPartialInfo> fetchPartialInfo({
    required String noBroker,
    required int noSak,
  }) async {
    final body = await api.getJson(
      '/api/labels/broker/partials/$noBroker/$noSak',
    );
    return BrokerPartialInfo.fromEnvelope(body);
  }
}
