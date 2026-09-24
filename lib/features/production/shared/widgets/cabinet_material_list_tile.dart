import 'package:flutter/material.dart';

import '../models/cabinet_material_item.dart';

/// Tile material kabinet 3-baris (redesign):
///
/// ┌────────────────────────────────────────────┐
/// │ [icon] NamaBahanPendukung                 │
/// │        NoBahanPendukung                   │
/// │        123 PCS [icon_qty]        [delete]  │
/// └────────────────────────────────────────────┘
///
/// Baris **NoBahanPendukung** tampil saat ada label Bahan Pendukung (BP.):
/// baris temp memakai label hasil scan sesi ini (via VM), baris existing
/// memakai label yang tersimpan di DB (dikembalikan GET inputs).
///
/// Icon qty dipakai sebagai penanda baris qty (pengganti teks polos).
class CabinetMaterialListTile extends StatelessWidget {
  const CabinetMaterialListTile({
    super.key,
    required this.item,
    required this.isTemp,
    this.bahanPendukungLabels = const <String>[],
    this.onDeleteTemp,
    this.onDeleteExisting,
  });

  final CabinetMaterialItem item;

  /// true = baris temp (hasil scan/input manual sesi ini, belum disimpan).
  final bool isTemp;

  /// Daftar NoBahanPendukung (label BP.) milik material ini. Diisi via VM
  /// (getter [List<String> bahanPendukungLabelsFor]) untuk baris temp, atau
  /// dari item model untuk baris existing (tersimpan di DB).
  final List<String> bahanPendukungLabels;

  final VoidCallback? onDeleteTemp;
  final VoidCallback? onDeleteExisting;

  @override
  Widget build(BuildContext context) {
    final borderColor = isTemp
        ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
        : const Color(0xFFE2E6EA);
    final bgColor = isTemp ? const Color(0xFFFFFBEB) : Colors.white;
    final showNoBP = bahanPendukungLabels.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.category_outlined,
              size: 16,
              color: Colors.deepPurple.shade400,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.Nama ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showNoBP) ...[
                  const SizedBox(height: 2),
                  Text(
                    bahanPendukungLabels.join(', '),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.Jumlah ?? 0} ${item.namaUom ?? 'unit'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onDeleteTemp != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
              tooltip: 'Hapus temp',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDeleteTemp,
            )
          else if (onDeleteExisting != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.grey.shade400,
              ),
              tooltip: 'Hapus material',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDeleteExisting,
            ),
        ],
      ),
    );
  }
}
