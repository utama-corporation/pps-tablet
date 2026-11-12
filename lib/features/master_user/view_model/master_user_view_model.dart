import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/master_user_models.dart';
import '../repository/master_user_repository.dart';

class MasterUserViewModel extends ChangeNotifier {
  MasterUserViewModel(this.repository);

  final MasterUserRepository repository;

  List<MasterUser> _items = [];
  List<UserGroup> groups = [];
  String search = '';
  bool loading = false;
  bool deleting = false;
  String error = '';



  List<MasterUser> get items {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(_items.where((u) {
      final hay =
          '${u.username} ${u.fullName} ${u.nik} ${u.employeeId ?? ''} ${u.companyId} ${u.groupNames.join(' ')}'
              .toLowerCase();
      return hay.contains(q);
    }));
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
        repository.fetchUsers(),
        repository.fetchGroups(),
      ]);
      _items = results[0] as List<MasterUser>;
      groups = results[1] as List<UserGroup>;

      // Backfill role chips when the list endpoint returns no GroupName.
      if (_items.any((u) => u.groupNames.isEmpty)) {
        final backfill = await Future.wait(
          _items
              .where((u) => u.groupNames.isEmpty)
              .map(
                (u) => repository
                    .fetchUserGroups(u.id)
                    .then((g) => MapEntry(u.id, g))
                    .catchError((_) => MapEntry(u.id, const <UserGroup>[])),
              ),
        );
        final byId = {for (final e in backfill) e.key: e.value};
        _items = [
          for (final u in _items)
            if (u.groupNames.isEmpty && (byId[u.id]?.isNotEmpty ?? false))
              u.copyWith(
                groupNames: [for (final g in byId[u.id]!) g.name],
              )
            else
              u,
        ];
      }
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<Map<String, dynamic>> createUser({
    required String fName,
    required String lName,
    required String username,
    required String password,
    required int employeeId,
    required String companyId,
    required String nik,
    required List<int> groupIds,
  }) => repository.create({
    'fName': fName,
    'lName': lName,
    'username': username,
    'password': password,
    'employeeId': employeeId,
    'companyId': companyId,
    'nik': nik,
    'idUGroup': groupIds,
  }).then((r) async {
    await load();
    return r;
  });

  Future<Map<String, dynamic>> updateUser({
    required int idUsername,
    required String fName,
    required String lName,
    required int employeeId,
    required bool resetPassword,
    required List<int> groupIds,
  }) => repository.update({
    'idUsername': idUsername,
    'fName': fName,
    'lName': lName,
    'employeeId': employeeId,
    'resetPassword': resetPassword,
    'idUGroup': groupIds,
  }).then((r) async {
    await load();
    return r;
  });

  Future<void> deleteUser(int idUsername) async {
    if (deleting) return;
    deleting = true;
    error = '';
    notifyListeners();
    try {
      await repository.delete(idUsername);
      await load();
    } catch (e) {
      error = apiErrorMessage(e);
      rethrow;
    } finally {
      deleting = false;
      notifyListeners();
    }
  }
}
