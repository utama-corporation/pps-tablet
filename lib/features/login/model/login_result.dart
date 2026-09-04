// lib/features/login/model/login_result.dart
class LoginResult {
  final bool success;
  final String message;

  /// auth | validation | network | server | unknown
  /// | nik_required  -> user belum punya NIK, wajib lengkapi (tidak ada token)
  /// | nik_not_found -> NIK tidak ada di database Ascend
  /// | nik_confirm   -> NIK ketemu, menunggu konfirmasi user (lihat [employeeFullName])
  final String errorType;

  /// backend_offline | dns | internet_offline | timeout | server_503 | server_500 | server_error | network_error | unknown
  final String detailCode;

  /// Diisi saat [errorType] == 'nik_confirm'.
  final String? employeeFullName;

  /// Nama database Ascend tempat NIK ditemukan (AS_GSU / AS_UC_2017 / AS_RU).
  /// Diisi saat [errorType] == 'nik_confirm'.
  final String? companyId;

  LoginResult({
    required this.success,
    required this.message,
    required this.errorType,
    required this.detailCode,
    this.employeeFullName,
    this.companyId,
  });

  factory LoginResult.ok([String msg = 'Login berhasil']) => LoginResult(
    success: true,
    message: msg,
    errorType: '',
    detailCode: '',
  );

  /// Login sukses secara kredensial tapi user belum punya NIK.
  bool get needsNik => !success && errorType == 'nik_required';
}
