// lib/features/label/bahan_pend_support/widgets/bahan_pend_support_header_table.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/atlas_data_table.dart';
import '../../../../common/widgets/atlas_paged_data_table.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../production/shared/models/label_usage_status.dart';
import '../model/bahan_pend_support_header_model.dart';
import '../view_model/bahan_pend_support_view_model.dart';

/// Tabel Label Bahan Pendukung.
///
/// Pakai [AtlasPagedDataTable] (bukan AtlasDataTable) supaya tabel bisa
/// discroll horizontal: jumlah kolom + lebar tetap membuat tabel lebih lebar
/// dari panel di tablet kecil, dan AtlasDataTable hanya bisa sharing ruang
/// sehingga teks kolom jadi sempit.
/// Pola ini sama dengan yang dipakai tabel Label Reject.
class BahanPendukungHeaderTable extends StatelessWidget {
  /// Merah untuk QTY label yang sudah terpakai.
  static const _qtyUsedColor = Color(0xFFC9372C);

  // Lebar tetap per kolom. Totalnya melebihi lebar panel sengaja, supaya
  // muncul scroll horizontal alih-alih kolom tergencet.
  static const _colNoWidth = 170.0;
  static const _colMaterialWidth = 260.0;
  static const _colQtyWidth = 100.0;
  static const _colPenerimaanWidth = 150.0;
  static const _colLokasiWidth = 110.0;
  static const _colKeteranganWidth = 220.0;
  static const _colPrintWidth = 90.0;

  final ValueChanged<BahanPendukungHeader> onItemTap;
  final void Function(BahanPendukungHeader header, Offset globalPosition)
  onItemLongPress;

  const BahanPendukungHeaderTable({
    super.key,
    required this.onItemTap,
    required this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BahanPendukungViewModel>(
      builder: (context, vm, _) {
        return AtlasPagedDataTable<BahanPendukungHeader>(
          pagingController: vm.pagingController,
          columns: _buildColumns(),
          selectedPredicate: (row) =>
              vm.selectedNoBahanPendukung == row.noBahanPendukung,
          onRowTap: onItemTap,
          onRowLongPress: onItemLongPress,
          firstPageError: _buildErrorState,
          noItems: (_) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Belum ada label Bahan Pendukung.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }

  List<AtlasTableColumn<BahanPendukungHeader>> _buildColumns() {
    return [
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'NO. LABEL',
        width: _colNoWidth,
        cellBuilder: (context, item, rowState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.noBahanPendukung,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: rowState.isSelected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: rowState.isSelected
                      ? const Color(0xFF0C66E4)
                      : Colors.black87,
                ),
                softWrap: true,
              ),
              if (item.usageStatus != LabelUsageStatus.belumDipakai) ...[
                const SizedBox(height: 4),
                _Badge(
                  text: item.usageStatus.label,
                  color: item.isFullyUsed
                      ? const Color(0xFFB71C1C)
                      : const Color(0xFFB26A00),
                ),
              ],
            ],
          );
        },
      ),
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'NAMA MATERIAL',
        width: _colMaterialWidth,
        cellBuilder: (context, item, rowState) {
          final nama = (item.namaCabinetMaterial ?? '').trim();
          return Text(
            nama.isEmpty ? '-' : nama,
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'QTY',
        width: _colQtyWidth,
        headerAlign: TextAlign.right,
        cellAlignment: Alignment.centerRight,
        cellBuilder: (context, item, rowState) {
          final q = item.qty;
          return Text(
            q == null ? '-' : formatPcsQty(q),
            // Label yang qty-nya sudah terpakai (penuh maupun sebagian) diberi
            // merah supaya operator langsung tahu stok label ini sudah dimakan
            // produksi.
            style: TextStyle(
              fontSize: 14,
              fontWeight: item.usageStatus == LabelUsageStatus.belumDipakai
                  ? null
                  : FontWeight.w700,
              color: item.usageStatus == LabelUsageStatus.belumDipakai
                  ? rowState.textColor
                  : _qtyUsedColor,
            ),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'NO. PENERIMAAN',
        width: _colPenerimaanWidth,
        cellBuilder: (context, item, rowState) {
          final s = (item.noPenerimaan ?? '').trim();
          return Text(
            s.isEmpty ? '-' : s,
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'LOKASI',
        width: _colLokasiWidth,
        cellBuilder: (context, item, rowState) {
          return Text(
            item.lokasi,
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'KETERANGAN',
        width: _colKeteranganWidth,
        cellBuilder: (context, item, rowState) {
          final s = (item.keterangan ?? '').trim();
          return Text(
            s.isEmpty ? '-' : s,
            style: TextStyle(fontSize: 13, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BahanPendukungHeader>(
        title: 'PRINT',
        width: _colPrintWidth,
        showDivider: false,
        cellBuilder: (context, item, rowState) {
          return Selector<LabelPrintLockSocketManager, _PrintCellState>(
            selector: (_, locks) => _PrintCellState(
              lock: locks.lockOf(item.noBahanPendukung),
              count: locks.printCountOf(item.noBahanPendukung),
            ),
            builder: (_, state, __) {
              final lock = state.lock;
              if (lock != null) {
                return Tooltip(
                  message: 'Sedang diprint oleh ${lock.displayUser}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB26A00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFB26A00).withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Text(
                      'Printing',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB26A00),
                      ),
                    ),
                  ),
                );
              }

              final count = state.count ?? item.hasBeenPrinted;
              if (count == 0) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C66E4).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF0C66E4).withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.print_rounded,
                      size: 12,
                      color: Color(0xFF0C66E4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${count}x',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0C66E4),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ];
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            context.read<BahanPendukungViewModel>().errorMessage,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PrintCellState {
  final LabelPrintLockInfo? lock;
  final int? count;

  const _PrintCellState({required this.lock, required this.count});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _PrintCellState &&
        other.lock == lock &&
        other.count == count;
  }

  @override
  int get hashCode => Object.hash(lock, count);
}