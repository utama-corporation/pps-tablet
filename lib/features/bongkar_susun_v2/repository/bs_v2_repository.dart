import '../../../core/network/api_client.dart';
import '../model/bs_v2_label_info.dart';
import '../model/bs_v2_transaction.dart';

class BsV2Repository {
  final ApiClient _api;

  BsV2Repository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  Future<BsV2LabelInfo> fetchLabelInfo(String labelCode) async {
    final body = await _api.getJson(
      '/api/bongkar-susun-v2/label/${Uri.encodeComponent(labelCode)}',
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data label');
    return BsV2LabelInfo.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
  }) async {
    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final body = await _api.getJson('/api/bongkar-susun-v2', query: qp);
    final dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map(
          (e) => BsV2Transaction.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final totalData = body['total'] is int
        ? body['total'] as int
        : int.tryParse(body['total']?.toString() ?? '0') ?? 0;
    final pageSize_ = body['pageSize'] is int
        ? body['pageSize'] as int
        : pageSize;
    final totalPages = pageSize_ > 0
        ? ((totalData + pageSize_ - 1) ~/ pageSize_)
        : 1;

    return {
      'items': items,
      'page': page,
      'totalPages': totalPages,
      'total': totalData,
    };
  }

  Future<BsV2Transaction> fetchDetail(String noBongkarSusun) async {
    final body = await _api.getJson('/api/bongkar-susun-v2/$noBongkarSusun');
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null)
      throw Exception('Response tidak mengandung data transaksi');
    return BsV2Transaction.fromJson(data);
  }

  Future<BsV2Transaction> submit({
    required String note,
    required List<String> inputs,
    required List<Map<String, dynamic>> outputs,
    List<Map<String, dynamic>>? inputsPartial,
  }) async {
    final reqBody = <String, dynamic>{
      'note': note,
      'inputs': inputs,
      'outputs': outputs,
      if (inputsPartial != null && inputsPartial.isNotEmpty)
        'inputsPartial': inputsPartial,
    };

    final jsonResp = await _api.postJson(
      '/api/bongkar-susun-v2',
      body: reqBody,
    );
    final data = jsonResp['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return BsV2Transaction.fromJson(data);
  }

  Future<void> delete(String noBongkarSusun) async {
    await _api.deleteJson('/api/bongkar-susun-v2/$noBongkarSusun');
  }
}
