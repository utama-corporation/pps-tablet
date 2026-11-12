import 'package:flutter/material.dart';

import '../model/master_user_models.dart';

class UserRowPopover extends StatelessWidget {
  const UserRowPopover({
    super.key,
    required this.user,
    required this.canUpdate,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final MasterUser user;
  final bool canUpdate;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0C66E4);
    const border = Color(0xFFDCDFE4);

    final divider = const Divider(height: 0, thickness: 0.8, color: border);

    Widget tile({
      required IconData icon,
      required String label,
      required bool enabled,
      required VoidCallback onTap,
      String? tooltipWhenDisabled,
      Color color = blue,
    }) {
      return Tooltip(
        message: enabled ? label : tooltipWhenDisabled ?? '',
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? color : Colors.grey.shade400,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? const Color(0xFF172B4D)
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      child: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: const Color(0xFF091E42).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFE9F2FF),
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: blue.withValues(alpha: 0.24)),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: blue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172B4D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.fullName.isNotEmpty)
                          Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF44546F),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            tile(
              icon: Icons.edit_outlined,
              label: 'Ubah',
              enabled: canUpdate,
              tooltipWhenDisabled: 'Tidak punya izin mengubah',
              onTap: () {
                onClose();
                onEdit();
              },
            ),
            divider,
            tile(
              icon: Icons.delete_outline_rounded,
              label: 'Hapus',
              enabled: canDelete,
              tooltipWhenDisabled: 'Tidak punya izin menghapus',
              color: const Color(0xFFC9372C),
              onTap: () {
                onClose();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
