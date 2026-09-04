import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/user_model.dart';
import '../../view_model/login_view_model.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kPrimarySoft = Color(0xFFE8EEF7);

/// Ubah kode database Ascend jadi nama perusahaan yang ramah dibaca user.
/// Hanya untuk tampilan — nilai yang disimpan server tetap kode aslinya.
String nikCompanyDisplayName(String? companyId) {
  switch ((companyId ?? '').trim().toUpperCase()) {
    case 'AS_GSU':
      return 'Ganda Saribu Utama';
    case 'AS_RU':
      return 'Ratimdo Utama';
    case 'AS_UC_2017':
      return 'Utama Corporation';
    default:
      return companyId ?? '-';
  }
}

/// Flow lengkap gate NIK untuk user yang belum punya NIK di MstUsername:
/// input NIK -> verifikasi (login+nik) -> konfirmasi data karyawan ->
/// simpan + login (login+nik+confirmNik).
///
/// Semua tahap memakai endpoint login yang sama; token baru dikeluarkan server
/// (dan disimpan repository) setelah konfirmasi berhasil.
///
/// Return `true` bila NIK berhasil disimpan & login tuntas (token tersimpan),
/// `false` bila user membatalkan.
Future<bool> showNikBindingDialog({
  required BuildContext context,
  required LoginViewModel viewModel,
  required String username,
  required String password,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NikBindingDialog(
      viewModel: viewModel,
      username: username,
      password: password,
    ),
  );
  return result ?? false;
}

class _NikBindingDialog extends StatefulWidget {
  const _NikBindingDialog({
    required this.viewModel,
    required this.username,
    required this.password,
  });

  final LoginViewModel viewModel;
  final String username;
  final String password;

  @override
  State<_NikBindingDialog> createState() => _NikBindingDialogState();
}

class _NikBindingDialogState extends State<_NikBindingDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  User get _user => User(username: widget.username, password: widget.password);

  Future<void> _submit() async {
    final nik = _controller.text.trim();

    if (nik.isEmpty) {
      setState(() => _errorText = 'NIK harus diisi');
      return;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(nik)) {
      setState(() => _errorText = 'NIK hanya boleh berupa angka');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    // Tahap 1: verifikasi NIK (belum simpan, belum ada token)
    final res = await widget.viewModel.validateLogin(_user, nik: nik);
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.errorType == 'nik_not_found') {
      setState(() => _errorText = 'NIK "$nik" tidak ditemukan');
      return;
    }
    if (res.errorType != 'nik_confirm') {
      setState(() => _errorText = res.message);
      return;
    }

    // Tahap 2: konfirmasi data karyawan
    final confirmed = await _showConfirmDialog(
      fullName: res.employeeFullName ?? '-',
      nik: nik,
      companyId: res.companyId,
    );
    if (!mounted) return;
    if (confirmed != true) return; // kembali ke input

    setState(() {
      _loading = true;
      _errorText = null;
    });

    // Tahap 3: simpan NIK + selesaikan login (token disimpan repository)
    final bindRes = await widget.viewModel.validateLogin(
      _user,
      nik: nik,
      confirmNik: true,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!bindRes.success) {
      setState(() {
        _errorText = bindRes.errorType == 'nik_not_found'
            ? 'NIK "$nik" tidak ditemukan'
            : bindRes.message;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<bool?> _showConfirmDialog({
    required String fullName,
    required String nik,
    String? companyId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NikConfirmDialog(
        fullName: fullName,
        nik: nik,
        companyName: nikCompanyDisplayName(companyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: screenW > 460 ? 400 : double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge ikon
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: _kPrimarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: _kPrimary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Lengkapi NIK',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Akun Anda belum memiliki NIK. Masukkan NIK karyawan untuk '
                  'melanjutkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                  onSubmitted: (_) {
                    if (!_loading) _submit();
                  },
                  decoration: InputDecoration(
                    hintText: '••••••',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      letterSpacing: 4,
                    ),
                    errorText: _errorText,
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _kPrimary, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.red.shade300),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kPrimary.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Lanjut',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NikConfirmDialog extends StatelessWidget {
  const _NikConfirmDialog({
    required this.fullName,
    required this.nik,
    required this.companyName,
  });

  final String fullName;
  final String nik;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: screenW > 460 ? 400 : double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.how_to_reg_rounded,
                    color: Colors.green.shade600,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Konfirmasi Karyawan',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pastikan data berikut sesuai sebelum disimpan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1D23),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row(Icons.badge_outlined, 'NIK', nik),
                      const SizedBox(height: 8),
                      _row(Icons.apartment_rounded, 'Perusahaan', companyName),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Bukan',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Konfirmasi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D23),
            ),
          ),
        ),
      ],
    );
  }
}
