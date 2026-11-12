import 'package:shared_preferences/shared_preferences.dart';

class PermissionStorage {
  /// Simpan daftar permission (biasanya dipanggil setelah login)
  static Future<void> savePermissions(List<String> permissions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('permissions', permissions);
  }

  /// Ambil daftar permission yang tersimpan
  static Future<List<String>> getPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('permissions') ?? [];
  }

  /// Cek apakah user memiliki permission tertentu
  static Future<bool> hasPermission(String code) async {
    final permissions = await getPermissions();
    return permissions.contains(code);
  }

  /// Hapus permission (misalnya saat logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('permissions');
  }
}
