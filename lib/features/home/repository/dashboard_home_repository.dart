import '../../../core/network/api_client.dart';
import '../model/dashboard_home.dart';

/// Ringkasan analytics `/api/dashboard/home`: kartu domain dengan delta,
/// tren harian, dan aktivitas hari ini untuk [range] hari s.d. kemarin.
class DashboardHomeRepository {
  final ApiClient api;
  const DashboardHomeRepository({required this.api});

  Future<DashHome> home(int range) async {
    final Map<String, dynamic> data;
    try {
      data = await api.getJson(
        '/api/dashboard/home',
        query: {'range': '$range'},
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(0, 'Ringkasan dashboard belum dapat dimuat.');
    }
    final body = data['data'];
    if (body is! Map<String, dynamic>) {
      throw ApiException(0, 'Format ringkasan dashboard tidak sesuai.');
    }
    return DashHome(body);
  }
}
