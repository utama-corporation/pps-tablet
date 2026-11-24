import '../../../core/network/api_client.dart';
import '../model/my_work.dart';

/// `/api/my-work`: ringkasan antrian dan daftar item per antrian.
class MyWorkRepository {
  final ApiClient api;
  const MyWorkRepository({required this.api});

  Future<MyWorkSummary> summary() async {
    final data = await api.getJson('/api/my-work');
    final body = data['data'];
    if (body is! Map<String, dynamic>) {
      throw ApiException(0, 'Format My Work tidak sesuai.');
    }
    return MyWorkSummary.fromJson(body);
  }

  Future<MyWorkItems> items(String key, {String search = ''}) async {
    final data = await api.getJson(
      '/api/my-work/${Uri.encodeComponent(key)}',
      query: {if (search.trim().isNotEmpty) 'search': search.trim()},
    );
    final body = data['data'];
    if (body is! Map<String, dynamic>) {
      throw ApiException(0, 'Format daftar pekerjaan tidak sesuai.');
    }
    return MyWorkItems.fromJson(body);
  }
}
