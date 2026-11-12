import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/user_session_storage.dart';
import '../../home/view/home_screen.dart' show BerandaColors;
import '../model/user_profile_model.dart';
import '../view_model/user_profile_view_model.dart';

/// Profil screen: account actions. There is no stored username/role from
/// login yet, so this deliberately shows a generic account label instead
/// of fabricating identity data.
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BerandaColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 18,
              20,
              22,
            ),
            decoration: const BoxDecoration(
              color: BerandaColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profil',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Akun Pengguna',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                const _UserCard(),
                const SizedBox(height: 12),
                const _UserDetailsCard(),
                const SizedBox(height: 16),
                const _ChangePasswordCard(),
          const SizedBox(height: 10),
          _ProfileAction(
            icon: Icons.logout_rounded,
            label: 'Keluar',
            danger: true,
            onTap: () => _confirmLogout(context),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final dangerColor = const Color(0xFFB91C1C);
    final color = danger ? dangerColor : BerandaColors.ink;
    return Material(
      color: danger ? const Color(0xFFFEF2F2) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger ? const Color(0xFFFECACA) : BerandaColors.border,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? const Color(0xFFF87171) : BerandaColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard();

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  String? _fullName;
  String? _username;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fullName = await UserSessionStorage.getFullName();
    final username = await UserSessionStorage.getUsername(fallback: '-');
    final trimmedName = fullName?.trim();
    if (!mounted) return;
    setState(() {
      _fullName =
          (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName;
      _username = username.trim();
      _loaded = true;
    });
  }

  String get _initials {
    final source = (_fullName ?? _username ?? 'U').trim();
    final words =
        source.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return 'U';
    if (words.length == 1) {
      final word = words.single;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BerandaColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: !_loaded
          ? const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          : Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: BerandaColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName ?? _username ?? 'Pengguna',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: BerandaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${_username ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: BerandaColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserDetailsCard extends StatefulWidget {
  const _UserDetailsCard();

  @override
  State<_UserDetailsCard> createState() => _UserDetailsCardState();
}

class _UserDetailsCardState extends State<_UserDetailsCard> {
  List<(String, String)>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fullName = await UserSessionStorage.getFullName();
    final username = await UserSessionStorage.getUsername(fallback: '-');
    final nik = await UserSessionStorage.getNik();
    final company = await UserSessionStorage.getCompanyId();
    final group = await UserSessionStorage.getUGroupName();
    final lastLogin = await UserSessionStorage.getLastLoginAt();
    final rows = <(String, String)>[
      ('Nama Lengkap', _orDash(fullName)),
      ('Username', username.trim().isEmpty ? '-' : username.trim()),
      ('NIK', _orDash(nik)),
      ('Company', _orDash(company)),
      ('Group', _orDash(group)),
      (
        'Login Terakhir',
        lastLogin == null
            ? '-'
            : DateFormat('dd MMMM yyyy, HH:mm', 'id_ID')
                .format(lastLogin.toLocal()),
      ),
    ];
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  static String _orDash(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? '-' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BerandaColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: rows == null
          ? const SizedBox(
              height: 230,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i != 0) const Divider(height: 1, color: BerandaColors.border),
                  _DetailRow(label: rows[i].$1, value: rows[i].$2),
                ],
              ],
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: BerandaColors.slate,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BerandaColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _oldPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  bool _submitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _oldPasswordError = oldPassword.isEmpty ? 'Password lama harus diisi!' : null;
      _newPasswordError = newPassword.isEmpty ? 'Password baru harus diisi!' : null;
      _confirmPasswordError = confirmPassword.isEmpty
          ? 'Konfirmasi password harus diisi!'
          : (newPassword != confirmPassword
              ? 'Konfirmasi tidak cocok dengan password baru!'
              : null);
    });

    if (_oldPasswordError != null ||
        _newPasswordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    setState(() => _submitting = true);
    final viewModel = context.read<UserProfileViewModel>();
    await viewModel.changePassword(
      userProfile: UserProfileModel(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (viewModel.errorMessage.isNotEmpty) {
      setState(() => _oldPasswordError = viewModel.errorMessage);
      return;
    }
    if (viewModel.successMessage.isNotEmpty) {
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.successMessage)),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon, String? errorText) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      errorText: errorText,
      isDense: true,
      filled: true,
      fillColor: BerandaColors.background,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BerandaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BerandaColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BerandaColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: BerandaColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: BerandaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ganti Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: BerandaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _oldPasswordController,
            obscureText: true,
            decoration: _decoration(
              'Password Lama',
              Icons.lock_outline_rounded,
              _oldPasswordError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: _decoration(
              'Password Baru',
              Icons.lock_outline_rounded,
              _newPasswordError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: _decoration(
              'Konfirmasi Password Baru',
              Icons.lock_reset_rounded,
              _confirmPasswordError,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: BerandaColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Ganti Password'),
            ),
          ),
        ],
      ),
    );
  }
}
