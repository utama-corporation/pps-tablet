import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../jenis_bonggolan/model/jenis_bonggolan_model.dart';
import '../../../jenis_bonggolan/view_model/jenis_bonggolan_view_model.dart';
import '../../../reject_type/model/reject_type_model.dart';
import '../../../reject_type/view_model/reject_type_view_model.dart';

/// Batas jenis per kategori dalam satu batch. Harus sama dengan
/// `MAX_SISA_JENIS_PER_KATEGORI` di backend (`inject-production-service.js`).
const int kMaxSisaJenisPerKategori = 5;

/// Satu baris input jenis bonggolan: jenis (wajib) + berat (wajib).
class SisaBonggolanRow {
  SisaBonggolanRow({this.jenis});

  JenisBonggolan? jenis;
  final TextEditingController beratCtrl = TextEditingController();

  void dispose() => beratCtrl.dispose();
}

/// Satu baris input jenis reject: jenis (wajib) + berat (wajib).
class SisaRejectRow {
  SisaRejectRow({this.jenis});

  RejectType? jenis;
  final TextEditingController beratCtrl = TextEditingController();

  void dispose() => beratCtrl.dispose();
}

/// Draft input "Sisa Akhir Shift" — user boleh menambah lebih dari satu jenis
/// bonggolan dan lebih dari satu jenis reject per batch.
///
/// Milik parent (bukan state milik widget) supaya nilainya bisa dibaca saat
/// submit tanpa perlu GlobalKey.
class SisaJenisDraft {
  SisaJenisDraft({int initialBonggolan = 1, int initialReject = 1}) {
    for (var i = 0; i < initialBonggolan; i++) {
      bonggolan.add(SisaBonggolanRow());
    }
    for (var i = 0; i < initialReject; i++) {
      reject.add(SisaRejectRow());
    }
  }

  final List<SisaBonggolanRow> bonggolan = [];
  final List<SisaRejectRow> reject = [];

  bool get canAddBonggolan => bonggolan.length < kMaxSisaJenisPerKategori;
  bool get canAddReject => reject.length < kMaxSisaJenisPerKategori;

  void addBonggolan() {
    if (!canAddBonggolan) return;
    bonggolan.add(SisaBonggolanRow());
  }

  void addReject() {
    if (!canAddReject) return;
    reject.add(SisaRejectRow());
  }

  void removeBonggolan(int index) => bonggolan.removeAt(index).dispose();
  void removeReject(int index) => reject.removeAt(index).dispose();

  /// id jenis yang sudah dipakai baris lain (untuk greying out di picker).
  Set<int> get usedBonggolanIds => {
    for (final r in bonggolan)
      if (r.jenis != null) r.jenis!.idBonggolan,
  };

  Set<int> get usedRejectIds => {
    for (final r in reject)
      if (r.jenis != null) r.jenis!.idReject,
  };

  static double? beratOf(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.replaceAll(',', '.'));

  /// Baris dianggap tersimpan hanya bila jenis dipilih DAN berat > 0.
  List<Map<String, dynamic>> get bonggolanPayload => [
    for (final r in bonggolan)
      if (r.jenis != null && (beratOf(r.beratCtrl) ?? 0) > 0)
        {'idBonggolan': r.jenis!.idBonggolan, 'berat': beratOf(r.beratCtrl)},
  ];

  List<Map<String, dynamic>> get rejectPayload => [
    for (final r in reject)
      if (r.jenis != null && (beratOf(r.beratCtrl) ?? 0) > 0)
        {'idReject': r.jenis!.idReject, 'berat': beratOf(r.beratCtrl)},
  ];

  bool get isEmpty => bonggolanPayload.isEmpty && rejectPayload.isEmpty;

  void dispose() {
    for (final r in bonggolan) {
      r.dispose();
    }
    for (final r in reject) {
      r.dispose();
    }
  }
}

/// Editor baris-repeatable untuk "Sisa Akhir Shift".
///
/// Tiap baris = [Jenis] + [Berat (kg)] + tombol hapus, dengan tombol
/// "+ Tambah Baris" per kategori. Jenis yang sudah dipakai baris lain
/// ditampilkan non-interaktif supaya user tidak bisa memilih duplikat.
class SisaJenisEditor extends StatefulWidget {
  const SisaJenisEditor({super.key, required this.draft, required this.accent});

  final SisaJenisDraft draft;

  /// Warna aksen section tempat editor ini berada (terminate / split time).
  final Color accent;

