import '../../../core/network/api_client.dart';
import '../model/so_v2_access_user.dart';

/// Repository untuk kelola akses user per blok+lokasi (MstUserLokasiAccess).
class SoV2UserLokasiAccessRepository {
  final ApiClient _api;

  SoV2UserLokasiAccessRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  Future<List<SoV2AccessUser>> fetchAllUsers() async {
    final body = await _api.getJson('/api/stock-opname-v2/lokasi-access/users');
    final dataList = (body['data'] ?? []) as List;
    return dataList
        .map(
          (e) => SoV2AccessUser.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> assignAccess({
    required String blok,
    required int idLokasi,
    required int idUsername,
    required String stockOpnameNo,
  }) async {
    await _api.postJson(
      '/api/stock-opname-v2/lokasi-access',
      body: {
        'blok': blok,
        'idLokasi': idLokasi,
        'idUsername': idUsername,
        'stockOpnameNo': stockOpnameNo,
      },
    );
  }

  Future<void> revokeAccess({
    required String blok,
    required int idLokasi,
    required int idUsername,
    required String stockOpnameNo,
  }) async {
    await _api.deleteJson(
      '/api/stock-opname-v2/lokasi-access/${Uri.encodeComponent(stockOpnameNo)}/${Uri.encodeComponent(blok)}/$idLokasi/$idUsername',
    );
  }
}
