import '../../../core/network/api_client.dart';
import '../model/master_user_models.dart';

class MasterUserRepository {
  const MasterUserRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-user';

  Future<List<MasterUser>> fetchUsers({String search = ''}) async {
    final body = await api.getJson(
      path,
      query: search.trim().isEmpty ? null : {'q': search.trim()},
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) MasterUser.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<UserGroup>> fetchGroups() async {
    final body = await api.getJson('$path/groups');
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) UserGroup.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<UserGroup>> fetchUserGroups(int idUsername) async {
    final body = await api.getJson(
      '$path/${Uri.encodeComponent('$idUsername')}/group',
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) UserGroup.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<EmployeeMatch>> searchEmployees({
    required String db,
    required String query,
  }) async {
    final body = await api.getJson(
      '$path/employees',
      query: {'db': db, 'q': query.trim()},
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          EmployeeMatch.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) =>
      api.postJson(path, body: body);

  Future<Map<String, dynamic>> update(Map<String, dynamic> body) =>
      api.putJson(path, body: body);

  Future<void> delete(int idUsername) async {
    await api.deleteJson(
      path,
      query: {'idUsername': idUsername},
    );
  }
}
