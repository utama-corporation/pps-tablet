import '../../../core/network/api_client.dart';
import '../model/role_models.dart';

class RoleRepository {
  const RoleRepository({required this.api});

  final ApiClient api;

  static const path = '/api/master-permission-group';

  Future<List<RoleGroup>> fetchRoles() async {
    final body = await api.getJson(path);
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) RoleGroup.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<PermissionItem>> fetchPermissions() async {
    final body = await api.getJson('$path/permissions');
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) PermissionItem.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, bool>> fetchRoleAllows(int idUGroup) async {
    final body = await api.getJson(
      '$path/${Uri.encodeComponent('$idUGroup')}',
    );
    final data = body['data'];
    final permissions = data is Map ? data['Permissions'] : null;
    final allows = <String, bool>{};
    if (permissions is List) {
      for (final row in permissions) {
        if (row is! Map) continue;
        final no = (row['NoPermission'] ?? '').toString().trim();
        if (no.isEmpty) continue;
        final raw = row['Allow'];
        allows[no] = raw == true ||
            raw == 1 ||
            '$raw'.toLowerCase() == 'true';
      }
    }
    return allows;
  }

  Future<void> createRole({
    required String name,
    required List<PermissionItem> all,
    required Map<String, bool> allow,
  }) => api.postJson(
    path,
    body: _roleBody(name: name, all: all, allow: allow),
  );

  Future<void> updateRole({
    required int idUGroup,
    required String name,
    required List<PermissionItem> all,
    required Map<String, bool> allow,
  }) => api.putJson(
    '$path/${Uri.encodeComponent('$idUGroup')}',
    body: _roleBody(name: name, all: all, allow: allow),
  );

  Future<void> deleteRole(int idUGroup) async {
    await api.deleteJson('$path/${Uri.encodeComponent('$idUGroup')}');
  }

  Future<void> createPermission(String no, String description) =>
      api.postJson(
        '$path/permissions',
        body: {'noPermission': no, 'permission': description},
      );

  Future<void> updatePermission(String no, String description) =>
      api.putJson(
        '$path/permissions/${Uri.encodeComponent(no)}',
        body: {'noPermission': no, 'permission': description},
      );

  Future<void> deletePermission(String no) async {
    await api.deleteJson('$path/permissions/${Uri.encodeComponent(no)}');
  }

  Map<String, dynamic> _roleBody({
    required String name,
    required List<PermissionItem> all,
    required Map<String, bool> allow,
  }) => {
    'uGroupName': name,
    'permissions': [
      for (final item in all)
        {'noPermission': item.no, 'allow': allow[item.no] == true},
    ],
  };
}
