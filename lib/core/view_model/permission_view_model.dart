import 'package:flutter/foundation.dart';

import '../services/permission_storage.dart';
import '../services/permission_rules.dart';

class PermissionViewModel extends ChangeNotifier {
  List<String> _permissions = [];

  List<String> get permissions => List.unmodifiable(_permissions);

  Future<void> loadPermissions() async {
    _permissions = await PermissionStorage.getPermissions();
    notifyListeners();
  }

  bool can(String code) => PermissionRules.allows(_permissions, code);

  void clear() {
    _permissions.clear();
    notifyListeners();
  }
}
