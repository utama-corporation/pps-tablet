import '../../../core/network/api_client.dart';
import '../model/kpi.dart';

/// `/api/kpi`: KPI bulan berjalan s.d. [tanggal] (YYYY-MM-DD).
class KpiRepository {
  final ApiClient api;
  const KpiRepository({required this.api});

  Future<KpiResult> load(String tanggal) async {
    final data = await api.getJson('/api/kpi', query: {'tanggal': tanggal});
    final body = data['data'];
    if (body is! Map<String, dynamic>) {
      throw ApiException(0, 'Format KPI tidak sesuai.');
    }
    return KpiResult.fromJson(body);
  }
}
