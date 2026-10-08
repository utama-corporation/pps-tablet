import 'package:flutter/material.dart';

import '../../shared/widgets/production_bonggolan_output_tile.dart';
import '../../shared/widgets/production_reject_output_tile.dart';
import '../model/inject_output_model.dart';

/// Daftar label "Sisa Akhir Shift" (bonggolan & reject) yang behave seperti
/// tab output: user bebas menambah label baru kapan saja dan menghapus label
/// yang salah input — tidak seperti input batch yang hanya bisa sekali kirim.
///
/// Data diambil dari repository output (`/outputs/bonggolan`, `/outputs/reject`)
/// sehingga label yang sudah tercipta via batch maupun via dialog tambah
/// akan muncul di sini.
class SisaLabelEditableSection extends StatelessWidget {
  const SisaLabelEditableSection({
    super.key,
    required this.bonggolan,
    required this.reject,
    required this.accent,
    this.locked = false,
    this.onAddBonggolan,
    this.onAddReject,
    this.onDeleteBonggolan,
    this.onDeleteReject,
    this.onTapBonggolan,
    this.onTapReject,
  });

  final List<InjectBonggolanOutputItem> bonggolan;
  final List<InjectRejectOutputItem> reject;
  final Color accent;

  /// Produksi sudah terkunci/complete — tombol tambah disembunyikan, aksi
  /// hapus dimatikan. Daftar label tetap ditampilkan agar operator masih bisa
  /// melihat dan mencetak label yang sudah terlanjur dibuat.
  final bool locked;

  final VoidCallback? onAddBonggolan;
  final VoidCallback? onAddReject;
  final void Function(String noBonggolan)? onDeleteBonggolan;
  final void Function(String noReject)? onDeleteReject;
  final void Function(InjectBonggolanOutputItem item)? onTapBonggolan;
  final void Function(InjectRejectOutputItem item)? onTapReject;

  /// Penjelasan singkat supaya operator tahu di mana label ini tercatat.
  /// Label bonggolan/reject disimpan sebagai label produksi (terhubung ke
  /// nomor produksi), bukan ke jam tertentu — jadi digabung ke bucket terakhir
  /// baik di daftar ini maupun di ringkasan/cetak label bucket tersebut.
  static const _captionText =
      'Label di bawah tercatat untuk produksi ini (terhubung ke nomor produksi), '
      'bukan ke jam tertentu. Semua label ini ikut masuk ke bucket terakhir — '
      'cetak sekaligus lewat tombol "Cetak Label" di bucket tersebut.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Caption(locked: locked),
        const SizedBox(height: 6),
        _buildBonggolan(context),
        const SizedBox(height: 8),
        _buildReject(context),
      ],
    );
  }

  Widget _buildBonggolan(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            title: 'Bonggolan',
            icon: Icons.recycling_outlined,
            count: bonggolan.length,
            onAdd: onAddBonggolan,
            addLabel: 'Tambah Bonggolan',
          ),
          const SizedBox(height: 6),
          if (bonggolan.isEmpty)
            const Text(
              'Belum ada label bonggolan',
              style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in bonggolan)
                  SizedBox(
                    width: 148,
                    child: ProductionBonggolanOutputTile(
                      labelCode: o.noBonggolan,
                      namaJenis: o.namaBonggolan,
                      berat: o.berat,
                      printCount: o.hasBeenPrinted,
                      accentColor: accent,
                      onTap:
                          onTapBonggolan == null
                              ? null
                              : () => onTapBonggolan!(o),
                      onDelete:
                          onDeleteBonggolan == null
                              ? null
                              : () => onDeleteBonggolan!(o.noBonggolan),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReject(BuildContext context) {
    const rejectColor = Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: rejectColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rejectColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(
            title: 'Reject',
            icon: Icons.block_outlined,
            count: reject.length,
            color: rejectColor,
            onAdd: onAddReject,
            addLabel: 'Tambah Reject',
          ),
          const SizedBox(height: 6),
          if (reject.isEmpty)
            const Text(
              'Belum ada label reject',
              style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in reject)
                  SizedBox(
                    width: 148,
                    child: ProductionRejectOutputTile(
                      labelCode: o.noReject,
                      namaJenis: o.namaJenis,
                      berat: o.berat,
                      pcs: o.pcs,
                      printCount: o.hasBeenPrinted,
                      accentColor: rejectColor,
                      onTap:
                          onTapReject == null ? null : () => onTapReject!(o),
                      onDelete:
                          onDeleteReject == null
                              ? null
                              : () => onDeleteReject!(o.noReject),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _header({
    required String title,
    required IconData icon,
    required int count,
    required VoidCallback? onAdd,
    required String addLabel,
    Color? color,
  }) {
    final c = color ?? accent;
    return Row(
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 5),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c),
          ),
        ),
        const Spacer(),
        if (locked)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 11, color: c),
              const SizedBox(width: 3),
              Text(
                'Terkunci',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          )
        else
        SizedBox(
          height: 26,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: c,
              backgroundColor: Colors.white,
              side: BorderSide(color: c.withValues(alpha: 0.40)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.add, size: 13),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}

/// Catatan kecil di atas daftar label sisa — menjelaskan bahwa label
/// bonggolan/reject tidak terikat ke jam bucket.
class _Caption extends StatelessWidget {
  const _Caption({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.info_outline_rounded,
            size: 12,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              locked
                  ? 'Produksi sudah selesai dan terkunci. Label di bawah '
                        'menampilkan sisa akhir shift — tidak bisa ditambah '
                        'atau dihapus lagi.'
                  : SisaLabelEditableSection._captionText,
              style: const TextStyle(
                fontSize: 9,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
