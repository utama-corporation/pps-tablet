import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stok_item_data.dart';

/// Header bar untuk section "Stok Item", konsisten dengan
/// [ProductionRiwayatHeader] pada riwayat produksi.
class StokItemHeader extends StatelessWidget {
  const StokItemHeader({
    super.key,
    this.onRefresh,
    this.title = 'Bahan Baku Proses',
  });

  final VoidCallback? onRefresh;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const Spacer(),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              color: const Color(0xFF9CA3AF),
              hoverColor: const Color(0xFFEFF6FF),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

/// List stok sisa (sak & berat) untuk section "Stok Item".
/// Generik atas [StokItemData] agar bisa dipakai untuk stok bahan baku
/// proses, stok washing, dsb.
class StokItemList<T extends StokItemData> extends StatelessWidget {
  const StokItemList({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onTap,
    this.oldestDateOf,
    this.showSakColumn = true,
    this.sakColumnLabel = 'SAK',
    this.showBeratColumn = true,
  });

  final List<T> items;
  final bool isLoading;
  final String? errorMessage;

  /// Dipanggil saat sebuah item stok di-tap — biasanya untuk menampilkan
  /// rincian label (per pallet/sak) dari item tersebut.
  final ValueChanged<T>? onTap;

  /// Jika disediakan, tanggal stok masuk paling awal ditampilkan sebagai
  /// subtitle di bawah nama — mis. untuk stok yang butuh perhatian karena
  /// sudah lama mengendap (bonggolan, dsb).
  final DateTime? Function(T item)? oldestDateOf;

  final bool showSakColumn;
  final String sakColumnLabel;

  /// Set `false` bila UOM item ini murni satuan ([sakSisa]) dan berat
  /// tidak relevan untuk ditampilkan — mis. Furniture WIP (Pcs).
  final bool showBeratColumn;

  bool _isEmpty(T item) {
    if (showSakColumn && showBeratColumn) {
      return item.sakSisa <= 0 && item.beratSisa <= 0;
    }
    if (showBeratColumn) return item.beratSisa <= 0;
    return item.sakSisa <= 0;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Gagal memuat stok item\n$errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data stok item',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }

    final sortedItems = [...items];
    mergeSort(sortedItems, compare: (a, b) {
      final aEmpty = _isEmpty(a);
      final bEmpty = _isEmpty(b);
      if (aEmpty == bEmpty) return 0;
      return aEmpty ? 1 : -1;
    });

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: sortedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = sortedItems[index];
        final isEmpty = _isEmpty(item);
        final oldestDate = isEmpty ? null : oldestDateOf?.call(item);

        final String qtyLabel;
        final String qtyValue;
        if (showSakColumn && showBeratColumn) {
          qtyLabel = 'Stok';
          qtyValue =
              '${item.sakSisa} $sakColumnLabel · '
              '${item.beratSisa.toStringAsFixed(2)} kg';
        } else if (showBeratColumn) {
          qtyLabel = 'Berat';
          qtyValue = '${item.beratSisa.toStringAsFixed(2)} kg';
        } else {
          qtyLabel = sakColumnLabel;
          qtyValue = '${item.sakSisa}';
        }

        return _StokItemRow(
          nama: item.nama,
          tanggalText: oldestDate == null
              ? '-'
              : DateFormat('dd MMM yyyy', 'id_ID').format(oldestDate.toLocal()),
          lokasiText: item.lokasi.trim().isEmpty ? '-' : item.lokasi,
          qtyLabel: qtyLabel,
          qtyValue: qtyValue,
          isEmpty: isEmpty,
          onTap: onTap == null ? null : () => onTap!(item),
        );
      },
    );
  }
}

const _kStokGreen = Color(0xFF059669);
const _kStokEmpty = Color(0xFFD1D5DB);

class _StokItemRow extends StatelessWidget {
  const _StokItemRow({
    required this.nama,
    required this.tanggalText,
    required this.lokasiText,
    required this.qtyLabel,
    required this.qtyValue,
    required this.isEmpty,
    required this.onTap,
  });

  final String nama;
  final String tanggalText;
  final String lokasiText;
  final String qtyLabel;
  final String qtyValue;
  final bool isEmpty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: isEmpty ? _kStokEmpty : _kStokGreen),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _StokMetaSection(
                        nama: nama,
                        tanggalText: tanggalText,
                        lokasiText: lokasiText,
                        qtyLabel: qtyLabel,
                        qtyValue: qtyValue,
                        qtyColor: isEmpty
                            ? const Color(0xFF9CA3AF)
                            : _kStokGreen,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empat section (Jenis / Tanggal / Lokasi / Qty) selaras dengan
/// `_MetaSection` pada [ProductionProduksiList] di riwayat produksi.
class _StokMetaSection extends StatelessWidget {
  const _StokMetaSection({
    required this.nama,
    required this.tanggalText,
    required this.lokasiText,
    required this.qtyLabel,
    required this.qtyValue,
    required this.qtyColor,
  });

  final String nama;
  final String tanggalText;
  final String lokasiText;
  final String qtyLabel;
  final String qtyValue;
  final Color qtyColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _StokMetaColumn(
                label: 'Jenis',
                value: nama,
                maxLines: null,
              ),
            ),
            Container(
              width: 1,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFFE5E7EB),
            ),
            Expanded(
              flex: 2,
              child: _StokMetaColumn(label: 'Tanggal', value: tanggalText),
            ),
            Container(
              width: 1,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFFE5E7EB),
            ),
            Expanded(
              flex: 2,
              child: _StokMetaLokasi(value: lokasiText),
            ),
            Container(
              width: 1,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFFE5E7EB),
            ),
            Expanded(
              flex: 2,
              child: _StokMetaColumn(
                label: qtyLabel,
                value: qtyValue,
                valueColor: qtyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StokMetaColumn extends StatelessWidget {
  const _StokMetaColumn({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF374151),
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Color valueColor;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Kolom Lokasi pada [_StokMetaSection] — badge biru (label "Lokasi" + chip)
/// konsisten dengan tampilan blok/lokasi pada tabel label.
class _StokMetaLokasi extends StatelessWidget {
  const _StokMetaLokasi({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Lokasi',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isPlaceholder ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isPlaceholder
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFBFDBFE),
            ),
          ),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isPlaceholder
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF1D4ED8),
            ),
          ),
        ),
      ],
    );
  }
}
