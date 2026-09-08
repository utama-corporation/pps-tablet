import 'package:flutter/material.dart';

import '../../../../core/services/permission_storage.dart';
import '../../../../core/services/user_session_storage.dart';
import '../../../login/view/widgets/nik_binding_dialog.dart'
    show nikCompanyDisplayName;

/// Dialog informasi akun (read-only): data user dari response login
/// (nama, username, NIK, company, group) beserta seluruh hak akses.
/// Desain mengikuti gaya dialog "Ubah Password".
class AccountInfoDialog extends StatelessWidget {
  const AccountInfoDialog({super.key});

  static const _primary = Color(0xFF0D47A1);
  static const _fieldFill = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  Future<_AccountInfo> _load() async {
    final results = await Future.wait([
      UserSessionStorage.getUsername(fallback: '-'),
      UserSessionStorage.getFullName(),
      UserSessionStorage.getNik(),
      UserSessionStorage.getCompanyId(),
      UserSessionStorage.getUGroupName(),
      UserSessionStorage.getLastLoginAt(),
      PermissionStorage.getPermissions(),
    ]);
    return _AccountInfo(
      username: results[0] as String,
      fullName: results[1] as String?,
      nik: results[2] as String?,
      companyId: results[3] as String?,
      uGroupName: results[4] as String?,
      lastLoginAt: results[5] as DateTime?,
      permissions: List<String>.from(results[6] as List),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 8,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 660),
        child: FutureBuilder<_AccountInfo>(
          future: _load(),
          builder: (context, snap) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                if (!snap.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Flexible(child: _buildBody(snap.data!)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Header (identik gaya dengan dialog Ubah Password) ─────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 12, 20),
      decoration: const BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Informasi Akun',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Detail akun & hak akses Anda',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody(_AccountInfo info) {
    final displayName =
        (info.fullName ?? '').isNotEmpty ? info.fullName! : info.username;

    final infoRows = <_RowData>[
      _RowData('Nama Lengkap', info.fullName),
      _RowData('Username', info.username),
      _RowData('NIK', info.nik),
      _RowData(
        'Company',
        (info.companyId ?? '').isEmpty
            ? null
            : nikCompanyDisplayName(info.companyId),
      ),
      _RowData('Group', info.uGroupName),
      if (info.lastLoginAt != null)
        _RowData('Login Terakhir', _formatDateTime(info.lastLoginAt!)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Kartu profil ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _primary,
                  child: Text(
                    _initials(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${info.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          _sectionLabel('Detail Akun'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < infoRows.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: _border),
                  _InfoRow(label: infoRows[i].label, value: infoRows[i].value),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),
          Row(
            children: [
              _sectionLabel('Hak Akses'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${info.permissions.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (info.permissions.isEmpty)
            const Text(
              'Tidak ada hak akses.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              decoration: BoxDecoration(
                color: _fieldFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildPermissionGroups(info.permissions),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      );

  List<Widget> _buildPermissionGroups(List<String> permissions) {
    final groups = <String, List<String>>{};
    for (final p in permissions) {
      final idx = p.indexOf(':');
      final module = idx == -1 ? p : p.substring(0, idx);
      final action = idx == -1 ? p : p.substring(idx + 1);
      groups.putIfAbsent(module, () => []).add(action);
    }
    final modules = groups.keys.toList()..sort();

    return [
      for (final module in modules) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            module,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final action in groups[module]!..sort())
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String _formatDateTime(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _RowData {
  final String label;
  final String? value;
  const _RowData(this.label, this.value);
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (value ?? '').trim().isEmpty ? '-' : value!.trim(),
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfo {
  final String username;
  final String? fullName;
  final String? nik;
  final String? companyId;
  final String? uGroupName;
  final DateTime? lastLoginAt;
  final List<String> permissions;

  const _AccountInfo({
    required this.username,
    required this.fullName,
    required this.nik,
    required this.companyId,
    required this.uGroupName,
    required this.lastLoginAt,
    required this.permissions,
  });
}