  @override
  State<SisaJenisEditor> createState() => _SisaJenisEditorState();
}

class _SisaJenisEditorState extends State<SisaJenisEditor> {
  SisaJenisDraft get draft => widget.draft;

  Future<void> _pickBonggolan(int index) async {
    final vm = context.read<JenisBonggolanViewModel>();
    await vm.ensureLoaded();
    if (!mounted) return;
    final picked = await showDialog<JenisBonggolan>(
      context: context,
      builder: (_) => _SisaJenisPickerDialog<JenisBonggolan>(
        title: 'Jenis Bonggolan',
        icon: Icons.recycling_outlined,
        items: vm.list,
        labelOf: (e) => e.namaBonggolan,
        subtitleOf: (_) => null,
        idOf: (e) => e.idBonggolan,
        excludedIds: {...draft.usedBonggolanIds}
          ..remove(draft.bonggolan[index].jenis?.idBonggolan),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final row = draft.bonggolan[index];
      if (row.jenis?.idBonggolan != picked.idBonggolan) {
        row.beratCtrl.clear();
      }
      row.jenis = picked;
    });
  }

  Future<void> _pickReject(int index) async {
    final vm = context.read<RejectTypeViewModel>();
    await vm.ensureLoaded();
    if (!mounted) return;
    final picked = await showDialog<RejectType>(
      context: context,
      builder: (_) => _SisaJenisPickerDialog<RejectType>(
        title: 'Jenis Reject',
        icon: Icons.recycling_outlined,
        items: vm.list,
        labelOf: (e) => e.namaReject,
        subtitleOf: (e) =>
            (e.itemCode ?? '').trim().isEmpty ? null : e.itemCode,
        idOf: (e) => e.idReject,
        excludedIds: {...draft.usedRejectIds}
          ..remove(draft.reject[index].jenis?.idReject),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final row = draft.reject[index];
      if (row.jenis?.idReject != picked.idReject) row.beratCtrl.clear();
      row.jenis = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          label: 'SISA AKHIR SHIFT (OPSIONAL)',
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(height: 8),
        _KategoriBlock(
          title: 'Bonggolan',
          icon: Icons.recycling_outlined,
          color: widget.accent,
          rowCount: draft.bonggolan.length,
          canAdd: draft.canAddBonggolan,
          onAdd: draft.addBonggolan,
          child: Column(
            children: [
              for (var i = 0; i < draft.bonggolan.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _JenisRow(
                  accent: widget.accent,
                  jenisName: draft.bonggolan[i].jenis?.namaBonggolan,
                  onPick: () => _pickBonggolan(i),
                  onRemove: draft.bonggolan.length > 1
                      ? () => setState(() => draft.removeBonggolan(i))
                      : null,
                  beratCtrl: draft.bonggolan[i].beratCtrl,
                  beratEnabled: draft.bonggolan[i].jenis != null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _KategoriBlock(
          title: 'Reject',
          icon: Icons.block_outlined,
          color: widget.accent,
          rowCount: draft.reject.length,
          canAdd: draft.canAddReject,
          onAdd: draft.addReject,
          child: Column(
            children: [
              for (var i = 0; i < draft.reject.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _JenisRow(
                  accent: widget.accent,
                  jenisName: draft.reject[i].jenis?.namaReject,
                  onPick: () => _pickReject(i),
                  onRemove: draft.reject.length > 1
                      ? () => setState(() => draft.removeReject(i))
                      : null,
                  beratCtrl: draft.reject[i].beratCtrl,
                  beratEnabled: draft.reject[i].jenis != null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Baris read-only untuk bucket yang sudah submitted — mengikuti jumlah jenis
/// bonggolan/reject yang benar-benar tercipta pada batch tersebut.
class SisaJenisReadOnlyList extends StatelessWidget {
  const SisaJenisReadOnlyList({
    super.key,
    required this.bonggolan,
    required this.reject,
  });

  final List<({String namaJenis, double? berat})> bonggolan;
  final List<({String namaJenis, double? berat})> reject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bonggolan.isNotEmpty) ...[
          _ReadOnlyKategori(
            title: 'Bonggolan',
            icon: Icons.recycling_outlined,
            rows: bonggolan,
          ),
          const SizedBox(height: 6),
        ],
        if (reject.isNotEmpty)
          _ReadOnlyKategori(
            title: 'Reject',
            icon: Icons.block_outlined,
            rows: reject,
          ),
      ],
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _KategoriBlock extends StatelessWidget {
  const _KategoriBlock({
    required this.title,
    required this.icon,
    required this.color,
    required this.rowCount,
    required this.canAdd,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final int rowCount;
  final bool canAdd;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 5),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '$rowCount/$kMaxSisaJenisPerKategori',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
              _AddRowButton(accent: color, enabled: canAdd, onTap: onAdd),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _AddRowButton extends StatelessWidget {
  const _AddRowButton({
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? accent : accent.withValues(alpha: 0.35);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              'Tambah',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JenisRow extends StatelessWidget {
  const _JenisRow({
    required this.accent,
    required this.jenisName,
    required this.onPick,
    required this.beratCtrl,
    required this.beratEnabled,
    this.onRemove,
  });

  final Color accent;
  final String? jenisName;
  final VoidCallback onPick;
  final TextEditingController beratCtrl;
  final bool beratEnabled;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: _JenisPickerField(
            selectedName: jenisName,
            accent: accent,
            onTap: onPick,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: _BeratField(
            ctrl: beratCtrl,
            enabled: beratEnabled,
            accent: accent,
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          _RemoveRowButton(accent: accent, onTap: onRemove!),
        ],
      ],
    );
  }
}

class _RemoveRowButton extends StatelessWidget {
  const _RemoveRowButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 32,
        width: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Icon(
          Icons.delete_outline,
          size: 14,
          color: Color(0xFFDC2626),
        ),
      ),
    );
  }
}

class _JenisPickerField extends StatelessWidget {
  const _JenisPickerField({
    required this.selectedName,
    required this.accent,
    required this.onTap,
  });

  final String? selectedName;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Jenis',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: hasValue ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasValue ? accent : accent.withValues(alpha: 0.30),
                width: hasValue ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? selectedName! : 'Pilih...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue ? accent : Colors.grey.shade400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 14,
                  color: hasValue ? accent : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BeratField extends StatelessWidget {
  const _BeratField({
    required this.ctrl,
    required this.enabled,
    required this.accent,
  });

  final TextEditingController ctrl;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Berat (kg)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 11,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.30)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: accent.withValues(alpha: 0.30)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: accent),
              ),
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _ReadOnlyKategori extends StatelessWidget {
  const _ReadOnlyKategori({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<({String namaJenis, double? berat})> rows;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 5),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: _ReadOnlyJenisField(
                    namaJenis: rows[i].namaJenis,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _ReadOnlyBeratField(
                    berat: rows[i].berat,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyJenisField extends StatelessWidget {
  const _ReadOnlyJenisField({required this.namaJenis, required this.color});

  final String? namaJenis;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Jenis',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: namaJenis != null
                ? const Color(0xFF374151)
                : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  namaJenis?.isNotEmpty == true ? namaJenis! : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: namaJenis?.isNotEmpty == true
                        ? color
                        : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyBeratField extends StatelessWidget {
  const _ReadOnlyBeratField({required this.berat, required this.color});

  final double? berat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Berat (kg)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: berat != null
                ? const Color(0xFF374151)
                : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Text(
            berat != null ? berat!.toStringAsFixed(1) : '-',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: berat != null ? color : Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Picker jenis dengan dukungan pengecualian — jenis yang sudah dipakai baris
/// lain ditampilkan non-interaktif (abu-abu + cent) supaya user melihat
/// jenismya memang ada tapi tidak bisa dipilih dua kali.
class _SisaJenisPickerDialog<T> extends StatelessWidget {
  const _SisaJenisPickerDialog({
    required this.title,
    required this.icon,
    required this.items,
    required this.labelOf,
    required this.subtitleOf,
    required this.idOf,
    required this.excludedIds,
  });

  final String title;
  final IconData icon;
  final List<T> items;
  final String Function(T) labelOf;
  final String? Function(T) subtitleOf;
  final int Function(T) idOf;
  final Set<int> excludedIds;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF92400E);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E6EA)),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Tidak ada data',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFFE2E6EA),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final sub = subtitleOf(item);
                    final isUsed = excludedIds.contains(idOf(item));
                    return InkWell(
                      onTap: isUsed ? null : () => Navigator.of(ctx).pop(item),
                      child: Opacity(
                        opacity: isUsed ? 0.45 : 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      labelOf(item),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    if (sub != null && sub.isNotEmpty)
                                      Text(
                                        sub,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                isUsed
                                    ? Icons.check_rounded
                                    : Icons.chevron_right,
                                size: 18,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
