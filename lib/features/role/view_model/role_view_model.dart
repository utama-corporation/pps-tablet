import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/role_models.dart';
import '../repository/role_repository.dart';

class RoleViewModel extends ChangeNotifier {
  RoleViewModel(this.repository);

  final RoleRepository repository;

  List<RoleGroup> _items = const [];
  List<PermissionItem> permissions = const [];
  String search = '';
  bool loading = false;
  bool deleting = false;
  String error = '';

  List<RoleGroup> get items {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where((r) => '${r.id} ${r.name}'.toLowerCase().contains(q)),
    );
  }

  int get totalCount => _items.length;

  void setSearch(String value) {
    if (search == value.trim()) return;
    search = value.trim();
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = '';
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.fetchRoles(),
        repository.fetchPermissions(),
      ]);
      _items = results[0] as List<RoleGroup>;
      permissions = results[1] as List<PermissionItem>;
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> createRole({
    required String name,
    required Map<String, bool> allow,
  }) async {
    await repository.createRole(name: name, all: permissions, allow: allow);
    await load();
  }

  Future<void> updateRole({
    required int idUGroup,
    required String name,
    required Map<String, bool> allow,
  }) async {
    await repository.updateRole(
      idUGroup: idUGroup,
      name: name,
      all: permissions,
      allow: allow,
    );
    await load();
  }

  Future<void> deleteRole(int idUGroup) async {
    if (deleting) return;
    deleting = true;
    error = '';
    notifyListeners();
    try {
      await repository.deleteRole(idUGroup);
      await load();
    } catch (e) {
      error = apiErrorMessage(e);
      rethrow;
    } finally {
      deleting = false;
      notifyListeners();
    }
  }

  Future<void> createPermission(String no, String description) async {
    await repository.createPermission(no, description);
    await load();
  }

  Future<void> updatePermission(String no, String description) async {
    await repository.updatePermission(no, description);
    await load();
  }

  Future<void> deletePermission(String no) async {
    await repository.deletePermission(no);
    await load();
  }
}
