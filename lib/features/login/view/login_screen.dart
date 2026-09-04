import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/error_presenter.dart';
import '../../../common/widgets/error_status_dialog.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../../update/model/update_model.dart';
import '../model/user_model.dart';
import '../view_model/login_view_model.dart';
import 'widgets/login_error_banner.dart';
import 'widgets/nik_binding_dialog.dart';

import '../../update/view_model/update_view_model.dart';
import '../../update/view/widgets/update_auto_sheet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  final LoginViewModel _viewModel = LoginViewModel();
  final UpdateViewModel _updateViewModel = UpdateViewModel();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isPasswordVisible = false;

  // ✅ State update yang diperluas
  bool _isCheckingUpdate = false;
  bool _lockLoginUi =
      true; // ✅ Default TRUE - blokir login sampai update check selesai
  bool _hasCompletedUpdateCheck =
      false; // ✅ Track apakah update check sudah selesai
  String? _updateError; // ✅ Simpan error message jika ada

  // state login
  String _errorMessage = '';
  String _errorType = '';
  String _detailCode = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();

    // ✅ Langsung check update saat init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkForUpdatesWithRetry();
    });
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  /// ✅ Check update dengan retry mechanism
  /// ✅ Check update dengan retry mechanism - FIXED VERSION
  Future<void> _checkForUpdatesWithRetry() async {
    if (!mounted) return;

    setState(() {
      _isCheckingUpdate = true;
      _lockLoginUi = true;
      _updateError = null;
    });

    try {
      print('🔍 [UPDATE] Starting update check...');

      // ✅ CRITICAL: Gunakan try-catch di dalam untuk catch error dari UpdateViewModel
      UpdateInfo? updateInfo;
      bool hasError = false;
      String? errorMessage;

      try {
        updateInfo = await _updateViewModel.checkForUpdate();
      } catch (e) {
        // ✅ Catch error dari checkForUpdate()
        hasError = true;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        print('❌ [LOGIN] Caught update check error: $errorMessage');
      }

      if (!mounted) return;

      // ✅ Jika ada error, tampilkan dialog error
      if (hasError) {
        setState(() {
          _updateError = errorMessage ?? 'Unknown error';
          _isCheckingUpdate = false;
          _lockLoginUi = true; // ✅ Tetap lock
          _hasCompletedUpdateCheck = false;
        });

        _showUpdateErrorDialog();
        return;
      }

      // ✅ Jika tidak ada update (sudah versi terbaru)
      if (updateInfo == null) {
        print('✅ [LOGIN] No update needed, unlocking login');
        setState(() {
          _lockLoginUi = false;
          _hasCompletedUpdateCheck = true;
          _isCheckingUpdate = false;
        });
        return;
      }

      // ✅ Jika ada update, tampilkan dialog download
      print('📥 [LOGIN] Update available, showing dialog');

      // Reset state sebelum show dialog
      setState(() {
        _isCheckingUpdate = false;
      });

      final needsUpdate = await UpdateDialog.show(
        context,
        vm: _updateViewModel,
      );

      if (!mounted) return;

      print('✅ [UPDATE] Update dialog closed. needsUpdate=$needsUpdate');

      // ✅ Jika return true -> installer dibuka, tetap lock UI
      if (needsUpdate == true) {
        setState(() {
          _lockLoginUi = true;
          _hasCompletedUpdateCheck = false;
        });

        _showMustInstallUpdateDialog();
      } else {
        // ✅ User cancel atau error saat download
        setState(() {
          _lockLoginUi = true;
          _hasCompletedUpdateCheck = false;
        });

        _showUpdateCancelledDialog();
      }
    } catch (e) {
      // ✅ Catch unexpected errors
      if (!mounted) return;

      print('❌ [LOGIN] Unexpected error in update flow: $e');

      setState(() {
        _updateError = 'Terjadi kesalahan tidak terduga: $e';
        _isCheckingUpdate = false;
        _lockLoginUi = true;
      });

      _showUpdateErrorDialog();
    }
  }

  /// ✅ Dialog ketika user cancel update atau download error
  void _showUpdateCancelledDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Dibatalkan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update diperlukan untuk melanjutkan menggunakan aplikasi.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Silakan coba lagi untuk melanjutkan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _checkForUpdatesWithRetry(); // ✅ Retry
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Dialog ketika update wajib diinstall
  void _showMustInstallUpdateDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update,
                color: Colors.orange.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Diperlukan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aplikasi harus diupdate ke versi terbaru untuk melanjutkan.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Silakan install update yang telah didownload, kemudian buka aplikasi kembali.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Tutup dialog dan tetap lock UI
                Navigator.of(context).pop();
              },
              child: Text(
                'Mengerti',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Dialog error dengan retry
  /// ✅ Dialog error dengan retry - ENHANCED VERSION
  void _showUpdateErrorDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Gagal Cek Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tidak dapat memeriksa update dari server:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _updateError ?? 'Unknown error',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pastikan:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildCheckItem('Koneksi internet aktif dan stabil'),
              _buildCheckItem('Server update dapat diakses'),
              _buildCheckItem('Jaringan WiFi/Mobile data tidak diblokir'),
              const SizedBox(height: 12),
              Text(
                'Jika masalah berlanjut, hubungi administrator.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _checkForUpdatesWithRetry(); // ✅ Retry
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    // ✅ Blokir login jika belum selesai update check
    if (_lockLoginUi || _isCheckingUpdate || !_hasCompletedUpdateCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mohon tunggu proses update selesai'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _clearErrorMessage();

    _usernameFocusNode.unfocus();
    _passwordFocusNode.unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username/NIK dan password harus diisi';
        _errorType = 'validation';
        _detailCode = 'validation';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _viewModel.validateLogin(
      User(username: username, password: password),
    );

    if (!mounted) return;

    if (!result.success) {
      // 🔒 Gate NIK: kredensial benar tapi user belum punya NIK di MstUsername.
      // Server TIDAK mengeluarkan token sampai NIK terisi — binding lewat
      // endpoint login yang sama (dialog di bawah).
      if (result.needsNik) {
        setState(() => _isLoading = false);
        final bound = await showNikBindingDialog(
          context: context,
          viewModel: _viewModel,
          username: username,
          password: password,
        );
        if (!mounted) return;
        if (!bound) {
          // User batal -> tetap di halaman login.
          return;
        }
        // Token sudah disimpan repository saat konfirmasi berhasil.
        setState(() => _isLoading = true);
        await _safeLoadPermissions();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _goHome();
        return;
      }

      // ⛔ Akun dinonaktifkan (IsEnable = 0) -> dialog, bukan banner biasa.
      if (result.errorType == 'account_disabled' ||
          result.errorType == 'user_inactive') {
        setState(() => _isLoading = false);
        _showAccountDisabledDialog(result.message);
        return;
      }

      setState(() {
        _errorMessage = result.message;
        _errorType = result.errorType;
        _detailCode = result.detailCode;
        _isLoading = false;
      });

      if (_errorType == 'network' || _errorType == 'server') {
        ErrorPresenter.showNetworkOrServerDialog(
          context,
          message: _errorMessage,
          errorType: _errorType,
          detailCode: _detailCode,
          onRetry: _login,
        );
      }
      return;
    }

    await _safeLoadPermissions();
    if (!mounted) return;

    setState(() => _isLoading = false);

    _goHome();
  }

  /// Dialog akun dinonaktifkan (IsEnable = 0) — pakai widget status error umum.
  void _showAccountDisabledDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => ErrorStatusDialog(
        title: 'Akun Dinonaktifkan',
        message: message.isNotEmpty
            ? message
            : 'Akun Anda telah dinonaktifkan. Hubungi kepala divisi atau IT '
                  'untuk mengaktifkan kembali.',
      ),
    );
  }

  void _goHome() {
    try {
      Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      setState(() {
        _errorMessage =
            'Login berhasil, tapi gagal membuka halaman Home. Pastikan route "/home" terdaftar.';
        _errorType = 'server';
        _detailCode = 'route_missing';
      });
    }
  }


  Future<void> _safeLoadPermissions() async {
    try {
      final permVm = context.read<PermissionViewModel>();
      await permVm.loadPermissions();
    } catch (_) {}
  }

  void _clearErrorMessage() {
    if (!mounted) return;
    if (_errorMessage.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _errorType = '';
        _detailCode = '';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    final screenHeight = mediaQuery.size.height;

    // ✅ Tampilkan overlay loading saat checking update
    if (_isCheckingUpdate) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const _GradientBackground(),
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 50,
                        width: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Memeriksa Update',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mohon tunggu sebentar...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ Tampilkan overlay lock jika update wajib
    if (_lockLoginUi && _hasCompletedUpdateCheck == false) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const _GradientBackground(),
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.system_update_alt,
                        size: 64,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Update Diperlukan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aplikasi harus diupdate sebelum dapat digunakan.\n\nSilakan install update yang telah didownload.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _checkForUpdatesWithRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Cek Update Lagi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D47A1),
                            side: const BorderSide(
                              color: Color(0xFF0D47A1),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ UI normal (login) - hanya muncul jika update check selesai dan tidak ada update wajib
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () {
          _usernameFocusNode.unfocus();
          _passwordFocusNode.unfocus();
        },
        child: Stack(
          children: [
            const _GradientBackground(),

            Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: isKeyboardVisible ? 0.0 : 1.0,
                  child: const Text(
                    'Welcome to PPS!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: isKeyboardVisible
                  ? (screenHeight - 480 - keyboardHeight) / 2
                  : (screenHeight - 480) / 2,
              left: 0,
              right: 0,
              bottom: 100,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildLoginCard(isKeyboardVisible),
              ),
            ),

            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isKeyboardVisible ? 0.0 : 1.0,
                  child: Text(
                    'Copyright © 2025, Utama Corporation\nAll rights reserved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(bool isKeyboardVisible) {
    return Center(
      child: Container(
        width: 400,
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isKeyboardVisible ? 80 : 120,
              width: isKeyboardVisible ? 80 : 120,
              child: Image.asset(
                'assets/images/icon_without_bg.png',
                fit: BoxFit.contain,
              ),
            ),
            Divider(color: Colors.grey[300], thickness: 1, height: 32),
            const SizedBox(height: 16),

            TextField(
              controller: _usernameController,
              focusNode: _usernameFocusNode,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearErrorMessage(),
              decoration: InputDecoration(
                labelText: 'Username / NIK',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D47A1),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _clearErrorMessage(),
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D47A1),
                    width: 2,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _errorMessage.isNotEmpty
                  ? LoginErrorBanner(
                      message: _errorMessage,
                      errorType: _errorType,
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D4D8C), Color(0xFFF9A825)],
        ),
      ),
    );
  }
}
