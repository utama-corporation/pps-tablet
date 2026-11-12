import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_error.dart';
import '../model/spk_models.dart';
import '../repository/spk_repository.dart';
import '../widgets/spk_widgets.dart';

/// "Buat SPK Produksi": review the selected items, adjust Qty SPK per item,
/// add an optional note and submit to `POST /api/spk-barang-jadi`.
///
/// Pops with the created [SpkDocument] on success, or null when cancelled.
class SpkCreateDialog extends StatefulWidget {
  const SpkCreateDialog({
    super.key,
    required this.items,
    required this.repository,
  });

  final List<SpkStockItem> items;
  final SpkRepository repository;

  @override
  State<SpkCreateDialog> createState() => _SpkCreateDialogState();
}

class _Line {
  _Line(this.item)
    : qty = TextEditingController(text: spkQtyInput(item.recommendation));
  final SpkStockItem item;
  final TextEditingController qty;

  double? get value => spkParseQty(qty.text);

  /// Blocking validation message, or null when the qty can be submitted.
  String? get error {
    final v = value;
    if (qty.text.trim().isNotEmpty && v == null) {
      return 'Format qty tidak valid';
    }
    if (v == null || v <= 0) return 'Qty SPK harus lebih dari 0';
    if (!spkHasMaxTwoDecimals(v)) return 'Maksimal 2 angka desimal';
    return null;
  }

  bool get mpqWarning {
    final v = value;
    return error == null && v != null && !spkIsMpqMultiple(v, item.mpq);
  }
}

class _SpkCreateDialogState extends State<SpkCreateDialog> {
  static const _border = Color(0xFFE5E7EB);
  static const _muted = Color(0xFF6B778C);
  static const _ink = Color(0xFF172B4D);

  late final List<_Line> _lines = [for (final i in widget.items) _Line(i)];
  final _notes = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    for (final line in _lines) {
      line.qty.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  bool get _valid => _lines.isNotEmpty && _lines.every((l) => l.error == null);
  double get _total =>
      _lines.fold(0, (sum, l) => l.error == null ? sum + l.value! : sum);

  Future<void> _submit() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final created = await widget.repository.create(
        items: [
          for (final l in _lines) SpkCreateLine(idBJ: l.item.id, qty: l.value!),
        ],
        notes: _notes.text,
      );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _remove(_Line line) {
    setState(() => _lines.remove(line));
    line.qty.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 980,
          height: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SpkDialogHeader(
                icon: Icons.post_add_rounded,
                title: 'Buat SPK Produksi',
                subtitle: 'Periksa dan sesuaikan qty sebelum SPK dibuat',
                onClose: _busy ? null : () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoStrip(),
                      const SizedBox(height: 16),
                      SpkSectionTitle(
                        icon: Icons.list_alt_rounded,
                        title: 'Detail barang (${_lines.length})',
                      ),
                      const SizedBox(height: 8),
                      _buildLinesTable(),
                      if (_lines.any((l) => l.mpqWarning)) ...[
                        const SizedBox(height: 10),
                        const SpkNotice(
                          icon: Icons.warning_amber_rounded,
                          color: Color(0xFFB45309),
                          background: Color(0xFFFFF7ED),
                          message:
                              'Ada qty yang tidak kelipatan MPQ. Qty akan tetap dibuat sesuai input Anda.',
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('spk-create-notes'),
                        controller: _notes,
                        enabled: !_busy,
                        maxLength: 255,
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan (opsional)',
                          hintText: 'Contoh: produksi untuk stok bulan ini',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SpkNotice(
                          icon: Icons.error_outline_rounded,
                          color: const Color(0xFFB91C1C),
                          background: const Color(0xFFFEF2F2),
                          message: _error,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoStrip() {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 10,
        children: [
          SpkMetaItem(label: 'No. SPK', value: 'Otomatis'),
          SpkMetaItem(label: 'Tanggal', value: today),
          const SpkMetaItem(
            label: 'Status awal',
            value: 'OPEN',
            trailing: SpkStatusLozenge('OPEN'),
          ),
          const SpkMetaItem(
            label: 'Snapshot stok',
            value: 'Diambil server saat SPK disimpan',
          ),
        ],
      ),
    );
  }

  static const _wStock = 100.0, _wRec = 120.0, _wMpq = 90.0, _wQty = 150.0;

  Widget _headerCell(
    String text, {
    double? width,
    TextAlign align = TextAlign.left,
  }) {
    final label = Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.35,
        color: Color(0xFF44546F),
      ),
    );
    return width == null
        ? Expanded(child: label)
        : SizedBox(width: width, child: label);
  }

  Widget _buildLinesTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCDFE4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF7F8F9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _headerCell('BARANG'),
                _headerCell('STOK', width: _wStock, align: TextAlign.right),
                _headerCell(
                  'REKOMENDASI',
                  width: _wRec,
                  align: TextAlign.right,
                ),
                _headerCell('MPQ', width: _wMpq, align: TextAlign.right),
                const SizedBox(width: 16),
                _headerCell('QTY SPK', width: _wQty),
                const SizedBox(width: 48),
              ],
            ),
          ),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tidak ada barang. Tutup dialog lalu pilih barang dari tabel.',
                style: TextStyle(color: _muted),
              ),
            ),
          for (final (index, line) in _lines.indexed) _buildLine(index, line),
        ],
      ),
    );
  }

  Widget _buildLine(int index, _Line line) {
    final i = line.item;
    final error = line.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFBFC),
        border: const Border(top: BorderSide(color: Color(0xFFEBECF0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.name.isEmpty ? '—' : i.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${i.code.isEmpty ? '—' : i.code} · ${i.uom.isEmpty ? '—' : i.uom}',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    SpkStatusLozenge(i.status),
                  ],
                ),
              ],
            ),
          ),
          _numCell(
            spkQty(i.stock),
            _wStock,
            color: i.stock <= 0 ? const Color(0xFFB91C1C) : null,
          ),
          _numCell(
            spkQty(i.recommendation),
            _wRec,
            color: i.recommendation > 0 ? const Color(0xFFB45309) : null,
          ),
          _numCell(spkQty(i.mpq), _wMpq),
          const SizedBox(width: 16),
          SizedBox(
            width: _wQty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: ValueKey('spk-qty-${i.id}'),
                  controller: line.qty,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: i.uom.isEmpty ? null : i.uom,
                    border: const OutlineInputBorder(),
                    filled: error != null,
                    fillColor: const Color(0xFFFEF2F2),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: error != null
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFDCDFE4),
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  )
                else if (line.mpqWarning)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Belum kelipatan MPQ (${spkQty(i.mpq)})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: 'Hapus dari SPK',
              onPressed: _busy || _lines.length <= 1
                  ? null
                  : () => _remove(line),
              icon: const Icon(Icons.delete_outline_rounded),
              color: const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numCell(String text, double width, {Color? color}) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF44546F),
        ),
      ),
    ),
  );

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_lines.length} BARANG',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: _muted,
                  ),
                ),
                Text(
                  'Total Qty SPK: ${spkQty(_total)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const ValueKey('spk-create-submit'),
            onPressed: _busy || !_valid ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'Membuat SPK...' : 'Buat SPK'),
          ),
        ],
      ),
    );
  }
}
