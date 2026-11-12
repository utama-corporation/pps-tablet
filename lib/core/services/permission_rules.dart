/// Matches backend require-permission.js: exact grants or global super-admin.
abstract final class PermissionRules {
  static bool allows(Iterable<String> granted, String required) {
    if (required.trim().isEmpty) return false;
    return granted.contains('*') || granted.contains(required);
  }
}
