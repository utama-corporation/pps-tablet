import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../model/mapping_v2_models.dart';

class MappingV2Repository {
  MappingV2Repository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<MappingV2Blok>> fetchBlok() async {
    try {
      final response = await _apiClient.getJson(
        '/api/mapping/blok',
        useAuth: true,
      );
      return _mapList(response['data']).map(MappingV2Blok.fromJson).toList();
    } on ApiFailure catch (error) {
      if (error.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<List<MappingV2Lokasi>> fetchLokasi(String blok) async {
    try {
      final response = await _apiClient.getJson(
        '/api/mapping/lokasi?blok=${Uri.encodeComponent(blok)}',
        useAuth: true,
      );
      return _mapList(
        response['data'],
      ).map(MappingV2Lokasi.fromJson).toList();
    } on ApiFailure catch (error) {
      if (error.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<MappingV2LabelPage> fetchLabels({
    required String blok,
    required int idLokasi,
    required int page,
    int limit = 50,
  }) async {
    final query = Uri(
      queryParameters: {
        'blok': blok,
        'idlokasi': '$idLokasi',
        'page': '$page',
        'limit': '$limit',
      },
    ).query;
    try {
      final response = await _apiClient.getJson(
        '/api/label/all/v2?$query',
        useAuth: true,
      );
      return MappingV2LabelPage.fromJson(response);
    } on ApiFailure catch (error) {
      if (error.statusCode == 404) {
        return MappingV2LabelPage(
          items: const [],
          totalData: 0,
          currentPage: page,
          totalPages: page,
          perPage: limit,
        );
      }
      rethrow;
    }
  }

  Future<MappingV2UpdateResult> updateLokasi({
    required String labelCode,
    required String blok,
    required int idLokasi,
  }) async {
    final response = await _apiClient.putJson(
      '/api/label/update-lokasi',
      body: {
        'labelCode': labelCode.trim(),
        'blok': blok,
        'idLokasi': idLokasi,
      },
      useAuth: true,
    );
    return MappingV2UpdateResult.fromJson(response);
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
