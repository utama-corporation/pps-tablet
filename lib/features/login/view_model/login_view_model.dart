// lib/features/login/view_model/login_view_model.dart
import '../data/login_repository.dart';
import '../model/login_result.dart';
import '../model/user_model.dart';

class LoginViewModel {
  LoginViewModel({LoginRepository? repo}) : _repo = repo ?? LoginRepository();
  final LoginRepository _repo;

  /// [nik] & [confirmNik] dipakai pada gate NIK (user belum punya NIK di
  /// MstUsername). Semua tahap — verifikasi, konfirmasi, penyimpanan — lewat
  /// endpoint login yang sama.
  Future<LoginResult> validateLogin(
    User user, {
    String? nik,
    bool confirmNik = false,
  }) async {
    // ViewModel hanya validasi ringan + delegasi ke repository
    if (user.username.trim().isEmpty || user.password.isEmpty) {
      return LoginResult(
        success: false,
        message: 'Username/NIK dan password harus diisi',
        errorType: 'validation',
        detailCode: 'validation',
      );
    }

    if (nik != null && !RegExp(r'^[0-9]+$').hasMatch(nik.trim())) {
      return LoginResult(
        success: false,
        message: 'NIK hanya boleh berupa angka',
        errorType: 'validation',
        detailCode: 'validation',
      );
    }

    // repository sudah return LoginResult (tidak throw)
    return _repo.login(user, nik: nik, confirmNik: confirmNik);
  }
}
