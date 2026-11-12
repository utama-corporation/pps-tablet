import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../common/widgets/atlas_data_table.dart';
import '../../../../common/widgets/atlas_paged_data_table.dart';
import '../../../../common/widgets/label_print_count_cell.dart';
import '../../../../core/utils/number_formatter.dart';
import '../model/barang_dagang_label.dart';

class BarangDagangHeaderTable extends StatelessWidget {
  final PagingController<int, BarangDagangLabel> pagingController;
  final String? selectedNoLabel;
  final ValueChanged<BarangDagangLabel>? onItemTap;
  final void Function(BarangDagangLabel item, Offset globalPosition)?
  onItemLongPress;

  const BarangDagangHeaderTable({
    super.key,
    required this.pagingController,
    this.selectedNoLabel,
    this.onItemTap,
    this.onItemLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AtlasPagedDataTable<BarangDagangLabel>(
      pagingController: pagingController,
      columns: _buildColumns(),
      selectedPredicate: (row) => row.code == selectedNoLabel,
      onRowTap: (row) => onItemTap?.call(row),
      onRowLongPress: (row, pos) => onItemLongPress?.call(row, pos),
    );
  }

  List<AtlasTableColumn<BarangDagangLabel>> _buildColumns() {
    return [
      AtlasTableColumn<BarangDagangLabel>(
        title: 'NO. LABEL',
        width: 170,
        cellBuilder: (context, item, rowState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.code,
                softWrap: true,
                style: TextStyle(
                  fontWeight: rowState.isSelected
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: rowState.isSelected
                      ? const Color(0xFF0C66E4)
                      : Colors.black87,
                ),
              ),
              if (item.used) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFB71C1C).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Terpakai',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB71C1C),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'NAMA BARANG',
        width: 250,
        cellBuilder: (context, item, rowState) {
          final nama = item.name.trim();
          return Text(
            nama.isEmpty ? '-' : nama,
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'SUPPLIER',
        width: 230,
        cellBuilder: (context, item, rowState) {
          final supplier = item.supplier.trim();
          return Text(
            supplier.isEmpty ? '-' : supplier,
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'PENERIMAAN',
        width: 190,
        cellBuilder: (context, item, rowState) {
          final receipt = item.receipt.trim();
          return Text(
            receipt.isEmpty ? '-' : receipt,
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'QTY',
        width: 95,
        headerAlign: TextAlign.right,
        cellAlignment: Alignment.centerRight,
        cellBuilder: (context, item, rowState) {
          return Text(
            formatPcsQty(item.qty),
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'SISA',
        width: 115,
        headerAlign: TextAlign.right,
        cellAlignment: Alignment.centerRight,
        cellBuilder: (context, item, rowState) {
          return Text(
            formatPcsQty(item.remainingQty),
            style: TextStyle(
              fontSize: 14,
              fontWeight: item.isPartial ? FontWeight.w700 : FontWeight.w500,
              color: item.isPartial ? Colors.red : rowState.textColor,
            ),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'LOKASI',
        width: 110,
        headerAlign: TextAlign.center,
        cellAlignment: Alignment.center,
        cellBuilder: (context, item, rowState) {
          return Text(
            _formatBlokLokasi(item.blok, item.idLokasi),
            style: TextStyle(fontSize: 14, color: rowState.textColor),
            softWrap: true,
          );
        },
      ),
      AtlasTableColumn<BarangDagangLabel>(
        title: 'PRINT',
        width: 72,
        horizontalPadding: 2,
        showDivider: false,
        cellBuilder: (context, item, rowState) {
          return LabelPrintCountCell(
            labelCode: item.code,
            rawPrintCount: item.printCount,
          );
        },
      ),
    ];
  }

  String _formatBlokLokasi(String blok, String idLokasi) {
    final hasBlok = blok.trim().isNotEmpty;
    final hasLokasi = idLokasi.trim().isNotEmpty;

    if (!hasBlok && !hasLokasi) {
      return '-';
    }

    return '$blok$idLokasi';
  }
}
