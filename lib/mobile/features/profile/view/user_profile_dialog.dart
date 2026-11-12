import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/user_profile_view_model.dart';
import '../model/user_profile_model.dart';

class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({Key? key}) : super(key: key);

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _oldPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  void _validateForm() {
    setState(() {
      _oldPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty) {
      _oldPasswordError = 'Password lama harus diisi!';
    }
    if (newPassword.isEmpty) {
      _newPasswordError = 'Password baru harus diisi!';
    }
    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Konfirmasi password harus diisi!';
    } else if (newPassword != confirmPassword) {
      _confirmPasswordError = 'Konfirmasi tidak cocok dengan password baru!';
    }

    if (_oldPasswordError == null &&
        _newPasswordError == null &&
        _confirmPasswordError == null) {
      _changePassword(oldPassword, newPassword, confirmPassword);
    }
  }

  void _changePassword(String oldPassword, String newPassword, String confirmPassword) async {
    final userProfile = UserProfileModel(
      oldPassword: oldPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    await context.read<UserProfileViewModel>().changePassword(userProfile: userProfile);

    final viewModel = context.read<UserProfileViewModel>();
    if (viewModel.errorMessage.isNotEmpty) {
      setState(() {
        _oldPasswordError = viewModel.errorMessage;
      });
    } else if (viewModel.successMessage.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.successMessage)),
      );
      Navigator.of(context).pop();
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, String? errorText) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      errorText: errorText,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ganti Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Old Password
              TextField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: _buildInputDecoration('Password Lama', Icons.lock, _oldPasswordError),
              ),
              const SizedBox(height: 16),

              // New Password
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: _buildInputDecoration('Password Baru', Icons.lock_outline, _newPasswordError),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: _buildInputDecoration('Konfirmasi Password Baru', Icons.lock_outline, _confirmPasswordError),
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF755330), // Warna coklat tua
                    ),
                    onPressed: _validateForm,
                    child: const Text('Simpan'),
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
