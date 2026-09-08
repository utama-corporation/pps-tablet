import 'package:shared_preferences/shared_preferences.dart';

class UserSessionStorage {
  static const String _usernameKey = 'logged_username';
  static const String _fullNameKey = 'logged_full_name';
  static const String _lastLoginKey = 'logged_last_login_at';
  static const String _groupIdKey = 'logged_ugroup_id';
  static const String _groupNameKey = 'logged_ugroup_name';
  static const String _nikKey = 'logged_nik';
  static const String _companyIdKey = 'logged_company_id';
  static const String _idUsernameKey = 'logged_id_username';

  static Future<void> saveUser({
    required String username,
    String? fullName,
    int? idUsername,
    String? nik,
    String? companyId,
    int? idUGroup,
    String? uGroupName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);

    await _setOrRemoveString(prefs, _fullNameKey, fullName);
    await _setOrRemoveString(prefs, _nikKey, nik);
    await _setOrRemoveString(prefs, _companyIdKey, companyId);
    await _setOrRemoveString(prefs, _groupNameKey, uGroupName);

    if (idUsername == null) {
      await prefs.remove(_idUsernameKey);
    } else {
      await prefs.setInt(_idUsernameKey, idUsername);
    }

    if (idUGroup == null) {
      await prefs.remove(_groupIdKey);
    } else {
      await prefs.setInt(_groupIdKey, idUGroup);
    }

    await prefs.setString(
      _lastLoginKey,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> _setOrRemoveString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, normalized);
    }
  }

  static Future<String> getUsername({String fallback = 'unknown'}) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey)?.trim();
    return username == null || username.isEmpty ? fallback : username;
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString(_fullNameKey)?.trim();
    return fullName == null || fullName.isEmpty ? null : fullName;
  }

  static Future<String?> getNik() async {
    final prefs = await SharedPreferences.getInstance();
    final nik = prefs.getString(_nikKey)?.trim();
    return nik == null || nik.isEmpty ? null : nik;
  }

  static Future<String?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    final company = prefs.getString(_companyIdKey)?.trim();
    return company == null || company.isEmpty ? null : company;
  }

  static Future<int?> getIdUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_idUsernameKey);
  }

  static Future<DateTime?> getLastLoginAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastLoginKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<int?> getUGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_groupIdKey);
  }

  static Future<String?> getUGroupName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_groupNameKey)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_lastLoginKey);
    await prefs.remove(_groupIdKey);
    await prefs.remove(_groupNameKey);
    await prefs.remove(_nikKey);
    await prefs.remove(_companyIdKey);
    await prefs.remove(_idUsernameKey);
  }
}
